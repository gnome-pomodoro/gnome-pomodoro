/*
 * Copyright (c) 2011-2024 gnome-pomodoro contributors
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

import Atk from 'gi://Atk';
import Clutter from 'gi://Clutter';
import Cogl from 'gi://Cogl';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Pango from 'gi://Pango';
import Shell from 'gi://Shell';
import St from 'gi://St';

import {MonitorConstraint} from 'resource:///org/gnome/shell/ui/layout.js';
import {Lightbox} from 'resource:///org/gnome/shell/ui/lightbox.js';
import {gettext as _} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as GnomeSession from 'resource:///org/gnome/shell/misc/gnomeSession.js';
import * as SystemActions from 'resource:///org/gnome/shell/misc/systemActions.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as Params from 'resource:///org/gnome/shell/misc/params.js';

import {extension} from './extension.js';
import {State, TimerLabel} from './timer.js';
import * as Utils from './utils.js';


/* Time between user input events before making overlay modal.
 * Value is a little higher than:
 *   - slow typing speed of 23 words per minute which translates
 *     to 523 miliseconds between key presses
 *   - moderate typing speed of 35 words per minute, 343 miliseconds.
 */
const IDLE_TIME_TO_ACKNOWLEDGE = 600;
const IDLE_TIME_TO_OPEN = 30000;
const MOTION_VELOCITY_TO_DISMISS = 3.0;

const FADE_IN_TIME = 500;
const FADE_OUT_TIME = 350;

const BLUR_BRIGHTNESS = 0.4;
const BLUR_RADIUS = 40.0;

const OPEN_WHEN_IDLE_MIN_REMAINING_TIME = 3.0;

const BACKGROUND_COLOR = Utils.isVersionAtLeast('47')
    ? new Cogl.Color({red: 0, green: 0, blue: 0, alpha: 255})
    : Clutter.Color.from_pixel(0x000000ff);
const ICON_SIZE = 24;

export const OverlayState = {
    OPENED: 0,
    CLOSED: 1,
    OPENING: 2,
    CLOSING: 3,
};

let overlayManager = null;


const PlainLightbox = GObject.registerClass(
class PomodoroPlainLightbox extends Lightbox {
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
            style_class: 'extension-pomodoro-lightbox',
        });
    }
});


