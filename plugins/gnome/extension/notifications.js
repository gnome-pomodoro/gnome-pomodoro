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

const Lang = imports.lang;
const Mainloop = imports.mainloop;
const Signals = imports.signals;

const Clutter = imports.gi.Clutter;
const GLib = imports.gi.GLib;
const Meta = imports.gi.Meta;
const St = imports.gi.St;

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


const NOTIFICATIONS_TIME_OFFSET = 10.0;


function getDefaultSource() {
    let extension = Extension.extension;
    let source = extension.notificationSource;

    if (!source) {
        source = new Source();
        let destroyId = source.connect('destroy', Lang.bind(source,
            function(source) {
                if (extension.notificationSource === source) {
                    extension.notificationSource = null;
                }

                source.disconnect(destroyId);
            }));

        extension.notificationSource = source;
    }

    return source;
}


const Source = new Lang.Class({
    Name: 'PomodoroNotificationSource',
    Extends: MessageTray.Source,

    ICON_NAME: 'gnome-pomodoro',

    _init: function() {
        this.parent(_("Pomodoro Timer"), this.ICON_NAME);

        this._idleId = 0;

        /* Take advantagoe of the fact that we create only single source at a time,
           so to monkey patch notification list. */
        let patch = new Utils.Patch(Calendar.NotificationSection.prototype, {
            _onNotificationAdded: function(source, notification) {
                if ((notification instanceof PomodoroEndNotification) ||
                    (notification instanceof PomodoroStartNotification))
                {
                    let message = new TimerBanner(notification);

                    this.addMessageAtIndex(message, this._nUrgent, this.actor.mapped);
                }
                else {
                    Lang.bind(this, patch.initial._onNotificationAdded)(source, notification);
                }
            }
        });
        this._patch = patch;
        this._patch.apply();
    },

    /* override parent method */
    _createPolicy: function() {
        return new MessageTray.NotificationPolicy({ showInLockScreen: true,
                                                    detailsInLockScreen: true });
    },

    _lastNotificationRemoved: function() {
        this._idleId = Mainloop.idle_add(Lang.bind(this,
                                         function() {
                                             if (!this.count) {
                                                 this.destroy();
                                             }

                                             return GLib.SOURCE_REMOVE;
                                         }));
        GLib.Source.set_name_by_id(this._idleId,
                                   '[gnome-pomodoro] this._lastNotificationRemoved');
    },

    /* override parent method */
    _onNotificationDestroy: function(notification) {
        let index = this.notifications.indexOf(notification);
        if (index < 0) {
            return;
        }

        this.notifications.splice(index, 1);
        if (this.notifications.length == 0) {
            this._lastNotificationRemoved();
        }

        this.countUpdated();
    },

    destroyNotifications: function() {
        let notifications = this.notifications.slice();

        notifications.forEach(
            function(notification) {
                notification.destroy();
            });
    },

    destroy: function() {
        this.parent();

        if (this._patch) {
            this._patch.revert();
            this._patch = null;
        }

        if (this._idleId) {
            Mainloop.source_remove(this._idleId);
            this._idleId = 0;
        }
    }
});


const Notification = new Lang.Class({
    Name: 'PomodoroNotification',
    Extends: MessageTray.Notification,

    _init: function(title, description, params) {
        this.parent(null, title, description, params);

        this._restoreForFeedback = false;

        // We want notifications to be shown right after the action,
        // therefore urgency bump.
        this.setUrgency(MessageTray.Urgency.HIGH);
    },

    activate: function() {
        this.parent();
        Main.panel.closeCalendar();
    },

    show: function() {
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

            this.source.notify(this);
        }
        else {
            Utils.logWarning('Called Notification.show() after destroy()');
        }
    }
});


