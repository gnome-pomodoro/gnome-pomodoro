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

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {trySpawnCommandLine} from 'resource:///org/gnome/shell/misc/util.js';
import {gettext as _} from 'resource:///org/gnome/shell/extensions/extension.js';
import {PopupAnimation} from 'resource:///org/gnome/shell/ui/boxpointer.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as MessageTray from 'resource:///org/gnome/shell/ui/messageTray.js';
import * as Params from 'resource:///org/gnome/shell/misc/params.js';
import * as Signals from 'resource:///org/gnome/shell/misc/signals.js';
let DoNotDisturb;
try {
    DoNotDisturb = await import('resource:///org/gnome/shell/ui/status/doNotDisturb.js');
} catch {}

import {extension} from './extension.js';
import {State} from './timer.js';
import * as Config from './config.js';
import * as ScreenOverlay from './screenOverlay.js';
import * as Utils from './utils.js';


// Time in seconds to annouce next timer state.
const ANNOUCEMENT_TIME = 10.0;

// Min display time in milliseconds after content changes.
const NOTIFICATION_TIMEOUT = 3000;

// Use symbolic icon instead of hi-res as in the app.
const ICON_NAME = 'gnome-pomodoro-symbolic';


let source = null;


/**
 * The source that should be used for our notifications.
 */
export function getDefaultSource() {
    if (!source) {
        source = new MessageTray.Source({
            title: _('Pomodoro Timer'),
            iconName: ICON_NAME,
            policy: new NotificationPolicy(),
        });

        source.connect('destroy', () => {
            source = null;
        });
        Main.messageTray.add(source);
    }

    return source;
}


/**
 * Format seconds as string "<number> <unit> remaining".
 *
 * @param {number} remaining - remaining seconds
 * @returns {string}
 */
export function formatRemainingTime(remaining) {
    let seconds = Math.round(remaining);
    let minutes;

    if (seconds > 45) {
        minutes = Math.round(seconds / 60);

        return GLib.dngettext(Config.GETTEXT_PACKAGE, '%d minute remaining', '%d minutes remaining', minutes).format(minutes);
    } else {
        seconds = seconds > 15
            ? Math.round(seconds / 15) * 15
            : Math.max(seconds, 0);

        return GLib.dngettext(Config.GETTEXT_PACKAGE, '%d second remaining', '%d seconds remaining', seconds).format(seconds);
    }
}


const NotificationView = {
    NULL: 0,
    POMODORO: 1,
    POMODORO_ABOUT_TO_END: 2,
    BREAK: 3,
    BREAK_ABOUT_TO_END: 4,
    BREAK_ENDED: 5,
};


const NotificationPolicy = GObject.registerClass(
class PomodoroNotificationPolicy extends MessageTray.NotificationPolicy {
    get showBanners() {
        return true;
    }

    get showInLockScreen() {
        return false;
    }
});