const BlurredLightbox = GObject.registerClass(
class PomodoroBlurredLightbox extends Lightbox {
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
            style_class: 'extension-pomodoro-lightbox-blurred',
        });
        this._background = null;

        const themeContext = St.ThemeContext.get_for_stage(global.stage);
        this._scaleChangedId = themeContext.connect('notify::scale-factor', this._updateEffects.bind(this));
        this._monitorsChangedId = Main.layoutManager.connect('monitors-changed', this._updateEffects.bind(this));
    }

    _createBackground() {
        if (!this._background) {
            // Clone the group that contains all of UI on the screen. This is the
            // chrome, the windows, etc.
            this._background = new Clutter.Clone({source: Main.uiGroup, clip_to_allocation: false});
            this._background.set_background_color(BACKGROUND_COLOR);
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
            const effect = this._background.get_effect('blur');

            if (effect) {
                effect.set({
                    brightness: BLUR_BRIGHTNESS,
                    radius: BLUR_RADIUS * themeContext.scale_factor,
                });
                effect.queue_repaint();
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

        const themeContext = St.ThemeContext.get_for_stage(global.stage);
        if (this._scaleChangedId) {
            themeContext.disconnect(this._scaleChangedId);
            this._scaleChangedId = 0;
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
            Main.screenShield._longLightbox]) {
            try {
                this.addChrome(chrome);
            } catch (error) {
                Utils.logError(error);
            }
        }
    }

    static getDefault() {
        if (!overlayManager)
            overlayManager = new OverlayManager();

        return overlayManager;
    }

    _createOverlayGroup() {
        if (!this._overlayGroup) {
            this._overlayGroup = new St.Widget({
                name: 'overlayGroup',
                reactive: false,
            });
            global.stage.add_child(this._overlayGroup);
            global.stage.set_child_above_sibling(this._overlayGroup, null);
        }

        if (!this._dummyChrome) {
            // LayoutManager tracks region changes, so create a mock member resembling overlayGroup.
            const constraint = new Clutter.BindConstraint({
                source: this._overlayGroup,
                coordinate: Clutter.BindCoordinate.ALL,
            });
            this._dummyChrome = new St.Widget({
                name: 'dummyOverlayGroup',
                reactive: false,
            });
            this._dummyChrome.add_constraint(constraint);
            Main.layoutManager.addTopChrome(this._dummyChrome);
        }

        for (const overlayData of this._overlayActors)
            this._overlayGroup.add_child(overlayData.actor);
    }

    _destroyOverlayGroup() {
        if (this._overlayGroup) {
            this._overlayGroup.remove_all_children();
            global.stage.remove_child(this._overlayGroup);
            this._overlayGroup = null;
        }

        if (this._dummyChrome) {
            Main.layoutManager.removeChrome(this._dummyChrome);
            this._dummyChrome = null;
        }
    }

    _raiseChromeInternal(chromeData) {
        if (chromeData.actor instanceof Lightbox) {
            chromeData.notifyOpacityId = chromeData.actor.connect('notify::opacity', () => {
                this._updateOpacity();
            });
        } else {
            Main.layoutManager.uiGroup.remove_child(chromeData.actor);
            global.stage.add_child(chromeData.actor);
        }
    }

    _raiseChrome() {
        if (!this._raised) {
            this._createOverlayGroup();

            for (let chromeData of this._chromeActors)
                this._raiseChromeInternal(chromeData);

            this._raised = true;
        }
    }

    _lowerChromeInternal(chromeData) {
        if (chromeData.actor instanceof Lightbox) {
            chromeData.actor.disconnect(chromeData.notifyOpacityId);
        } else {
            global.stage.remove_child(chromeData.actor);
            Main.layoutManager.uiGroup.add_child(chromeData.actor);
        }
    }

    _lowerChrome() {
        if (this._raised) {
            for (let chromeData of this._chromeActors)
                this._lowerChromeInternal(chromeData);

            this._destroyOverlayGroup();

            this._raised = false;
        }
    }

    _updateOpacity() {
        let maxOpacity = 0;
        for (let chromeData of this._chromeActors) {
            if (chromeData.actor instanceof Lightbox)
                maxOpacity = Math.max(maxOpacity, chromeData.actor.opacity);
        }

        for (let overlayData of this._overlayActors)
            overlayData.actor._layout.opacity = 255 - maxOpacity;
    }

    _onOverlayNotifyVisible() {
        let visibleCount = 0;

        for (let overlayData of this._overlayActors) {
            if (overlayData.actor.visible && !(overlayData.actor instanceof Lightbox))
                visibleCount++;
        }

        if (visibleCount > 0)
            this._raiseChrome();
        else
            this._lowerChrome();
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
            actor,
            notifyVisibleId: actor.connect('notify::visible', this._onOverlayNotifyVisible.bind(this)),
            destroyId: actor.connect('destroy', this._onOverlayDestroy.bind(this)),
        });

        this._onOverlayNotifyVisible();
    }

    addChrome(actor) {
        if (actor.get_parent() !== Main.layoutManager.uiGroup)
            throw new Error('Passed actor is not a direct child of Main.layoutManager.uiGroup');

        const chromeData = {
            actor,
            notifyOpacityId: 0,
        };
        this._chromeActors.push(chromeData);

        if (this._raised)
            this._raiseChromeInternal(chromeData);
    }

    destroy() {
        this._lowerChrome();

        for (const overlayData of this._overlayActors) {
            overlayData.actor.disconnect(overlayData.notifyVisibleId);
            overlayData.actor.disconnect(overlayData.destroyId);
        }

        this._overlayActors = [];
        this._chromeActors = [];
    }
}



