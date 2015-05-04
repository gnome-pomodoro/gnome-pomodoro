/*
 * Copyright (c) 2013 gnome-pomodoro contributors
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

using GLib;


[Flags]
public enum Pomodoro.HoldReason {
    NONE = 0,
    SERVICE,
    TIMER
}


public enum Pomodoro.ExitStatus {
    SUCCESS = 0,
    FAILURE = 1
}


namespace Pomodoro.Resources {
    public const string NONE = null;
    public const string BOOKMARK = "bookmark-symbolic";
    public const string BOOKMARK_ADD = "bookmark-add-symbolic";
}


public class Pomodoro.Application : Gtk.Application
{
    public Pomodoro.Service service;
    public Pomodoro.Timer timer;

    private Gtk.Window preferences_dialog;
    private Gtk.Window about_dialog;

    private List<Pomodoro.Module> modules;
    private Pomodoro.GnomeDesktopModule desktop_module;
    private int hold_reasons;

    public Application ()
    {
        GLib.Object (
            application_id: "org.gnome.Pomodoro",
            flags: GLib.ApplicationFlags.HANDLES_COMMAND_LINE
        );

        this.inactivity_timeout = 300000;
        this.register_session = false;

        this.timer = null;
        this.service = null;
        this.hold_reasons = HoldReason.NONE;
    }

    public new void hold (HoldReason reason = 0)
    {
        if (reason == 0) {
            base.hold ();
        }
        else if ((this.hold_reasons & reason) == 0) {
            this.hold_reasons |= reason;
            base.hold ();
        }
    }

    public new void release (HoldReason reason = 0)
    {
        if (reason == 0) {
            base.release ();
        }
        else if ((this.hold_reasons & reason) != 0) {
            this.hold_reasons &= ~reason;
            base.release ();
        }
    }

    public unowned Gtk.Window get_last_focused_window ()
    {
        unowned List<weak Gtk.Window> windows = this.get_windows ();

        return windows != null
                ? windows.first ().data
                : null;
    }

    private void setup_resources ()
    {
        var css_provider = new Gtk.CssProvider ();
        try {
           var css_file = File.new_for_uri ("resource:///org/gnome/pomodoro/gtk-style.css");

           css_provider.load_from_file (css_file);
        }
        catch (Error e) {
            GLib.warning (e.message);
        }

        Gtk.StyleContext.add_provider_for_screen (
                                     Gdk.Screen.get_default (),
                                     css_provider,
                                     Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }

    public void show_preferences_full (string? view,
                                       uint32  timestamp)
    {
        if (this.preferences_dialog == null) {
            this.preferences_dialog = new Pomodoro.PreferencesDialog ();
            this.preferences_dialog.destroy.connect (() => {
                this.remove_window (this.preferences_dialog);
                this.preferences_dialog = null;
            });
            this.add_window (this.preferences_dialog);
        }

        if (this.preferences_dialog != null) {
            if (timestamp > 0) {
                this.preferences_dialog.present_with_time (timestamp);
            }
            else {
                this.preferences_dialog.present ();
            }
        }
    }

    public void show_preferences ()
    {
        this.show_preferences_full (null, 0);
    }

    private void action_preferences (SimpleAction action,
                                     Variant?     parameter)
    {
        this.show_preferences ();
    }

    private void action_visit_website (SimpleAction action,
                                       Variant?     parameter)
    {
        try {
            string[] spawn_args = { "xdg-open", Config.PACKAGE_URL };
            string[] spawn_env = Environ.get ();

            Process.spawn_async (null,
                                 spawn_args,
                                 spawn_env,
                                 SpawnFlags.SEARCH_PATH,
                                 null,
                                 null);
        }
        catch (GLib.SpawnError error) {
            GLib.warning ("Failed to spawn proccess: %s", error.message);
        }
    }

    private void action_report_issue (SimpleAction action,
                                      Variant?     parameter)
    {
        try {
            string[] spawn_args = { "xdg-open", Config.PACKAGE_BUGREPORT };
            string[] spawn_env = Environ.get ();

            Process.spawn_async (null,
                                 spawn_args,
                                 spawn_env,
                                 SpawnFlags.SEARCH_PATH,
                                 null,
                                 null);
        }
        catch (GLib.SpawnError error) {
            GLib.warning ("Failed to spawn proccess: %s", error.message);
        }
    }

    private void action_enable_extension (SimpleAction action,
                                          Variant?     parameter)
    {
        this.desktop_module.enable_extension ();
    }

    private void action_about (SimpleAction action, Variant? parameter)
    {
        if (this.about_dialog == null)
        {
            var window = this.get_last_focused_window ();

            this.about_dialog = new Pomodoro.AboutDialog ();
            this.about_dialog.destroy.connect (() => {
                this.remove_window (this.about_dialog);
                this.about_dialog = null;
            });

            if (window != null) {
                this.about_dialog.set_transient_for (window);
            }

            this.add_window (this.about_dialog);
        }

        this.about_dialog.present ();
    }

    private void action_quit (SimpleAction action, Variant? parameter)
    {
        this.quit ();
    }

    private void setup_actions ()
    {
        var preferences_action = new GLib.SimpleAction ("preferences", null);
        preferences_action.activate.connect (this.action_preferences);

        var visit_website_action = new GLib.SimpleAction ("visit-website", null);
        visit_website_action.activate.connect (this.action_visit_website);

        var report_issue_action = new GLib.SimpleAction ("report-issue", null);
        report_issue_action.activate.connect (this.action_report_issue);

        var enable_extension_action = new GLib.SimpleAction ("enable-extension", null);
        enable_extension_action.activate.connect (this.action_enable_extension);

        var about_action = new GLib.SimpleAction ("about", null);
        about_action.activate.connect (this.action_about);

        var quit_action = new GLib.SimpleAction ("quit", null);
        quit_action.activate.connect (this.action_quit);

        this.add_action (preferences_action);
        this.add_action (visit_website_action);
        this.add_action (report_issue_action);
        this.add_action (enable_extension_action);
        this.add_action (about_action);
        this.add_action (quit_action);
    }

    private void setup_menu ()
    {
        var builder = new Gtk.Builder ();
        try {
            builder.add_from_resource ("/org/gnome/pomodoro/menu.ui");

            var menu = builder.get_object ("app-menu") as GLib.MenuModel;
            this.set_app_menu (menu);
        }
        catch (GLib.Error error) {
            GLib.warning (error.message);
        }
    }

    /* Emitted on the primary instance immediately after registration.
     */
    public override void startup ()
    {
        this.hold (HoldReason.SERVICE);

        base.startup ();

        this.setup_resources ();

        this.timer.state_changed.connect (this.on_timer_state_changed);
        this.timer.destroy.connect (this.on_timer_destroy);
        this.timer.restore ();

        this.desktop_module = new Pomodoro.GnomeDesktopModule (this.timer);

        this.modules = new List<Pomodoro.Module> ();
        this.modules.prepend (new Pomodoro.SoundsModule (this.timer));
        this.modules.prepend (new Pomodoro.PresenceModule (this.timer));
        this.modules.prepend (new Pomodoro.ScreenSaverModule (this.timer));
        this.modules.prepend (this.desktop_module);

        foreach (var module in this.modules)
        {
            module.enable ();
        }

        this.setup_actions ();
        this.setup_menu ();
    }

    private void on_timer_state_changed (Timer timer)
    {
        var is_running = timer.state != State.NULL;

        if (is_running) {
            this.hold (HoldReason.TIMER);
        }
        else {
            this.release (HoldReason.TIMER);
        }
    }

    private void on_timer_destroy (Timer timer)
    {
        this.release (HoldReason.TIMER);
        this.timer = null;
    }

    private int do_command_line (ApplicationCommandLine command_line)
    {
        var arguments = new CommandLine ();

        if (arguments.parse (command_line.get_arguments ()))
        {
            if (arguments.preferences) {
                this.activate_action ("preferences", null);
            }

            if (arguments.no_default_window) {
                this.hold (HoldReason.SERVICE);
            }

            if (!arguments.preferences && !arguments.no_default_window) {
                this.activate ();
            }

            return ExitStatus.SUCCESS;
        }

        return ExitStatus.FAILURE;
    }

    public override int command_line (ApplicationCommandLine command_line)
    {
        this.hold ();
        var status = this.do_command_line (command_line);
        this.release ();

        return status;
    }

    /* Save the state before exit.
     *
     * Emitted only on the registered primary instance immediately after
     * the main loop terminates.
     */
    public override void shutdown ()
    {
        foreach (var module in this.modules)
        {
            module.disable ();
        }

        this.modules = null;

        base.shutdown ();
    }

    /* Emitted on the primary instance when an activation occurs.
     * The application must be registered before calling this function.
     */
    public override void activate ()
    {
        this.activate_action ("preferences", null);
    }

    public override bool dbus_register (DBusConnection connection,
                                        string         object_path) throws GLib.Error
    {
        if (!base.dbus_register (connection, object_path)) {
            return false;
        }

        if (this.timer == null) {
            this.timer = new Pomodoro.Timer ();
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
            this.service.dispose ();
            this.service = null;
        }

        if (this.timer != null) {
            this.timer.destroy ();
            this.timer = null;
        }
    }
}

