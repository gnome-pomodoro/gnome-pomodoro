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

const { Clutter, GLib, GObject, Meta, St } = imports.gi;

const Calendar = imports.ui.calendar;
const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const Params = imports.misc.params;
const Util = imports.misc.util;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Config = Extension.imports.config;
const Timer = Extension.imports.timer;
const Utils = Extension.imports.utils;

const Gettext = imports.gettext.domain(Config.GETTEXT_PACKAGE);
const _ = Gettext.gettext;
const ngettext = Gettext.ngettext;


function getDefaultSource() {
    let extension = Extension.extension;
    let source = extension.notificationSource;

    if (!source) {
        source = new Source();
        let destroyId = source.connect('destroy',
            (source) => {
                if (extension.notificationSource === source) {
                    extension.notificationSource = null;
                }

                source.disconnect(destroyId);
            });

        extension.notificationSource = source;
    }

    return source;
}

var NotificationPolicy = GObject.registerClass({
    Properties: {
        'show-in-lock-screen': GObject.ParamSpec.boolean(
            'show-in-lock-screen', 'show-in-lock-screen', 'show-in-lock-screen',
            GObject.ParamFlags.READABLE, true),
        'details-in-lock-screen': GObject.ParamSpec.boolean(
            'details-in-lock-screen', 'details-in-lock-screen', 'details-in-lock-screen',
            GObject.ParamFlags.READABLE, true),
    },
}, class PomodoroNotificationPolicy extends MessageTray.NotificationPolicy {
    get showInLockScreen() {
        return true;
    }

    get detailsInLockScreen() {
        return true;
    }
});

var Source = GObject.registerClass(
class PomodoroSource extends MessageTray.Source {
    _init() {
        let icon_name = 'gnome-pomodoro';

        super._init(_("Pomodoro Timer"), icon_name);

        this.ICON_NAME = icon_name;

        this._idleId = 0;

        /* Take advantage of the fact that we create only single source at a time,
           so to monkey patch notification list. */
        let patch = new Utils.Patch(Calendar.NotificationSection.prototype, {
            _onNotificationAdded(source, notification) {
                if (notification instanceof PomodoroEndNotification ||
                    notification instanceof PomodoroStartNotification)
                {
                    let message = new TimerBanner(notification);

                    this.addMessageAtIndex(message, this._nUrgent, this.mapped);
                }
                else {
                    patch.initial._onNotificationAdded.bind(this)(source, notification);
                }
            }
        });
        this._patch = patch;
        this._patch.apply();

        this.connect('destroy', () => {
            if (this._patch) {
                this._patch.revert();
                this._patch = null;
            }

            if (this._idleId) {
                GLib.source_remove(this._idleId);
                this._idleId = 0;
            }

            this.destroyNotifications();
        });
    }

    /* override parent method */
    _createPolicy() {
        return new NotificationPolicy();
    }

    _lastNotificationRemoved() {
        this._idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
            if (this.notifications.length == 0) {
                this.destroy();
            }

            return GLib.SOURCE_REMOVE;
        });
        GLib.Source.set_name_by_id(this._idleId,
                                   '[gnome-pomodoro] this._lastNotificationRemoved');
    }

    /* override parent method */
    _onNotificationDestroy(notification) {
        let index = this.notifications.indexOf(notification);
        if (index < 0) {
            return;
        }

        this.notifications.splice(index, 1);
        this.countUpdated();

        if (this.notifications.length == 0) {
            this._lastNotificationRemoved();
        }
    }

    destroyNotifications() {
        let notifications = this.notifications.slice();

        notifications.forEach((notification) => {
            notification.destroy();
        });
    }
});


var Notification = GObject.registerClass(
class PomodoroNotification extends MessageTray.Notification {
    _init(title, description, params) {
        super._init(null, title, description, params);

        this._restoreForFeedback = false;
        this._destroying = false;

        // We want notifications to be shown right after the action,
        // therefore urgency bump.
        this.setUrgency(MessageTray.Urgency.HIGH);
    }

    activate() {
        super.activate();
        Main.panel.closeCalendar();
    }

    show() {
        if (this.source && this.source.isPlaceholder) {
            this.source.destroy();
            this.source = null;
        }

        if (!this.source) {
            this.source = getDefaultSource();
        }

        if (this.source) {
            // Popup notification regardless of session busy status
            if (!this.forFeedback) {
                this.setForFeedback(true);
                this._restoreForFeedback = true;
            }

            this.acknowledged = false;

            if (!Main.messageTray.contains(this.source)) {
                Main.messageTray.add(this.source);
            }

            this.source.showNotification(this);
        }
        else {
            Utils.logWarning('Called Notification.show() after destroy()');
        }
    }

    // FIXME: We shouldn't override `destroy`. There may happen a second call
    // `.destroy(NotificationDestroyedReason.EXPIRED)`. I'm not sure if this bug is on our side or in MessageTray.
    destroy(reason) {
        if (this._destroying) {
            Utils.logWarning('Already called Notification.destroy()');
            return;
        }
        this._destroying = true;

        super.destroy(reason);
    }
});


