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

const POMODORO_SERVICE_NAME = 'org.gnome.Pomodoro';

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

var PomodoroProxy = Gio.DBusProxy.makeProxyWrapper(PomodoroInterface);

function Pomodoro(init_callback, cancellable) {
    return new PomodoroProxy(Gio.DBus.session, 'org.gnome.Pomodoro', '/org/gnome/Pomodoro', init_callback, cancellable);
}


const GtkActionsInterface = <interface name="org.gtk.Actions">
    <method name="Activate">
        <arg type="s" name="action_name" direction="in"/>
        <arg type="av" name="parameter" direction="in"/>
        <arg type="a{sv}" name="platform_data" direction="in"/>
    </method>
</interface>;

var GtkActionsProxy = Gio.DBusProxy.makeProxyWrapper(GtkActionsInterface);

function GtkActions(init_callback, cancellable) {
    return new GtkActionsProxy(Gio.DBus.session, 'org.gnome.Pomodoro', '/org/gnome/Pomodoro', init_callback, cancellable);
}
