/*
 * Copyright (c) 2014-2016 gnome-pomodoro contributors
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
const Utils = Extension.imports.utils;


var State = {
    NULL: 'null',
    POMODORO: 'pomodoro',
    SHORT_BREAK: 'short-break',
    LONG_BREAK: 'long-break',

    label(state) {
        switch (state) {
            case State.POMODORO:
                return _("Pomodoro");

            case State.SHORT_BREAK:
                return _("Short Break");

            case State.LONG_BREAK:
                return _("Long Break");

            default:
                return null;
        }
    }
};


var Timer = new Lang.Class({
    Name: 'PomodoroTimer',

    _init() {
        this._connected = false;
        this._state = null;
        this._isPaused = null;
        this._stateDuration = 0;
        this._propertiesChangedId = 0;
        this._elapsed = 0.0;

        this._proxy = DBus.Pomodoro(this._onInit.bind(this));

        this._propertiesChangedId = this._proxy.connect(
                                       'g-properties-changed',
                                       this._onPropertiesChanged.bind(this));

        this._nameWatcherId = Gio.DBus.session.watch_name(
                                       'org.gnome.Pomodoro',
                                       Gio.BusNameWatcherFlags.AUTO_START,
                                       this._onNameAppeared.bind(this),
                                       this._onNameVanished.bind(this));
    },

    _onNameAppeared() {
        this._connected = true;

        this.emit('service-connected');
        this.emit('update');
    },

    _onNameVanished() {
        this._connected = false;

        this.emit('update');
        this.emit('service-disconnected');
    },

    _onPropertiesChanged(proxy, properties) {
        let state = proxy.State;
        let stateDuration = proxy.StateDuration;
        let elapsed = proxy.Elapsed;
        let isPaused = proxy.IsPaused;

        if (this._state != state || this._stateDuration != stateDuration || this._elapsed > elapsed) {
            this._state = state;
            this._stateDuration = stateDuration;
            this._elapsed = elapsed

            this.emit('state-changed');
        }
        else {
            this._elapsed = elapsed;
        }

        if (this._isPaused !== isPaused) {
            this._isPaused = isPaused;
            this.emit(isPaused ? 'paused' : 'resumed');
        }

        this.emit('update');
    },

    _onInit(proxy, error) {
        if (error) {
            Utils.logWarning(error.message);
            this._notifyServiceNotInstalled();
        }
    },

    _onCallback(result, error) {
        if (error) {
            Utils.logWarning(error.message);

            if (error.matches(Gio.DBusError, Gio.DBusError.SERVICE_UNKNOWN)) {
                this._notifyServiceNotInstalled();
            }
        }
    },

    getState() {
        if (!this._connected || this._proxy.State === null) {
            return State.NULL;
        }

        return this._proxy.State;
    },

    setState(state, timestamp) {
        this._proxy.SetStateRemote(state,
                                   timestamp || 0,
                                   this._onCallback.bind(this));
    },

    getStateDuration() {
        return this._proxy.StateDuration;
    },

    setStateDuration(duration) {
        this._proxy.SetStateDurationRemote(this._proxy.State,
                                           duration,
                                           this._onCallback.bind(this));
    },

    get stateDuration() {
        return this._proxy.StateDuration;
    },

    set stateDuration(value) {
        this._proxy.SetStateDurationRemote(this._proxy.State,
                                           value,
                                           this._onCallback.bind(this));
    },

    getElapsed() {
        return this._proxy.Elapsed;
    },

    getRemaining() {
        let state = this.getState();

        if (state === State.NULL) {
            return 0.0;
        }

        return Math.ceil(this._proxy.StateDuration - this._proxy.Elapsed);
    },

    getProgress() {
        return (this._connected && this._proxy.StateDuration > 0)
                ? this._proxy.Elapsed / this._proxy.StateDuration
                : 0.0;
    },

    isPaused() {
        return this._connected && this._proxy.IsPaused;
    },

    start() {
        this._proxy.StartRemote(this._onCallback.bind(this));
    },

    stop() {
        this._proxy.StopRemote(this._onCallback.bind(this));
    },

    pause() {
        this._proxy.PauseRemote(this._onCallback.bind(this));
    },

    resume() {
        this._proxy.ResumeRemote(this._onCallback.bind(this));
    },

    skip() {
        this._proxy.SkipRemote(this._onCallback.bind(this));
    },

    reset() {
        this._proxy.ResetRemote(this._onCallback.bind(this));
    },

    toggle() {
        if (this.getState() === State.NULL) {
            this.start();
        }
        else {
            this.stop();
        }
    },

    isBreak() {
        let state = this.getState();

        return state === State.SHORT_BREAK || state === State.LONG_BREAK;
    },

    showMainWindow(timestamp) {
        this._proxy.ShowMainWindowRemote(timestamp, this._onCallback.bind(this));
    },

    showPreferences(timestamp) {
        this._proxy.ShowPreferencesRemote(timestamp, this._onCallback.bind(this));
    },

    quit() {
        this._proxy.QuitRemote((result, error) => {
            Utils.disableExtension(Config.EXTENSION_UUID);
        });
    },

    _notifyServiceNotInstalled() {
        Extension.extension.notifyIssue(_("Failed to run <i>%s</i> service").format(Config.PACKAGE_NAME));
    },

    destroy() {
        if (this._propertiesChangedId != 0) {
            this._proxy.disconnect(this._propertiesChangedId);
            this._propertiesChangedId = 0;
        }

        if (this._nameWatcherId) {
            Gio.DBus.session.unwatch_name(this._nameWatcherId);
            this._nameWatcherId = 0;
        }
    }
});
Signals.addSignalMethods(Timer.prototype);
