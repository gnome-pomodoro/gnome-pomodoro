// A simple pomodoro timer for Gnome-shell
// Copyright (C) 2011,2012 Gnome-shell pomodoro extension contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

const DBus = imports.dbus;
const Lang = imports.lang;

const PomodoroTimerIface = {
    name: 'org.gnome.Shell.Extensions.Pomodoro',
    methods: [{ name: 'Start',
                inSignature: '',
                outSignature: ''
              },
              { name: 'Stop',
                inSignature: '',
                outSignature: ''
              },
              { name: 'Reset',
                inSignature: '',
                outSignature: ''
              },
              { name: 'GetElapsed',
                inSignature: '',
                outSignature: 'i'
              },
              { name: 'GetRemaining',
                inSignature: '',
                outSignature: 'i'
              },
              { name: 'GetSessionCount',
                inSignature: '',
                outSignature: 'i'
              },
              { name: 'GetState',
                inSignature: '',
                outSignature: 'i'
              },
              { name: 'SetState',
                inSignature: 'i',
                outSignature: ''
              }
             ],
    signals: [
              { name: 'StateChanged',
                inSignature: 'i' },
              { name: 'NotifyPomodoroStart',
                inSignature: '' },
              { name: 'NotifyPomodoroEnd',
                inSignature: '' }],
    properties: []
};

function PomodoroTimer(timer) {
    this._init(timer);
}

PomodoroTimer.prototype = {
    _init: function(timer) {
        DBus.session.exportObject('/org/gnome/Shell/Extensions/Pomodoro',
                                  this);
        
        this._timer = timer;
        this._timer.connect('state-changed',
                            Lang.bind(this, this._onTimerStateChanged));
        
        this._timer.connect('notify-pomodoro-start',
                            Lang.bind(this, this._onTimerNotifyPomodoroStart));
        
        this._timer.connect('notify-pomodoro-end',
                            Lang.bind(this, this._onTimerNotifyPomodoroEnd));
    },

    Start: function() {
        if (this._timer)
        this._timer.start();
    },

    Stop: function() {
        if (this._timer)
        this._timer.stop();
    },

    Reset: function() {
        if (this._timer)
        this._timer.reset();
    },

    GetElapsed: function() {
        if (this._timer)
        return this._timer.elapsed;
    },

    GetRemaining: function() {
        if (this._timer)
        return this._timer.remaining;
    },

    GetSessionCount: function() {
        if (this._timer)
        return this._timer.sessionCount;
    },

    GetState: function() {
        if (this._timer)
        return this._timer.state;
    },

    SetState: function(state) {
        if (this._timer)
        this._timer.setState(state);
    },

    _onTimerStateChanged: function(object, state) {
        DBus.session.emit_signal('/org/gnome/Shell/Extensions/Pomodoro',
                                 'org.gnome.Shell.Extensions.Pomodoro',
                                 'StateChanged', 'i',
                                 [state]);
    },

    _onTimerNotifyPomodoroStart: function(object) {
        DBus.session.emit_signal('/org/gnome/Shell/Extensions/Pomodoro',
                                 'org.gnome.Shell.Extensions.Pomodoro',
                                 'NotifyPomodoroStart', '', []);
    },

    _onTimerNotifyPomodoroEnd: function(object) {
        DBus.session.emit_signal('/org/gnome/Shell/Extensions/Pomodoro',
                                 'org.gnome.Shell.Extensions.Pomodoro',
                                 'NotifyPomodoroEnd', '', []);
    },

    destroy: function() {
        DBus.session.unexportObject(this);
    }
};

DBus.conformExport(PomodoroTimer.prototype, PomodoroTimerIface);

