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

    private Gtk.Window preferences_dialog;
    private Gtk.Window about_dialog;

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
        GLib.Object (application_id: "org.gnome.Pomodoro",
                     flags: GLib.ApplicationFlags.HANDLES_COMMAND_LINE);

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

    private unowned Gtk.Window get_last_focused_window ()
    {
        unowned List<weak Gtk.Window> windows = this.get_windows();
        return windows.first().data;
    }

    private void action_preferences (SimpleAction action, Variant? parameter)
    {
        if (this.preferences_dialog == null) {
            this.preferences_dialog = new Pomodoro.PreferencesDialog();
            this.preferences_dialog.destroy.connect (() => {
                this.remove_window (this.preferences_dialog);
                this.preferences_dialog = null;
            });
            this.add_window (this.preferences_dialog);
        }

        if (this.preferences_dialog != null) {
            this.preferences_dialog.present ();

            /* FIXME
             * It looks like there is a bug gtk/gnome-shell/mutter when calling
             * window.present() - after user activates menu item in gnome-shell
             * window should be brought to front.
             *
             * The present() method presents a window to the user. This may mean
             * raising the window in the stacking order, deiconifying it, moving
             * it to the current desktop, and/or giving it the keyboard focus,
             * possibly dependent on the user's platform, window manager, and
             * preferences. If the window is hidden, this method calls the the
             * gtk.Widget.show() method as well. This method should be used when
             * the user tries to open a window that's already open. Say for
             * example the preferences dialog is currently open, and the user
             * chooses Preferences from the menu a second time; use the
             * present() method to move the already-open dialog where the user
             * can see it.
             */
        }
    }

    private void action_about (SimpleAction action, Variant? parameter)
    {
        if (this.about_dialog == null)
        {
            var window = this.get_last_focused_window();

            this.about_dialog = new Pomodoro.AboutDialog();
            this.about_dialog.destroy.connect (() => {
                this.remove_window (this.about_dialog);
                this.about_dialog = null;
            });

            if (window != null)
                this.about_dialog.set_transient_for (window);

            this.add_window (this.about_dialog);
        }

        this.about_dialog.present();
    }

    private void action_quit (SimpleAction action, Variant? parameter)
    {
        // For now application gui and the service uses same process
        // so if service is running we don't want to close both
        if (this.timer.state != State.NULL) {
            foreach (var window in this.get_windows()) {
                window.destroy();
            }
        }
        else {
            this.quit ();
        }
    }

    private void setup_actions ()
    {
        var preferences_action = new GLib.SimpleAction ("preferences", VariantType.STRING);
        preferences_action.activate.connect (this.action_preferences);

        var about_action = new GLib.SimpleAction("about", null);
        about_action.activate.connect (this.action_about);

        var quit_action = new GLib.SimpleAction("quit", null);
        quit_action.activate.connect (this.action_quit);

        this.add_accelerator ("<Primary>q", "app.quit", null);

        this.add_action (preferences_action);
        this.add_action(about_action);
        this.add_action (quit_action);
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
            GLib.error ("Failed to load app-menu.ui from the resource file.");
        }

        menu = builder.get_object("app-menu") as GLib.MenuModel;
        this.set_app_menu (menu);
    }

    private List<Object> modules;

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

        this.modules = new List<Object>();
        this.modules.prepend (new Pomodoro.Sounds (this.timer));

        this.timer.restore();

        this.setup_menu ();
    }

    private int do_command_line (ApplicationCommandLine command_line)
    {
        var arguments = new CommandLine();

        if (arguments.parse (command_line.get_arguments ()))
        {
            if (arguments.preferences)
                this.activate_action ("preferences", "");

            if (arguments.no_default_window)
                this.hold (HoldReason.SERVICE);

            if (!arguments.preferences && !arguments.no_default_window)
                this.activate();

            return 0;
        }

        return 1;
    }

    public override int command_line (ApplicationCommandLine command_line)
    {
        int status = 0;

        this.hold();
        status = this.do_command_line (command_line);
        this.release();

        return status;
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

