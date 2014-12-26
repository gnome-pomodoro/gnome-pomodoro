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

        this.settings     = null;
        this.timer        = null;
        this.indicator    = null;
        this.notification = null;
        this.dialog       = null;
        this.presence     = null;
        this.keybinding   = false;

        try {
            this.settings = Settings.getSettings('org.gnome.pomodoro.preferences');

            this.settings.connect('changed::show-screen-notifications',
                                  Lang.bind(this, this._onSettingsChanged));
            this._onSettingsChanged(this.settings, 'show-screen-notifications');
        }
        catch (error) {
            this.logError(error);

            // TODO: Notify issue
        }

        this.timer = new Timer.Timer();

        Main.sessionMode.connect('updated', Lang.bind(this, this._onSessionModeUpdated));
        this._onSessionModeUpdated();

        this.timer.connect('service-connected', Lang.bind(this, this._onServiceConnected));
        this.timer.connect('service-disconnected', Lang.bind(this, this._onServiceDisconnected));
        this.timer.connect('state-changed', Lang.bind(this, this._onTimerStateChanged));
        this.timer.connect('notify-pomodoro-start', Lang.bind(this, this._onNotifyPomodoroStart));
        this.timer.connect('notify-pomodoro-end', Lang.bind(this, this._onNotifyPomodoroEnd));
    },

    _destroyNotifications: function() {
        if (Notifications.source) {
            Notifications.source.destroy();
        }
    },

    _destroyPreviousNotifications: function() {
        if (Notifications.source) {
            let notifications = Notifications.source.notifications;

            for (let i = notifications.length - 1; i >= 0; i--) {
                if (notifications[i] !== this.notification) {
                    notifications[i].destroy();
                }
            }
        }
    },

    _onSettingsChanged: function(settings, key) {
        switch(key)
        {
            case 'show-screen-notifications':
                this._showScreenNotifications = this.settings.get_boolean(key);

                if (this.dialog && this.timer.getState() == Timer.State.PAUSE)
                {
                    if (this._showScreenNotifications) {
                        this.dialog.openWhenIdle();
                    }
                    else {
                        this.dialog.close();
                    }
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
        if (this.dialog) {
            this.dialog.close();
        }

        this._destroyNotifications();
    },

    _onTimerStateChanged: function() {
        let state = this.timer.getState();

        if (this.dialog && state != Timer.State.PAUSE) {
            this.dialog.close();
        }

        if (state == Timer.State.NULL) {
            this._destroyNotifications();
        }

        /* don't wait for pomodoro-start signal to reduce flicker */
        if (!(this.notification instanceof Notifications.PomodoroEndNotification) &&
            (state == Timer.State.POMODORO || state == Timer.State.IDLE))
        {
            this._onNotifyPomodoroStart();
        }
    },

    _onNotifyPomodoroStart: function() {
        if (this.notification &&
            this.notification instanceof Notifications.PomodoroStartNotification)
        {
            /* do not renotify */
        }
        else {
            this.notification = new Notifications.PomodoroStartNotification(this.timer);
            this.notification.connect('clicked', Lang.bind(this,
                function(notification) {
                    Main.messageTray.close();

                    notification.hide();
                }));
            this.notification.connect('destroy', Lang.bind(this, this._onNotificationDestroy));
            this.notification.show();
        }

        this._destroyPreviousNotifications();
    },

    _onNotifyPomodoroEnd: function() {
        if (this.notification &&
            this.notification instanceof Notifications.PomodoroEndNotification)
        {
            /* do not renotify */
        }
        else {
            this.notification = new Notifications.PomodoroEndNotification(this.timer);
            this.notification.connect('clicked', Lang.bind(this,
                function(notification){
                    if (this.dialog) {
                        this.dialog.open();
                        this.dialog.pushModal();

                        notification.hide();
                    }
                }));
            this.notification.connect('destroy', Lang.bind(this, this._onNotificationDestroy));
        }

        if (this.dialog && this._showScreenNotifications) {
            this.dialog.open();
        }
        else {
            this.notification.show();
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
            Main.wm.addKeybinding('toggle-timer-key',
                                  this.settings,
                                  Meta.KeyBindingFlags.NONE,
                                  Shell.KeyBindingMode.ALL,
                                  Lang.bind(this, this._onKeybindingPressed));
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
            this._onNotifyPomodoroStart();
        }

        if (state == Timer.State.PAUSE) {
            this._onNotifyPomodoroEnd();
        }
    },

    disableNotifications: function() {
        this.notification = null;

        this._destroyNotifications();
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

                    Main.messageTray.close();

                    if (this.presence) {
                        this.presence.update();
                    }
                }));
            this.dialog.connect('closing', Lang.bind(this,
                function() {
                    if (this.timer.getState() == Timer.State.PAUSE)
                    {
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
                }));
            this.dialog.connect('destroy', Lang.bind(this,
                function() {
                    this.dialog = null;
                }));
        }
    },

    disableScreenNotifications: function() {
        if (this.dialog) {
            this.dialog.destroy();
            this.dialog = null;
        }
    },

    setInLockScreen: function(inLockScreen) {
        if (this.inLockScreen !== inLockScreen) {
            this.inLockScreen = inLockScreen;

            if (inLockScreen) {
                this.disableIndicator();
                this.disableScreenNotifications();
            }
            else {
                this.enableIndicator();
                this.enableScreenNotifications();
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
        this.disableKeybinding();
        this.disablePresence();
        this.disableIndicator();
        this.disableNotifications();
        this.disableScreenNotifications();

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
        extension = new PomodoroExtension();
    }
}


function disable() {
    if (extension && !Main.sessionMode.isLocked) {
        extension.destroy();
        extension = null;
    }
}