export const Notification = GObject.registerClass({
    Properties: {
        'view': GObject.ParamSpec.int('view', '', '',
            GObject.ParamFlags.READWRITE,
            0,
            GLib.MAXINT32,
            NotificationView.NULL),
    },
},
class PomodoroNotification extends MessageTray.Notification {
    constructor(timer, params) {
        params = Params.parse(params, {
            source: getDefaultSource(),
            useBodyMarkup: false,
        });

        super(params);

        // Notification will update its contents.
        this.resident = true;

        // Notification should not expire while the timer is running.
        this.isTransient = false;

        // Show notification regardless of session busy status.
        this.forFeedback = true;

        // Hide notification on screen shield.
        this.privacyScope = MessageTray.PrivacyScope.USER;

        // We want notifications to be shown right after the action,
        // therefore urgency bump.
        this.urgency = MessageTray.Urgency.HIGH;

        this._timer = timer;
        this._timerState = State.NULL;
        this._timerUpdateId = this._timer.connect('update', this._onTimerUpdate.bind(this));
        this._view = NotificationView.NULL;

        this.connect(
            'destroy', () => {
                if (this._timerUpdateId) {
                    this._timer.disconnect(this._timerUpdateId);
                    this._timerUpdateId = 0;
                }

                this._timer = null;
            }
        );
    }

    get timer() {
        return this._timer;
    }

    get view() {
        return this._view;
    }

    set view(value) {
        if (!Object.values(NotificationView).includes(value))
            throw new Error('out of range');

        if (this._view !== value) {
            this._view = value;
            this.notify('view');
        }

        this._update();
    }

    get timerState() {
        return this._timerState;
    }

    get datetime() {
        return null;
    }

    set datetime(value) {
    }

    _updateTitle() {
        let title;
        const isStarting = this._timer.getElapsed() < 0.1;

        switch (this._view) {
        case NotificationView.POMODORO:
            title = isStarting ? _('Pomodoro') : State.label(this._timerState);  // TODO: change title when starting a pomodoro
            break;

        case NotificationView.POMODORO_ABOUT_TO_END:
            title = _('Pomodoro is about to end');
            break;

        case NotificationView.BREAK:
            if (isStarting) {
                title = this._timerState === State.LONG_BREAK
                    ? _('Take a long break')
                    : _('Take a short break');
            } else {
                title = State.label(this._timerState);
            }
            break;

        case NotificationView.BREAK_ABOUT_TO_END:
            title = _('Break is about to end');
            break;

        case NotificationView.BREAK_ENDED:
            title = _('Break is over');
            break;

        default:
            title = State.label(this._timerState);
            break;
        }

        this.title = title;
    }

    _updateBody() {
        let body;

        switch (this._view) {
        case NotificationView.POMODORO:
        case NotificationView.POMODORO_ABOUT_TO_END:
        case NotificationView.BREAK:
        case NotificationView.BREAK_ABOUT_TO_END:
            body = formatRemainingTime(this._timer.getRemaining());
            break;

        case NotificationView.BREAK_ENDED:
            body = _('Get ready…');
            break;

        default:
            body = '';
            break;
        }

        this.body = body;
    }

    _updateActions() {
        // Display only one variant of buttons or none across all notification views.

        const hasActions = this.actions.length > 0;
        const showActions =
            this._view === NotificationView.POMODORO_ABOUT_TO_END ||
            this._view === NotificationView.BREAK ||
            this._view === NotificationView.BREAK_ABOUT_TO_END;
        if (hasActions === showActions)
            return;

        if (showActions) {
            this.addAction(_('Skip Break'), () => {
                this._timer.setState(State.POMODORO);
            });
            this.addAction(_('+1 Minute'), () => {
                // Force not closing the banner after click. This may be reverted back to proper value after
                // the timer state change.
                this.resident = true;

                this._timer.stateDuration += 60.0;
            });
        } else {
            this.clearActions();
        }
    }

    _update() {
        this._timerState = this._timer.getState();

        this._updateTitle();
        this._updateBody();
        this._updateActions();
    }

    _onTimerUpdate() {
        if (this._timer.getState() !== this._timerState)
            return;

        this._updateBody();
    }
});


export const IssueNotification = GObject.registerClass(
class PomodoroIssueNotification extends MessageTray.Notification {
    constructor(message) {
        super({
            source: getDefaultSource(),
            title: _('Pomodoro Timer'),
            body: message,
            urgency: MessageTray.Urgency.HIGH,
            isTransient: true,
            useBodyMarkup: true,
        });

        this.addAction(_('Report issue'), () => {
            trySpawnCommandLine(`xdg-open ${GLib.shell_quote(Config.PACKAGE_BUGREPORT)}`);
        });
    }
});


