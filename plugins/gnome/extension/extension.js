/*
 * A simple pomodoro timer for GNOME Shell
 *
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


var extension = null;


const ExtensionMode = {
    DEFAULT: 0,
    RESTRICTED: 1
};


// notifications pop up before state changes
const NOTIFICATIONS_TIME_OFFSET = 10.0;


const PomodoroExtension = new Lang.Class({
    Name: 'PomodoroExtension',

    _init: function(mode) {
        Extension.extension = this;

        this.settings            = null;
        this.pluginSettings      = null;
        this.timer               = null;
        this.indicator           = null;
        this.notificationSource  = null;
        this.notification        = null;
        this.dialog              = null;
        this.presence            = null;
        this.mode                = null;
        this.keybinding          = false;
        this._isPaused           = false;
        this._timerState         = Timer.State.NULL;
        this._timerStateDuration = 0.0;

        try {
            this.settings = Settings.getSettings('org.gnome.pomodoro.preferences');
            this.settings.connect('changed::show-screen-notifications',
                                  Lang.bind(this, this._onSettingsChanged));

            this.pluginSettings = Settings.getSettings('org.gnome.pomodoro.plugins.gnome');
            this.pluginSettings.connect('changed::hide-system-notifications',
                                        Lang.bind(this, this._onSettingsChanged));
            this.pluginSettings.connect('changed::indicator-type',
                                        Lang.bind(this, this._onSettingsChanged));

            this.timer = new Timer.Timer();
            this.timer.connect('service-disconnected', Lang.bind(this, this._onServiceDisconnected));
            this.timer.connect('update', Lang.bind(this, this._onTimerUpdate));
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
        if (this.mode != mode) {
            this.mode = mode;

            if (mode == ExtensionMode.RESTRICTED) {
                this._disableIndicator();
                this._disableScreenNotification();
            }
            else {
                this._enableIndicator();

                if (this.settings.get_boolean('show-screen-notifications')) {
                    this._enableScreenNotification();
                }
            }

            if (this.pluginSettings.get_boolean('hide-system-notifications')) {
                this._enablePresence();
            }
            else {
                this._disablePresence();
            }

            this._enableKeybinding();
            this._updateNotification();
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
                    this._enableScreenNotification();
                }
                else {
                    this._disableScreenNotification();
                }

                break;

            case 'hide-system-notifications':
                if (settings.get_boolean(key)) {
                    this._enablePresence();
                }
                else {
                    this._disablePresence();
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
    },

    _onTimerUpdate: function() {
        let remaining = this.timer.getRemaining();

        if (remaining <= NOTIFICATIONS_TIME_OFFSET && !this.notification) {
            this._updateNotification();
        }
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
            if (this.notification.resident || this.notification.acknowledged) {
                this.notification.show();
            }
        }
        else {
            this.notification = new Notifications.PomodoroStartNotification(this.timer);
            this.notification.connect('activated', Lang.bind(this,
                function(notification) {
                    if (this.timer.isBreak()) {
                        this.timer.skip();
                    }
                    else {
                        notification.destroy();
                    }
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
            if (this.dialog && this.timer.isBreak()) {
                this.dialog.open(true);
            }
            else if (this.notification.resident || this.notification.acknowledged) {
                this.notification.show();
            }
        }
        else {
            this.notification = new Notifications.PomodoroEndNotification(this.timer);
            this.notification.connect('activated', Lang.bind(this,
                function(notification) {
                    if (this.timer.isBreak()) {
                        if (this.dialog) {
                            this.dialog.open(true);
                            this.dialog.pushModal();
                        }
                    }
                    else {
                        this.timer.skip();
                    }
                }));
            this.notification.connect('destroy', Lang.bind(this, this._onNotificationDestroy));

            if (this.dialog && this.timer.isBreak()) {
                this.dialog.open(true);
            }
            else {
                this.notification.show();
            }

            this._destroyPreviousNotifications();
        }
    },

    _updateNotification: function() {
        let timerState = this.timer.getState();
        let isPaused   = this.timer.isPaused();

        if (timerState != Timer.State.NULL && (!isPaused || this.timer.getElapsed() == 0.0)) {
            if (this.mode == ExtensionMode.RESTRICTED) {
                this._destroyNotifications();

                // TODO: As currently notifications on the screenShield can't be updated they are pretty useless
                // if (!(this.notification &&
                //       this.notification instanceof Notifications.TimerNotification))
                // {
                //     this.notification = new Notifications.TimerNotification(this.timer);
                //     this.notification.connect('destroy', Lang.bind(this, this._onNotificationDestroy));
                //     this.notification.show();
                //
                //     this._destroyPreviousNotifications();
                // }
            }
            else if (this.timer.getRemaining() > NOTIFICATIONS_TIME_OFFSET) {
                if (timerState == Timer.State.POMODORO) {
                    this._notifyPomodoroStart();
                }
                else {
                    this._notifyPomodoroEnd();
                }
            }
            else {
                if (timerState != Timer.State.POMODORO) {
                    this._notifyPomodoroStart();
                }
                else {
                    this._notifyPomodoroEnd();
                }
            }
        }
        else {
            this._destroyNotifications();
        }
    },

    _updateScreenNotification: function() {
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

    _updatePresence: function() {
        if (this.presence) {
            if (this._timerState == Timer.State.NULL) {
                this.presence.setDefault();
            }
            else {
                this.presence.setBusy(this._timerState == Timer.State.POMODORO);
            }
        }
    },

    _update: function() {
        let timerState = this.timer.getState();
        let timerStateDuration = this.timer.getStateDuration();
        let isPaused = this.timer.isPaused();

        if (this._isPaused != isPaused || this._timerState != timerState) {
            this._isPaused = isPaused;
            this._timerState = timerState;
            this._timerStateDuration = timerStateDuration;

            this._updatePresence();
            this._updateNotification();
            this._updateScreenNotification();
        }
        else if (this._timerStateDuration == timerStateDuration) {
            this._updateScreenNotification();
        }
        else {
            this._timerStateDuration = timerStateDuration;
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
        if (!this.presence) {
            this.presence = new Presence.Presence();
        }

        this._updatePresence();
    },

    _disablePresence: function() {
        this._destroyPresence();
    },

    _enableScreenNotification: function() {
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
                }));
            this.dialog.connect('destroy', Lang.bind(this,
                function() {
                    this.dialog = null;
                }));
        }

        this._updateScreenNotification();
    },

    _disableScreenNotification: function() {
        this._destroyScreenNotification();
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

    _destroyScreenNotification: function() {
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
        this._destroyScreenNotification();
        this._destroyNotifications();

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
