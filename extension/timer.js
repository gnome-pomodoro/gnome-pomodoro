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
const DBus = Extension.imports.dbus;
const Settings = Extension.imports.settings;


const State = {
    NULL: 'null',
    POMODORO: 'pomodoro',
    PAUSE: 'pause',
    IDLE: 'idle'
};


const Timer = new Lang.Class({
    Name: 'PomodoroTimer',

    _init: function() {
        this.proxy = null;
        this.state = State.NULL;

        this._state = null;
        this._propertiesChangedId = 0;
        this._notifyPomodoroStartId = 0;
        this._notifyPomodoroEndId = 0;

        this._nameWatcherId = Gio.DBus.session.watch_name(
                                       DBus.SERVICE_NAME,
                                       Gio.BusNameWatcherFlags.AUTO_START,
                                       Lang.bind(this, this._onNameAppeared),
                                       Lang.bind(this, this._onNameVanished));

        if (this._isRunning()) {
            this._ensureProxy();
        }
    },

    _isRunning: function() {
        let settings;
        let state;

        try {
            settings = Settings.getSettings('org.gnome.pomodoro.state');
            state = settings.get_string('state');
        }
        catch (error) {
            Extension.extension.logError(error);
        }

        return state && state != State.NULL;
    },

    _ensureProxy: function(callback) {
        if (this.proxy) {
            if (callback) {
                callback.call(this);
            }
            return;
        }

        this.proxy = DBus.Pomodoro(Lang.bind(this, function(proxy, error) {
            if (error) {
                Extension.extension.logError(error.message);
                Extension.extension.notifyIssue(_("Looks like gnome-pomodoro is not installed"));
                return;
            }

            if (proxy !== this.proxy) {
                return;
            }

            /* Keep in mind that signals won't be called right after initialization
             * when gnome-pomodoro comes back and gets restored
             */
            if (this._propertiesChangedId == 0) {
                this._propertiesChangedId = this.proxy.connect(
                                           'g-properties-changed',
                                           Lang.bind(this, this._onPropertiesChanged));
            }

            if (this._notifyPomodoroStartId == 0) {
                this._notifyPomodoroStartId = this.proxy.connectSignal(
                                           'NotifyPomodoroStart',
                                           Lang.bind(this, this._onNotifyPomodoroStart));
            }

            if (this._notifyPomodoroEndId == 0) {
                this._notifyPomodoroEndId = this.proxy.connectSignal(
                                           'NotifyPomodoroEnd',
                                           Lang.bind(this, this._onNotifyPomodoroEnd));
            }

            if (callback) {
                callback.call(this);
            }

            this.emit('service-connected');
            this.emit('state-changed');

            this._onPropertiesChanged(this.proxy, null);
        }));
    },

    _onNameAppeared: function() {
        this._ensureProxy();
    },

    _onNameVanished: function() {
        this.emit('state-changed');
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

    _onNotifyPomodoroStart: function(proxy, senderName, [isRequested]) {
        this.emit('notify-pomodoro-start', isRequested);
    },

    _onNotifyPomodoroEnd: function(proxy, senderName, [isCompleted]) {
        this.emit('notify-pomodoro-end', isCompleted);
    },

    _onCallback: function(result, error) {
        if (error) {
            Extension.extension.logError(error.message)
        }
    },

    getState: function() {
        return this.proxy ? this.proxy.State : State.NULL;
    },

    setState: function(state, duration) {
        this._ensureProxy(Lang.bind(this,
            function() {
                this.proxy.SetStateRemote(state,
                                          duration || 0,
                                          Lang.bind(this, this._onCallback));
            }));
    },

    getRemaining: function() {
        let state = this.getState();

        if (state == State.IDLE) {  /* TODO: should be done earlier */
            return Extension.extension.settings.get_double('pomodoro-duration');
        }

        if (state == State.NULL) {
            return 0.0;
        }

        return Math.ceil(this.proxy.StateDuration - this.proxy.Elapsed);
    },

    getProgress: function() {
        return (this.proxy && this.proxy.StateDuration > 0)
                ? this.proxy.Elapsed / this.proxy.StateDuration
                : 0.0;
    },

    start: function() {
        this._ensureProxy(Lang.bind(this,
            function() {
                this.proxy.StartRemote(Lang.bind(this, this._onCallback));
            }));
    },

    stop: function() {
        this._ensureProxy(Lang.bind(this,
            function() {
                this.proxy.StopRemote(Lang.bind(this, this._onCallback));
            }));
    },

    reset: function() {
        this._ensureProxy(Lang.bind(this,
            function() {
                this.proxy.ResetRemote(Lang.bind(this, this._onCallback));
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

    showMainWindow: function(timestamp) {
        this._ensureProxy(Lang.bind(this,
            function() {
                this.proxy.ShowMainWindowRemote(timestamp);
            }));
    },

    showPreferences: function(view, timestamp) {
        this._ensureProxy(Lang.bind(this,
            function() {
                this.proxy.ShowPreferencesRemote(view, timestamp);
            }));
    },

    destroy: function() {
        if (this._nameWatcherId) {
            Gio.DBus.session.unwatch_name(this._nameWatcherId);
            this._nameWatcherId = 0;
        }
    }
});
Signals.addSignalMethods(Timer.prototype);
