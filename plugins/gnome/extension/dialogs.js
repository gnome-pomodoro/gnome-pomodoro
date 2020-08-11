/*
 * Copyright (c) 2011-2017 gnome-pomodoro contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */

const Signals = imports.signals;

const Atk = imports.gi.Atk;
const Clutter = imports.gi.Clutter;
const GLib = imports.gi.GLib;
const GObject = imports.gi.GObject;
const Meta = imports.gi.Meta;
const St = imports.gi.St;
const Pango = imports.gi.Pango;

const GrabHelper = imports.ui.grabHelper;
const Layout = imports.ui.layout;
const Lightbox = imports.ui.lightbox;
const Main = imports.ui.main;

const Params = imports.misc.params;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Config = Extension.imports.config;
const Timer = Extension.imports.timer;
const Utils = Extension.imports.utils;

const Gettext = imports.gettext.domain(Config.GETTEXT_PACKAGE);
const _ = Gettext.gettext;
const ngettext = Gettext.ngettext;


/* Time between user input events before making dialog modal.
 * Value is a little higher than:
 *   - slow typing speed of 23 words per minute which translates
 *     to 523 miliseconds between key presses
 *   - moderate typing speed of 35 words per minute, 343 miliseconds.
 */
const IDLE_TIME_TO_PUSH_MODAL = 600;
const PUSH_MODAL_TIME_LIMIT = 1000;
const PUSH_MODAL_RATE = Clutter.get_default_frame_rate();
const MOTION_DISTANCE_TO_CLOSE = 20;

const IDLE_TIME_TO_OPEN = 60000;
const IDLE_TIME_TO_CLOSE = 600;
const MIN_DISPLAY_TIME = 500;

const FADE_IN_TIME = 200;
const FADE_IN_OPACITY = 0.45;

const FADE_OUT_TIME = 200;

const OPEN_WHEN_IDLE_MIN_REMAINING_TIME = 3.0;

// A single pass blur approximation, with hacky brightness param
const BLUR_FRAGMENT_SHADER = '\
uniform sampler2D tex; \
uniform float x_step, y_step, factor, brightness; \
\
const float[7] weights = float[7](0.1452444, 0.1314128, 0.1115940, 0.0831466, 0.0543562,  0.0311780,  0.0156902); \
const float[7] offsets = float[7](0.0000000, 2.4876390, 4.4711854, 6.4547903, 8.4384988, 10.4223371, 12.4063545); \
\
void main () { \
  vec2 uv = vec2(cogl_tex_coord_in[0].st); \
  vec2 pixel_size = vec2(x_step * factor, y_step * factor); \
  vec4 color = vec4(0.0); \
  color += weights[0] * texture2D(tex, uv); \
  for (int i=1; i < 7; i++) { \
    color += \
      weights[i] * texture2D(tex, uv - pixel_size * offsets[i]) + \
      weights[i] * texture2D(tex, uv + pixel_size * offsets[i]); \
  } \
  color.rgb *= 1.0 - (1.0 - sqrt(brightness)) * factor; \
  cogl_color_out = color; \
}';


var State = {
    OPENED: 0,
    CLOSED: 1,
    OPENING: 2,
    CLOSING: 3
};


