/*
 * Copyright (c) 2012-2013 gnome-shell-pomodoro contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */

const Gio = imports.gi.Gio;
const GLib = imports.gi.GLib;
const Lang = imports.lang;

const Timer = imports.timer;

const PomodoroInterface = <interface name="org.gnome.Pomodoro">
    <property name="Elapsed" type="i" access="read"/>
    <property name="ElapsedLimit" type="i" access="read"/>
    <property name="SessionCount" type="i" access="read"/>
    <property name="State" type="s" access="readwrite"/>
    <method name="Start"/>
    <method name="Stop"/>
    <method name="Reset"/>
    <signal name="ElapsedChanged">
        <arg type="i" name="elapsed"/>
    </signal>
    <signal name="StateChanged">
        <arg type="s" name="state"/>
    </signal>
    <signal name="NotifyPomodoroStart">
        <arg type="b" name="requested"/>
    </signal>
    <signal name="NotifyPomodoroEnd">
        <arg type="b" name="completed"/>
    </signal>
</interface>;


const Pomodoro = new Lang.Class({
    Name: 'PomodoroDBus',

    _init: function(timer) {
        this.dbus = Gio.DBusExportedObject.wrapJSObject(PomodoroInterface, this);
        this.dbus.export(Gio.DBus.session, '/org/gnome/Pomodoro');

        this.set_timer(timer);
    },

    set_timer: function(timer) {
        this.timer = timer;
        if (!timer)
            return;

        this.timer.connect('elapsed-changed', Lang.bind(this, function(timer)
        {
            this.dbus.emit_property_changed('Elapsed',
                            GLib.Variant.new('i', timer.elapsed));

            this.dbus.emit_property_changed('ElapsedLimit',
                            GLib.Variant.new('i', timer.elapsed_limit));

            this.dbus.emit_signal('ElapsedChanged',
                            GLib.Variant.new('(i)', [timer.elapsed]));

            this.dbus.flush();
        }));

        this.timer.connect('state-changed', Lang.bind(this, function(timer)
        {
            this.dbus.emit_property_changed('Elapsed',
                            GLib.Variant.new('i', timer.elapsed));

            this.dbus.emit_property_changed('ElapsedLimit',
                            GLib.Variant.new('i', timer.elapsed_limit));

            this.dbus.emit_property_changed('State',
                            GLib.Variant.new('s', timer.state));

            this.dbus.emit_signal('StateChanged',
                            GLib.Variant.new('(s)', [timer.state]));

            this.dbus.flush();
        }));

        this.timer.connect('notify-pomodoro-start', Lang.bind(this, function(timer, requested) {
            this.dbus.emit_signal('NotifyPomodoroStart', GLib.Variant.new('(b)', [requested]));
        }));

        this.timer.connect('notify-pomodoro-end', Lang.bind(this, function(timer, completed) {
            this.dbus.emit_signal('NotifyPomodoroEnd', GLib.Variant.new('(b)', [completed]));
        }));
    },

    Start: function() {
        try {
            if (this.timer)
                this.timer.start();
        }
        catch (error) {
            log(error.fileName + ':' + error.lineNumber + ' ' + error.name + ': ' + error.message);
        }
    },

    Stop: function() {
        try {
            if (this.timer)
                this.timer.stop();
        }
        catch (error) {
            log(error.fileName + ':' + error.lineNumber + ' ' + error.name + ': ' + error.message);
        }
    },

    Reset: function() {
        try {
            if (this.timer)
                this.timer.reset();
        }
        catch (error) {
            log(error.fileName + ':' + error.lineNumber + ' ' + error.name + ': ' + error.message);
        }
    },

    get Elapsed() {
        return this.timer ? this.timer.elapsed : 0;
    },

    get ElapsedLimit() {
        return this.timer ? this.timer.elapsed_limit : 0;
    },

    get SessionCount() {
        return this.timer ? this.timer.session_count : 0;
    },

    get State() {
        return this.timer ? this.timer.state : Timer.State.NULL;
    },

    set State(value) {
        try {
            if (this.timer)
                this.timer.set_state(value);
        }
        catch (error) {
            log(error.fileName + ':' + error.lineNumber + ' ' + error.name + ': ' + error.message);
        }
    },

    destroy: function() {
        this.dbus.unexport();
    }
});
