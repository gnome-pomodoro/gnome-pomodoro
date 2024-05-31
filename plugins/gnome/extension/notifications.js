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

import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {EventEmitter} from 'resource:///org/gnome/shell/misc/signals.js';
import {trySpawnCommandLine} from 'resource:///org/gnome/shell/misc/util.js';
import {gettext as _} from 'resource:///org/gnome/shell/extensions/extension.js';
import {PopupAnimation} from 'resource:///org/gnome/shell/ui/boxpointer.js';
import * as Calendar from 'resource:///org/gnome/shell/ui/calendar.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as MessageTray from 'resource:///org/gnome/shell/ui/messageTray.js';
import * as Params from 'resource:///org/gnome/shell/misc/params.js';

import {extension} from './extension.js';
import {PomodoroEndDialog, DialogState} from './dialogs.js';
import {State} from './timer.js';
import * as Config from './config.js';
import * as Utils from './utils.js';


// Time in seconds to annouce next timer state.
const ANNOUCEMENT_TIME = 10.0;

// Min display time in milliseconds after content changes.
const NOTIFICATION_TIMEOUT = 3000;

// Use symbolic icon instead of hi-res as in the app.
const ICON_NAME = 'gnome-pomodoro-symbolic';


let source = null;


/**
 *
 */
function getDefaultSource() {
    if (!source) {
        source = new Source();
        source.connect('destroy',
            _source => {
                if (_source === source)
                    source = null;
            });
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


const Source = GObject.registerClass(
class PomodoroSource extends MessageTray.Source {
    _init() {
        super._init(_('Pomodoro Timer'), ICON_NAME);
    }

    /* override parent method */
    _createPolicy() {
        return new NotificationPolicy();
    }
});


export const Notification = GObject.registerClass({
    Properties: {
        // TODO: timer should be a property
        'view': GObject.ParamSpec.int('view', 'view', 'view',
            GObject.ParamFlags.READWRITE,
            Math.min(...Object.values(NotificationView)),
            Math.max(...Object.values(NotificationView)),
            NotificationView.NULL),
    },
},
class PomodoroNotification extends MessageTray.Notification {
    _init(timer) {
        super._init(null, '', null, null);

        // Notification will update its contents.
        this.setResident(true);

        // Notification should not expire while the timer is running.
        this.setTransient(false);

        // Show notification regardless of session busy status.
        this.setForFeedback(true);

        // We want notifications to be shown right after the action,
        // therefore urgency bump.
        this.setUrgency(MessageTray.Urgency.HIGH);

        this._timer = timer;
    }

    get timer() {
        return this._timer;
    }

    // `createBanner()` is used only to display a notification popup.
    // Banners in calendar menu or the lock screen are made by GNOME Shell.
    createBanner() {
        let idleId = 0;

        const banner = new NotificationBanner(this);

        // We keep notification as resident to keep banner visible. Once we want to hide the banner
        // we need to update the notification.
        // Note that `notify::mapped` will be triggered when we're moving MessageTray above the dialog.
        banner.connect('notify::mapped', () => {
            if (idleId) {
                GLib.source_remove(idleId);
                idleId = 0;
            }

            if (!banner.mapped) {
                idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
                    idleId = 0;

                    // TODO: this should be handled by NotificationManager
                    if (this.resident && extension.notificationManager)
                        extension.notificationManager._updateNotification();


                    return GLib.SOURCE_REMOVE;
                });
                GLib.Source.set_name_by_id(idleId, '[gnome-shell] banner._onNotifyMapped()');
            }
        });

        return banner;
    }

    show() {
        if (!this.source)
            this.source = getDefaultSource();


        if (this.source) {
            this.acknowledged = false;

            if (!Main.messageTray.contains(this.source))
                Main.messageTray.add(this.source);

            this.source.showNotification(this);
        } else {
            Utils.logWarning('Called Notification.show() after destroy()');
        }
    }
});