var BlurEffect = GObject.registerClass({
    Properties: {
        'orientation': GObject.ParamSpec.enum(
            'orientation', 'orientation', 'orientation',
            GObject.ParamFlags.READWRITE,
            Clutter.Orientation, Clutter.Orientation.HORIZONTAL
        ),
        'brightness': GObject.ParamSpec.float(
            'brightness', 'brightness', 'brightness',
            GObject.ParamFlags.READWRITE,
            0, 1, 1
        ),
        'factor': GObject.ParamSpec.float(
            'factor', 'factor', 'factor',
            GObject.ParamFlags.READWRITE,
            0, 1, 0
        ),
    },
}, class PomodoroBlurEffect extends Clutter.ShaderEffect {
    _init(params) {
        params = Params.parse(params, {
            orientation: Clutter.Orientation.HORIZONTAL,
            brightness: 1.0,
            factor: 0.0,
        });

        this._orientation = undefined;
        this._brightness = undefined;
        this._factor = undefined;

        super._init({ shader_type: Clutter.ShaderType.FRAGMENT_SHADER });

        this.set_shader_source(BLUR_FRAGMENT_SHADER);

        this.orientation = params.orientation;
        this.brightness = params.brightness;
        this.factor = params.factor;
    }

    get brightness() {
        return this._brightness;
    }

    set brightness(value) {
        if (this._brightness == value)
            return;
        this._brightness = value;
        this.set_uniform_value('brightness', GObject.Float(this._brightness));
        this.notify('brightness');
    }

    get factor() {
        return this._factor;
    }

    set factor(value) {
        if (this._factor == value)
            return;
        this._factor = value;
        this.set_uniform_value('factor', GObject.Float(this._factor));
        this.notify('factor');
    }

    get orientation() {
        return this._orientation;
    }

    set orientation(value) {
        if (this._orientation == value)
            return;
        this._orientation = value;
        this.notify('orientation');
    }

    vfunc_pre_paint(context) {
        let res = super.vfunc_pre_paint(context);
        let [success, width, height] = this.get_target_size();

        if (success) {
            // Actually we don't blur horizontally / vertically, but diagonally
            if (this.orientation != Clutter.Orientation.HORIZONTAL) {
                this.set_uniform_value('x_step', GObject.Float(1.0 / width));
                this.set_uniform_value('y_step', GObject.Float(1.0 / height));
            }
            else {
                this.set_uniform_value('x_step', GObject.Float(-1.0 / width));
                this.set_uniform_value('y_step', GObject.Float(1.0 / height));
            }
        }
        else {
            this.set_uniform_value('x_step', GObject.Float(0.0));
            this.set_uniform_value('y_step', GObject.Float(0.0));
        }

        return res;
    }
});


var BlurredLightbox = GObject.registerClass(
class extends Lightbox.Lightbox {
    _init(container, params) {
        params.radialEffect = false;

        super._init(container, params);

        if (Clutter.feature_available(Clutter.FeatureFlags.SHADERS_GLSL)) {
            // Clone the group that contains all of UI on the screen.  This is the
            // chrome, the windows, etc.
            let uiGroupClone = new Clutter.Clone({ source: Main.uiGroup,
                                                   clip_to_allocation: true });
            uiGroupClone.add_effect_with_name('blur1',
                new BlurEffect({
                    orientation: Clutter.Orientation.HORIZONTAL,
                    brightness: this._fadeFactor,
                    factor: 0.0,
                }));
            uiGroupClone.add_effect_with_name('blur2',
                new BlurEffect({
                    orientation: Clutter.Orientation.VERTICAL,
                    brightness: this._fadeFactor,
                    factor: 0.0,
                }));

            this.set_child(uiGroupClone);

            this._uiGroup = uiGroupClone;

            this.set({ opacity: 255 });
        }
        else {
            this._uiGroup = null;
        }

        this.add_style_class_name('extension-pomodoro-lightbox');
    }

    lightOn(fadeInTime) {
        this.remove_all_transitions();

        let easeProps = {
            duration: 0,  // fadeInTime || 0,  // FIXME: since 3.36 only one effect is being animated
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
        };

        let onComplete = () => {
            this._active = true;
            this.notify('active');
        };

        this.show();

        if (this._uiGroup) {
            this._uiGroup.remove_all_transitions();

            this._uiGroup.ease_property(
                '@effects.blur1.factor', 1.0, easeProps);
            this._uiGroup.ease_property(
                '@effects.blur2.factor', 1.0, Object.assign({ onComplete }, easeProps));
        } else {
            this.ease(Object.assign(easeProps, {
                opacity: 255 * this._fadeFactor,
                onComplete,
            }));
        }
    }

    lightOff(fadeOutTime) {
        this.remove_all_transitions();

        this._active = false;
        this.notify('active');

        let easeProps = {
            duration: 0,  // fadeOutTime || 0, // FIXME: since 3.36 only one effect is being animated
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
        };

        let onComplete = () => this.hide();

        if (this._uiGroup) {
            this._uiGroup.remove_all_transitions();

            this._uiGroup.ease_property(
                '@effects.blur1.factor', 0.0, easeProps);
            this._uiGroup.ease_property(
                '@effects.blur2.factor', 0.0, Object.assign({ onComplete }, easeProps));
        } else {
            this.ease(Object.assign(easeProps, { opacity: 0, onComplete }));
        }
    }
});


