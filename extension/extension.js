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

const ExtensionSystem = imports.ui.extensionSystem;
const Gio = imports.gi.Gio;
const Main = imports.ui.main;
const Meta = imports.gi.Meta;
const Shell = imports.gi.Shell;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Config = Extension.imports.config;
const DBus = Extension.imports.dbus;
const Indicator = Extension.imports.indicator;
const Notifications = Extension.imports.notifications;
const Dialogs = Extension.imports.dialogs;
const Presence = Extension.imports.presence;
const Settings = Extension.imports.settings;
const Timer = Extension.imports.timer;


let extension = null;


const PomodoroExtension = new Lang.Class({
    Name: 'PomodoroExtension',

    _init: function() {
        Extension.extension = this;

        this.settings           = null;
        this.timer              = null;
        this.indicator          = null;
        this.notificationSource = null;
        this.notification       = null;
        this.dialog             = null;
        this.reminderManager    = null;
        this.presence           = null;
        this.keybinding         = false;

        try {
            this.settings = Settings.getSettings('org.gnome.pomodoro.preferences');

            this.settings.connect('changed::show-screen-notifications',
                                  Lang.bind(this, this._onSettingsChanged));
            this.settings.connect('changed::show-reminders',
                                  Lang.bind(this, this._onSettingsChanged));

            this._showScreenNotifications = this.settings.get_boolean('show-screen-notifications');
            this._showReminders = this.settings.get_boolean('show-reminders');
        }
        catch (error) {
            this.logError(error);

            // TODO: Notify issue
        }

        this.timer = new Timer.Timer();

        this.dbus = new DBus.PomodoroExtension();

        this.timer.connect('service-connected', Lang.bind(this, this._onServiceConnected));
        this.timer.connect('service-disconnected', Lang.bind(this, this._onServiceDisconnected));
        this.timer.connect('state-changed', Lang.bind(this, this._onTimerStateChanged));

        Main.sessionMode.connect('updated', Lang.bind(this, this._onSessionModeUpdated));
        this._onSessionModeUpdated();
    },

    _destroyNotifications: function() {
        if (this.notificationSource) {
            this.notificationSource.destroyAllNotifications();
        }
    },

    _destroyPreviousNotifications: function() {
        if (Notifications.source) {
            let notifications = Notifications.source.notifications.filter(Lang.bind(this,
                function(notification) {
                    return notification !== this.notification;
                }));

            Notifications.source.destroyNotifications(notifications);
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

                if (this._showReminders && this.timer.getState() == Timer.State.PAUSE) {
                    this._schedulePomodoroEndReminder();
                }
                else {
                    this.disableReminders();
                }

                break;
        }
    },

    _onSessionModeUpdated: function() {
        this.setInLockScreen(Main.sessionMode.isLocked);
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

            if (this.dialog && timerState != Timer.State.PAUSE) {
                this.dialog.close(true);
            }

            if (this.reminderManager) {
                this.reminderManager.destroy();
                this.reminderManager = null;
            }

            switch (timerState) {
                case Timer.State.POMODORO:
                case Timer.State.IDLE:
                    this._notifyPomodoroStart();
                    break;

                case Timer.State.PAUSE:
                    this._notifyPomodoroEnd();
                    break;

                case Timer.State.NULL:
                    this._destroyNotifications();
                    break;
            }
        }
    },

    _notifyPomodoroStart: function() {
        if (this.notification &&
            this.notification instanceof Notifications.PomodoroStartNotification)
        {
            /* do not renotify */
        }
        else {
            this.notification = new Notifications.PomodoroStartNotification(this.timer);
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
                    let timerState = this.timer.getState();

                    if (this.dialog && timerState == Timer.State.PAUSE) {
                        this.dialog.open(true);
                        this.dialog.pushModal();
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

    _onKeybindingPressed: function() {
        if (this.timer) {
            this.timer.toggle();
        }
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
                this.logError(error.message);
            }
        }
    },

    disableIndicator: function() {
        if (this.indicator) {
            this.indicator.destroy();
            this.indicator = null;
        }
    },

    enableKeybinding: function() {
        if (!this.keybinding) {
            this.keybinding = true;
            if (Shell.ActionMode) {
                Main.wm.addKeybinding('toggle-timer-key',  // 3.16+
                                      this.settings,
                                      Meta.KeyBindingFlags.NONE,
                                      Shell.ActionMode.ALL,
                                      Lang.bind(this, this._onKeybindingPressed));
            }
            else {
                Main.wm.addKeybinding('toggle-timer-key',  // deprecated
                                      this.settings,
                                      Meta.KeyBindingFlags.NONE,
                                      Shell.KeyBindingMode.ALL,
                                      Lang.bind(this, this._onKeybindingPressed));
            }
        }
    },

    disableKeybinding: function() {
        if (this.keybinding) {
            this.keybinding = false;
            Main.wm.removeKeybinding('toggle-timer-key');
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

        if (state == Timer.State.POMODORO || state == Timer.State.IDLE) {
            this._notifyPomodoroStart();
        }

        if (state == Timer.State.PAUSE) {
            this._notifyPomodoroEnd();
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
        let state = this.timer.getState();

        if (state == Timer.State.PAUSE && this._showReminders) {
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
        if (this.dialog && this.timer.getState() == Timer.State.PAUSE)
        {
            if (this._showScreenNotifications) {
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
                        this.logError(error.message);        
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
                    if (this.timer.getState() == Timer.State.PAUSE) {
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

    setInLockScreen: function(inLockScreen) {
        if (this.inLockScreen !== inLockScreen) {
            this.inLockScreen = inLockScreen;

            if (inLockScreen) {
                this.disableIndicator();
                this.disableScreenNotifications();
                this.disableReminders();
            }
            else {
                this.enableIndicator();
                this.enableScreenNotifications();
                this.enableReminders();
            }

            this.enableKeybinding();
            this.enableNotifications();
            this.enablePresence();
        }
    },

    notifyIssue: function(message) {
        let notification = new Notifications.IssueNotification(message);
        notification.show();
    },

    logError: function(message) {
        ExtensionSystem.logExtensionError(Extension.metadata.uuid, message);
    },

    destroy: function() {
        if (this._destroying) {
            return;
        }
        this._destroying = true;

        this.disableKeybinding();
        this.disablePresence();
        this.disableIndicator();
        this.disableReminders();
        this.disableNotifications();
        this.disableScreenNotifications();

        if (this.notificationSource) {
            this.notificationSource.destroy();
        }

        this.dbus.destroy();
        this.timer.destroy();

        this.settings.run_dispose();

        this.emit('destroy');
    }
});
Signals.addSignalMethods(PomodoroExtension.prototype);


function init(metadata) {
    Gettext.bindtextdomain(Config.GETTEXT_PACKAGE,
                           Config.LOCALE_DIR);
}


function enable() {
    if (!extension) {
        if (Main.pomodoro && Main.pomodoro !== extension) {
            Main.pomodoro.destroy();
        }

        extension = new PomodoroExtension();
        extension.connect('destroy', Lang.bind(this,
            function() {
                extension = null;
            }));

        Main.pomodoro = extension;
    }
}


function disable() {
    if (extension && !Main.sessionMode.isLocked) {
        extension.destroy();
        extension = null;
    }
}