const AcknowledgeGesture = GObject.registerClass({
    Signals: {
        'begin': {},
        'end': {},
    },
}, class PomodoroAcknowledgeGesture extends GObject.Object {
    _init(actor) {
        super._init();

        this._actor = actor;
        this._began = false;
        this._lastActiveTime = -1;
        this._intervalId = 0;
        this._eventId = 0;
    }

    begin() {
        if (this._began)
            return;

        this._began = true;
        this._lastActiveTime = GLib.get_monotonic_time() / 1000;

        this._intervalId = GLib.timeout_add(
            GLib.PRIORITY_DEFAULT,
            IDLE_TIME_TO_ACKNOWLEDGE / 10,
            () => {
                const currentTime = GLib.get_monotonic_time() / 1000;
                const idleTime = currentTime - this._lastActiveTime;

                if (idleTime >= IDLE_TIME_TO_ACKNOWLEDGE) {
                    this._intervalId = 0;
                    this._end();

                    return GLib.SOURCE_REMOVE;
                }

                return GLib.SOURCE_CONTINUE;
            });

        this._eventId = this._actor.connect('event', this._handleEvent.bind(this));

        this.emit('begin');
    }

    _end() {
        this._began = false;

        if (this._intervalId) {
            GLib.source_remove(this._intervalId);
            this._intervalId = 0;
        }

        if (this._eventId) {
            this._actor.disconnect(this._eventId);
            this._eventId = 0;
        }

        this.emit('end');
    }

    canHandleEvent(event) {
        if (!this._began)
            return false;

        if (!event.get_device())
            return false;

        switch (event.type()) {
        case Clutter.EventType.BUTTON_PRESS:
        case Clutter.EventType.BUTTON_RELEASE:
        case Clutter.EventType.KEY_PRESS:
        case Clutter.EventType.KEY_RELEASE:
        case Clutter.EventType.MOTION:
        case Clutter.EventType.SCROLL:
        case Clutter.EventType.TOUCHPAD_PINCH:
        case Clutter.EventType.TOUCHPAD_SWIPE:
        case Clutter.EventType.TOUCH_BEGIN:
        case Clutter.EventType.TOUCH_CANCEL:
        case Clutter.EventType.TOUCH_END:
        case Clutter.EventType.TOUCH_UPDATE:
            return true;

        default:
            return false;
        }
    }

    _handleEvent(actor, event) {
        if (!this.canHandleEvent(event))
            return Clutter.EVENT_PROPAGATE;

        this._lastActiveTime = event.get_time();

        return Clutter.EVENT_STOP;
    }
});



const DismissGesture = GObject.registerClass({
    Signals: {
        'begin': {},
        'end': {},
    },
}, class PomodoroDismissGesture extends GObject.Object {
    _init(actor) {
        super._init();

        this._actor = actor;
        this._began = false;
        this._lastMotionX = -1;
        this._lastMotionY = -1;
        this._lastMotionTime = -1;
        this._eventId = 0;
    }

    begin() {
        if (this._began)
            return;

        this._began = true;
        this._eventId = this._actor.connect('event', this._handleEvent.bind(this));

        this.emit('begin');
    }

    _end() {
        this._began = false;

        if (this._eventId) {
            this._actor.disconnect(this._eventId);
            this._eventId = 0;
        }

        this.emit('end');
    }

    canHandleEvent(event) {
        if (!this._began)
            return false;

        if (!event.get_device())
            return false;

        switch (event.type()) {
        case Clutter.EventType.BUTTON_PRESS:
        case Clutter.EventType.KEY_PRESS:
        case Clutter.EventType.MOTION:
        case Clutter.EventType.TOUCHPAD_SWIPE:
        case Clutter.EventType.TOUCH_BEGIN:
            return true;

        default:
            return false;
        }
    }

    _handleEvent(actor, event) {
        if (!this.canHandleEvent(event))
            return Clutter.EVENT_PROPAGATE;

        const time = event.get_time();
        let x, y, dx, dy, dt, velocitySquared;
        let isUserActive = true;

        // Add some resistance to small mouse movements.
        if (event.type() === Clutter.EventType.MOTION) {
            [x, y] = event.get_coords();
            dt = time - this._lastMotionTime;

            if (this._lastMotionTime > 0 && dt > 0) {
                dx = x - this._lastMotionX;
                dy = y - this._lastMotionY;
                velocitySquared = (dx * dx + dy * dy) / (dt * dt);
                isUserActive = velocitySquared > MOTION_VELOCITY_TO_DISMISS * MOTION_VELOCITY_TO_DISMISS;
            } else {
                isUserActive = false;
            }

            this._lastMotionX = x;
            this._lastMotionY = y;
            this._lastMotionTime = time;
        }

        if (isUserActive)
            this._end();

        return Clutter.EVENT_STOP;
    }
});


