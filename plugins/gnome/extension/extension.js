/*
 * A simple pomodoro timer for GNOME Shell
 *
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
 * Authors: Arun Mahapatra <pratikarun@gmail.com>
 *          Kamil Prusko <kamilprusko@gmail.com>
 */

const Gettext = imports.gettext;

const { GLib, Gio, Meta, Shell, St } = imports.gi;

const Main = imports.ui.main;
const ExtensionUtils = imports.misc.extensionUtils;
const ExtensionSystem = imports.ui.extensionSystem;
const MessageTray = imports.ui.messageTray;
const Signals = imports.misc.signals;
const UnlockDialog = imports.ui.unlockDialog;

const Extension = ExtensionUtils.getCurrentExtension();
const Config = Extension.imports.config;
const DBus = Extension.imports.dbus;
const Indicator = Extension.imports.indicator;
const Notifications = Extension.imports.notifications;
const Presence = Extension.imports.presence;
const Settings = Extension.imports.settings;
const Timer = Extension.imports.timer;
const Utils = Extension.imports.utils;
const ScreenShield = Extension.imports.screenShield;


var ExtensionMode = {
    DEFAULT: 0,
    RESTRICTED: 1
};


var PomodoroExtension = class extends Signals.EventEmitter {
    constructor(mode) {
        super();

        this.settings            = null;
        this.pluginSettings      = null;
        this.timer               = null;
        this.indicator           = null;
        this._notificationManager = null;
        this.presence            = null;
        this.mode                = null;
        this.service             = null;
        this.keybinding          = false;
        this._pendingMode        = false;

        try {
            this.settings = Settings.getSettings('org.gnome.pomodoro.preferences');
            this.settings.connect('changed::show-screen-notifications',
                                  this._onSettingsChanged.bind(this));

            this.pluginSettings = Settings.getSettings('org.gnome.pomodoro.plugins.gnome');
            this.pluginSettings.connect('changed::hide-system-notifications',
                                        this._onSettingsChanged.bind(this));
            this.pluginSettings.connect('changed::indicator-type',
                                        this._onSettingsChanged.bind(this));

            this.timer = new Timer.Timer();
            this.timer.connect('service-connected', this._onTimerServiceConnected.bind(this));
            this.timer.connect('service-disconnected', this._onTimerServiceDisconnected.bind(this));
            this.timer.connect('state-changed', this._onTimerStateChanged.bind(this));

            this.service = new DBus.PomodoroExtension();
            this.service.connect('name-acquired', this._onServiceNameAcquired.bind(this));
            this.service.connect('name-lost', this._onServiceNameLost.bind(this));

            this.setMode(mode);
        }
        catch (error) {
            Utils.logError(error);
        }
    }

    get application() {
        return Shell.AppSystem.get_default().lookup_app('org.gnome.Pomodoro.desktop');
    }
    
    get notificationManager() {
        return this._notificationManager;
    }

    setMode(mode) {
        const previousMode = this.mode;

        if (!this.service.initialized) {
            this.mode = mode;
            this._isModePending = true;  // TODO: make setMode async instead of using _isModePending

            return;  /* wait until service name is acquired */
        }

        if (this.mode !== mode || this._isModePending) {
            this.mode = mode;
            this._isModePending = false;

            if (mode === ExtensionMode.RESTRICTED) {
                this._disableIndicator();
                this._disableNotificationManager();
                this._enableScreenShieldManager();
            }
            else {
                this._enableIndicator();
                this._enableNotificationManager(previousMode !== ExtensionMode.RESTRICTED);
                this._disableScreenShieldManager();
            }

            if (this.pluginSettings.get_boolean('hide-system-notifications')) {
                this._enablePresence();
            }
            else {
                this._disablePresence();
            }

            this._enableKeybinding();

            this._updatePresence();
        }
    }

    notifyIssue(message) {
        const notification = new Notifications.IssueNotification(message);
        notification.show();
    }

    _onSettingsChanged(settings, key) {
        switch(key) {
            case 'show-screen-notifications':
                if (this._notificationManager) {
                    this._notificationManager.useDialog = settings.get_boolean(key);
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
    }

    _onServiceNameAcquired() {
        this.emit('service-name-acquired');

        this.setMode(this.mode);
    }

    _onServiceNameLost() {
        this.emit('service-name-lost');

        Utils.logError(new Errror('Lost service name "org.gnome.Pomodoro.Extension"'));
    }

    _onTimerServiceConnected() {
        this.service.run();
    }

    _onTimerServiceDisconnected() {
        Utils.logWarning('Lost connection to "org.gnome.Pomodoro"');
    }

    _onTimerStateChanged() {
        this._updatePresence();
    }

    _onKeybindingPressed() {
        if (this.timer) {
            this.timer.toggle();
        }
    }

    _updatePresence() {
        if (this.presence) {
            const timerState = this.timer.getState();

            if (timerState === Timer.State.NULL) {
                this.presence.setDefault();
            }
            else {
                this.presence.setBusy(timerState === Timer.State.POMODORO);
            }
        }
    }

    _enableIndicator() {
        if (!this.indicator) {
            this.indicator = new Indicator.Indicator(this.timer,
                                                     this.pluginSettings.get_string('indicator-type'));
            this.indicator.connect('destroy',
                () => {
                    this.indicator = null;
                });

            try {
                Main.panel.addToStatusArea(Config.PACKAGE_NAME, this.indicator);
            }
            catch (error) {
                Utils.logError(error);
            }
        }
        else {
            this.indicator.show();
        }
    }

    _disableIndicator() {
        if (this.indicator) {
            this.indicator.hide();
        }
    }

    _enableKeybinding() {
        if (!this.keybinding) {
            this.keybinding = true;
            Main.wm.addKeybinding('toggle-timer-key',
                                  this.settings,
                                  Meta.KeyBindingFlags.NONE,
                                  Shell.ActionMode.ALL,
                                  this._onKeybindingPressed.bind(this));
        }
    }

    _disableKeybinding() {
        if (this.keybinding) {
            this.keybinding = false;
            Main.wm.removeKeybinding('toggle-timer-key');
        }
    }

    _enablePresence() {
        if (!this.presence) {
            this.presence = new Presence.Presence();
        }

        this._updatePresence();
    }

    _disablePresence() {
        this._destroyPresence();
    }

    _enableNotificationManager(animate) {
        if (!this._notificationManager) {
            const params = {
                useDialog: this.settings.get_boolean('show-screen-notifications'),
                animate: animate,
            };
            this._notificationManager = new Notifications.NotificationManager(this.timer, params);
        }
    }

    _disableNotificationManager() {
        if (this._notificationManager) {
            this._notificationManager.destroy();
            this._notificationManager = null;
        }
    }

    _enableScreenShieldManager() {
        if (!Main.screenShield) {
            return;
        }

        if (!this._screenShieldManager) {
            this._screenShieldManager = new ScreenShield.ScreenShieldManager(this.timer);
        }
    }

    _disableScreenShieldManager() {
        if (this._screenShieldManager) {
            this._screenShieldManager.destroy();
            this._screenShieldManager = null;
        }
    }

    _destroyPresence() {
        if (this.presence) {
            this.presence.destroy();
            this.presence = null;
        }
    }

    _destroyIndicator() {
        if (this.indicator) {
            this.indicator.destroy();
            this.indicator = null;
        }
    }

    destroy() {
        if (this._destroying) {
            return;
        }
        this._destroying = true;

        this._disableKeybinding();
        this._disableScreenShieldManager();
        this._disableNotificationManager();

        this._destroyPresence();
        this._destroyIndicator();

        this.timer.destroy();
        this.service.destroy();
        this.settings.run_dispose();

        this.emit('destroy');
    }
};


function init(metadata) {
    Gettext.bindtextdomain(Config.GETTEXT_PACKAGE,
                           Config.PACKAGE_LOCALE_DIR);
}


function enable() {
    let extension = Extension.extension;
    let sessionModeUpdatedId;

    if (!extension) {
        extension = new PomodoroExtension(Main.sessionMode.isLocked
                                          ? ExtensionMode.RESTRICTED : ExtensionMode.DEFAULT);
        extension.connect('destroy',
            () => {
                if (Extension.extension === extension) {
                    Extension.extension = null;
                }

                if (sessionModeUpdatedId != 0) {
                    Main.sessionMode.disconnect(sessionModeUpdatedId);
                    sessionModeUpdatedId = 0;
                }
            });
        extension.connect('service-name-lost',
            () => {
                let metadata = ExtensionUtils.extensions[Config.EXTENSION_UUID];

                if (metadata && metadata.extension === extension) {
                    ExtensionSystem.disableExtension(Config.EXTENSION_UUID);
                }
                else {
                    extension.destroy();
                }
            });

        sessionModeUpdatedId = Main.sessionMode.connect('updated',
            () => {
                extension.setMode(Main.sessionMode.isLocked
                                  ? ExtensionMode.RESTRICTED : ExtensionMode.DEFAULT);
            });

        Extension.extension = extension;
    }
}


function disable() {
    let extension = Extension.extension;

    if (extension) {
        extension.destroy();
    }
}
