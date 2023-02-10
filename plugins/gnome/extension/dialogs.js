/*
 * Copyright (c) 2011-2023 gnome-pomodoro contributors
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

const { Atk, Clutter, GLib, GObject, Meta, Shell, St, Pango } = imports.gi;

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
const PUSH_MODAL_RATE = 60;
const MOTION_DISTANCE_TO_CLOSE = 20;

const IDLE_TIME_TO_OPEN = 30000;
const IDLE_TIME_TO_ACKNOWLEDGE = 600;
const MIN_DISPLAY_TIME = 500;

const FADE_IN_TIME = 500;
const FADE_OUT_TIME = 350;

const BLUR_BRIGHTNESS = 0.4;
const BLUR_SIGMA = 20.0;

const OPEN_WHEN_IDLE_MIN_REMAINING_TIME = 3.0;

const DEFAULT_BACKGROUND_COLOR = Clutter.Color.from_pixel(0x000000ff);
const HAVE_SHADERS_GLSL = Utils.versionCheck('42.0') || Clutter.feature_available(Clutter.FeatureFlags.SHADERS_GLSL);  // TODO there is no such feature flag since 42

var State = {
    OPENED: 0,
    CLOSED: 1,
    OPENING: 2,
    CLOSING: 3
};

var overlayManager = null;


var BlurredLightbox = GObject.registerClass(
class PomodoroBlurredLightbox extends Lightbox.Lightbox {
    _init(container, params) {
        params = Params.parse(params, {
            inhibitEvents: false,
            width: null,
            height: null,
        });

        super._init(container, {
            inhibitEvents: params.inhibitEvents,
            width: params.width,
            height: params.height,
            fadeFactor: 1.0,
            radialEffect: false,
        });

        this.set({
            opacity: 0,
            style_class: HAVE_SHADERS_GLSL ? 'extension-pomodoro-lightbox-blurred' : 'extension-pomodoro-lightbox',
        });
        this._background = null;

        let themeContext = St.ThemeContext.get_for_stage(global.stage);
        this._scaleChangedId = themeContext.connect('notify::scale-factor', this._updateEffects.bind(this));
        this._monitorsChangedId = Main.layoutManager.connect('monitors-changed', this._updateEffects.bind(this));
    }

    _createBackground() {
        if (!this._background && HAVE_SHADERS_GLSL) {
            // Clone the group that contains all of UI on the screen. This is the
            // chrome, the windows, etc.
            this._background = new Clutter.Clone({ source: Main.uiGroup, clip_to_allocation: true });
            this._background.set_background_color(DEFAULT_BACKGROUND_COLOR);
            this._background.add_effect_with_name('blur', new Shell.BlurEffect());
            this.set_child(this._background);
        }

        this._updateEffects();
    }

    _destroyBackground() {
        if (this._background) {
            this._background.destroy();
            this._background = null;
        }
    }

    _updateEffects() {
        if (this._background) {
            const themeContext = St.ThemeContext.get_for_stage(global.stage);
            let effect = this._background.get_effect('blur');

            if (effect) {
                effect.set({
                    brightness: BLUR_BRIGHTNESS,
                    sigma: BLUR_SIGMA * themeContext.scale_factor,
                });
                effect.queue_repaint();
            }
        }
    }

    lightOn(fadeInTime) {
        super.lightOn(fadeInTime);

        if (this._background && !Utils.versionCheck('40.0')) {  // TODO remove compatibility for 3.38
            let effect = this._background.get_effect('blur');
            if (effect) {
                effect.set({
                    brightness: BLUR_BRIGHTNESS * 0.99,
                });
            }

            // HACK: force effect to be repaint itself during fading-in
            // in theory effect.queue_repaint(); should be enough
            this._background.ease_property('@effects.blur.brightness', BLUR_BRIGHTNESS, {
                duration: fadeInTime || 0,
            });
        }
    }

    lightOff(fadeOutTime) {
        super.lightOff(fadeOutTime);

        if (this._background && !Utils.versionCheck('40.0')) {  // TODO remove compatibility for 3.38
            let effect = this._background.get_effect('blur');
            if (effect) {
                // HACK: force effect to be repaint itself during fading-out
                // in theory effect.queue_repaint(); should be enough
                this._background.ease_property('@effects.blur.brightness', BLUR_BRIGHTNESS * 0.99, {
                    duration: fadeOutTime || 0,
                });
            }
        }
    }

    vfunc_map() {
        this._createBackground();

        super.vfunc_map();
    }

    vfunc_unmap() {
        super.vfunc_unmap();

        this._destroyBackground();
    }

    /* override parent method */
    _onDestroy() {
        if (this._monitorsChangedId) {
            Main.layoutManager.disconnect(this._monitorsChangedId);
            delete this._monitorsChangedId;
        }

        let themeContext = St.ThemeContext.get_for_stage(global.stage);
        if (this._scaleChangedId) {
            themeContext.disconnect(this._scaleChangedId);
            delete this._scaleChangedId;
        }

        this._destroyBackground();

        super._onDestroy();
    }
});


