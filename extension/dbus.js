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
    <property name="Session" type="d" access="read"/> \
    <property name="SessionLimit" type="d" access="read"/> \
    <property name="State" type="s" access="read"/> \
    <property name="StateDuration" type="d" access="read"/> \
    <property name="Version" type="s" access="read"/> \
    <method name="SetState"> \
        <arg type="s" name="state" direction="in" /> \
        <arg type="d" name="duration" direction="in" /> \
    </method> \
    <method name="ShowPreferences"> \
        <arg type="s" name="view" direction="in" /> \
        <arg type="u" name="timestamp" direction="in" /> \
    </method> \
    <method name="Start"/> \
    <method name="Stop"/> \
    <method name="Reset"/> \
    <signal name="NotifyPomodoroStart"> \
        <arg type="b" name="is_requested"/> \
    </signal> \
    <signal name="NotifyPomodoroEnd"> \
        <arg type="b" name="is_completed"/> \
    </signal> \
</interface> \
</node>';

const PomodoroExtensionInterface = '<node> \
<interface name="org.gnome.Pomodoro.Extension"> \
<method name="GetCapabilities"> \
    <arg type="a{sv}" direction="out"/> \
</method> \
</interface> \
</node>';


var PomodoroProxy = Gio.DBusProxy.makeProxyWrapper(PomodoroInterface);
function Pomodoro(init_callback, cancellable) {
    return new PomodoroProxy(Gio.DBus.session, 'org.gnome.Pomodoro', '/org/gnome/Pomodoro', init_callback, cancellable);
}


const PomodoroExtension = new Lang.Class({
    Name: 'PomodoroExtensionDBus',

    _init: function() {
        this._dbusImpl = Gio.DBusExportedObject.wrapJSObject(PomodoroExtensionInterface, this);
        this._dbusImpl.export(Gio.DBus.session, '/org/gnome/Pomodoro/Extension');

        this._dbusId = Gio.DBus.session.own_name('org.gnome.Pomodoro.Extension',
                                                 Gio.BusNameOwnerFlags.ALLOW_REPLACEMENT,
                                                 null,
                                                 null);
    },

    GetCapabilities: function() {
        let capabilities = {
        };

        let out = {};
        for (let key in capabilities) {
            let val = capabilities[key];
            let type;
            switch (typeof val) {
                case 'string':
                    type = 's';
                    break;
                case 'number':
                    type = 'd';
                    break;
                case 'boolean':
                    type = 'b';
                    break;
                default:
                    continue;
            }
            out[key] = GLib.Variant.new(type, val);
        }

        return out;
    },

    destroy: function() {
        this._dbusImpl.unexport();
        Gio.DBus.session.unown_name(this._dbusId);
    }
});