const PomodoroStartNotification = new Lang.Class({
    Name: 'PomodoroStartNotification',
    Extends: Notification,

    /**
     * Notification pops up a little before Pomodoro starts and changes message once started.
     */

    _init: function(timer) {
        let title = _("Pomodoro");

        this.parent(title, '', null);

        this.setResident(true);
        this.setForFeedback(true);
        this.setUrgency(MessageTray.Urgency.HIGH);

        this.timer = timer;
        this._timerStateChangedId = this.timer.connect('state-changed', Lang.bind(this, this._onTimerStateChanged));

        this._onTimerStateChanged();
    },

    _onTimerStateChanged: function() {
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
    },

    _getBodyText: function() {
        let remaining = Math.max(this.timer.getRemaining(), 0.0);
        let minutes = Math.round(remaining / 60);
        let seconds = Math.round(remaining % 60);

        return remaining > 45
                ? ngettext("%d minute remaining",
                           "%d minutes remaining", minutes).format(minutes)
                : ngettext("%d second remaining",
                           "%d seconds remaining", seconds).format(seconds);
    },

    /**
     * createBanner() is used only to display a notification popup.
     * Banners in calendar menu or the lock screen are made by GNOME Shell.
     */
    createBanner: function() {
        let banner,
            extendButton;

        banner = this.parent();
        banner.canClose = function() {
            return false;
        };

        let onTimerUpdate = Lang.bind(this, function() {
            if (banner.bodyLabel && banner.bodyLabel.actor.clutter_text) {
                let bodyText = this._getBodyText();

                if (bodyText !== banner._bodyText) {
                    banner._bodyText = bodyText;
                    banner.setBody(bodyText);
                }
            }
        });
        let onChanged = Lang.bind(this,
            function() {
                if (this.timer.isBreak()) {
                    extendButton = banner.addAction(_("+1 Minute"), Lang.bind(this,
                        function() {
                            this.timer.stateDuration += 60.0;
                        }));
                }
                else if (extendButton) {
                    extendButton.destroy();
                }
            });
        let onDestroy = Lang.bind(this,
            function() {
                this.timer.disconnect(timerUpdateId);
                this.disconnect(notificationChangedId);
                this.disconnect(notificationDestroyId);
            });

        let timerUpdateId = this.timer.connect('update', onTimerUpdate);
        let notificationChangedId = this.connect('changed', onChanged);
        let notificationDestroyId = this.connect('destroy', onDestroy);

        onChanged();
        onTimerUpdate();

        return banner;
    },

    destroy: function(reason) {
        if (this._timerStateChangedId != 0) {
            this.timer.disconnect(this._timerStateChangedId);
            this._timerStateChangedId = 0;
        }

        return this.parent(reason);
    }
});


const PomodoroEndNotification = new Lang.Class({
    Name: 'PomodoroEndNotification',
    Extends: Notification,

    _init: function(timer) {
        let title = '';

        this.parent(title, null, null);

        this.setResident(true);
        this.setForFeedback(true);
        this.setUrgency(MessageTray.Urgency.HIGH);

        this.timer = timer;
        this._timerStateChangedId = this.timer.connect('state-changed', Lang.bind(this, this._onTimerStateChanged));

        this._onTimerStateChanged();
    },

    _onTimerStateChanged: function() {
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
    },

    _getBodyText: function() {
        let remaining = Math.max(this.timer.getRemaining(), 0.0);
        let minutes = Math.round(remaining / 60);
        let seconds = Math.round(remaining % 60);

        return remaining > 45
                ? ngettext("%d minute remaining",
                           "%d minutes remaining", minutes).format(minutes)
                : ngettext("%d second remaining",
                           "%d seconds remaining", seconds).format(seconds);
    },

    createBanner: function() {
        let banner = this.parent();

        banner.canClose = function() {
            return false;
        };

        if (this.timer.getElapsed() > 15.0) {
            banner.setTitle(Timer.State.label(this.timer.getState()));
        }

        let skipButton = banner.addAction(_("Skip Break"), Lang.bind(this,
            function() {
                this.timer.setState(Timer.State.POMODORO);

                this.destroy();
            }));
        let extendButton = banner.addAction(_("+1 Minute"), Lang.bind(this,
            function() {
                this.timer.stateDuration += 60.0;
            }));

        let onTimerUpdate = Lang.bind(this,
            function() {
                if (banner.bodyLabel && banner.bodyLabel.actor.clutter_text) {
                    let bodyText = this._getBodyText();

                    if (bodyText !== banner._bodyText) {
                        banner._bodyText = bodyText;
                        banner.setBody(bodyText);
                    }
                }
            });
        let onDestroy = Lang.bind(this,
            function() {
                this.timer.disconnect(timerUpdateId);
                this.disconnect(notificationDestroyId);
            });

        let timerUpdateId = this.timer.connect('update', onTimerUpdate);
        let notificationDestroyId = this.connect('destroy', onDestroy);

        onTimerUpdate();

        return banner;
    },

    destroy: function(reason) {
        if (this._timerStateChangedId != 0) {
            this.timer.disconnect(this._timerStateChangedId);
            this._timerStateChangedId = 0;
        }

        return this.parent(reason);
    }
});