/**
 * Helper class for raising actors above `Main.layoutManager.uiGroup`
 */
class OverlayManager {
    constructor() {
        this._raised = false;
        this._overlayActors = [];
        this._chromeActors = [];

        for (let chrome of [Main.messageTray,
                            Main.screenShield._shortLightbox,
                            Main.screenShield._longLightbox])
        {
            try {
                this.addChrome(chrome);
            }
            catch (error) {
                Utils.logError(error);
            }
        }
    }

    static getDefault() {
        if (!overlayManager) {
            overlayManager = new OverlayManager();
        }

        return overlayManager;
    }

    _createOverlayGroup() {
        if (!this._overlayGroup) {
            this._overlayGroup = new St.Widget({
                name: 'overlayGroup',
                reactive: false,
            });
	        global.stage.add_actor(this._overlayGroup);
	        global.stage.set_child_above_sibling(this._overlayGroup, null);
        }

        if (!this._dummyChrome) {
            // LayoutManager tracks region changes, so create a mock member resembling overlayGroup.
            const constraint = new Clutter.BindConstraint({
                                           source: this._overlayGroup,
                                           coordinate: Clutter.BindCoordinate.ALL });
            this._dummyChrome = new St.Widget({
                name: 'dummyOverlayGroup',
                reactive: false,
            });
            this._dummyChrome.add_constraint(constraint);
            Main.layoutManager.addTopChrome(this._dummyChrome);
        }

        for (const overlayData of this._overlayActors) {
            this._overlayGroup.add_actor(overlayData.actor);
        }
    }

    _destroyOverlayGroup() {
        if (this._overlayGroup) {
            for (const overlayData of this._overlayActors) {
                this._overlayGroup.remove_actor(overlayData.actor);
            }

            global.stage.remove_actor(this._overlayGroup);
            this._overlayGroup = null;
        }

        if (this._dummyChrome) {
            Main.layoutManager.removeChrome(this._dummyChrome);
            this._dummyChrome = null;
        }
    }

    _raiseChromeInternal(chromeData) {
        if (chromeData.actor instanceof Lightbox.Lightbox) {
            chromeData.notifyOpacityId = chromeData.actor.connect('notify::opacity', () => {
                this._updateOpacity();
            });
        }
        else {
            chromeData.actor.ref();
            try {
                Main.layoutManager.uiGroup.remove_actor(chromeData.actor);
                global.stage.add_actor(chromeData.actor);
            }
            finally {
                chromeData.actor.unref();
            }
        }
    }

    _raiseChrome() {
        if (!this._raised) {
            this._createOverlayGroup();

            for (let chromeData of this._chromeActors) {
                this._raiseChromeInternal(chromeData);
            }

            this._raised = true;
        }
    }

    _lowerChromeInternal(chromeData) {
        if (chromeData.actor instanceof Lightbox.Lightbox) {
            chromeData.actor.disconnect(chromeData.notifyOpacityId);
        }
        else {
            chromeData.actor.ref();
            try {
                global.stage.remove_actor(chromeData.actor);
                Main.layoutManager.uiGroup.add_actor(chromeData.actor);
            }
            finally {
                chromeData.actor.unref();
            }
        }
    }

    _lowerChrome() {
        if (this._raised) {
            for (let chromeData of this._chromeActors) {
                this._lowerChromeInternal(chromeData);
            }

            this._destroyOverlayGroup();

            this._raised = false;
        }
    }

    _updateOpacity() {
        let maxOpacity = 0;
        for (let chromeData of this._chromeActors) {
            if (chromeData.actor instanceof Lightbox.Lightbox) {
                maxOpacity = Math.max(maxOpacity, chromeData.actor.opacity);
            }
        }

        for (let overlayData of this._overlayActors) {
            overlayData.actor._layout.opacity = 255 - maxOpacity;
        }
    }