var PomodoroStartNotification = GObject.registerClass({
    Signals: {
        'changed': {},
    },
}, class PomodoroStartNotification extends Notification {
    /**
     * Notification pops up a little before Pomodoro starts and changes message once started.
     */

    _init(timer) {
        let title = _("Pomodoro");

        // TODO: try customContent param

        super._init(title, '', null);

        this.setResident(true);
        this.setForFeedback(true);
        this.setUrgency(MessageTray.Urgency.HIGH);

        this.timer = timer;
        this._timerState = null;
        this._timerStateChangedId = this.timer.connect('state-changed', this._onTimerStateChanged.bind(this));

        this.connect('destroy', () => {
            if (this._timerStateChangedId != 0) {
                this.timer.disconnect(this._timerStateChangedId);
                this._timerStateChangedId = 0;
            }
        });

        this._onTimerStateChanged();
    }

    _onTimerStateChanged() {
        let title,
            message,
            resident,
            state = this.timer.getState();

        if (this._timerState != state) {
            this._timerState = state;

            switch (state) {
                case Timer.State.POMODORO:
                    title = _("Pomodoro");
                    // message = _("Time to work");
                    resident = false;
                    break;

                case Timer.State.SHORT_BREAK:
                case Timer.State.LONG_BREAK:
                    title = _("Break is about to end");
                    // message = _("Click to start Pomodoro");
                    resident = true;
                    break;

                default:
                    // keep notification as is until destroyed
                    return;
            }

            this.title = title;
            // this.bannerBodyText = message;
            this.setResident(resident);
            this.setTransient(!resident);

            if (this.acknowledged) {
                this.acknowledged = false;
            }

            this.emit('changed');
        }
    }

    _getBodyText() {
        let remaining = Math.max(this.timer.getRemaining(), 0.0);
        let minutes = Math.round(remaining / 60);
        let seconds = Math.round(remaining % 60);

        return remaining > 45
                ? ngettext("%d minute remaining",
                           "%d minutes remaining", minutes).format(minutes)
                : ngettext("%d second remaining",
                           "%d seconds remaining", seconds).format(seconds);
    }

    /**
     * createBanner() is used only to display a notification popup.
     * Banners in calendar menu or the lock screen are made by GNOME Shell.
     */
    createBanner() {
        let banner,
            extendButton;

        banner = super.createBanner();
        banner.canClose = function() {
            return false;
        };

        let onTimerUpdate = () => {
            if (banner.bodyLabel) {
                let bodyText = this._getBodyText();

                if (bodyText !== banner._bodyText) {
                    banner._bodyText = bodyText;
                    banner.setBody(bodyText);
                }
            }
        };
        let onNotificationChanged = () => {
            if (this.timer.isBreak()) {
                extendButton = banner.addAction(_("+1 Minute"), () => {
                    this.timer.stateDuration += 60.0;
                });
            }
            else if (extendButton) {
                extendButton.destroy();
                extendButton = null;
            }
        };
        let onNotificationDestroy = () => {
            if (timerUpdateId != 0) {
                this.timer.disconnect(timerUpdateId);
                timerUpdateId = 0;
            }

            if (notificationChangedId != 0) {
                this.disconnect(notificationChangedId);
                notificationChangedId = 0;
            }

            if (notificationDestroyId != 0) {
                this.disconnect(notificationDestroyId);
                notificationDestroyId = 0;
            }
        };

        let timerUpdateId = this.timer.connect('update', onTimerUpdate);
        let notificationChangedId = this.connect('changed', onNotificationChanged);
        let notificationDestroyId = this.connect('destroy', onNotificationDestroy);

        banner.connect('destroy', () => onNotificationDestroy());

        onNotificationChanged();
        onTimerUpdate();

        return banner;
    }
});