const IssueNotification = new Lang.Class({
    Name: 'PomodoroIssueNotification',

    /* Use base class instead of PomodoroNotification, in case
     * issue is caused by our implementation.
     */
    Extends: MessageTray.Notification,

    _init: function(message) {
        let source = getDefaultSource();
        let title  = _("Pomodoro Timer");
        let url    = Config.PACKAGE_BUGREPORT;

        this.parent(source, title, message, { bannerMarkup: true });

        this.setTransient(true);
        this.setUrgency(MessageTray.Urgency.HIGH);

        this.addAction(_("Report issue"), Lang.bind(this,
            function() {
                Util.trySpawnCommandLine('xdg-open ' + GLib.shell_quote(url));
                this.destroy();
            }));
    },

    show: function() {
        if (!Main.messageTray.contains(this.source)) {
            Main.messageTray.add(this.source);
        }

        this.source.notify(this);
    }
});


// A notification meant only for the lockscreen
//
const TimerNotification = new Lang.Class({
    Name: 'PomodoroTimerNotification',
    Extends: Notification,

    _init: function(timer) {
        this.parent(null, null, null);

        this.setTransient(false);
        this.setResident(true);

        // We want notifications to be shown right after the action,
        // therefore urgency bump.
        this.setUrgency(MessageTray.Urgency.HIGH);

        this.timer = timer;

        this._timerUpdateId = this.timer.connect('update', Lang.bind(this, this._onTimerUpdate));

        this._onTimerUpdate();
    },

    _onTimerStateChanged: function() {
        let state = this.timer.getState();
        let title = Timer.State.label(state);

        // HACK: To make notifications on screen shield look prettier
        if (title) {
            this.source.setTitle(title);
        }
    },

    _onTimerElapsedChanged: function() {
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
    },

    _onTimerUpdate: function() {
        let timerState = this.timer.getState(),
            isPaused = this.timer.isPaused(),
            bannerBodyText = this.bannerBodyText,
            changed = false;

        if (this._timerState != timerState || this._isPaused != isPaused) {
            this._timerState = timerState;
            this._isPaused = isPaused;

            this._onTimerStateChanged();
            changed = true;
        }

        this._onTimerElapsedChanged();

        if (this.bannerBodyText !== bannerBodyText) {
            changed = true;
        }

        if (changed) {
            // "updated" is original MessageTray.Notification signal
            // it indicates that content changed.
            this.emit('changed');
        }
    },

    destroy: function(reason) {
        if (this._timerUpdateId != 0) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }

        return this.parent(reason);
    }
});


const TimerBanner = new Lang.Class({
    Name: 'PomodoroTimerNotificationBanner',
    Extends: Calendar.NotificationMessage,

    _init: function(notification) {
        this.parent(notification);

        this.timer = notification.timer;

        this.setUseBodyMarkup(false);

        this._timerUpdateId = this.timer.connect('update', Lang.bind(this, this._onTimerUpdate));
        this._onTimerUpdate();

        this.addAction(_("Skip"), Lang.bind(this,
            function() {
                this.timer.skip();

                notification.destroy();
            }));
        this.addAction(_("+1 Minute"), Lang.bind(this,
            function() {
                this.timer.stateDuration += 60.0;
            }));

        this.connect('destroy', Lang.bind(this,
            function() {
                if (this._timerUpdateId) {
                    this.timer.disconnect(this._timerUpdateId);
                    this._timerUpdateId = 0;
                }
            }));
    },

    /* override parent method */
    canClose: function() {
        return false;
    },

    addButton: function(button, callback) {
        button.connect('clicked', callback);
        this._mediaControls.add_actor(button);

        return button;
    },

    addAction: function(label, callback) {
        let button = new St.Button({ style_class: 'extension-pomodoro-message-action',
                                     label: label,
                                     x_expand: true,
                                     can_focus: true });

        return this.addButton(button, callback);
    },

    _getBodyText: function() {
        let remaining = Math.max(this.timer.getRemaining(), 0.0);
        let minutes = Math.round(remaining / 60);
        let seconds = Math.round(remaining % 60);

        return remaining > 45
                ? ngettext("%d minute remaining",
                           "%d minutes remaining", minutes).format(minutes)
                : ngettext("%d second remaining",
                           "%d seconds remaining", seconds).format(seconds);
    },

    _onTimerStateChanged: function() {
        let state = this.timer.getState();
        let title;

        if (this.timer.isPaused()) {
            title = _("Paused");
        }
        else {
            title = Timer.State.label(state);
        }

        if (title && this.titleLabel && this.titleLabel.clutter_text) {
            this.setTitle(title);
        }
    },

    _onTimerElapsedChanged: function() {
        if (this.bodyLabel && this.bodyLabel.actor.clutter_text) {
            let bodyText = this._getBodyText();

            if (bodyText !== this._bodyText) {
                this._bodyText = bodyText;
                this.setBody(bodyText);
            }
        }
    },

    _onTimerUpdate: function() {
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
    },

    /* override parent method */
    _onUpdated: function(n, clear) {
    }
});