const NotificationBanner = GObject.registerClass(
class PomodoroNotificationBanner extends MessageTray.NotificationBanner {
    _init(notification) {
        super._init(notification);

        this._timer = notification.timer;
        this._view = NotificationView.NULL;
        this._timerState = null;
        this._skipBreakButton = null;
        this._extendButton = null;
        this._updateActionsBlocked = false;
        this._timerUpdateId = 0;

        this._notificationUpdatedId = this.notification.connect('updated', this._onNotificationUpdated.bind(this));

        this.notification.connectObject(
            'destroy', reason => {  // eslint-disable-line no-unused-vars
                if (this._notificationUpdatedId) {
                    notification.disconnect(this._notificationUpdatedId);
                    this._notificationUpdatedId = 0;
                }

                if (this._timerUpdateId) {
                    this._timer.disconnect(this._timerUpdateId);
                    this._timerUpdateId = 0;
                }
            }
        );

        this._onNotificationUpdated();
    }

    get timer() {
        return this._timer;
    }

    get view() {
        return this._view;
    }

    /* override parent method */
    canClose() {
        return false;
    }

    _blockUpdateActions() {
        if (!this._updateActionsBlocked)
            this._updateActionsBlocked = true;
    }

    _updateTitle() {
        let title;
        const isStarting = this._timer.getElapsed() < 0.1;

        switch (this._view) {
        case NotificationView.POMODORO:
            title = isStarting ? _('Pomodoro') : State.label(this._timerState);
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

        this.setTitle(title);
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

        this.setBody(body);
    }

    _updateActions() {
        // Currently we display only one variant of buttons across all notification views.

        const hasButtons = this._skipBreakButton !== null && this._extendButton !== null;
        const showButtons =
            this._view === NotificationView.POMODORO_ABOUT_TO_END ||
            this._view === NotificationView.BREAK ||
            this._view === NotificationView.BREAK_ABOUT_TO_END;
        if (hasButtons === showButtons)
            return;

        if (showButtons) {
            this._skipBreakButton = this.addAction(_('Skip Break'), () => {
                this._timer.setState(State.POMODORO);
            });
            this._extendButton = this.addAction(_('+1 Minute'), () => {
                // Force not closing the banner after click. This may be reverted back to proper value after
                // the timer state change.
                this.notification.resident = true;

                this._blockUpdateActions();
                this._timer.stateDuration += 60.0;
            });
        } else {
            this._skipBreakButton.destroy();
            this._extendButton.destroy();

            this._skipBreakButton = null;
            this._extendButton = null;
        }
    }

    _onNotificationUpdated() {
        const timerState = this._timer.getState();
        const view = this.notification.view;

        // Don't update actions when "+1 Minute" was clicked.
        let updateActions = !this._updateActionsBlocked;

        if (timerState === State.NULL || !view)
            return;

        if (this._timerState !== timerState) {
            this._timerState = timerState;
            updateActions = true;
        }

        if (this._view !== view)
            this._view = view;

        this._updateTitle();
        this._updateBody();

        if (updateActions) {
            if (this.expanded && !this.hover)
                this.unexpand();

            this._updateActions();
        }

        this._updateActionsBlocked = false;
    }

    _onTimerUpdate() {
        this._updateBody();
    }

    vfunc_map() {
        if (!this._timerUpdateId)
            this._timerUpdateId = this._timer.connect('update', this._onTimerUpdate.bind(this));

        this._onTimerUpdate();

        super.vfunc_map();
    }

    vfunc_unmap() {
        if (this._timerUpdateId) {
            this._timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }

        super.vfunc_unmap();
    }

    _onDestroy() {
        if (this.notification && this._notificationUpdatedId) {
            this.notification.disconnect(this._notificationUpdatedId);
            this._notificationUpdatedId = 0;
        }

        if (this._timerUpdateId) {
            this._timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }

        super._onDestroy();
    }
});


const NotificationMessage = GObject.registerClass(
class PomodoroNotificationMessage extends Calendar.NotificationMessage {
    _init(notification) {
        super._init(notification);

        this._timer = notification.timer;
        this._timerState = null;
        this._isPaused = false;

        this.setUseBodyMarkup(false);

        // Reclaim space used by unused elements.
        this._secondaryBin.hide();
        this._closeButton.hide();

        this.notification.connectObject(
            'updated', this._onNotificationUpdated.bind(this),
            'destroy', () => {
                if (this._timerUpdateId) {
                    this._timer.disconnect(this._timerUpdateId);
                    this._timerUpdateId = 0;
                }
            }
        );

        this._onNotificationUpdated();
    }

    /* override parent method */
    canClose() {
        return false;
    }

    _updateTitle() {
        this.setTitle(State.label(this._timerState));
    }

    _updateBody() {
        if (this._timer.getState() === this._timerState)
            this.setBody(formatRemainingTime(this._timer.getRemaining()));
    }

    _onNotificationUpdated() {
        const timerState = this._timer.getState();
        const isPaused = this._timer.isPaused();

        if (timerState === State.NULL)
            return;

        this._timerState = timerState;
        this._isPaused = isPaused;

        this._updateTitle();
        this._updateBody();
    }

    _onTimerUpdate() {
        this._updateBody();
    }

    /* override parent method */
    _onUpdated(n, clear) {  // eslint-disable-line no-unused-vars
    }

    vfunc_map() {
        if (!this._timerUpdateId)
            this._timerUpdateId = this._timer.connect('update', this._onTimerUpdate.bind(this));

        this._onTimerUpdate();

        super.vfunc_map();
    }

    vfunc_unmap() {
        if (this._timerUpdateId) {
            this._timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }

        super.vfunc_unmap();
    }
});


export const IssueNotification = GObject.registerClass(
class PomodoroIssueNotification extends MessageTray.Notification {
    _init(message) {
        super._init(getDefaultSource(), _('Pomodoro Timer'), message, {bannerMarkup: true});

        this.setTransient(true);
        this.setUrgency(MessageTray.Urgency.HIGH);

        this.addAction(_('Report issue'), () => {
            trySpawnCommandLine(`xdg-open ${GLib.shell_quote(Config.PACKAGE_BUGREPORT)}`);
            this.destroy();
        });
    }

    show() {
        if (!Main.messageTray.contains(this.source))
            Main.messageTray.add(this.source);

        this.source.showNotification(this);
    }
});


export const NotificationManager = class extends EventEmitter {
    constructor(timer, params) {
        params = Params.parse(params, {
            useDialog: true,
            animate: true,
        });

        super();

        this._timer = timer;
        this._timerState = State.NULL;
        this._notification = null;
        this._dialog = null;
        this._useDialog = params.useDialog;
        this._view = NotificationView.NULL;
        this._patches = this._createPatches();
        this._notificationSectionPatch = null;
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

    get dialog() {
        return this._dialog;
    }

    get useDialog() {
        return this._useDialog;
    }

    set useDialog(value) {
        this._useDialog = value;
    }

    // Replace notification banner under date menu with our own `NotificationMessage`.
    _patchNotificationSection() {
        const notificationSection = Main.panel?.statusArea.dateMenu?._messageList?._notificationSection;

        if (this._notificationSectionPatch) {
            this._notificationSectionPatch.destroy();
            this._notificationSectionPatch = null;
        }

        if (!notificationSection)
            return;

        const notificationSectionPatch = new Utils.Patch(notificationSection, {
            addMessageAtIndex(message, index, animate) {
                const notification = message.notification;
                const isUrgent = notification.urgency === MessageTray.Urgency.CRITICAL;

                if ((notification instanceof Notification) && !(message instanceof NotificationMessage)) {
                    // undo what _onNotificationAdded has done
                    notification.disconnectObject(this);

                    message = new NotificationMessage(message.notification);
                    index = this._nUrgent;
                    animate = this.mapped;

                    notification.connectObject(
                        'destroy', () => {
                            if (isUrgent)
                                this._nUrgent--;
                        },
                        'updated', () => {
                            this.moveMessage(message, this._nUrgent, this.mapped);
                        }, this);
                }

                notificationSectionPatch.initial.addMessageAtIndex.bind(this)(message, index, animate);
            },
        });
        notificationSectionPatch.apply();

        this._notificationSectionPatch = notificationSectionPatch;
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

        const messageListPatch = new Utils.Patch(Calendar.CalendarMessageList.prototype, {});
        messageListPatch.connect('applied', () => {
            this._patchNotificationSection();
        });
        messageListPatch.connect('reverted', () => {
            if (this._notificationSectionPatch) {
                this._notificationSectionPatch.destroy();
                this._notificationSectionPatch = null;
            }
        });

        return [
            messagesIndicatorPatch,
            messageTrayPatch,
            messageListPatch,
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
                    this.openDialog();
                    break;

                case NotificationView.BREAK:
                    this.openDialog();
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

    _createDialog() {
        const dialog = new PomodoroEndDialog(this._timer);
        dialog.connect('opening',
            () => {
                // `MessageTray` opens a banner as soon as the date menu starts closing. To avoid unnecessary flicker
                // destroy the notification before `MessageTray` considers it.
                const dateMenu = Main.panel.statusArea.dateMenu?.menu;

                this._expireNotification();

                if (dateMenu && dateMenu.actor.visible)
                    dateMenu.close(PopupAnimation.NONE);
            });
        dialog.connect('closing',
            () => {
                if (this._view !== NotificationView.NULL && !this._destroying) {
                    this._expireNotification();
                    this._notify();

                    if (this._view === NotificationView.BREAK)
                        dialog.openWhenIdle();
                }
            });
        dialog.connect('destroy',
            () => {
                if (this._dialog === dialog)
                    this._dialog = null;
            });

        return dialog;
    }

    _isDialogOpen() {
        return this._dialog && (
            this._dialog.state === DialogState.OPENED || this._dialog.state === DialogState.OPENING);
    }

    openDialog(animate = true) {
        if (this._destroying)
            return;

        if (!this._dialog)
            this._dialog = this._createDialog();

        if (this._dialog) {
            this._dialog.open(animate);

            if (!animate)
                this._dialog.pushModal();
        }
    }

    _tryOpenDialog(animate = true) {
        if (this._destroying)
            return;

        if (!this._dialog)
            this._dialog = this._createDialog();

        if (this._dialog && this._dialog.canOpen())
            this.openDialog(animate);
        else
            this._notify();
    }

    _showDoNotDisturbButton() {
        const dndButton = Main.panel.statusArea.dateMenu._messageList._dndButton;
        dndButton.show();

        for (const sibling of [dndButton.get_previous_sibling(), dndButton.get_next_sibling()]) {
            if (sibling instanceof St.Label)
                sibling.show();
        }
    }

    _hideDoNotDisturbButton() {
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

        const title = State.label(timerState);
        if (notification.title !== title)
            changed = true;

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
            notification.update(title, '', {});
        }
    }

    _notify(animate = true) {
        if (this._destroying)
            return;

        if (this._dialog)
            this._dialog.close(animate);

        if (!this._notification)
            this._notification = this._createNotification();

        this._updateNotification();

        const notification = this._notification;

        if (notification.acknowledged)
            notification.acknowledged = false;

        notification.show();

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

        // Dialog is already open.
        if (this._isDialogOpen()) {
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
                if (this._useDialog && view === NotificationView.BREAK) {
                    this._tryOpenDialog(animate);
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
                if (this._dialog && (timerState !== State.SHORT_BREAK && timerState !== State.LONG_BREAK))
                    this._dialog.close(animate);

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

            if (this._dialog) {
                this._dialog.destroy();
                this._dialog = null;
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

        if (!this._isDialogOpen() && this._view !== NotificationView.NULL)
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

        if (this._dialog) {
            this._dialog.destroy();
            this._dialog = null;
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