var PomodoroEndNotification = GObject.registerClass({
    Signals: {
        'changed': {},
    },
}, class PomodoroEndNotification extends Notification {
    _init(timer) {
        let title = '';

        // TODO: try customContent param

        super._init(title, null, null);

        this.setResident(true);
        this.setForFeedback(true);
        this.setUrgency(MessageTray.Urgency.HIGH);

        this.timer = timer;
        this._timerState = null;
        this._timerStateChangedId = this.timer.connect('state-changed', this._onTimerStateChanged.bind(this));

        this.connect('destroy', () => {
            if (this._timerStateChangedId != 0) {
                this.timer.disconnect(this._timerStateChangedId);
                this._timerStateChangedId = 0;
            }
        });

        this._onTimerStateChanged();
    }

    _onTimerStateChanged() {
        let title,
            message,
            resident,
            state = this.timer.getState();

        if (this._timerState != state) {
            this._timerState = state;

            switch (state) {
                case Timer.State.POMODORO:
                    title = _("Pomodoro is about to end");
                    // message = _("Click to start a break");
                    resident = true;
                    break;

                case Timer.State.SHORT_BREAK:
                case Timer.State.LONG_BREAK:
                    title = _("Take a break");
                    resident = true;
                    break;

                default:
                    // keep notification as is until destroyed
                    return;
            }

            this.title = title;
            // this.bannerBodyText = message;
            this.setResident(resident);
            this.setTransient(!resident);

            if (this.acknowledged) {
                this.acknowledged = false;
            }

            this.emit('changed');
        }
    }

    _getBodyText() {
        let remaining = Math.max(this.timer.getRemaining(), 0.0);
        let minutes = Math.round(remaining / 60);
        let seconds = Math.round(remaining % 60);

        return remaining > 45
                ? ngettext("%d minute remaining",
                           "%d minutes remaining", minutes).format(minutes)
                : ngettext("%d second remaining",
                           "%d seconds remaining", seconds).format(seconds);
    }

    createBanner() {
        let banner;

        banner = super.createBanner();
        banner.canClose = function() {
            return false;
        };
        banner.addAction(_("Skip Break"), () => {
            this.timer.setState(Timer.State.POMODORO);

            this.destroy();
        });
        banner.addAction(_("+1 Minute"), () => {
            this.timer.stateDuration += 60.0;
        });

        if (this.timer.getElapsed() > 15.0) {
            banner.setTitle(Timer.State.label(this.timer.getState()));
        }

        let onTimerUpdate = () => {
            if (banner.bodyLabel) {
                let bodyText = this._getBodyText();

                if (bodyText !== banner._bodyText) {
                    banner._bodyText = bodyText;
                    banner.setBody(bodyText);
                }
            }
        };
        let onNotificationDestroy = () => {
            if (timerUpdateId != 0) {
                this.timer.disconnect(timerUpdateId);
                timerUpdateId = 0;
            }

            if (notificationDestroyId != 0) {
                this.disconnect(notificationDestroyId);
                notificationDestroyId = 0;
            }
        };

        let timerUpdateId = this.timer.connect('update', onTimerUpdate);
        let notificationDestroyId = this.connect('destroy', onNotificationDestroy);

        banner.connect('destroy', () => onNotificationDestroy());

        onTimerUpdate();

        return banner;
    }
});


var ScreenShieldNotification = GObject.registerClass({
    Signals: {
        'changed': {},
    },
}, class PomodoroScreenShieldNotification extends Notification {
    _init(timer) {
        super._init('', null, null);

        this.timer = timer;
        this.source = getDefaultSource();

        this.setTransient(false);
        this.setResident(true);

        // We want notifications to be shown right after the action,
        // therefore urgency bump.
        this.setUrgency(MessageTray.Urgency.HIGH);

        this._isPaused = false;
        this._timerState = Timer.State.NULL;
        this._timerUpdateId = this.timer.connect('update', this._onTimerUpdate.bind(this));

        let patch = new Utils.Patch(Main.screenShield, {
            emit(name /* , arg1, arg2 */) {
                if (name != 'wake-up-screen') {
                    patch.initial.emit.apply(patch.object, arguments);
                }
            }
        });
        this._screenShieldPatch = patch;

        this.connect('destroy', () => {
            if (this._timerUpdateId != 0) {
                this.timer.disconnect(this._timerUpdateId);
                this._timerUpdateId = 0;
            }

            if (this._screenShieldPatch) {
                this._screenShieldPatch.destroy();
                this._screenShieldPatch = null;
            }
        });

        this._onTimerUpdate();
    }

    _onTimerStateChanged() {
        let state = this.timer.getState();
        let title = Timer.State.label(state);

        // HACK: "Pomodoro" in application name may be confusing with state name,
        //       so replace application name with current state.
        if (this.source !== null) {
            this.source.setTitle(title ? title : '');
        }
    }

    _onTimerElapsedChanged() {
        let remaining = Math.max(this.timer.getRemaining(), 0.0);
        let minutes = Math.round(remaining / 60);
        let seconds = Math.round(remaining % 60);

        if (remaining > 15) {
            seconds = Math.ceil(seconds / 15) * 15;
        }

        this.bannerBodyText = (remaining > 45)
                ? ngettext("%d minute remaining",
                           "%d minutes remaining", minutes).format(minutes)
                : ngettext("%d second remaining",
                           "%d seconds remaining", seconds).format(seconds);
    }

    _onTimerUpdate() {
        let timerState = this.timer.getState(),
            isPaused = this.timer.isPaused(),
            bannerBodyText = this.bannerBodyText,
            stateChanged = false,
            elapsedChanged = false;

        if (this._timerState != timerState || this._isPaused != isPaused) {
            this._timerState = timerState;
            this._isPaused = isPaused;

            this._onTimerStateChanged();
            elapsedChanged = stateChanged = true;
        }

        this._onTimerElapsedChanged();

        if (this.bannerBodyText !== bannerBodyText) {
            elapsedChanged = true;
        }

        if (stateChanged) {
            // "updated" is original MessageTray.Notification signal
            // it indicates that content changed.
            this.emit('changed');

            // HACK: Force screen shield to update notification body
            if (this.source !== null) {
                this.source.notify('count');
            }
        }
        else if (elapsedChanged) {
            this.emit('changed');

            if (this.source !== null) {
                this._screenShieldPatch.apply();
                this.source.notify('count');
                this._screenShieldPatch.revert();
            }
        }
    }
});


