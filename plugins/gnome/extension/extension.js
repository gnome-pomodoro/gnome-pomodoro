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
        this.pluginSettings     = null;
        this.timer              = null;
        this.indicator          = null;
        this.notificationSource = null;
        this.notification       = null;
        this.dialog             = null;
        this.reminder           = null;
        this.presence           = null;
        this.mode               = null;
        this.keybinding         = false;
        this._isPaused          = false;
        this._timerState        = Timer.State.NULL;

        try {
            this.settings = Settings.getSettings('org.gnome.pomodoro.preferences');
            this.settings.connect('changed::show-reminders',
                                  Lang.bind(this, this._onSettingsChanged));
            this.settings.connect('changed::show-screen-notifications',
                                  Lang.bind(this, this._onSettingsChanged));

            this.pluginSettings = Settings.getSettings('org.gnome.pomodoro.plugins.gnome');
            this.pluginSettings.connect('changed::hide-system-notifications',
                                        Lang.bind(this, this._onSettingsChanged));
            this.pluginSettings.connect('changed::indicator-type',
                                        Lang.bind(this, this._onSettingsChanged));

            this.timer = new Timer.Timer();
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

    get application() {
        return Shell.AppSystem.get_default().lookup_app('org.gnome.Pomodoro.desktop');
    },

    setMode: function(mode) {
        if (this.mode !== mode) {
            this.mode = mode;

            if (mode == ExtensionMode.RESTRICTED) {
                this._disableIndicator();
                this._disableScreenNotifications();
                this._disableReminders();
            }
            else {
                this._enableIndicator();

                if (this.settings.get_boolean('show-screen-notifications')) {
                    this._enableScreenNotifications();
                }

                if (this.settings.get_boolean('show-reminders')) {
                    this._enableReminders();
                }
            }

            this._enableKeybinding();
            this._enablePresence();

            this._updateNotifications();
        }
    },

    notifyIssue: function(message) {
        let notification = new Notifications.IssueNotification(message);
        notification.show();
    },

    _onSettingsChanged: function(settings, key) {
        switch(key) {
            case 'show-screen-notifications':
                if (settings.get_boolean(key) && this.mode != ExtensionMode.RESTRICTED) {
                    this._enableScreenNotifications();
                }
                else {
                    this._disableScreenNotifications();
                }

                break;

            case 'show-reminders':
                if (settings.get_boolean(key) && this.mode != ExtensionMode.RESTRICTED) {
                    this._enableReminders();
                }
                else {
                    this._disableReminders();
                }

                break;

            case 'hide-system-notifications':
                if (this.presence) {
                    this.presence.setHideSystemNotifications(settings.get_boolean(key));
                }

                break;

            case 'indicator-type':
                if (this.indicator) {
                    this.indicator.setType(settings.get_string(key));
                }

                break;
        }
    },

    _onServiceDisconnected: function() {
        Utils.disableExtension(Config.EXTENSION_UUID);
    },

    _onTimerPaused: function() {
        this._update();
    },

    _onTimerResumed: function() {
        this._update();
    },

    _onTimerStateChanged: function() {
        this._update();
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
                    this.application.activate();
                }));
            this.notification.connect('destroy', Lang.bind(this, this._onNotificationDestroy));
            this.notification.show();

            this._destroyPreviousNotifications();
        }
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
                        this.application.activate();
                    }

                    if (this.reminder) {
                        this.reminder.dismiss();
                    }
                }));
            this.notification.connect('destroy', Lang.bind(this, this._onNotificationDestroy));

            if (this.dialog) {
                this.dialog.open(true);
            }
            else {
                this.notification.show();

                if (this.reminder && !this.reminder.acknowledged) {
                    this.reminder.schedule();
                }
            }

            this._destroyPreviousNotifications();
        }
    },

    _updateNotifications: function() {
        if (this.timer.isPaused()) {
            this._destroyNotifications();
        }
        else {
            switch (this.timer.getState()) {
                case Timer.State.POMODORO:
                    this._notifyPomodoroStart();
                    break;

                case Timer.State.SHORT_BREAK:
                case Timer.State.LONG_BREAK:
                    this._notifyPomodoroEnd();
                    break;

                default:
                    this._destroyNotifications();
                    break;
            }
        }
    },

    _updateScreenNotifications: function() {
        if (this.dialog) {
            if (this.timer.isBreak() && !this.timer.isPaused()) {
                this.dialog.open(false);
                this.dialog.pushModal();
            }
            else {
                this.dialog.close(false);
            }
        }
    },

    _update: function() {
        let timerState = this.timer.getState();
        let isPaused = this.timer.isPaused();
        let isRunning = timerState != Timer.State.NULL && !isPaused;

        if (this._isPaused != isPaused || this._timerState != timerState) {
            this._isPaused = isPaused;
            this._timerState = timerState;

            if (this.presence) {
                this.presence.setBusy(timerState == Timer.State.POMODORO);
            }

            if (this.reminder && !this.timer.isBreak()) {
                this.reminder.unschedule();
            }

            this._updateNotifications();
            this._updateScreenNotifications();
        }
    },

    _enableIndicator: function() {
        if (!this.indicator) {
            this.indicator = new Indicator.Indicator(this.timer,
                                                     this.pluginSettings.get_string('indicator-type'));
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
        else {
            this.indicator.actor.show();
        }
    },

    _disableIndicator: function() {
        if (this.indicator) {
            this.indicator.actor.hide();
        }
    },

    _enableKeybinding: function() {
        if (!this.keybinding) {
            this.keybinding = true;
            Main.wm.addKeybinding('toggle-timer-key',
                                  this.settings,
                                  Meta.KeyBindingFlags.NONE,
                                  Shell.ActionMode.ALL,
                                  Lang.bind(this, this._onKeybindingPressed));
        }
    },

    _disableKeybinding: function() {
        if (this.keybinding) {
            this.keybinding = false;
            Main.wm.removeKeybinding('toggle-timer-key');
        }
    },

    _enablePresence: function() {
        let state = this.timer.getState();

        if (!this.presence) {
            this.presence = new Presence.PresenceManager();
            this.presence.setHideSystemNotifications(this.pluginSettings.get_boolean('hide-system-notifications'));
            this.presence.setBusy(this.timer.getState() == Timer.State.POMODORO);
        }
    },

    _disablePresence: function() {
        this._destroyPresence();
    },

    _enableReminders: function() {
        if (!this.reminder) {
            this.reminder = new Notifications.ReminderManager(this.timer);
            this.reminder.connect('notify', Lang.bind(this,
                function() {
                    let notification = new Notifications.RemindPomodoroEndNotification();
                    notification.connect('activated', Lang.bind(this,
                        function(notification) {
                            this.reminder.dismiss();

                            if (this.dialog) {
                                this.dialog.open(true);
                                this.dialog.pushModal();
                            }
                            else {
                                this.application.activate();
                            }

                            notification.destroy();
                        }));
                }));
            this.reminder.connect('destroy', Lang.bind(this,
                function() {
                    this.reminder = null;
                }));
        }

        if (this.timer.isBreak() && !this.timer.isPaused() && this.reminder && !this.reminder.acknowledged) {
            this.reminder.schedule();
        }
    },

    _disableReminders: function() {
        this._destroyReminders();
    },

    _enableScreenNotifications: function() {
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

                    if (this.reminder) {
                        this.reminder.unschedule();
                    }
                }));
            this.dialog.connect('closing', Lang.bind(this,
                function() {
                    if (this.timer.isBreak() && !this.timer.isPaused()) {
                        if (this.notification instanceof Notifications.PomodoroEndNotification) {
                            this.notification.show();
                        }

                        if (this.dialog) {
                            this.dialog.openWhenIdle();
                        }
                    }

                    if (this.reminder && !this.reminder.acknowledged) {
                        this.reminder.schedule();
                    }
                }));
            this.dialog.connect('destroy', Lang.bind(this,
                function() {
                    this.dialog = null;
                }));
        }

        this._updateScreenNotifications();
    },

    _disableScreenNotifications: function() {
        this._destroyScreenNotifications();
    },

    _destroyPresence: function() {
        if (this.presence) {
            this.presence.destroy();
            this.presence = null;
        }
    },

    _destroyIndicator: function() {
        if (this.indicator) {
            this.indicator.destroy();
            this.indicator = null;
        }
    },

    _destroyReminders: function() {
        if (this.reminder) {
            this.reminder.destroy();
            this.reminder = null;
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

    _destroyScreenNotifications: function() {
        if (this.dialog) {
            this.dialog.destroy();
            this.dialog = null;
        }
    },

    destroy: function() {
        if (this._destroying) {
            return;
        }
        this._destroying = true;

        this._disableKeybinding();

        this._destroyPresence();
        this._destroyIndicator();
        this._destroyScreenNotifications();
        this._destroyNotifications();
        this._destroyReminders();

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