    _onOverlayNotifyVisible() {
        let visibleCount = 0;

        for (let overlayData of this._overlayActors) {
            if (overlayData.actor.visible && !(overlayData.actor instanceof Lightbox.Lightbox)) {
                visibleCount++;
            }
        }

        if (visibleCount > 0) {
            this._raiseChrome();
        }
        else {
            this._lowerChrome();
        }
    }

    _onOverlayDestroy(actor) {
        let index = -1;

        for (let overlayData of this._overlayActors) {
            index++;

            if (overlayData.actor === actor) {
                this._overlayActors.pop(index);
                break;
            }
        }
    }

    add(actor) {
        this._overlayActors.push({
            actor: actor,
            notifyVisibleId: actor.connect('notify::visible', this._onOverlayNotifyVisible.bind(this)),
            destroyId: actor.connect('destroy', this._onOverlayDestroy.bind(this)),
        });
        actor.ref();

        this._onOverlayNotifyVisible();
    }

    addChrome(actor) {
        if (actor.get_parent() !== Main.layoutManager.uiGroup) {
            throw new Error('Passed actor is not a direct child of Main.layoutManager.uiGroup');
        }

        const chromeData = {
            actor: actor,
            notifyOpacityId: 0,
        };
        this._chromeActors.push(chromeData);

        if (this._raised) {
            this._raiseChromeInternal(chromeData);
        }
    }

    destroy() {
        this._lowerChrome();

        for (const overlayData of this._overlayActors) {
            overlayData.actor.disconnect(overlayData.notifyVisibleId);
            overlayData.actor.disconnect(overlayData.destroyId);
            overlayData.actor.unref();
        }

        this._overlayActors = [];
        this._chromeActors = [];
    }
}


/**
 * ModalDialog class based on ModalDialog from GNOME Shell. We need our own
 * class to have more event signals, different fade in/out times, and different
 * event blocking behavior.
 */
