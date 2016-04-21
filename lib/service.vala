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

[DBus (name = "org.gnome.Pomodoro")]
public class Pomodoro.Service : GLib.Object
{
    private weak GLib.DBusConnection connection;
    private Pomodoro.Timer timer;
    private GLib.HashTable<string, GLib.Variant> changed_properties;
    private uint idle_id;
    private GLib.Cancellable cancellable;

    public double elapsed {
        get { return this.timer.elapsed; }
    }

    public string state {
        get { return this.timer.state.name; }
    }

    public double state_duration {
        get { return this.timer.state.duration; }
    }

    public bool is_paused {
        get { return this.timer.is_paused; }
    }

    public string version {
        get { return Config.PACKAGE_VERSION; }
    }

    public Service (GLib.DBusConnection connection,
                    Pomodoro.Timer      timer)
    {
        this.connection = connection;
        this.timer = timer;
        this.changed_properties = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
        this.idle_id = 0;

        this.cancellable = new GLib.Cancellable ();

        this.timer.notify.connect (this.on_timer_property_notify);
    }

    public void set_state (string name,
                           double timestamp)
    {
        var state = TimerState.lookup (name);

        if (timestamp > 0.0) {
            state.timestamp = timestamp;
        }

        if (state != null) {
            this.timer.state = state;
        }

        this.timer.update ();  // TODO: perhaps timer should have "changed" signal
    }

    public void show_preferences (string page,
                                  uint32 timestamp)
    {
        var application = GLib.Application.get_default () as Pomodoro.Application;
        application.show_preferences_full (page, timestamp);
    }

    public void start ()
    {
        this.timer.start ();
    }

    public void stop ()
    {
        this.timer.stop ();
    }

    public void reset ()
    {
        this.timer.reset ();
    }

    public void pause ()
    {
        this.timer.pause ();
    }

    public void resume ()
    {
        this.timer.resume ();
    }

    public void skip ()
    {
        this.timer.skip ();
    }

    private void flush ()
    {
        var builder_properties = new GLib.VariantBuilder (GLib.VariantType.ARRAY);
        var builder_invalid = new GLib.VariantBuilder (GLib.VariantType.STRING_ARRAY);

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
                                         new GLib.Variant ("(sa{sv}as)",
                                                           "org.gnome.Pomodoro",
                                                           builder_properties,
                                                           builder_invalid)
                                         );
            this.connection.flush_sync (this.cancellable);
        }
        catch (GLib.Error error) {
            GLib.warning ("%s", error.message);
        }

        if (this.idle_id != 0) {
            GLib.Source.remove (this.idle_id);
            this.idle_id = 0;
        }
    }

    private void send_property_changed (string       property_name,
                                        GLib.Variant new_value)
    {
        this.changed_properties.replace (property_name, new_value);

        if (this.idle_id == 0) {
            this.idle_id = Idle.add (() => {
                this.flush ();

                return false;
            });
        }
    }

    private void on_timer_property_notify (GLib.ParamSpec param_spec)
    {
        switch (param_spec.name)
        {
            case "elapsed":
                this.send_property_changed ("Elapsed",
                                            new Variant.double (this.elapsed));
                break;

            case "state":
                this.send_property_changed ("State",
                                            new Variant.string (this.state));
                this.send_property_changed ("StateDuration",
                                            new Variant.double (this.state_duration));
                break;

            case "state-duration":
                this.send_property_changed ("StateDuration",
                                            new Variant.double (this.state_duration));
                break;

            case "is-paused":
                this.send_property_changed ("IsPaused",
                                            new Variant.boolean (this.is_paused));
                break;
        }
    }

    public virtual signal void destroy ()
    {
        this.dispose ();
    }
}
