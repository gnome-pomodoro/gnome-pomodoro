/*
 * Copyright (c) 2013 gnome-shell-pomodoro contributors
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

namespace Pomodoro
{
    [Flags]
    public enum HoldReason {
        NONE = 0,
        SERVICE,
        TIMER
    }
}

public class Pomodoro.Application : Gtk.Application
{
    public GLib.Settings settings;
    public Pomodoro.Service service;
    public Pomodoro.Timer timer;
    public Gtk.Window window;

    private int hold_reasons;

    // The flags can only be modified if application has not yet been registered
    public bool is_service {
        get {
            return (this.flags & ApplicationFlags.IS_SERVICE) != 0;
        }
        set {
            if (this.is_registered) {
                warning("Could not change service state, app already registered.");
                return;
            }

            if (value) {
                this.set_flags (this.flags | ApplicationFlags.IS_SERVICE);
                this.hold (HoldReason.SERVICE);
            }
            else {
                this.set_flags (this.flags & (~ApplicationFlags.IS_SERVICE));
                this.release (HoldReason.SERVICE);
            }
        }
    }

    public Application ()
    {
        GLib.Object (application_id: "org.gnome.Pomodoro");

        /* register with session manager */
        this.register_session = true;

        this.inactivity_timeout = 10000;

        this.settings = new GLib.Settings ("org.gnome.pomodoro");
        this.timer = null;
        this.service = null;
        this.window = null;
        this.hold_reasons = HoldReason.NONE;

        this.setup_actions();
    }

    public new void hold (HoldReason reason = 0)
    {
        if (reason == 0)
            base.hold();
        else
            if ((this.hold_reasons & reason) == 0) {
                this.hold_reasons |= reason;
                base.hold();
            }
    }

    public new void release (HoldReason reason = 0)
    {
        if (reason == 0)
            base.release();
        else
            if ((this.hold_reasons & reason) != 0) {
                this.hold_reasons &= ~reason;
                base.release();
            }
    }

    private void action_preferences (Action action)
    {
    }

    private void action_about (Action action)
    {
    }

    private void action_quit (Action action)
    {
        if (this.timer != null) {
            this.timer.destroy();
            this.timer = null;
        }
    }

    private void setup_actions ()
    {
    }

    private void setup_menu ()
    {
        Gtk.Builder builder;
        GLib.MenuModel menu;

        builder = new Gtk.Builder();
        try {
            builder.add_from_resource ("/org/gnome/pomodoro/app-menu.ui");
        }
        catch (GLib.Error error) {
            GLib.error("Failed to load app-menu.ui from the resource file");
        }

        menu = builder.get_object("app-menu") as GLib.MenuModel;
        this.set_app_menu (menu);
    }

    // Emitted on the primary instance immediately after registration.
    public override void startup ()
    {
        base.startup();

        this.timer.destroy.connect ((timer) => {
            this.release (HoldReason.TIMER);
            this.timer = null;
        });

        this.timer.state_changed.connect ((timer) => {
            var is_running = timer.state != State.NULL;
            if (is_running)
                this.hold (HoldReason.TIMER);
            else
                this.release (HoldReason.TIMER);
        });

        this.timer.restore();

        this.setup_menu ();
    }

    // Save the state before exit.
    // Emitted only on the registered primary instance instance immediately
    // after the main loop terminates.
    public override void shutdown ()
    {
        base.shutdown();
    }

    // Emitted on the primary instance when an activation occurs.
    // The application must be registered before calling this function.
    public override void activate ()
    {
    }

    public override bool dbus_register (DBusConnection connection,
                                        string         object_path) throws GLib.Error
    {
        if (!base.dbus_register (connection, object_path)) {
            return false;
        }

        if (this.timer == null) {
            this.timer = new Pomodoro.Timer();
        }

        if (this.service == null) {
            this.service = new Pomodoro.Service (connection, this.timer);

            try {
                connection.register_object ("/org/gnome/Pomodoro", this.service);
            }
            catch (IOError e) {
                GLib.warning ("%s", e.message);
                return false;
            }
        }

        return true;
    }

    public override void dbus_unregister (DBusConnection connection,
                                          string         object_path)
    {
        base.dbus_unregister (connection, object_path);

        if (this.service != null) {
            this.service.dispose();
            this.service = null;
        }

        if (this.timer != null) {
            this.timer.destroy();
            this.timer = null;
        }
    }
}