var ModalDialog = GObject.registerClass({
    Properties: {
        'state': GObject.ParamSpec.int('state', 'Dialog state', 'state',
                                       GObject.ParamFlags.READABLE,
                                       Math.min(...Object.values(State)),
                                       Math.max(...Object.values(State)),
                                       State.CLOSED),
    },
    Signals: { 'opened': {}, 'opening': {}, 'closed': {}, 'closing': {} },
}, class PomodoroModalDialog extends St.Widget {
    _init() {
        super._init({ style_class: 'extension-pomodoro-dialog',
                      accessible_role: Atk.Role.DIALOG,
                      layout_manager: new Clutter.BinLayout(),
                      reactive: false,
                      visible: false,
                      opacity: 0 });

        this._state = State.CLOSED;
        this._acknowledged = false;
        this._hasModal = false;
        this._grab = null;
        this._destroyed = false;
        this._pushModalTimeoutId = 0;
        this._pushModalWatchId = 0;
        this._pushModalSource = 0;
        this._openWhenIdleWatchId = 0;
        this._acknowledgeTimeoutId = 0;
        this._acknowledgeIdleWatchId = 0;
        this._keyFocusOutId = 0;
        this._eventId = 0;
        this._lastActiveTime = -1;
        this._lastEventX = -1;
        this._lastEventY = -1;
        this._bindingAction = 0;
        this._acceleratorActivatedId = 0;
        this._monitorConstraint = new Layout.MonitorConstraint();
        this._monitorConstraint.primary = true;
        this._stageConstraint = new Clutter.BindConstraint({
                                       source: global.stage,
                                       coordinate: Clutter.BindCoordinate.ALL });
        this.add_constraint(this._stageConstraint);

        if (global.backend.get_core_idle_monitor !== undefined) {
            this._idleMonitor = global.backend.get_core_idle_monitor();
        }
        else {
            this._idleMonitor = Meta.IdleMonitor.get_core();  // TODO: remove along support for gnome-shell 40
        }

        this.connect('destroy', this._onDestroy.bind(this));

        // Modal dialogs are fixed width and grow vertically; set the request
        // mode accordingly so wrapped labels are handled correctly during
        // size requests.
        this._layout = new St.Widget({ layout_manager: new Clutter.BinLayout() });
        this._layout.add_constraint(this._monitorConstraint);
        this.add_actor(this._layout);

        // Lightbox will be a direct child of the ModalDialog
        this._lightbox = new BlurredLightbox(this,
                                             { inhibitEvents: false });
        this._lightbox.highlight(this._layout);

        global.focus_manager.add_group(this._lightbox);

        OverlayManager.getDefault().add(this);
    }

    get state() {
        return this._state;
    }

    _setState(state) {
        if (this._state === state) {
            return;
        }

        this._state = state;
        this.notify('state');
    }

    _onAcceleratorActivated(display, action, device, timestamp) {
        if (action === this._bindingAction) {
            this.close(true);
        }
    }

    // register a failsafe method of closing the dialog
    _grabAccelerators() {
        if (!this._bindingAction) {
            const bindingAction = global.display.grab_accelerator('Escape', Meta.KeyBindingFlags.NONE);
            const bindingName = Meta.external_binding_name_for_action(bindingAction);

            if (bindingAction === Meta.KeyBindingAction.NONE) {
                Utils.logWarning('Failed to grab accelerator for the dialog.');
                return;
            }

            this._bindingAction = bindingAction;

            Main.wm.allowKeybinding(bindingName, Shell.ActionMode.ALL);
        }

        if (!this._acceleratorActivatedId) {
            this._acceleratorActivatedId = global.display.connect('accelerator-activated', this._onAcceleratorActivated.bind(this));
        }
    }

    _ungrabAccelerators() {
        if (this._bindingAction) {
            const bindingName = Meta.external_binding_name_for_action(this._bindingAction);
            Main.wm.allowKeybinding(bindingName, Shell.ActionMode.NONE);

            if (global.display.ungrab_accelerator(this._bindingAction)) {
                this._bindingAction = null;
            }
            else {
                Utils.logWarning('Failed to ungrab accelerator for the dialog.');
            }
        }

        if (this._acceleratorActivatedId) {
            global.display.disconnect(this._acceleratorActivatedId);
            this._acceleratorActivatedId = 0;
        }
    }

    _getIdleTime(event) {
        const eventTime = event ? event.get_time() : GLib.get_monotonic_time() / 1000;
        const idleTime = this._lastActiveTime > 0 ? Math.max(eventTime - this._lastActiveTime, 0) : 0;

        return Math.max(this._idleMonitor.get_idletime(), idleTime);
    }

    acknowledge() {
        if (this.state === State.CLOSED || this.state === State.CLOSING) {
            return;
        }

        this._acknowledged = true;
    }

    _onKeyFocusOut() {
        let focus = global.stage.key_focus;

        if (focus === null || !this._lightbox.contains(focus)) {
            this.close(true);
        }
    }

    _onOpenComplete() {
        this._setState(State.OPENED);

        if (!this._acknowledgeTimeoutId) {
            this._acknowledgeTimeoutId = GLib.timeout_add(
                GLib.PRIORITY_DEFAULT,
                MIN_DISPLAY_TIME,
                () => {
                    if (this._getIdleTime() >= IDLE_TIME_TO_ACKNOWLEDGE) {
                        this.acknowledge();
                    }
                    else {
                        this._acknowledgeIdleWatchId = this._idleMonitor.add_idle_watch(IDLE_TIME_TO_ACKNOWLEDGE,
                            (monitor) => this.acknowledge()
                        );
                    }

                    this._acknowledgeTimeoutId = 0;
                    return GLib.SOURCE_REMOVE;
                });
            GLib.Source.set_name_by_id(this._acknowledgeTimeoutId,
                                       '[gnome-pomodoro] this._acknowledgeTimeoutId');
        }

        this.emit('opened');
    }

    _onIdleMonitorBecameIdle(monitor) {
        let pushModalTries = 0;
        let pushModalInterval = Math.floor(1000 / PUSH_MODAL_RATE);
        let timestamp = global.get_current_time();

        if (this._pushModalWatchId) {
            this._idleMonitor.remove_watch(this._pushModalWatchId);
            this._pushModalWatchId = 0;
        }

        if (this.pushModal(timestamp)) {
            return GLib.SOURCE_REMOVE;
        }

        this._pushModalSource = GLib.timeout_add(
            GLib.PRIORITY_DEFAULT,
            pushModalInterval,
            () => {
                pushModalTries += 1;

                if (this.pushModal()) {
                    this._pushModalSource = 0;
                    return GLib.SOURCE_REMOVE;  // success
                }

                if (pushModalTries * pushModalInterval >= PUSH_MODAL_TIME_LIMIT) {
                    Utils.logWarning('Unable to push modal. Closing the modal dialog...');
                    this.close(true);
                    this._pushModalSource = 0;
                    return GLib.SOURCE_REMOVE;  // failure
                }

                return GLib.SOURCE_CONTINUE;
            });
        GLib.Source.set_name_by_id(this._pushModalSource,
                                   '[gnome-pomodoro] this._pushModalSource');
    }

    // Gradually open the dialog. Try to make it modal once user had chance to see it
    // and schedule to close it once user becomes active.
    open(animate) {
        if (this.state === State.OPENED || this.state === State.OPENING || this._destroyed) {
            return;
        }

        if (this._pushModalTimeoutId) {
            GLib.source_remove(this._pushModalTimeoutId);
            this._pushModalTimeoutId = 0;
        }

        this._pushModalTimeoutId = GLib.timeout_add(
            GLib.PRIORITY_DEFAULT,
            Math.max(MIN_DISPLAY_TIME - IDLE_TIME_TO_PUSH_MODAL, 0),
            () => {
                if (!this._pushModalWatchId) {
                    this._pushModalWatchId = this._idleMonitor.add_idle_watch(IDLE_TIME_TO_PUSH_MODAL,
                                                                              this._onIdleMonitorBecameIdle.bind(this));
                }

                this._pushModalTimeoutId = 0;

                return GLib.SOURCE_REMOVE;
            }
        );
        GLib.Source.set_name_by_id(this._pushModalTimeoutId,
                                   '[gnome-pomodoro] this._pushModalTimeoutId');

        this.remove_all_transitions();
        this.show();
        this._setState(State.OPENING);
        this._acknowledged = false;
        this.emit('opening');

        if (animate) {
            this._lightbox.lightOn(FADE_IN_TIME);

            this.ease({
                opacity: 255,
                duration: FADE_IN_TIME,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                onComplete: this._onOpenComplete.bind(this),
            });
        }
        else {
            this._lightbox.lightOn();
            this.opacity = 255;
            this._onOpenComplete();
        }
    }

    canOpen() {
        if (!this.timer.isBreak() ||
            this.timer.isPaused() ||
            this.timer.getRemaining() < OPEN_WHEN_IDLE_MIN_REMAINING_TIME)
        {
            return false;
        }

        if (Utils.isVideoPlayerOpen()) {
            Utils.logWarning('Can\'t open dialog. A video player is running.');
            return false;
        }

        if (this._destroyed) {
            Utils.logWarning('Can\'t open dialog. Dialog should be destroyed.');
            return false;
        }

        return true;
    }

    // Schedule to open when user becomes idle
    openWhenIdle() {
        if (this.state === State.OPENED || this.state === State.OPENING || this._destroyed) {
            return;
        }

        if (!this._openWhenIdleWatchId) {
            this._openWhenIdleWatchId = this._idleMonitor.add_idle_watch(IDLE_TIME_TO_OPEN,
                (monitor) => {
                    try {
                        if (this.canOpen()) {
                            this.open(true);
                        }
                    }
                    catch (error) {
                        Utils.logError(error);
                    }
                });
        }
    }

    _onCloseComplete() {
        this.hide();
        this._setState(State.CLOSED);

        this.emit('closed');
    }

    close(animate) {
        if (this.state === State.CLOSED || this.state === State.CLOSING) {
            return;
        }

        this.popModal();
        this._setState(State.CLOSING);
        this.emit('closing');

        this.remove_all_transitions();

        if (animate) {
            this._lightbox.lightOff(FADE_OUT_TIME);
            this.ease({
                opacity: 0,
                duration: FADE_OUT_TIME,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                onComplete: this._onCloseComplete.bind(this),
            });
        } else {
            this._lightbox.lightOff();
            this.opacity = 0;
            this._onCloseComplete();
        }
    }

    _disconnectPushModalSignals() {
        if (this._pushModalTimeoutId) {
            GLib.source_remove(this._pushModalTimeoutId);
            this._pushModalTimeoutId = 0;
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

    // Drop modal status without closing the dialog; this makes the
    // dialog insensitive as well, so it needs to be followed shortly
    // by either a close() or a pushModal()
    popModal(timestamp) {
        this._disconnectPushModalSignals();

        if (this._keyFocusOutId) {
            this._lightbox.disconnect(this._keyFocusOutId);
            this._keyFocusOutId = 0;
        }

        if (this._eventId) {
            this._lightbox.disconnect(this._eventId);
            this._eventId = 0;
        }

        if (!this._hasModal) {
            return;
        }

        if (this._grab && this._grab.get_seat_state !== undefined) {
            // gnome-shell 42 and newer
            Main.popModal(this._grab, timestamp);
        }
        else {
            Main.popModal(this, timestamp);
        }
        this._grab = null;
        this._hasModal = false;

        this._lightbox.reactive = false;
    }

    pushModal(timestamp) {
        if (this._hasModal) {
            return true;
        }

        if (this.state === State.CLOSED || this.state === State.CLOSING || this._destroyed) {
            return false;
        }

        let params = { actionMode: Shell.ActionMode.SYSTEM_MODAL };
        if (timestamp) {
            params['timestamp'] = timestamp;
        }

        let grab = Main.pushModal(this, params);
        if (grab && grab.get_seat_state !== undefined) {
            // gnome-shell 42 and newer
            if (grab.get_seat_state() !== Clutter.GrabState.ALL) {
                Utils.logWarning('Unable become fully modal');
                Main.popModal(grab);
                return false;
            }
        } else {
            if (!grab) {
                return false;
            }
        }

        this._grab = grab;
        this._hasModal = true;
        this._disconnectPushModalSignals();

        this._lightbox.reactive = true;
        this._lightbox.grab_key_focus();
        this._lastActiveTime = GLib.get_monotonic_time() / 1000;
        this._lastEventX = -1;
        this._lastEventY = -1;

        if (!this._keyFocusOutId) {
            this._keyFocusOutId = this._lightbox.connect('key-focus-out', this._onKeyFocusOut.bind(this));
        }

        if (!this._eventId) {
            this._eventId = this._lightbox.connect('event', this._onEvent.bind(this));
        }

        Main.layoutManager.emit('system-modal-opened');

        return true;
    }

    // Main event handler once dialog becomes modal and reactive.
    // There are two stages on how events are blocked:
    //   1. Once the dialog becomes modal initially all inputs are ignored. This is to not let accidentally dismiss
    //      the dialog. It's still possible to dismiss the dialog with Esc key.
    //   2. After the dialog gets acknowledged (when user becomes slightly idle), the dialog becomes trully reactive
    //      and any event should dismiss the dialog.
    _onEvent(actor, event) {
        if (!event.get_device()) {
            return Clutter.EVENT_PROPAGATE;
        }

        let x, y, dx, dy, distance;
        let isUserActive = false;

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
                dx       = this._lastEventX >= 0 ? x - this._lastEventX : 0;
                dy       = this._lastEventY >= 0 ? y - this._lastEventY : 0;
                distance = dx * dx + dy * dy;

                this._lastEventX = x;
                this._lastEventY = y;

                if (distance > MOTION_DISTANCE_TO_CLOSE * MOTION_DISTANCE_TO_CLOSE) {
                    isUserActive = true;
                }

                break;

            case Clutter.EventType.KEY_PRESS:
                switch (event.get_key_symbol())
                {
                    case Clutter.KEY_AudioCycleTrack:
                    case Clutter.KEY_AudioForward:
                    case Clutter.KEY_AudioLowerVolume:
                    case Clutter.KEY_AudioNext:
                    case Clutter.KEY_AudioPause:
                    case Clutter.KEY_AudioPlay:
                    case Clutter.KEY_AudioPrev:
                    case Clutter.KEY_AudioRaiseVolume:
                    case Clutter.KEY_AudioRandomPlay:
                    case Clutter.KEY_AudioRecord:
                    case Clutter.KEY_AudioRepeat:
                    case Clutter.KEY_AudioRewind:
                    case Clutter.KEY_AudioStop:
                    case Clutter.KEY_AudioMicMute:
                    case Clutter.KEY_AudioMute:
                    case Clutter.KEY_MonBrightnessDown:
                    case Clutter.KEY_MonBrightnessUp:
                    case Clutter.KEY_Display:
                        return Clutter.EVENT_PROPAGATE;

                    case Clutter.KEY_Escape:
                        this.acknowledge();
                        isUserActive = true;
                        break;

                    default:
                        isUserActive = true;
                        break;
                }

                break;

            case Clutter.EventType.BUTTON_PRESS:
            case Clutter.EventType.TOUCH_BEGIN:
                isUserActive = true;
                break;
        }

        if (isUserActive)
        {
            if (this._getIdleTime(event) >= IDLE_TIME_TO_ACKNOWLEDGE) {
                this._acknowledged = true;
            }

            this._lastActiveTime = event.get_time();
        }

        if (this._acknowledged && isUserActive) {
            this.close(true);
        }

        return Clutter.EVENT_STOP;
    }

    vfunc_map() {
        this._grabAccelerators();

        super.vfunc_map();
    }

    vfunc_unmap() {
        super.vfunc_unmap();

        this._ungrabAccelerators();
    }

    _onDestroy() {
        this.popModal();

        this._destroyed = true;

        if (this._lightbox) {
            this._lightbox.destroy();
            this._lightbox = null;
        }
    }
});


var PomodoroEndDialog = GObject.registerClass(
class PomodoroEndDialog extends ModalDialog {
    _init(timer) {
        super._init();

        this.timer = timer;
        this._timerUpdateId = 0;
        this._styleChangedId = 0;
        this._minutesLabel = new St.Label({
            text: "0",
            x_expand: true,
            x_align: Clutter.ActorAlign.END,
        });
        this._separatorLabel = new St.Label({
            text: ":",
        });
        this._secondsLabel = new St.Label({
            text: "00",
            x_expand: true,
            x_align: Clutter.ActorAlign.START,
        });
        this._minutesLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this._separatorLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this._secondsLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;

        let hbox = new St.BoxLayout({ vertical: false, style_class: 'extension-pomodoro-dialog-timer' });
        hbox.add_actor(this._minutesLabel);
        hbox.add_actor(this._separatorLabel);
        hbox.add_actor(this._secondsLabel);

        this._descriptionLabel = new St.Label({
            style_class: 'extension-pomodoro-dialog-description',
            text: _("It's time to take a break"),
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._descriptionLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this._descriptionLabel.clutter_text.line_wrap = true;

        let box = new St.BoxLayout({ style_class: 'extension-pomodoro-dialog-box',
                                     vertical: true });
        box.add_actor(hbox);
        box.add_actor(this._descriptionLabel);
        this._layout.add_actor(box);
    }

    get description() {
        return this._descriptionLabel.clutter_text.get_text();
    }

    set description(value) {
        this._descriptionLabel.clutter_text.set_text(value);
    }

    _onStyleChanged(actor) {
        let themeNode = actor.get_theme_node();
        let font      = themeNode.get_font();
        let context   = actor.get_pango_context();
        let metrics   = context.get_metrics(font, context.get_language());
        let digitWidth = metrics.get_approximate_digit_width() / Pango.SCALE;
        const [, naturalWidth] = actor.get_preferred_width(-1);

        this._secondsLabel.natural_width = Math.max(2 * digitWidth, naturalWidth);
    }

    _updateLabels() {
        if (this._destroyed) {
            return;
        }

        const remaining = this.timer.isBreak() ? Math.max(this.timer.getRemaining(), 0.0) : 0.0;
        const minutes   = Math.floor(remaining / 60);
        const seconds   = Math.floor(remaining % 60);

        if (this._minutesLabel.clutter_text) {
            this._minutesLabel.clutter_text.set_text('%d'.format(minutes));
        }

        if (this._secondsLabel.clutter_text) {
            this._secondsLabel.clutter_text.set_text('%02d'.format(seconds));
        }
    }

    _onTimerUpdate() {
        if (this.state === State.OPENED || this.state === State.OPENING) {
            this._updateLabels();
        }
    }

    vfunc_map() {
        if (!this._styleChangedId) {
            this._styleChangedId = this._secondsLabel.connect('style-changed', this._onStyleChanged.bind(this));
            this._onStyleChanged(this._secondsLabel);
        }

        if (!this._timerUpdateId) {
            this._timerUpdateId = this.timer.connect('update', this._onTimerUpdate.bind(this));
        }

        this._updateLabels();

        super.vfunc_map();
    }

    vfunc_unmap() {
        if (this._styleChangedId && !this._destroyed) {
            this._secondsLabel.disconnect(this._styleChangedId);
            this._styleChangedId = 0;
        }

        if (this._timerUpdateId) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }

        super.vfunc_unmap();
    }
});
