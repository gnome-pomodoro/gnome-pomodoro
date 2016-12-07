/*
 * Copyright (c) 2011-2014 gnome-pomodoro contributors
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

const GLib = imports.gi.GLib;
const Meta = imports.gi.Meta;
const St = imports.gi.St;

const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const Util = imports.misc.util;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Config = Extension.imports.config;
const Timer = Extension.imports.timer;
const Utils = Extension.imports.utils;

const Gettext = imports.gettext.domain(Config.GETTEXT_PACKAGE);
const _ = Gettext.gettext;
const ngettext = Gettext.ngettext;


const IDLE_TIME_TO_ACKNOWLEDGE_REMINDER = 45;

const REMINDER_TIMEOUT = 75;

const REMINDER_MIN_REMAINING_TIME = 60;


function getDefaultSource() {
    let extension = Extension.extension;
    let source = extension.notificationSource;

    /* a walkaround for ScreenShield requiring new source for each
       music notification */
    if (source && Main.sessionMode.isLocked) {
        source.destroy();
        source = null;
    }

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
        this.parent(_("Pomodoro"), this.ICON_NAME);

        this._idleId = 0;
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

        /* We want notifications to be shown right after the action,
         * therefore urgency bump.
         */
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
            /* Popup notification regardless of session busy status */
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

    _init: function(timer) {
        let title = _("Pomodoro");
        let message = _("Focus on your task.");

        this.parent(title, message, null);

        this.setTransient(false);
        this.setResident(true);

        this.timer = timer;

        this.addAction(_("Take a break"), Lang.bind(this,
            function() {
                this.timer.skip ();
                this.destroy();
            }));
    }
});


const PomodoroEndNotification = new Lang.Class({
    Name: 'PomodoroEndNotification',
    Extends: Notification,

    _init: function(timer) {
        let title = _("Take a break!");

        this.parent(title, null, null);

        this.setTransient(false);
        this.setResident(true);

        this.timer = timer;

        this._timerUpdateId = this.timer.connect('update', Lang.bind(this, this._onTimerUpdate));
        this._onTimerUpdate();

        this.connect('destroy', Lang.bind(this,
            function() {
                if (this._timerUpdateId) {
                    this.timer.disconnect(this._timerUpdateId);
                    this._timerUpdateId = 0;
                }
            }));
    },

    _onTimerUpdate: function() {
        let state = this.timer.getState();

        if (this.timer.isBreak()) {
            let remaining = Math.max(this.timer.getRemaining(), 0.0);
            let minutes = Math.round(remaining / 60);
            let seconds = Math.round(remaining % 60);

            if (remaining > 15) {
                seconds = Math.ceil(seconds / 15) * 15;
            }

            this.bannerBodyText = (remaining > 45)
                    ? ngettext("You have %d minute until next pomodoro.",
                               "You have %d minutes until next pomodoro.", minutes).format(minutes)
                    : ngettext("You have %d second until next pomodoro.",
                               "You have %d seconds until next pomodoro.", seconds).format(seconds);
        }

        this.emit('timer-updated');
    },

    createBanner: function() {
        let banner = this.parent();

        let onTimerUpdated = Lang.bind(this,
            function() {
                if (banner.bodyLabel && banner.bodyLabel.actor.clutter_text) {
                    banner.setBody(this.bannerBodyText);
                }

                if (this.timer.canSwitchBreak()) {
                    switchBreakButton.set_label(this.timer.getState() == Timer.State.SHORT_BREAK
                            ? _("Lengthen it") : _("Shorten it"));

                    switchBreakButton.show();
                }
                else {
                    switchBreakButton.hide();
                }
            });

        let onDestroy = Lang.bind(this,
            function() {
                this.disconnect(notificationUpdatedId);
                this.disconnect(notificationDestroyId);
            });

        let switchBreakButton = banner.addAction('', Lang.bind(this,
            function() {
                this.timer.switchBreak();
            }));

        let startPomodoroButton = banner.addAction(_("Start pomodoro"), Lang.bind(this,
            function() {
                this.timer.skip ();
                this.destroy();
            }));

        let notificationUpdatedId = this.connect('timer-updated', onTimerUpdated);
        let notificationDestroyId = this.connect('destroy', onDestroy);

        this._onTimerUpdate();

        return banner;
    }
});


const ReminderManager = new Lang.Class({
    Name: 'PomodoroReminderManager',

    _init: function(timer) {
        this.timer = timer;
        this.acknowledged = false;

        this._idleMonitor = Meta.IdleMonitor.get_core();
        this._idleWatchId = 0;
        this._timeoutSource = 0;
    },

    _onIdleWatch: function(monitor) {
        if (this._idleWatchId) {
            this._idleMonitor.remove_watch(this._idleWatchId);
            this._idleWatchId = 0;
        }

        this.dismiss();
    },

    _onTimeout: function() {
        this._timeoutSource = 0;

        if (this._idleWatchId) {
            this._idleMonitor.remove_watch(this._idleWatchId);
            this._idleWatchId = 0;
        }

        /* acknowledge break if playing a video or playing a game */
        let info = Utils.getFocusedWindowInfo();

        if (info.isPlayer && info.isFullscreen) {
            this.acknowledged = true;
        }

        if (!this.acknowledged && this.timer.getRemaining() > REMINDER_MIN_REMAINING_TIME) {
            this.emit('notify');
        }

        return GLib.SOURCE_REMOVE;
    },

    _schedule: function() {
        if (this._timeoutSource) {
            Mainloop.source_remove(this._timeoutSource);
            this._timeoutSource = 0;
        }

        this._timeoutSource = Mainloop.timeout_add_seconds(
                                   REMINDER_TIMEOUT,
                                   Lang.bind(this, this._onTimeout));

        if (this._idleWatchId == 0) {
            this._idleWatchId = this._idleMonitor.add_idle_watch(IDLE_TIME_TO_ACKNOWLEDGE_REMINDER * 1000,
                                                                 Lang.bind(this, this._onIdleWatch));
        }
    },

    _unschedule: function() {
        if (this._timeoutSource) {
            Mainloop.source_remove(this._timeoutSource);
            this._timeoutSource = 0;
        }

        if (this._idleWatchId) {
            this._idleMonitor.remove_watch(this._idleWatchId);
            this._idleWatchId = 0;
        }
    },

    schedule: function() {
        this.acknowledged = false;
        this._schedule();
    },

    unschedule: function() {
        this._unschedule();
    },

    dismiss: function() {
        this.acknowledged = true;
        this._unschedule();
    },

    destroy: function() {
        this._unschedule();

        this.emit('destroy');
    }
});
Signals.addSignalMethods(ReminderManager.prototype);


const RemindPomodoroEndNotification = new Lang.Class({
    Name: 'RemindPomodoroEndNotification',
    Extends: Notification,

    _init: function() {
        let title = _("Hey!");
        let message = _("You're missing out on a break");

        this.parent(title, message, null);

        this.setTransient(true);
        this.setUrgency(MessageTray.Urgency.LOW);
    }
});


const IssueNotification = new Lang.Class({
    Name: 'PomodoroIssueNotification',
    Extends: MessageTray.Notification,

    _init: function(message) {
        let source = getDefaultSource();
        let title  = _("Pomodoro");
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
