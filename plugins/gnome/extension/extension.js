/*
 * A simple pomodoro timer for GNOME Shell
 *
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
 * Authors: Arun Mahapatra <pratikarun@gmail.com>
 *          Kamil Prusko <kamilprusko@gmail.com>
 */

const Lang = imports.lang;
const Gettext = imports.gettext;
const Signals = imports.signals;

const Gio = imports.gi.Gio;
const Main = imports.ui.main;
const Meta = imports.gi.Meta;
const Shell = imports.gi.Shell;
const ExtensionSystem = imports.ui.extensionSystem;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Config = Extension.imports.config;
const Indicator = Extension.imports.indicator;
const Notifications = Extension.imports.notifications;
const Dialogs = Extension.imports.dialogs;
const Presence = Extension.imports.presence;
const Settings = Extension.imports.settings;
const Timer = Extension.imports.timer;
const Utils = Extension.imports.utils;


let extension = null;


const ExtensionMode = {
    DEFAULT: 0,
    RESTRICTED: 1
};


const PomodoroExtension = new Lang.Class({
    Name: 'PomodoroExtension',

    _init: function(mode) {
        Extension.extension = this;

        this.settings           = null;
        this.timer              = null;
        this.indicator          = null;
        this.notificationSource = null;
        this.notification       = null;
        this.dialog             = null;
        this.reminderManager    = null;
        this.presence           = null;
        this.mode               = null;

        try {
            this.settings = Settings.getSettings('org.gnome.pomodoro.preferences');

            this.settings.connect('changed::show-screen-notifications',
                                  Lang.bind(this, this._onSettingsChanged));
            this.settings.connect('changed::show-reminders',
                                  Lang.bind(this, this._onSettingsChanged));

            this._showScreenNotifications = this.settings.get_boolean('show-screen-notifications');
            this._showReminders = this.settings.get_boolean('show-reminders');

            this.timer = new Timer.Timer();

            this.timer.connect('service-connected', Lang.bind(this, this._onServiceConnected));
            this.timer.connect('service-disconnected', Lang.bind(this, this._onServiceDisconnected));
            this.timer.connect('state-changed', Lang.bind(this, this._onTimerStateChanged));
            this.timer.connect('paused', Lang.bind(this, this._onTimerPaused));
            this.timer.connect('resumed', Lang.bind(this, this._onTimerResumed));

            this.setMode(mode);
        }
        catch (error) {
            Utils.logError(error.message);
        }
    },

    setMode: function(mode) {
        if (this.mode !== mode) {
            this.mode = mode;

            if (mode == ExtensionMode.RESTRICTED) {
                this.disableIndicator();
                this.disableScreenNotifications();
                this.disableReminders();
            }
            else {
                this.enableIndicator();
                this.enableScreenNotifications();
                this.enableReminders();
            }

            this.enableNotifications();
            this.enablePresence();
        }
    },

    _destroyNotifications: function() {
        if (this.notificationSource) {
            this.notificationSource.destroyNotifications();
        }
    },

    _destroyPreviousNotifications: function() {
        if (this.notificationSource) {
            let notifications = this.notificationSource.notifications.filter(
                Lang.bind(this, function(notification) {
                    return notification !== this.notification;
                }));

            notifications.forEach(
                function(notification) {
                    notification.destroy();
                });
        }
    },

    _onSettingsChanged: function(settings, key) {
        switch(key)
        {
            case 'show-screen-notifications':
                this._showScreenNotifications = settings.get_boolean(key);

                this._updateScreenNotifications();

                break;

            case 'show-reminders':
                this._showReminders = settings.get_boolean(key);

                if (this._showReminders && this.timer.isBreak() && !this.timer.isPaused()) {
                    this._schedulePomodoroEndReminder();
                }
                else {
                    this.disableReminders();
                }

                break;
        }
    },

    _onServiceConnected: function() {
        this.enableNotifications();
    },

    _onServiceDisconnected: function() {
        this._updateScreenNotifications();
        this._destroyNotifications();
    },

    _onTimerStateChanged: function() {
        let timerState = this.timer.getState();

        if (this._timerState !== timerState) {
            this._timerState = timerState;

            if (this.dialog && !this.timer.isBreak()) {
                this.dialog.close(true);
            }

            if (this.reminderManager) {
                this.reminderManager.destroy();
                this.reminderManager = null;
            }

            switch (timerState) {
                case Timer.State.POMODORO:
                    this._notifyPomodoroStart();
                    break;

                case Timer.State.SHORT_BREAK:
                case Timer.State.LONG_BREAK:
                    this._notifyPomodoroEnd();
                    break;

                case Timer.State.NULL:
                    this._destroyNotifications();
                    break;
            }
        }
    },

    _onTimerPaused: function() {
        this.disableReminders();

        this._updateScreenNotifications();
    },

    _onTimerResumed: function() {
        this.enableReminders();

        this._updateScreenNotifications();
    },

    _notifyPomodoroStart: function() {
        if (this.notification &&
            this.notification instanceof Notifications.PomodoroStartNotification)
        {
            /* do not renotify */
        }
        else {
            this.notification = new Notifications.PomodoroStartNotification(this.timer);
            this.notification.connect('activated', Lang.bind(this,
                function(notification) {
                    this._getApp().activate();
                }));
            this.notification.connect('destroy', Lang.bind(this, this._onNotificationDestroy));
            this.notification.show();
        }

        this._destroyPreviousNotifications();
    },

    _notifyPomodoroEnd: function() {
        if (this.notification &&
            this.notification instanceof Notifications.PomodoroEndNotification)
        {
            /* do not renotify */
        }
        else {
            this.notification = new Notifications.PomodoroEndNotification(this.timer);
            this.notification.connect('activated', Lang.bind(this,
                function(notification) {
                    if (this.dialog) {
                        this.dialog.open(true);
                        this.dialog.pushModal();
                    }
                    else {
                        this._getApp().activate();
                    }

                    if (this.reminderManager) {
                        this.reminderManager.acknowledged = true;
                    }
                }));
            this.notification.connect('destroy', Lang.bind(this, this._onNotificationDestroy));

            if (this._showReminders) {
                this._schedulePomodoroEndReminder();
            }

            if (this.dialog && this._showScreenNotifications) {
                this.dialog.open(true);
            }
            else {
                this.notification.show();
            }
        }

        this._destroyPreviousNotifications();
    },

    _onNotificationDestroy: function(notification) {
        if (this.notification === notification) {
            this.notification = null;
        }
    },

    enableIndicator: function() {
        if (!this.indicator) {
            this.indicator = new Indicator.Indicator(this.timer);
            this.indicator.connect('destroy', Lang.bind(this,
                function() {
                    this.indicator = null;
                }));

            try {
                Main.panel.addToStatusArea(Config.PACKAGE_NAME, this.indicator);
            }
            catch (error) {
                Utils.logError(error.message);
            }
        }
    },

    disableIndicator: function() {
        if (this.indicator) {
            this.indicator.destroy();
        }
    },

    enablePresence: function() {
        if (!this.presence) {
            this.presence = new Presence.Presence();
        }
    },

    disablePresence: function() {
        if (this.presence) {
            this.presence.destroy();
            this.presence = null;
        }
    },

    enableNotifications: function() {
        let state = this.timer.getState();

        switch (state) {
            case Timer.State.POMODORO:
                this._notifyPomodoroStart();
                break;

            case Timer.State.SHORT_BREAK:
            case Timer.State.LONG_BREAK:
                this._notifyPomodoroEnd();
                break;
        }
    },

    disableNotifications: function() {
        if (this.notification) {
            this.notification.destroy();
            this.notification = null;
        }

        this._destroyNotifications();
    },

    enableReminders: function() {
        if (this.timer.isBreak() && !this.timer.isPaused() && this._showReminders) {
            this._schedulePomodoroEndReminder();
        }
    },

    disableReminders: function() {
        if (this.reminderManager) {
            this.reminderManager.destroy();
            this.reminderManager = null;
        }
    },

    _updateScreenNotifications: function() {
        if (this.dialog) {
            if (this._showScreenNotifications && this.timer.isBreak() && !this.timer.isPaused()) {
                this.dialog.open(false);
                this.dialog.pushModal();
            }
            else {
                this.dialog.close(false);
            }
        }
    },

    enableScreenNotifications: function() {
        if (!this.dialog) {
            this.dialog = new Dialogs.PomodoroEndDialog(this.timer);
            this.dialog.connect('opening', Lang.bind(this,
                function() {
                    try {
                        if (Main.messageTray._notification) {
                            Main.messageTray._hideNotification(true);
                        }
                    }
                    catch (error) {
                        Utils.logWarning(error.message);
                    }

                    if (this.presence) {
                        this.presence.update();
                    }

                    if (this.reminderManager) {
                        this.reminderManager.block();
                    }
                }));
            this.dialog.connect('closing', Lang.bind(this,
                function() {
                    if (this.timer.isBreak() && !this.timer.isPaused()) {
                        if (this.notification instanceof Notifications.PomodoroEndNotification) {
                            this.notification.show();
                        }

                        if (this._showScreenNotifications) {
                            this.dialog.openWhenIdle();
                        }
                    }

                    if (this.presence) {
                        this.presence.update();
                    }

                    if (this.reminderManager) {
                        this.reminderManager.unblock();
                    }
                }));
            this.dialog.connect('destroy', Lang.bind(this,
                function() {
                    this.dialog = null;
                }));
        }

        this._updateScreenNotifications();
    },

    disableScreenNotifications: function() {
        if (this.dialog) {
            this.dialog.destroy();
            this.dialog = null;
        }
    },

    _schedulePomodoroEndReminder: function() {
        if (!this.reminderManager) {
            this.reminderManager = new Notifications.ReminderManager(this.timer);
            this.reminderManager.connect('notify', Lang.bind(this,
                function() {
                    let notification = new Notifications.PomodoroEndReminderNotification();
                    notification.connect('activated', Lang.bind(this,
                        function(notification) {
                            this.reminderManager.acknowledged = true;

                            if (this.dialog) {
                                this.dialog.open(true);
                                this.dialog.pushModal();
                            }
                            else {
                                this._getApp().activate();
                            }

                            notification.destroy();
                        }));
                    // notification.connect('destroy', Lang.bind(this,
                    //     function(notification) {
                    //         if (!this.reminderManager.acknowledged) {
                    //             this.reminderManager.schedule();
                    //         }
                    //     }));
                    // notification.show();
                }));
            this.reminderManager.connect('destroy', Lang.bind(this,
                function() {
                    this.reminderManager = null;
                }));

            if (this.dialog && this.dialog.isOpened) {
                this.reminderManager.block();
            }
        }

        this.reminderManager.schedule();
    },

    _getApp: function() {
        return Shell.AppSystem.get_default().lookup_app('org.gnome.Pomodoro.desktop');
    },

    notifyIssue: function(message) {
        let notification = new Notifications.IssueNotification(message);
        notification.show();
    },

    destroy: function() {
        if (this._destroying) {
            return;
        }
        this._destroying = true;

        this.disablePresence();
        this.disableIndicator();
        this.disableReminders();
        this.disableNotifications();
        this.disableScreenNotifications();

        if (this.notificationSource) {
            this.notificationSource.destroy();
        }

        this.timer.destroy();

        this.settings.run_dispose();

        this.emit('destroy');
    }
});
Signals.addSignalMethods(PomodoroExtension.prototype);


function init(metadata) {
    Gettext.bindtextdomain(Config.GETTEXT_PACKAGE,
                           Config.PACKAGE_LOCALE_DIR);
}


function enable() {
    let sessionModeUpdatedId;

    if (!extension) {
        extension = new PomodoroExtension(Main.sessionMode.isLocked
                                          ? ExtensionMode.RESTRICTED : ExtensionMode.DEFAULT);
        extension.connect('destroy',
            function() {
                extension = null;

                if (sessionModeUpdatedId != 0) {
                    Main.sessionMode.disconnect(sessionModeUpdatedId);
                    sessionModeUpdatedId = 0;
                }
            });

        sessionModeUpdatedId = Main.sessionMode.connect('updated',
            function() {
                if (Main.sessionMode.isLocked) {
                    ExtensionSystem.enableExtension(Config.EXTENSION_UUID);
                }
                else {
                    extension.setMode(ExtensionMode.DEFAULT);
                }
            });
    }
}


function disable() {
    if (extension) {
        if (Main.sessionMode.isLocked) {
            extension.setMode(ExtensionMode.RESTRICTED);
        }
        else {
            extension.destroy();
        }
    }
}
