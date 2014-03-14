/*
 * Copyright (c) 2012-2013 gnome-pomodoro contributors
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
    private GLib.Cancellable cancellable;

    public double elapsed {
        get { return this.timer.elapsed; }
    }

    public double state_duration {
        get { return this.timer.state_duration; }
    }

    public double session {
        get { return this.timer.session; }
    }

    public double session_limit {
        get { return this.timer.session_limit; }
    }

    public string state {
        owned get { return state_to_string (this.timer.state); }
    }

    public Service (DBusConnection connection, Pomodoro.Timer timer)
    {
        this.connection = connection;
        this.timer = timer;
        this.changed_properties = new HashTable<string, Variant> (str_hash, str_equal);
        this.idle_id = 0;

        this.cancellable = new GLib.Cancellable ();

        this.timer.notify.connect (this.on_property_notify);

        this.timer.notify_pomodoro_start.connect ((timer, is_requested) => {
            this.notify_pomodoro_start (is_requested);
        });

        this.timer.notify_pomodoro_end.connect ((timer, is_completed) => {
            this.notify_pomodoro_end (is_completed);
        });
    }

    public void start ()
    {
        this.timer.start ();
    }

    public void set_state (string state,
                           double state_duration)
    {
        this.timer.set_state_full (string_to_state (state),
                                   state_duration);
    }

    public void stop ()
    {
        this.timer.stop ();
    }

    public void reset ()
    {
        this.timer.reset ();
    }

    private void flush ()
    {
        var builder_properties = new VariantBuilder (VariantType.ARRAY);
        var builder_invalid = new VariantBuilder (VariantType.STRING_ARRAY);

        /* FIXME: Compile warnings from C compiler */
        this.changed_properties.foreach ((key, value) => {
            builder_properties.add ("{sv}", key, value);
        });
        this.changed_properties.remove_all ();

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
            this.connection.flush_sync (this.cancellable);
        }
        catch (Error e) {
            GLib.warning ("%s", e.message);
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
                this.flush ();

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
                                            new Variant.double (this.elapsed));
                break;

            case "session":
                this.send_property_changed ("Session",
                                            new Variant.double (this.session));
                break;

            case "session-limit":
                this.send_property_changed ("SessionLimit",
                                            new Variant.double (this.session_limit));
                break;

            case "state":
                this.send_property_changed ("State",
                                            new Variant.string (this.state));
                break;

            case "state-duration":
                this.send_property_changed ("StateDuration",
                                            new Variant.double (this.state_duration));
                break;
        }
    }

    public signal void notify_pomodoro_end (bool is_requested);
    public signal void notify_pomodoro_start (bool is_completed);
}
