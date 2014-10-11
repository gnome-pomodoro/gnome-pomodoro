/*
 * A simple pomodoro timer for GNOME Shell
 *
 * Copyright (c) 2011-2013 gnome-pomodoro contributors
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
const Settings = Extension.imports.settings;
const Timer = Extension.imports.timer;


let extension = null;


const PomodoroExtension = new Lang.Class({
    Name: 'PomodoroExtensoin',

    _init: function() {
        Extension.extension = this;

        this.settings = null;
        this.timer = null;
        this.indicator = null;
        this.dialog = null;

        this._settingsChangedId = 0;

        try {
            this.settings = Settings.getSettings('org.gnome.pomodoro.preferences');
            this._settingsChangedId = this.settings.connect('changed', Lang.bind(this, this._onSettingsChanged));
        }
        catch (error) {
            this.logError(error);
        }

        this.timer = new Timer.Timer();

        this.enableKeybinding();
        this.enableIndicator();
        this.enableNotifications();

        this.timer.connect('service-connected', Lang.bind(this, this._onServiceConnected));
        this.timer.connect('service-disconnected', Lang.bind(this, this._onServiceDisconnected));
        this.timer.connect('state-changed', Lang.bind(this, this._onTimerStateChanged));
        this.timer.connect('notify-pomodoro-start', Lang.bind(this, this._onNotifyPomodoroStart));
        this.timer.connect('notify-pomodoro-end', Lang.bind(this, this._onNotifyPomodoroEnd));
    },

    _onServiceConnected: function() {
        let state = this.timer.getState();

        if (state == Timer.State.POMODORO || state == Timer.State.IDLE) {
            this._onNotifyPomodoroStart();
        }

        if (state == Timer.State.PAUSE) {
            this._onNotifyPomodoroEnd();
        }
    },

    _onServiceDisconnected: function() {
        if (this.dialog) {
            this.dialog.close();
        }
    },

    _onTimerStateChanged: function() {
        let state = this.timer.getState();

        if (this.dialog && state != Timer.State.PAUSE) {
            this.dialog.close();
        }
    },

    _onNotifyPomodoroStart: function() {
    },

    _onNotifyPomodoroEnd: function() {
        if (this.dialog) {
            this.dialog.open();
        }
    },

    _onSettingsChanged: function() {
        let enableNotifications = this.settings.get_boolean('show-screen-notifications');

        if (this.dialog && !enableNotifications) {
            this.disableNotifications();
        }

        if (!this.dialog && enableNotifications) {
            this.enableNotifications();
        }
    },

    _onKeybindingPressed: function() {
        if (this.timer) {
            this.timer.toggle();
        }
    },

    enableIndicator: function() {
        this.indicator = new Indicator.Indicator(this.timer);

        Main.panel.addToStatusArea(Config.PACKAGE_NAME, this.indicator);
    },

    disableIndicator: function() {
        if (this.indicator) {
            this.indicator.destroy();
            this.indicator = null;
        }
    },

    enableKeybinding: function() {
        Main.wm.addKeybinding('toggle-timer-key',
                              this.settings,
                              Meta.KeyBindingFlags.NONE,
                              Shell.KeyBindingMode.ALL,
                              Lang.bind(this, this._onKeybindingPressed));

    },

    disableKeybinding: function() {
        Main.wm.removeKeybinding('toggle-timer-key');
    },

    enableNotifications: function() {
        this.dialog = new Notifications.PomodoroEndDialog(this.timer);
        this.dialog.connect('closing', Lang.bind(this,
            function() {
                if (this.timer.getState() == Timer.State.PAUSE) {
                    this.dialog.openWhenIdle();
                }
            }));
        this.dialog.connect('destroy', Lang.bind(this,
            function() {
                this.dialog = null;
            }));
    },

    disableNotifications: function() {
        if (this.dialog) {
            this.dialog.destroy();
            this.dialog = null;
        }
    },

    notifyIssue: function(message) {
        let notification = new Notifications.Issue(message);
        notification.show();
    },

    logError: function(message) {
        ExtensionSystem.logExtensionError(Extension.metadata.uuid, message);
    },

    destroy: function() {
        if (this._settingsChangedId) {
            this.settings.disconnect(this._settingsChangedId);
            this._settingsChangedId = 0;
        }

        if (Notifications.source) {
            Notifications.source.destroy();
        }

        this.disableKeybinding();
        this.disableIndicator();
        this.disableNotifications();

        this.timer.destroy();

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
    if (extension) {
        extension.destroy();
        extension = null;
    }
}
