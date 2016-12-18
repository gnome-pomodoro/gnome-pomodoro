/*
 * Copyright (c) 2012-2013 gnome-pomodoro contributors
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
 *
 */

const Lang = imports.lang;
const Gio = imports.gi.Gio;


const PomodoroInterface = '<node> \
<interface name="org.gnome.Pomodoro"> \
    <property name="Elapsed" type="d" access="read"/> \
    <property name="State" type="s" access="read"/> \
    <property name="StateDuration" type="d" access="read"/> \
    <property name="IsPaused" type="b" access="read"/> \
    <property name="Version" type="s" access="read"/> \
    <method name="SetState"> \
        <arg type="s" name="state" direction="in" /> \
        <arg type="d" name="timestamp" direction="in" /> \
    </method> \
    <method name="ShowMainWindow"> \
        <arg type="u" name="timestamp" direction="in" /> \
    </method> \
    <method name="ShowPreferences"> \
        <arg type="u" name="timestamp" direction="in" /> \
    </method> \
    <method name="Start"/> \
    <method name="Stop"/> \
    <method name="Reset"/> \
    <method name="Pause"/> \
    <method name="Resume"/> \
    <method name="Skip"/> \
    <method name="Quit"/> \
</interface> \
</node>';


const PomodoroProxy = Gio.DBusProxy.makeProxyWrapper(PomodoroInterface);
function Pomodoro(callback, cancellable) {
    return new PomodoroProxy(Gio.DBus.session, 'org.gnome.Pomodoro', '/org/gnome/Pomodoro', callback, cancellable);
}
