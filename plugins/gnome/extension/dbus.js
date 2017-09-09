/*
 * Copyright (c) 2012-2017 gnome-pomodoro contributors
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
const Signals = imports.signals;
const Gio = imports.gi.Gio;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Capabilities = Extension.imports.capabilities;


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
    <method name="SetStateDuration"> \
        <arg type="s" name="state" direction="in" /> \
        <arg type="d" name="duration" direction="in" /> \
    </method> \
    <method name="ShowMainWindow"> \
        <arg type="s" name="mode" direction="in" /> \
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

const PomodoroExtensionInterface = '<node> \
<interface name="org.gnome.Pomodoro.Extension"> \
    <property name="PluginName" type="s" access="read"/> \
    <property name="Capabilities" type="as" access="read"/> \
</interface> \
</node>';


var PomodoroProxy = Gio.DBusProxy.makeProxyWrapper(PomodoroInterface);
function Pomodoro(callback, cancellable) {
    return new PomodoroProxy(Gio.DBus.session, 'org.gnome.Pomodoro', '/org/gnome/Pomodoro', callback, cancellable);
}


var PomodoroExtension = new Lang.Class({
    Name: 'PomodoroExtensionDBus',

    _init: function() {
        this._dbusImpl = Gio.DBusExportedObject.wrapJSObject(PomodoroExtensionInterface, this);
        this._dbusImpl.export(Gio.DBus.session, '/org/gnome/Pomodoro/Extension');

        this.initialized = false;

        this._dbusId = Gio.DBus.session.own_name('org.gnome.Pomodoro.Extension',
                                                 Gio.BusNameOwnerFlags.REPLACE,
                                                 Lang.bind(this, this._onNameAcquired),
                                                 Lang.bind(this, this._onNameLost));
    },

    PluginName: "gnome",

    Capabilities: Capabilities.capabilities,

    _onNameAcquired: function(name) {
        this.initialized = true;

        this.emit('name-acquired');
    },

    _onNameLost: function(name) {
        this.initialized = false;

        this.emit('name-lost');
    },

    destroy: function() {
        this.disconnectAll();

        Gio.DBus.session.unown_name(this._dbusId);

        this._dbusImpl.unexport();

        this.emit('destroy');
    }
});
Signals.addSignalMethods(PomodoroExtension.prototype);