var IssueNotification = GObject.registerClass(
class PomodoroIssueNotification extends MessageTray.Notification {
    /* Use base class instead of PomodoroNotification, in case
     * issue is caused by our implementation.
     */

    _init(message) {
        let source = getDefaultSource();
        let title  = _("Pomodoro Timer");
        let url    = Config.PACKAGE_BUGREPORT;

        super._init(source, title, message, { bannerMarkup: true });

        this.setTransient(true);
        this.setUrgency(MessageTray.Urgency.HIGH);

        this.addAction(_("Report issue"), () => {
                Util.trySpawnCommandLine('xdg-open ' + GLib.shell_quote(url));
                this.destroy();
            });
    }

    show() {
        if (!Main.messageTray.contains(this.source)) {
            Main.messageTray.add(this.source);
        }

        this.source.showNotification(this);
    }
});


var TimerBanner = GObject.registerClass(
class PomodoroTimerBanner extends Calendar.NotificationMessage {
    _init(notification) {
        super._init(notification);

        this.timer = notification.timer;

        this.setUseBodyMarkup(false);

        this._isPaused = null;
        this._timerState = null;
        this._timerUpdateId = this.timer.connect('update', this._onTimerUpdate.bind(this));
        this._onTimerUpdate();

        this.addAction(_("Skip"), () => {
                this.timer.skip();

                notification.destroy();
            });
        this.addAction(_("+1 Minute"), () => {
                this.timer.stateDuration += 60.0;
            });

        this.connect('close', this._onClose.bind(this));
    }

    /* override parent method */
    canClose() {
        return false;
    }

    addButton(button, callback) {
        button.connect('clicked', callback);
        this._mediaControls.add_actor(button);

        return button;
    }

    addAction(label, callback) {
        let button = new St.Button({ style_class: 'extension-pomodoro-message-action',
                                     label: label,
                                     x_expand: true,
                                     can_focus: true });

        return this.addButton(button, callback);
    }

    _getBodyText() {
        let remaining = Math.max(this.timer.getRemaining(), 0.0);
        let minutes = Math.round(remaining / 60);
        let seconds = Math.round(remaining % 60);

        return remaining > 45
                ? ngettext("%d minute remaining",
                           "%d minutes remaining", minutes).format(minutes)
                : ngettext("%d second remaining",
                           "%d seconds remaining", seconds).format(seconds);
    }

    _onTimerStateChanged() {
        let state = this.timer.getState();
        let title;

        if (this.timer.isPaused()) {
            title = _("Paused");
        }
        else {
            title = Timer.State.label(state);
        }

        if (title && this.titleLabel) {
            this.setTitle(title);
        }
    }

    _onTimerElapsedChanged() {
        if (this.bodyLabel) {
            let bodyText = this._getBodyText();

            if (bodyText !== this._bodyText) {
                this._bodyText = bodyText;
                this.setBody(bodyText);
            }
        }
    }

    _onTimerUpdate() {
        let timerState = this.timer.getState();
        let isPaused = this.timer.isPaused();

        if (this._timerState != timerState || this._isPaused != isPaused) {
            this._timerState = timerState;
            this._isPaused = isPaused;

            this._onTimerStateChanged();
        }

        if (this._timerState != Timer.State.NULL) {
            this._onTimerElapsedChanged();
        }
    }

    /* override parent method */
    _onUpdated(n, clear) {
    }

    _onClose() {
        if (this._timerUpdateId != 0) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }
    }

    _onDestroy() {
        this._onClose();

        super._onDestroy();
    }
});
