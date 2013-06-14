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

using GLib;

[DBus (name = "org.gnome.Pomodoro")]
public class Pomodoro.Service : Object
{
    private weak DBusConnection connection;
    private Pomodoro.Timer timer;
    private HashTable<string, Variant> changed_properties;
    private uint idle_id;

    public uint elapsed {
        get { return this.timer.elapsed; }
    }

    public uint elapsed_limit {
        get { return this.timer.elapsed_limit; }
    }

    public uint session {
        get { return this.timer.session; }
    }

    public uint session_limit {
        get { return this.timer.session_limit; }
    }

    public string state {
        owned get { return state_to_string (this.timer.state); }
    }

    public Service (DBusConnection connection, Pomodoro.Timer timer)
    {
        this.connection = connection;
        this.timer = timer;
        this.changed_properties = new HashTable<string, Variant>(str_hash, str_equal);
        this.idle_id = 0;

        this.timer.notify.connect (this.on_property_notify);

        this.timer.elapsed_changed.connect ((timer) => {
            this.elapsed_changed (this.elapsed);
        });

        this.timer.state_changed.connect ((timer) => {
            this.state_changed (this.state);
        });

        this.timer.notify_pomodoro_start.connect ((timer, is_requested) => {
            this.notify_pomodoro_start (is_requested);
        });

        this.timer.notify_pomodoro_end.connect ((timer, is_completed) => {
            this.notify_pomodoro_end (is_completed);
        });
    }

    public void start() {
        if (this.timer != null)
            this.timer.start();
    }

    public void stop() {
        if (this.timer != null)
            this.timer.stop();
    }

    public void reset() {
        if (this.timer != null)
            this.timer.reset();
    }

    private void flush ()
    {
        var builder_properties = new VariantBuilder (VariantType.ARRAY);
        var builder_invalid = new VariantBuilder (VariantType.STRING_ARRAY);

        this.changed_properties.foreach ((key, value) => {
            builder_properties.add ("{sv}", key, value);
        });

        this.changed_properties.remove_all();

        try {
            this.connection.emit_signal (null,
                                         "/org/gnome/Pomodoro",
                                         "org.freedesktop.DBus.Properties",
                                         "PropertiesChanged",
                                         new Variant ("(sa{sv}as)",
                                                      "org.gnome.Pomodoro",
                                                      builder_properties,
                                                      builder_invalid)
                                         );
            this.connection.flush();
        }
        catch (Error e) {
            GLib.warning ("%s\n", e.message);
        }

        if (this.idle_id != 0) {
            Source.remove (this.idle_id);
            this.idle_id = 0;
        }
    }

    private void send_property_changed (string property_name, Variant new_value)
    {
        this.changed_properties.replace (property_name, new_value);

        if (this.idle_id == 0) {
            this.idle_id = Idle.add (() => {
                this.flush();
                return false;
            });
        }
    }

    private void on_property_notify (ParamSpec param_spec)
    {
        switch (param_spec.name)
        {
            case "elapsed":
                this.send_property_changed ("Elapsed",
                                            new Variant.uint32 (this.elapsed));
                break;

            case "elapsed-limit":
                this.send_property_changed ("ElapsedLimit",
                                            new Variant.uint32 (this.elapsed_limit));
                break;

            case "session":
                this.send_property_changed ("Session",
                                            new Variant.uint32 (this.session));
                break;

            case "session-limit":
                this.send_property_changed ("SessionLimit",
                                            new Variant.uint32 (this.session_limit));
                break;

            case "state":
                this.send_property_changed ("State",
                                            new Variant.string (this.state));
                break;
        }
    }

    public signal void elapsed_changed (uint elapsed);
    public signal void state_changed (string state);
    public signal void notify_pomodoro_end (bool is_requested);
    public signal void notify_pomodoro_start (bool is_completed);
}