/**
 * ScreenOverlayBase class is based on ModalDialog from GNOME Shell.
 */
const ScreenOverlayBase = GObject.registerClass({
    Properties: {
        'state': GObject.ParamSpec.int(
            'state', 'state', 'state',
            GObject.ParamFlags.READABLE,
            Math.min(...Object.values(OverlayState)),
            Math.max(...Object.values(OverlayState)),
            OverlayState.CLOSED),
        'has-modal': GObject.ParamSpec.boolean(
            'has-modal', 'has-modal', 'has-modal',
            GObject.ParamFlags.READABLE,
            false),
        'acknowledged': GObject.ParamSpec.boolean(
            'acknowledged', 'acknowledged', 'acknowledged',
            GObject.ParamFlags.READABLE,
            false),
    },
    Signals: {
        'opened': {},
        'opening': {},
        'closed': {},
        'closing': {},
    },
}, class PomodoroScreenOverlayBase extends St.Widget {
    _init() {
        super._init({
            style_class: 'extension-pomodoro-overlay',
            accessible_role: Atk.Role.DIALOG,
            layout_manager: new Clutter.BinLayout(),
            reactive: false,
            visible: false,
            opacity: 0,
        });

        this._state = OverlayState.CLOSED;
        this._hasModal = false;
        this._grab = null;
        this._destroyed = false;
        this._openWhenIdleWatchId = 0;
        this._acknowledged = false;
        this._keyFocusOutId = 0;
        this._capturedEventId = 0;

        this._monitorConstraint = new MonitorConstraint();
        this._monitorConstraint.primary = true;
        this._stageConstraint = new Clutter.BindConstraint({
            source: global.stage,
            coordinate: Clutter.BindCoordinate.ALL,
        });
        this.add_constraint(this._stageConstraint);

        this._idleMonitor = global.backend.get_core_idle_monitor();
        this._session = new GnomeSession.SessionManager();

        this._layout = new St.Widget({layout_manager: new Clutter.BinLayout()});
        this._layout.add_constraint(this._monitorConstraint);
        this.add_child(this._layout);

        // Lightbox will be a direct child of the overlay
        this._lightbox = extension.pluginSettings.get_boolean('blur-effect')
            ? new BlurredLightbox(this) : new PlainLightbox(this);
        this._lightbox.highlight(this._layout);

        global.focus_manager.add_group(this._lightbox);

        OverlayManager.getDefault().add(this);

        this._acknowledgeGesture = new AcknowledgeGesture(this._lightbox);
        this._acknowledgeGesture.connect('end', this.acknowledge.bind(this));

        this._dismissGesture = new DismissGesture(this._lightbox);
        this._dismissGesture.connect('end', this.dismiss.bind(this));

        this.connect('destroy', this._onDestroy.bind(this));
    }

    get state() {
        return this._state;
    }

    _setState(state) {
        if (this._state === state)
            return;

        this._state = state;
        this.notify('state');
    }

    get hasModal() {
        return this._hasModal;
    }

    get acknowledged() {
        return this._acknowledged;
    }

    _beginAcknowledgeGesture() {
        if (this._acknowledged || this._state !== OverlayState.OPENED)
            return;

        // Skip acknowledge gesture if user has been idle for a while.
        if (this._idleMonitor.get_idletime() >= IDLE_TIME_TO_ACKNOWLEDGE * 2) {
            this.acknowledge();
            return;
        }

        // Make overlay modal early in order to start acknowledge gesture. Close if unsuccessful.
        if (this.pushModal())
            this._acknowledgeGesture.begin();
        else
            this.close(true);
    }

    _beginDismissGesture() {
        this._dismissGesture.begin();
    }

    acknowledge() {
        if (this._acknowledged)
            return;

        this._acknowledged = true;
        this.notify('acknowledged');

        if (this.pushModal())
            this._beginDismissGesture();
        else
            this.close(true);
    }

    dismiss() {
        if (this._acknowledged)
            this.close(true);
    }

    // Drop modal status without closing the overlay; this makes the
    // overlay insensitive as well, so it needs to be followed shortly
    // by either a close() or a pushModal()
    popModal(timestamp) {
        if (this._capturedEventId) {
            this._lightbox.disconnect(this._capturedEventId);
            this._capturedEventId = 0;
        }

        if (this._keyFocusOutId) {
            this._lightbox.disconnect(this._keyFocusOutId);
            this._keyFocusOutId = 0;
        }

        if (!this._hasModal)
            return;

        Main.popModal(this._grab, timestamp);
        this._grab = null;
        this._hasModal = false;
        this._lightbox.reactive = false;

        this.notify('has-modal');
    }

    pushModal(timestamp) {
        if (this._hasModal)
            return true;

        if (this.state === OverlayState.CLOSED || this.state === OverlayState.CLOSING || this._destroyed)
            return false;

        const params = {actionMode: Shell.ActionMode.SYSTEM_MODAL};
        if (timestamp)
            params['timestamp'] = timestamp;

        const grab = Main.pushModal(this, params);
        if (grab && grab.get_seat_state() !== Clutter.GrabState.ALL) {
            Utils.logWarning('Unable become fully modal');
            Main.popModal(grab);
            return false;
        }

        if (!grab)
            return false;

        this._grab = grab;
        this._hasModal = true;
        this._lightbox.reactive = true;
        this._lightbox.grab_key_focus();

        if (!this._capturedEventId)
            this._capturedEventId = this._lightbox.connect('captured-event', this._onCapturedEvent.bind(this));

        if (!this._keyFocusOutId)
            this._keyFocusOutId = this._lightbox.connect('key-focus-out', this._onKeyFocusOut.bind(this));

        this.notify('has-modal');

        Main.layoutManager.emit('system-modal-opened');

        return true;
    }

    _canOpen() {
        return !this._destroyed;
    }

    // Gradually open the overlay. Try to make it modal once user had chance to see it
    // and schedule to close it once user becomes active.
    open(animate = true) {
        if (this.state === OverlayState.OPENED || this.state === OverlayState.OPENING)
            return true;

        if (!this._canOpen())
            return false;

        this.remove_all_transitions();
        this._setState(OverlayState.OPENING);
        this._lastEventX = -1;
        this._lastEventY = -1;
        this._lastMotionTime = -1;
        this._lastActiveTime = -1;
        this._acknowledged = false;
        this.notify('acknowledged');
        this.emit('opening');
        this.show();

        if (animate) {
            if (this._idleMonitor.get_idletime() >= IDLE_TIME_TO_ACKNOWLEDGE * 2)
                this.acknowledge();

            this._lightbox.lightOn(FADE_IN_TIME);
            this.ease({
                opacity: 255,
                duration: FADE_IN_TIME,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                onComplete: this._onOpenComplete.bind(this),
            });
        } else {
            this._lightbox.lightOn();
            this.opacity = 255;
            this._onOpenComplete();
        }

        return true;
    }

    _onBecomeIdle(_monitor) {
        try {
            this.open(true);
        } catch (error) {
            Utils.logError(error);
        }
    }

    // Schedule to open when user becomes idle.
    openWhenIdle() {
        if (this.state === OverlayState.OPENED || this.state === OverlayState.OPENING || this._destroyed)
            return;

        if (!this._openWhenIdleWatchId) {
            this._openWhenIdleWatchId = this._idleMonitor.add_idle_watch(
                IDLE_TIME_TO_OPEN, this._onBecomeIdle.bind(this));
        }
    }

    close(animate = true) {
        if (this.state === OverlayState.CLOSED || this.state === OverlayState.CLOSING)
            return;

        this.popModal();
        this._setState(OverlayState.CLOSING);
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

    _onOpenComplete() {
        this._setState(OverlayState.OPENED);
        this._beginAcknowledgeGesture();

        this.emit('opened');
    }

    _onCloseComplete() {
        this.hide();
        this._setState(OverlayState.CLOSED);

        this.emit('closed');
    }

    _onCapturedEvent(actor, event) {
        if (event.type() !== Clutter.EventType.KEY_PRESS)
            return Clutter.EVENT_PROPAGATE;

        // TODO: block printscreen

        if (event.get_key_symbol() === Clutter.KEY_Escape && this._state === OverlayState.OPENED)
            this.close(true);


        if (this._acknowledged)
            this.close(true);

        return Clutter.EVENT_PROPAGATE;
    }

    _onKeyFocusOut() {
        const focus = global.stage.key_focus;

        if (focus === null || !this._lightbox.contains(focus))
            this.close(true);
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


export const ScreenOverlay = GObject.registerClass({
    Properties: {
        'use-gestures': GObject.ParamSpec.boolean(
            'use-gestures', 'use-gestures', 'use-gestures',
            GObject.ParamFlags.READWRITE,
            true),
    },
}, class PomodoroScreenOverlay extends ScreenOverlayBase {
    _init(timer) {
        super._init();

        const buttonsBox = new St.BoxLayout({
            style_class: 'extension-pomodoro-overlay-buttons',
            x_align: Clutter.ActorAlign.END,
            y_align: Clutter.ActorAlign.START,
        });
        if (Utils.isVersionAtLeast('48'))
            buttonsBox.orientation = Clutter.Orientation.HORIZONTAL;
        else
            buttonsBox.vertical = false;

        const lockScreenButton = this._createIconButton('lock-screen-symbolic');
        lockScreenButton.connect('clicked', this._onLockScreenButtonClicked.bind(this));
        buttonsBox.add_child(lockScreenButton);

        const closeButton = this._createIconButton('close-symbolic');
        closeButton.connect('clicked', this._onCloseButtonClicked.bind(this));
        buttonsBox.add_child(closeButton);

        const contentsBox = new St.BoxLayout({
            style_class: 'extension-pomodoro-overlay-contents',
            x_align: Clutter.ActorAlign.FILL,
            y_align: Clutter.ActorAlign.CENTER,
            y_expand: true,
        });
        if (Utils.isVersionAtLeast('48'))
            contentsBox.orientation = Clutter.Orientation.VERTICAL;
        else
            contentsBox.vertical = true;

        const timerLabel = new TimerLabel(timer, {
            x_align: Clutter.ActorAlign.CENTER,
        });
        contentsBox.add_child(timerLabel);

        const descriptionLabel = new St.Label({
            style_class: 'extension-pomodoro-overlay-description',
            text: _("It's time to take a break"),
            x_align: Clutter.ActorAlign.CENTER,
        });
        descriptionLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        descriptionLabel.clutter_text.line_wrap = true;
        contentsBox.add_child(descriptionLabel);

        const doNotTouchIcon = new St.Icon({
            style_class: 'extension-pomodoro-do-not-touch-icon',
            gicon: Utils.loadIcon('do-not-touch-symbolic'),
            icon_size: ICON_SIZE,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.END,
        });

        const container = new St.BoxLayout({
            style_class: 'extension-pomodoro-overlay-container',
            x_expand: true,
            y_expand: true,
        });
        if (Utils.isVersionAtLeast('48'))
            container.orientation = Clutter.Orientation.VERTICAL;
        else
            container.vertical = true;

        container.add_child(buttonsBox);
        container.add_child(contentsBox);
        container.add_child(doNotTouchIcon);

        this._layout.add_child(container);

        this._timer = timer;
        this._timerStateChangedId = this._timer.connect('state-changed', this._freezeTimerLabel.bind(this));
        this._buttonsBox = buttonsBox;
        this._timerLabel = timerLabel;
        this._doNotTouchIcon = doNotTouchIcon;
        this._systemActions = new SystemActions.getDefault();

        this.bind_property('use-gestures', buttonsBox, 'visible',
            GObject.BindingFlags.SYNC_CREATE | GObject.BindingFlags.INVERT_BOOLEAN);
        this.bind_property('use-gestures', doNotTouchIcon, 'visible',
            GObject.BindingFlags.SYNC_CREATE);

        this.connect('notify::acknowledged', this._updateDoNotTouchIcon.bind(this));
        this.connect('opening', this._onOpening.bind(this));
        this.connect('closing', this._onClosing.bind(this));

        this._freezeTimerLabel();
        this._updateDoNotTouchIcon();
    }

    get timer() {
        return this._timer;
    }

    get useGestures() {
        return this._useGestures;
    }

    set useGestures(value) {
        if (this._useGestures === value)
            return;

        this._useGestures = value;
        this.notify('use-gestures');
    }

    _createIconButton(iconName) {
        const icon = new St.Icon({
            gicon: Utils.loadIcon(iconName),
            style_class: 'popup-menu-icon',
            icon_size: ICON_SIZE,
        });
        const iconButton = new St.Button({
            reactive: true,
            can_focus: false,
            track_hover: true,
            style_class: 'icon-button',
        });
        iconButton.add_style_class_name('flat');
        iconButton.set_child(icon);

        return iconButton;
    }

    _canOpen() {
        if (!this._timer)
            return false;

        if (!this._timer.isBreak() ||
            this._timer.isPaused() ||
            this._timer.getRemaining() < OPEN_WHEN_IDLE_MIN_REMAINING_TIME)
            return false;

        return super._canOpen();
    }

    acknowledge() {
        if (this._useGestures) {
            super.acknowledge();
            return;
        }

        if (!this.pushModal())
            this.close(true);
    }

    _beginAcknowledgeGesture() {
        if (this._useGestures) {
            super._beginAcknowledgeGesture();
            return;
        }

        this.acknowledge();
    }

    _beginDismissGesture() {
        if (this._useGestures)
            super._beginDismissGesture();
    }

    _freezeTimerLabel() {
        const timerState = this._timer.getState();

        if (timerState === State.SHORT_BREAK || timerState === State.LONG_BREAK)
            this._timerLabel.freezeState();
    }

    _updateDoNotTouchIcon() {
        this._doNotTouchIcon.remove_all_transitions();

        if (this._acknowledged && this._lightbox.opacity === 0) {
            this._doNotTouchIcon.opacity = 0;
        } else {
            this._doNotTouchIcon.ease({
                opacity: this.acknowledged ? 0 : 255,
                duration: 100,
                mode: Clutter.AnimationMode.EASE_IN_QUAD,
            });
        }
    }

    _onLockScreenButtonClicked() {
        this._systemActions.activateLockScreen();
    }

    _onCloseButtonClicked() {
        this.close(true);
    }

    _onOpening() {
        this._timerLabel.unfreeze();
    }

    _onClosing() {
        this._timerLabel.freeze();
    }

    _onDestroy() {
        if (this._timerStateChangedId) {
            this._timer.disconnect(this._timerStateChangedId);
            this._timerStateChangedId = 0;
            this._timer = null;
        }

        super._onDestroy();
    }
});