/**
 * ModalDialog class based on ModalDialog from GNOME Shell. We need our own
 * class to have more event signals, different fade in/out times, and different
 * event blocking behavior.
 */
var ModalDialog = class {
    constructor() {
        this.state = State.CLOSED;

        this._idleMonitor          = Meta.IdleMonitor.get_core();
        this._pushModalDelaySource = 0;
        this._pushModalWatchId     = 0;
        this._pushModalSource      = 0;
        this._pushModalTries       = 0;

        this._monitorConstraint = new Layout.MonitorConstraint();
        this._stageConstraint = new Clutter.BindConstraint({
                                       source: global.stage,
                                       coordinate: Clutter.BindCoordinate.ALL });

        this.actor = new St.Widget({ style_class: 'extension-pomodoro-dialog',
                                     accessible_role: Atk.Role.DIALOG,
                                     layout_manager: new Clutter.BinLayout(),
                                     visible: false,
                                     opacity: 0 });
        this.actor._delegate = this;
        this.actor.add_constraint(this._stageConstraint);
        this.actor.connect('destroy', this._onActorDestroy.bind(this));

        // Modal dialogs are fixed width and grow vertically; set the request
        // mode accordingly so wrapped labels are handled correctly during
        // size requests.
        this._layout = new St.Widget({ layout_manager: new Clutter.BinLayout() });
        this._layout.add_constraint(this._monitorConstraint);

        this.actor.add_actor(this._layout);

        this._lightbox = new BlurredLightbox(this.actor,
                                             { fadeFactor: FADE_IN_OPACITY,
                                               inhibitEvents: false });
        this._lightbox.highlight(this._layout);

        this._grabHelper = new GrabHelper.GrabHelper(this.actor);
        this._grabHelper.addActor(this._lightbox);

        global.stage.add_actor(this.actor);
        global.focus_manager.add_group(this.actor);
    }

    get isOpened() {
        return this.state == State.OPENED || this.state == State.OPENING;
    }

    _addMessageTray() {
        let messageTray = Main.messageTray;

        messageTray.ref();

        Main.layoutManager.removeChrome(messageTray);

        global.stage.add_child(messageTray);

        messageTray.unref();
        messageTray.bannerBlocked = false;
    }

    _removeMessageTray() {
        let messageTray = Main.messageTray;

        messageTray.ref();

        global.stage.remove_child(messageTray);

        Main.layoutManager.addChrome(messageTray, { affectsInputRegion: false });

        messageTray.unref();
    }

    open(animate) {
        if (this.state == State.OPENED || this.state == State.OPENING) {
            return;
        }

        this.state = State.OPENING;

        if (this._pushModalDelaySource == 0) {
            this._pushModalDelaySource = GLib.timeout_add(
                        GLib.PRIORITY_DEFAULT,
                        Math.max(MIN_DISPLAY_TIME - IDLE_TIME_TO_PUSH_MODAL, 0),
                        this._onPushModalDelayTimeout.bind(this));
        }

        // fallback to global.screen.get_current_monitor() for mutter < 3.29
        this._monitorConstraint.index = typeof(global.display) === 'object' && typeof(global.display.get_current_monitor) !== 'undefined'
            ? global.display.get_current_monitor() : global.screen.get_current_monitor();

        global.stage.set_child_above_sibling(this.actor, null);
        this.actor.show();

        this.actor.remove_all_transitions();

        this._addMessageTray();

        if (animate) {
            this._lightbox.lightOn(FADE_IN_TIME);
            this.actor.ease({
                opacity: 255,
                duration: FADE_IN_TIME,
                mode: Clutter.Animation.EASE_OUT_QUAD,
                onComplete: () => {
                    if (this.state == State.OPENING) {
                        this.state = State.OPENED;
                        this.emit('opened');
		    }
                }
            });
            this.emit('opening');
        }
        else {
            this._lightbox.lightOn();
            this.actor.opacity = 255;

            this.state = State.OPENED;

            this.emit('opening');
            this.emit('opened');
        }
    }

    close(animate) {
        this._cancelOpenWhenIdle();

        if (this.state == State.CLOSED || this.state == State.CLOSING) {
            return;
        }

        this.state = State.CLOSING;
        this.popModal();

        this.actor.remove_all_transitions();

        if (animate) {
            this._lightbox.lightOff(FADE_OUT_TIME);
            this.actor.ease({
                opacity: 0,
                duration: FADE_OUT_TIME,
                mode: Clutter.Animation.EASE_OUT_QUAD,
                onComplete: () => {
                    if (this.state == State.CLOSING) {
                        this.state = State.CLOSED;
                        this.actor.hide();

                        this._removeMessageTray();

                        this.emit('closed');
		    }
                }
            });
            this.emit('closing');
        }
        else {
            this.actor.opacity = 0;
            this.actor.hide();
            this._lightbox.lightOff();

            this.state = State.CLOSED;

            this._removeMessageTray();

            this.emit('closing');
            this.emit('closed');
        }
    }

    _onPushModalDelayTimeout() {
        /* Don't become modal and block events just yet,
         * wait until user becomes idle.
         */
        if (this._pushModalWatchId == 0) {
            this._pushModalWatchId = this._idleMonitor.add_idle_watch(IDLE_TIME_TO_PUSH_MODAL,
                (monitor) => {
                    if (this._pushModalWatchId) {
                        this._idleMonitor.remove_watch(this._pushModalWatchId);
                        this._pushModalWatchId = 0;
                    }
                    this.pushModal();
                });
        }

        this._pushModalDelaySource = 0;
        return GLib.SOURCE_REMOVE;
    }

    _pushModal() {
        if (this.state == State.CLOSED || this.state == State.CLOSING) {
            return false;
        }

        return this._grabHelper.grab({
            actor: this._lightbox,
            focus: this._lightbox,
            onUngrab: this._onUngrab.bind(this)
        });
    }

    _onPushModalTimeout() {
        if (this.state == State.CLOSED || this.state == State.CLOSING) {
            this._pushModalSource = 0;
            return GLib.SOURCE_REMOVE;
        }

        this._pushModalTries += 1;

        if (this._pushModal()) {
            this._pushModalSource = 0;
            return GLib.SOURCE_REMOVE; /* dialog finally opened */
        }

        if (this._pushModalTries > PUSH_MODAL_TIME_LIMIT * PUSH_MODAL_RATE) {
            this.close(true);
            this._pushModalSource = 0;
            return GLib.SOURCE_REMOVE; /* dialog can't become modal */
        }

        return GLib.SOURCE_CONTINUE;
    }

    pushModal() {
        if (this.state == State.CLOSED || this.state == State.CLOSING) {
            return;
        }

        this._disconnectSignals();

        this._lightbox.reactive = true;

        // this._grabHelper.ignoreRelease();

        /* delay pushModal to ignore current events */
        GLib.idle_add(
            GLib.PRIORITY_DEFAULT,
            () => {
                this._pushModalTries = 1;

                if (this._pushModal()) {
                    /* dialog became modal */
                }
                else {
                    this._pushModalSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT,
                                                             Math.floor(1000 / PUSH_MODAL_RATE),
                                                             this._onPushModalTimeout.bind(this));
                }

                return GLib.SOURCE_REMOVE;
            });
    }

    /**
     * Drop modal status without closing the dialog; this makes the
     * dialog insensitive as well, so it needs to be followed shortly
     * by either a close() or a pushModal()
     */
    popModal() {
        try {
            if (this._grabHelper.isActorGrabbed(this._lightbox)) {
                this._grabHelper.ungrab({
                    actor: this._lightbox
                });
            }
        }
        catch (error) {
            Utils.logWarning(error.message);
        }

        this._disconnectSignals();
    }

    _disconnectSignals() {
        if (this._pushModalDelaySource) {
            GLib.source_remove(this._pushModalDelaySource);
            this._pushModalDelaySource = 0;
        }

        if (this._pushModalSource) {
            GLib.source_remove(this._pushModalSource);
            this._pushModalSource = 0;
        }

        if (this._pushModalWatchId) {
            this._idleMonitor.remove_watch(this._pushModalWatchId);
            this._pushModalWatchId = 0;
        }
    }

    _onUngrab() {
        this.close(true);
    }

    _onActorDestroy() {
        if (this._destroyed)
            return;
        this._destroyed = true;

        this.close(false);

        this.actor._delegate = null;

        this.emit('destroy');
    }

    destroy() {
        this.actor.destroy();
    }
};
Signals.addSignalMethods(ModalDialog.prototype);