export const NotificationManager = class extends Signals.EventEmitter {
    constructor(timer, params) {
        params = Params.parse(params, {
            useScreenOverlay: true,
            animate: true,
        });

        super();

        this._timer = timer;
        this._timerState = State.NULL;
        this._notification = null;
        this._screenOverlay = null;
        this._useScreenOverlay = params.useScreenOverlay;
        this._view = NotificationView.NULL;
        this._patches = this._createPatches();
        this._destroying = false;

        this._annoucementTimeoutId = 0;
        this._timerStateChangedId = this._timer.connect('state-changed', this._onTimerStateChanged.bind(this));
        this._timerPausedId = this._timer.connect('paused', this._onTimerPaused.bind(this));
        this._timerResumedId = this._timer.connect('resumed', this._onTimerResumed.bind(this));

        this._update(params.animate);
    }

    get timer() {
        return this._timer;
    }

    get notification() {
        return this._notification;
    }

    get screenOverlay() {
        return this._screenOverlay;
    }

    get useScreenOverlay() {
        return this._useScreenOverlay;
    }

    set useScreenOverlay(value) {
        this._useScreenOverlay = value;
    }

    _createPatches() {
        const messagesIndicatorPatch = new Utils.Patch(Main.panel.statusArea.dateMenu._indicator, {
            _sync() {
                this.icon_name = 'message-indicator-symbolic';
                this.visible = this._count > 0;
            },
        });
        messagesIndicatorPatch.connect('applied', () => {
            Main.panel.statusArea.dateMenu._indicator._sync();
        });
        messagesIndicatorPatch.connect('reverted', () => {
            Main.panel.statusArea.dateMenu._indicator._sync();
        });

        const messageTrayPatch = new Utils.Patch(Main.messageTray, {
            _expandBanner(autoExpanding) {
                // Don't auto expand pomodoro notifications, despite Urgency.CRITICAL.
                if (autoExpanding && this._notification instanceof Notification)
                    return;

                messageTrayPatch.initial._expandBanner.bind(this)(autoExpanding);
            },
        });

        return [
            messagesIndicatorPatch,
            messageTrayPatch,
        ];
    }

    _createNotification() {
        const notification = new Notification(this._timer);
        notification.connect('activated',
            () => {
                switch (this._view) {
                case NotificationView.POMODORO:
                    break;

                case NotificationView.POMODORO_ABOUT_TO_END:
                    this._timer.skip();
                    this.openScreenOverlay();
                    break;

                case NotificationView.BREAK:
                    this.openScreenOverlay();
                    break;
                }
            });
        notification.connect('destroy',
            () => {
                if (this._notification === notification)
                    this._notification = null;
            });

        return notification;
    }

    _createScreenOverlay() {
        const screenOverlay = new ScreenOverlay.ScreenOverlay(this._timer);
        screenOverlay.connect('opening',
            () => {
                // `MessageTray` opens a banner as soon as the date menu starts closing. To avoid unnecessary flicker
                // destroy the notification before `MessageTray` considers it.
                const dateMenu = Main.panel.statusArea.dateMenu?.menu;

                this._expireNotification();

                if (dateMenu && dateMenu.actor.visible)
                    dateMenu.close(PopupAnimation.NONE);
            });
        screenOverlay.connect('closing',
            () => {
                if (this._view !== NotificationView.NULL && !this._destroying) {
                    this._expireNotification();
                    this._notify();

                    if (this._view === NotificationView.BREAK)
                        screenOverlay.openWhenIdle();
                }
            });
        screenOverlay.connect('destroy',
            () => {
                if (this._screenOverlay === screenOverlay)
                    this._screenOverlay = null;
            });

        extension.pluginSettings.bind('dismiss-gesture', screenOverlay, 'use-gestures', Gio.SettingsBindFlags.DEFAULT);

        return screenOverlay;
    }

    _isScreenOverlayOpened() {
        return this._screenOverlay && (
            this._screenOverlay.state === ScreenOverlay.OverlayState.OPENED ||
            this._screenOverlay.state === ScreenOverlay.OverlayState.OPENING);
    }

    openScreenOverlay(animate = true) {
        if (this._destroying)
            return false;

        if (!this._screenOverlay)
            this._screenOverlay = this._createScreenOverlay();

        return this._screenOverlay.open(animate);
    }

    _openScreenOverlayOrNotify(animate) {
        if (this._destroying)
            return;

        // TODO: detect webcam

        if (!this.openScreenOverlay(animate))
            this._notify();
    }

    _showDoNotDisturbButton() {
        if (DoNotDisturb) {
            for (const indicator of Main.panel.statusArea.quickSettings._indicators.get_children()) {
                if (indicator instanceof DoNotDisturb.Indicator) {
                    for (const qs of indicator.quickSettingsItems) {
                        qs.reactive = true;
                    }
                }
            }
            return;
        }

        const dndButton = Main.panel.statusArea.dateMenu._messageList._dndButton;
        dndButton.show();

        for (const sibling of [dndButton.get_previous_sibling(), dndButton.get_next_sibling()]) {
            if (sibling instanceof St.Label)
                sibling.show();
        }
    }

    _hideDoNotDisturbButton() {
        if (DoNotDisturb) {
            for (const indicator of Main.panel.statusArea.quickSettings._indicators.get_children()) {
                if (indicator instanceof DoNotDisturb.Indicator) {
                    for (const qs of indicator.quickSettingsItems) {
                        qs.reactive = false;
                    }
                }
            }
            return;
        }

        const dndButton = Main.panel.statusArea.dateMenu._messageList._dndButton;
        dndButton.hide();

        for (const sibling of [dndButton.get_previous_sibling(), dndButton.get_next_sibling()]) {
            if (sibling instanceof St.Label)
                sibling.hide();
        }
    }

    _applyPatches() {
        this._hideDoNotDisturbButton();

        for (const patch of this._patches)
            patch.apply();
    }

    _revertPatches() {
        this._showDoNotDisturbButton();

        for (const patch of this._patches)
            patch.revert();
    }

    // TODO: move annoucements to a helper class
    _scheduleAnnoucement() {
        const timeout = Math.round(this._timer.getRemaining() - ANNOUCEMENT_TIME);

        this._unscheduleAnnoucement();

        if (timeout <= 0) {
            this._onAnnoucementTimeout();
            return;
        }

        this._annoucementTimeoutId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT,
            timeout,
            this._onAnnoucementTimeout.bind(this));
        GLib.Source.set_name_by_id(this._annoucementTimeoutId,
            '[gnome-pomodoro] NotificationManager._annoucementTimeoutId');
    }

    _unscheduleAnnoucement() {
        if (this._annoucementTimeoutId) {
            GLib.source_remove(this._annoucementTimeoutId);
            this._annoucementTimeoutId = 0;
        }
    }

    _resolveView(timerState, isPaused, isStarting, isEnding) {
        if (isPaused) {
            return timerState === State.POMODORO && isStarting
                ? NotificationView.BREAK_ENDED
                : NotificationView.NULL;
        }

        switch (timerState) {
        case State.POMODORO:
            if (isEnding)
                return NotificationView.POMODORO_ABOUT_TO_END;

            return NotificationView.POMODORO;

        case State.SHORT_BREAK:
        case State.LONG_BREAK:
            if (isEnding)
                return NotificationView.BREAK_ABOUT_TO_END;

            return NotificationView.BREAK;
        }

        return NotificationView.NULL;
    }

    _expireNotification(animate = false) {
        if (!this._notification)
            return;

        const notification = this._notification;

        this._notification = null;

        if (animate &&
            Main.messageTray._notification === notification &&
            Main.messageTray._notificationState !== MessageTray.State.HIDDEN) {
            notification.isTransient = true;
            notification.acknowledged = true;

            Main.messageTray._expireNotification();
        } else {
            notification.destroy(MessageTray.NotificationDestroyedReason.EXPIRED);
        }
    }

    _updateNotification() {
        if (!this._notification || this._destroying)
            return;

        const notification = this._notification;
        const timerState = this._timerState;
        const view = this._view;
        const isStarting = this._timer.getElapsed() < 0.1;

        let changed = false;

        // Use Urgency.CRITICAL to force notification banner to stay open.
        const isUrgent =
            view === NotificationView.POMODORO_ABOUT_TO_END ||
            view === NotificationView.BREAK_ABOUT_TO_END ||
            view === NotificationView.BREAK_ENDED;
        const urgency = isUrgent ? MessageTray.Urgency.CRITICAL : MessageTray.Urgency.HIGH;
        if (notification.urgency !== urgency) {
            notification.urgency = urgency;
            changed = true;
        }

        const isTransient =
            view === NotificationView.POMODORO ||
            view === NotificationView.NULL;
        if (notification.isTransient !== isTransient) {
            notification.isTransient = isTransient;
            changed = true;
        }

        const forceResident =
            view === NotificationView.POMODORO_ABOUT_TO_END ||
            view === NotificationView.BREAK_ABOUT_TO_END ||
            view === NotificationView.BREAK_ENDED;
        const resident = (!isTransient || forceResident) && view !== NotificationView.NULL;
        if (notification.resident !== resident) {
            notification.resident = resident;
            changed = true;
        }

        // Keep the view shown in the banner after extending duration.
        const banner = Main.messageTray._banner?.notification === notification ? Main.messageTray._banner : null;
        const keepBannerView = !isStarting && (
            notification.view === NotificationView.POMODORO_ABOUT_TO_END && view === NotificationView.POMODORO);

        if (banner && keepBannerView)
            changed = false;
        else if (notification.view !== view)
            changed = true;
        else if (notification.timerState !== timerState)
            changed = true;

        if (changed) {
            notification.view = view;
            notification.acknowledged = false;
        }
    }

    _notify(animate = true) {
        if (this._destroying)
            return;

        if (this._screenOverlay)
            this._screenOverlay.close(animate);

        if (!this._notification)
            this._notification = this._createNotification();

        this._updateNotification();

        const notification = this._notification;

        if (notification.acknowledged)
            notification.acknowledged = false;

        notification.source.addNotification(notification);

        if (Main.messageTray._notification === notification && notification.urgency !== MessageTray.Urgency.CRITICAL)
            Main.messageTray._updateNotificationTimeout(NOTIFICATION_TIMEOUT);
    }

    _shouldNotify(timerState, view, isStarting) {
        if (view === NotificationView.NULL || timerState === State.NULL)
            return false;

        // Pomodoro has been extended.
        if (this._view === NotificationView.POMODORO_ABOUT_TO_END && view === NotificationView.POMODORO && !isStarting)
            return false;

        // Break has been extended.
        if (this._view === NotificationView.BREAK_ABOUT_TO_END && view === NotificationView.BREAK && !isStarting)
            return false;

        // Update existing banner after skipping a break.
        const banner = Main.messageTray._banner?.notification === this._notification
            ? Main.messageTray._banner : null;
        if (banner && Main.messageTray._notificationHovered && view === NotificationView.POMODORO && isStarting)
            return false;

        // Screen overlay is already opened.
        if (this._isScreenOverlayOpened()) {
            if (timerState === State.SHORT_BREAK || timerState === State.LONG_BREAK)
                return false;

            if (view === NotificationView.BREAK_ABOUT_TO_END)
                return false;
        }

        return this._timerState !== timerState || this._view !== view || isStarting;
    }

    _update(animate = true) {
        const timerState = this._timer.getState();

        if (timerState !== State.NULL) {
            const isPaused = this._timer.isPaused();
            const isStarting = this._timer.getElapsed() < 0.1;
            const isEnding = this._timer.getRemaining() <= ANNOUCEMENT_TIME + 5.0;

            const previousTimerState = this._timerState;
            const previousView = this._view;
            const view = this._resolveView(timerState, isPaused, isStarting, isEnding);
            const notify = this._shouldNotify(timerState, view, isStarting);

            this._applyPatches();

            this._timerState = timerState;
            this._view = view;

            if (notify) {
                if (this._useScreenOverlay && view === NotificationView.BREAK) {
                    this._openScreenOverlayOrNotify(animate);
                } else {
                    if (previousView === NotificationView.POMODORO && view === NotificationView.BREAK ||
                        previousView === NotificationView.POMODORO_ABOUT_TO_END && view === NotificationView.BREAK ||
                        previousView === NotificationView.BREAK && view === NotificationView.POMODORO ||
                        previousView === NotificationView.BREAK_ABOUT_TO_END && view === NotificationView.POMODORO ||
                        previousView === NotificationView.BREAK_ENDED && view === NotificationView.POMODORO ||
                        previousView === view && previousTimerState !== timerState)
                        this._expireNotification(animate);

                    this._notify(animate);
                }
            } else {
                if (this._screenOverlay && (timerState !== State.SHORT_BREAK && timerState !== State.LONG_BREAK))
                    this._screenOverlay.close(animate);

                if (view !== NotificationView.NULL)
                    this._updateNotification();
                else
                    this._expireNotification(false);
            }

            // Change of state duration may not trigger "changed" signal, so (re)schedule annoucement here.
            if (view === NotificationView.POMODORO || view === NotificationView.BREAK)
                this._scheduleAnnoucement();
            else
                this._unscheduleAnnoucement();
        } else {
            this._timerState = State.NULL;
            this._view = NotificationView.NULL;

            this._unscheduleAnnoucement();

            if (this._screenOverlay) {
                this._screenOverlay.destroy();
                this._screenOverlay = null;
            }

            if (this._notification) {
                this._notification.destroy(MessageTray.NotificationDestroyedReason.EXPIRED);
                this._notification = null;
            }

            // Ensure stopping the timer removes all notifications.
            if (source) {
                const notifications = source ? source.notifications : [];

                notifications.forEach(notification => {
                    if (notification instanceof Notification)
                        notification.destroy(MessageTray.NotificationDestroyedReason.EXPIRED);
                });
            }

            this._revertPatches();
        }
    }

    _onAnnoucementTimeout() {
        this._annoucementTimeoutId = 0;
        this._view = this._resolveView(this._timerState, false, false, true);

        if (!this._isScreenOverlayOpened() && this._view !== NotificationView.NULL)
            this._notify();

        return GLib.SOURCE_REMOVE;
    }

    _onTimerStateChanged() {
        this._update();
    }

    _onTimerPaused() {
        this._update();
    }

    _onTimerResumed() {
        this._update();
    }

    destroy() {
        this._destroying = true;
        this._timerState = State.NULL;
        this._view = NotificationView.NULL;
        this._unscheduleAnnoucement();

        if (this._screenOverlay) {
            this._screenOverlay.destroy();
            this._screenOverlay = null;
        }

        if (this._notification) {
            this._notification.destroy(MessageTray.NotificationDestroyedReason.EXPIRED);
            this._notification = null;
        }

        if (this._timerStateChangedId) {
            this._timer.disconnect(this._timerStateChangedId);
            this._timerStateChangedId = 0;
        }

        if (this._timerPausedId) {
            this._timer.disconnect(this._timerPausedId);
            this._timerPausedId = 0;
        }

        if (this._timerResumedId) {
            this._timer.disconnect(this._timerResumedId);
            this._timerResumedId = 0;
        }

        for (const patch of this._patches)
            patch.destroy();

        this.emit('destroy');
    }
};
