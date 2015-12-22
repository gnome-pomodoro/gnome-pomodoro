/*
 * Copyright (c) 2014 gnome-pomodoro contributors
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
 */

const Lang = imports.lang;
const Signals = imports.signals;

const Gio = imports.gi.Gio;
const Main = imports.ui.main;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Config = Extension.imports.config;
const DBus = Extension.imports.dbus;
const Settings = Extension.imports.settings;
const Utils = Extension.imports.utils;


const State = {
    NULL: 'null',
    POMODORO: 'pomodoro',
    SHORT_BREAK: 'short-break',
    LONG_BREAK: 'long-break'
};


const Timer = new Lang.Class({
    Name: 'PomodoroTimer',

    _init: function() {
        this._proxy = null;
        this._connected = false;

        this._state = null;
        this._propertiesChangedId = 0;
        this._settingsChangedId = 0;
        this._shortBreakDuration = 0;
        this._longBreakDuration = 0;

        this._nameWatcherId = Gio.DBus.session.watch_name(
                                       'org.gnome.Pomodoro',
                                       Gio.BusNameWatcherFlags.AUTO_START,
                                       Lang.bind(this, this._onNameAppeared),
                                       Lang.bind(this, this._onNameVanished));

        let settings = Extension.extension.settings;
        this._settingsChangedId  = settings.connect('changed', Lang.bind(this, this._onSettingsChanged));
        this._shortBreakDuration = settings.get_double('short-break-duration');
        this._longBreakDuration  = settings.get_double('long-break-duration');

        // if (this._isRunning()) {
        this._ensureProxy();
        // }
    },

    //_isRunning: function() {
    //    let settings;
    //    let state;
    //
    //    try {
    //        settings = Settings.getSettings('org.gnome.pomodoro.state');
    //        state = settings.get_string('state');
    //    }
    //    catch (error) {
    //        Utils.logWarning(error.message);
    //    }
    //
    //    return state && state != State.NULL;
    //},

    _onSettingsChanged: function(settings, key) {
        switch (key) {
            case 'short-break-duration':
                this._shortBreakDuration = settings.get_double('short-break-duration');
                break;

            case 'long-break-duration':
                this._longBreakDuration = settings.get_double('long-break-duration');
                break;
        }
    },

    _ensureProxy: function(callback) {
        if (this._proxy) {
            if (callback) {
                callback.call(this);
            }
            return;
        }

        this._proxy = DBus.Pomodoro(Lang.bind(this, function(proxy, error) {
            if (error) {
                Utils.logWarning(error.message);
                this._notifyServiceNotInstalled();
                return;
            }

            /* Keep in mind that signals won't be called right after initialization
             * when gnome-pomodoro comes back and gets restored
             */
            if (this._propertiesChangedId == 0) {
                this._propertiesChangedId = this._proxy.connect(
                                           'g-properties-changed',
                                           Lang.bind(this, this._onPropertiesChanged));
            }

            this._connected = true;

            if (callback) {
                callback.call(this);
            }

            this.emit('service-connected');
            this.emit('state-changed');
            this.emit('update');

            this._onPropertiesChanged(this._proxy, null);
        }));
    },

    _onNameAppeared: function() {
        this._ensureProxy();
    },

    _onNameVanished: function() {
        if (this._propertiesChangedId != 0) {
            this._proxy.disconnect(this._propertiesChangedId);
            this._propertiesChangedId = 0;
        }

        this._proxy = null;
        this._connected = false;

        this.emit('state-changed');
        this.emit('update');
        this.emit('service-disconnected');
    },

    _onPropertiesChanged: function(proxy, properties) {
        let state = proxy.State;

        if (this._state !== state) {
            this._state = state;
            this.emit('state-changed');
        }

        this.emit('update');
    },

    _onCallback: function(result, error) {
        if (error) {
            Utils.logWarning(error.message);

            /* timer toggle assumes success right away, so we need to
               straighten it out */
            this.emit('state-changed');

            if (error.matches(Gio.DBusError, Gio.DBusError.SERVICE_UNKNOWN)) {
                this._notifyServiceNotInstalled();
            }
        }
    },

    getState: function() {
        if (!this._connected || this._proxy.State == null) {
            return State.NULL;
        }

        return this._proxy.State;
    },

    setState: function(state, duration) {
        this._ensureProxy(Lang.bind(this,
            function() {
                this._proxy.SetStateRemote(state,
                                           duration || 0,
                                           Lang.bind(this, this._onCallback));
            }));
    },

    getStateDuration: function() {
        return this._proxy.StateDuration;
    },

    getElapsed: function() {
        return this._proxy.Elapsed;
    },

    getRemaining: function() {
        let state = this.getState();

        if (state == State.NULL) {
            return 0.0;
        }

        return Math.ceil(this._proxy.StateDuration - this._proxy.Elapsed);
    },

    getProgress: function() {
        return (this._connected && this._proxy.StateDuration > 0)
                ? this._proxy.Elapsed / this._proxy.StateDuration
                : 0.0;
    },

    start: function() {
        this._ensureProxy(Lang.bind(this,
            function() {
                this._proxy.StartRemote(Lang.bind(this, this._onCallback));
            }));
    },

    stop: function() {
        this._ensureProxy(Lang.bind(this,
            function() {
                this._proxy.StopRemote(Lang.bind(this, this._onCallback));
            }));
    },

    reset: function() {
        this._ensureProxy(Lang.bind(this,
            function() {
                this._proxy.ResetRemote(Lang.bind(this, this._onCallback));
            }));
    },

    toggle: function() {
        if (this.getState() == State.NULL) {
            this.start();
        }
        else {
            this.stop();
        }
    },

    isBreak: function() {
        let state = this.getState();

        return state == State.SHORT_BREAK || state == State.LONG_BREAK;
    },

    canSwitchBreak: function() {
        return (this.getElapsed() < this._shortBreakDuration) &&
               (this._shortBreakDuration < this._longBreakDuration);
    },

    switchBreak: function() {
        let state = this.getState();

        if (state == State.SHORT_BREAK) {
            this.setState(State.LONG_BREAK);
        }

        if (state == State.LONG_BREAK) {
            this.setState(State.SHORT_BREAK);
        }
    },

    showMainWindow: function(timestamp) {
        this._ensureProxy(Lang.bind(this,
            function() {
                this._proxy.ShowMainWindowRemote(timestamp, Lang.bind(this, this._onCallback));
            }));
    },

    showPreferences: function(view, timestamp) {
        this._ensureProxy(Lang.bind(this,
            function() {
                this._proxy.ShowPreferencesRemote(view, timestamp, Lang.bind(this, this._onCallback));
            }));
    },

    _notifyServiceNotInstalled: function() {
        Extension.extension.notifyIssue(_("Failed to run <i>%s</i> service").format(Config.PACKAGE_NAME));
    },

    destroy: function() {
        if (this._nameWatcherId) {
            Gio.DBus.session.unwatch_name(this._nameWatcherId);
            this._nameWatcherId = 0;
        }

        if (this._settingsChangedId) {
            Extension.extension.settings.disconnect(this._settingsChangedId);
            this._settingsChangedId = 0;
        }
    }
});
Signals.addSignalMethods(Timer.prototype);