var PomodoroEndDialog = class extends ModalDialog {
    constructor(timer) {
        super();

        this.timer = timer;
        this.description = _("It's time to take a break");

        this._openWhenIdleWatchId        = 0;
        this._closeWhenActiveDelaySource = 0;
        this._closeWhenActiveIdleWatchId = 0;
        this._actorMappedId              = 0;
        this._timerUpdateId              = 0;
        this._eventId                    = 0;
        this._styleChangedId             = 0;

        this._minutesLabel = new St.Label({
            x_expand: true,
            x_align: Clutter.ActorAlign.END,
        });
        this._separatorLabel = new St.Label({
            text: ":",
        });
        this._secondsLabel = new St.Label({
            x_expand: true,
            x_align: Clutter.ActorAlign.START,
        });

        let hbox = new St.BoxLayout({ vertical: false, style_class: 'extension-pomodoro-dialog-timer' });
        hbox.add_actor(this._minutesLabel);
        hbox.add_actor(this._separatorLabel);
        hbox.add_actor(this._secondsLabel);

        this._descriptionLabel = new St.Label({
            style_class: 'extension-pomodoro-dialog-description',
            text: this.description,
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._descriptionLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this._descriptionLabel.clutter_text.line_wrap = true;

        let box = new St.BoxLayout({ style_class: 'extension-pomodoro-dialog-box',
                                     vertical: true });
        box.add_actor(hbox);
        box.add_actor(this._descriptionLabel);
        this._layout.add_actor(box);

        this._actorMappedId = this.actor.connect('notify::mapped', this._onActorMappedChanged.bind(this));

        this.connect('closing', this._onClosing.bind(this));
        this.connect('destroy', this._onDestroy.bind(this));
    }

    _onActorMappedChanged(actor) {
        if (actor.mapped) {
            if (!this._styleChangedId) {
                this._styleChangedId = this._secondsLabel.connect('style-changed', this._onStyleChanged.bind(this));
                this._onStyleChanged(this._secondsLabel);
            }
            if (!this._timerUpdateId) {
                this._timerUpdateId = this.timer.connect('update', this._onTimerUpdate.bind(this));
                this._onTimerUpdate();
            }
        }
        else {
            if (this._timerUpdateId) {
                this.timer.disconnect(this._timerUpdateId);
                this._timerUpdateId = 0;
            }
        }
    }

    _onStyleChanged(actor) {
        let themeNode = actor.get_theme_node();
        let font      = themeNode.get_font();
        let context   = actor.get_pango_context();
        let metrics   = context.get_metrics(font, context.get_language());
        let digitWidth = metrics.get_approximate_digit_width() / Pango.SCALE;

        this._secondsLabel.natural_width = 2 * digitWidth;
    }

    _onTimerUpdate() {
        if (this.timer.isBreak()) {
            let remaining = Math.max(this.timer.getRemaining(), 0.0);
            let minutes   = Math.floor(remaining / 60);
            let seconds   = Math.floor(remaining % 60);

            /* method may be called while label actor got destroyed */
            if (this._minutesLabel.clutter_text) {
                this._minutesLabel.clutter_text.set_text('%d'.format(minutes));
            }
            if (this._secondsLabel.clutter_text) {
                this._secondsLabel.clutter_text.set_text('%02d'.format(seconds));
            }
        }
    }

    _onClosing() {
        this._cancelCloseWhenActive();
        this._cancelOpenWhenIdle();

        if (this._closeWhenActiveDelaySource) {
            GLib.source_remove(this._closeWhenActiveDelaySource);
            this._closeWhenActiveDelaySource = 0;
        }

        if (this._closeWhenActiveIdleWatchId) {
            this._idleMonitor.remove_watch(this._closeWhenActiveIdleWatchId);
            this._closeWhenActiveIdleWatchId = 0;
        }

        if (this._timerUpdateId) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }

        if (this._styleChangedId) {
            this._secondsLabel.disconnect(this._styleChangedId);
            this._styleChangedId = 0;
        }
    }

    _onDestroy() {
        this._onClosing();

        if (this._actorMappedId) {
            this.actor.disconnect(this._actorMappedId);
            this._actorMappedId = 0;
        }
    }

    _onEvent(actor, event) {
        let x, y, dx, dy, distance;

        if (!event.get_device ()) {
            return Clutter.EVENT_STOP;
        }

        switch (event.type())
        {
            case Clutter.EventType.ENTER:
            case Clutter.EventType.LEAVE:
            case Clutter.EventType.STAGE_STATE:
            case Clutter.EventType.DESTROY_NOTIFY:
            case Clutter.EventType.CLIENT_MESSAGE:
            case Clutter.EventType.DELETE:
                return Clutter.EVENT_PROPAGATE;

            case Clutter.EventType.MOTION:
                [x, y]   = event.get_coords();
                dx       = this._eventX >= 0 ? x - this._eventX : 0;
                dy       = this._eventY >= 0 ? y - this._eventY : 0;
                distance = dx * dx + dy * dy;

                this._eventX = x;
                this._eventY = y;

                if (distance > MOTION_DISTANCE_TO_CLOSE * MOTION_DISTANCE_TO_CLOSE) {
                    this.close(true);
                }

                break;

            case Clutter.EventType.KEY_PRESS:
                switch (event.get_key_symbol())
                {
                    case Clutter.KEY_AudioLowerVolume:
                    case Clutter.KEY_AudioRaiseVolume:
                        return Clutter.EVENT_PROPAGATE;

                    default:
                        this.close(true);
                        break;
                }

                break;

            case Clutter.EventType.BUTTON_PRESS:
            case Clutter.EventType.TOUCH_BEGIN:
                this.close(true);

                break;
        }

        return Clutter.EVENT_STOP;
    }

    /**
     * Open the dialog and setup closing when user becomes active.
     */
    open(animate) {
        super.open(animate);

        /* Wait until user has a chance of seeing the dialog */
        if (this._closeWhenActiveDelaySource == 0) {
            this._closeWhenActiveDelaySource = GLib.timeout_add(
                GLib.PRIORITY_DEFAULT,
                MIN_DISPLAY_TIME,
                () => {
                    if (this._idleMonitor.get_idletime() < IDLE_TIME_TO_CLOSE) {
                        /* Wait until user becomes slightly idle */
                        this._closeWhenActiveIdleWatchId =
                                this._idleMonitor.add_idle_watch(IDLE_TIME_TO_CLOSE,
                                                                 this.closeWhenActive.bind(this));
                    }
                    else {
                        this.closeWhenActive();
                    }

                    this._closeWhenActiveDelaySource = 0;
                    return GLib.SOURCE_REMOVE;
                });
        }
    }

    _cancelOpenWhenIdle() {
        if (this._openWhenIdleWatchId) {
            this._idleMonitor.remove_watch(this._openWhenIdleWatchId);
            this._openWhenIdleWatchId = 0;
        }
    }

    openWhenIdle() {
        if (this.state == State.OPEN || this.state == State.OPENING) {
            return;
        }

        if (this._openWhenIdleWatchId == 0) {
            this._openWhenIdleWatchId = this._idleMonitor.add_idle_watch(IDLE_TIME_TO_OPEN,
                () => {
                    let info = Utils.getFocusedWindowInfo();

                    if (info.isPlayer && info.isFullscreen)
                    {
                        /* dont reopen if playing a video */
                        return;
                    }

                    if (!this.timer.isBreak() ||
                        this.timer.getRemaining() < OPEN_WHEN_IDLE_MIN_REMAINING_TIME)
                    {
                        return;
                    }

                    this.open(true);
                });
        }
    }

    _cancelCloseWhenActive() {
        if (this._eventId) {
            this._lightbox.disconnect(this._eventId);
            this._eventId = 0;
        }
    }

    // TODO: should be private
    closeWhenActive() {
        if (this.state == State.CLOSED || this.state == State.CLOSING) {
            return;
        }

        if (this._eventId == 0) {
            this._eventX = -1;
            this._eventY = -1;
            this._eventId = this._lightbox.connect('event', this._onEvent.bind(this));
        }
    }

    setDescription(text) {
        this.description = text;

        if (this._descriptionLabel.clutter_text) {
            this._descriptionLabel.clutter_text.set_text(this.description);
        }
    }
};
