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

const Gio = imports.gi.Gio;
const GLib = imports.gi.GLib;
const Lang = imports.lang;
const Signals = imports.signals;


const PomodoroTimerIface = <interface name="org.gnome.Shell.Extensions.Pomodoro">
<method name="Start"/>
<method name="Stop"/>
<method name="Reset"/>
<method name="GetElapsed">
    <arg type="i" direction="out" name="seconds"/>
</method>
<method name="GetRemaining">
    <arg type="i" direction="out" name="seconds"/>
</method>
<method name="GetSessionCount">
    <arg type="i" direction="out" name="count"/>
</method>
<method name="GetState">
    <arg type="i" direction="out" name="state"/>
</method>
<method name="SetState">
    <arg type="i" direction="in" name="state"/>
</method>
<signal name="StateChanged">
    <arg type="i" name="state"/>
</signal>
<signal name="NotifyPomodoroStart"/>
<signal name="NotifyPomodoroEnd"/>
</interface>;


const PomodoroTimer = new Lang.Class({
    Name: 'PomodoroTimerDBus',

    _init: function(timer) {
        this._dbus = Gio.DBusExportedObject.wrapJSObject(PomodoroTimerIface, this);
        this._dbus.export(Gio.DBus.session, '/org/gnome/Shell/Extensions/Pomodoro');

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
        return this._timer ? this._timer.elapsed : 0;
    },

    GetRemaining: function() {
        return this._timer ? this._timer.remaining : 0;
    },

    GetSessionCount: function() {
        return this._timer ? this._timer.sessionCount : 0;
    },

    GetState: function() {
        return this._timer ? this._timer.state : -1;
    },

    SetState: function(state) {
        if (this._timer)
            this._timer.setState(state);
    },

    _onTimerStateChanged: function(object, state) {
        this._dbus.emit_signal('StateChanged',
                               GLib.Variant.new('(i)', [state]));
    },

    _onTimerNotifyPomodoroStart: function(object) {
        this._dbus.emit_signal('NotifyPomodoroStart', null);
    },

    _onTimerNotifyPomodoroEnd: function(object) {
        this._dbus.emit_signal('NotifyPomodoroEnd', null);
    },

    destroy: function() {
        this._dbus.unexport();
    }
});
