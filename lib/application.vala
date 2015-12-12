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

    private enum ExitStatus
    {
        UNDEFINED = -1,
        SUCCESS   =  0,
        FAILURE   =  1
    }

    private struct Options
    {
        public static bool no_default_window = false;
        public static bool preferences = false;
        public static bool quit = false;

        public static ExitStatus exit_status = ExitStatus.UNDEFINED;

        public static const GLib.OptionEntry[] entries = {
            { "no-default-window", 0, GLib.OptionFlags.HIDDEN, GLib.OptionArg.NONE,
              ref no_default_window, N_("Run as background service"), null },

            { "preferences", 0, 0, GLib.OptionArg.NONE,
              ref preferences, N_("Show preferences"), null },

            { "quit", 0, 0, GLib.OptionArg.NONE,
              ref quit, N_("Quit application"), null },

            { "version", 0, GLib.OptionFlags.NO_ARG, GLib.OptionArg.CALLBACK,
              (void *) command_line_version_callback, N_("Print version information and exit"), null },

            { null }
        };
    }

    public Application ()
    {
        GLib.Object (
            application_id: "org.gnome.Pomodoro",
            flags: GLib.ApplicationFlags.HANDLES_COMMAND_LINE
        );

        this.timer = null;
        this.service = null;
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
           var css_file = File.new_for_uri ("resource:///org/gnome/pomodoro/ui/style.css");

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
            builder.add_from_resource ("/org/gnome/pomodoro/ui/menus.ui");

            var menu = builder.get_object ("app-menu") as GLib.MenuModel;
            this.set_app_menu (menu);
        }
        catch (GLib.Error error) {
            GLib.warning (error.message);
        }
    }

    private static bool command_line_version_callback ()
    {
        stdout.printf ("%s %s\n",
                       GLib.Environment.get_application_name (),
                       Config.PACKAGE_VERSION);

        Options.exit_status = ExitStatus.SUCCESS;

        return true;
    }

    /* Emitted on the primary instance immediately after registration.
     */
    public override void startup ()
    {
        this.hold ();

        base.startup ();

        this.setup_resources ();

        Pomodoro.Timer.restore (this.timer);

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

        this.release ();
    }

    public Pomodoro.Module? get_module_by_name (string name)
    {
        foreach (var module in this.modules)
        {
            if (module != null && module.name == name) {
//                module.plugin_enabled.connect ((plugin) => {
//                    message ("Plugin enabled");
//                });

//                module.plugin_disabled.connect ((plugin) => {
//                    message ("Plugin disabled");
//                });

                return module;
            }
        }

        return null;
    }

    /**
     * This is just for local things, like showing help
     */
    private void parse_command_line (ref unowned string[] arguments) throws GLib.OptionError
    {
        var option_context = new GLib.OptionContext (_("- Time management utility for GNOME"));

        option_context.add_main_entries (Options.entries, Config.GETTEXT_PACKAGE);
        option_context.add_group (Gtk.get_option_group (true));

        // TODO: add options from plugins

        option_context.parse (ref arguments);
    }

    protected override bool local_command_line ([CCode (array_length = false, array_null_terminated = true)] ref unowned string[] arguments, out int exit_status)
    {
        string[] tmp = arguments;
        unowned string[] arguments_copy = tmp;

        try
        {
            // This is just for local things, like showing help
            this.parse_command_line (ref arguments_copy);
        }
        catch (GLib.Error error)
        {
            stderr.printf ("Failed to parse options: %s\n", error.message);
            exit_status = ExitStatus.FAILURE;

            return true;
        }

        if (Options.exit_status != ExitStatus.UNDEFINED)
        {
            exit_status = Options.exit_status;

            return true;
        }

        return base.local_command_line (ref arguments, out exit_status);
    }

    public override int command_line (ApplicationCommandLine command_line)
    {
        string[] tmp = command_line.get_arguments ();
        unowned string[] arguments_copy = tmp;

        var exit_status = ExitStatus.SUCCESS;

        do {

            try
            {
                this.parse_command_line (ref arguments_copy);
            }
            catch (GLib.Error error)
            {
                stderr.printf ("Failed to parse options: %s\n", error.message);

                exit_status = ExitStatus.FAILURE;
                break;
            }

            if (Options.exit_status != ExitStatus.UNDEFINED)
            {
                exit_status = Options.exit_status;
                break;
            }

            this.activate ();
        }
        while (false);

        return exit_status;
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
        this.hold ();

        if (Options.quit) {
            this.quit ();
        }

        if (Options.preferences) {
            this.show_preferences ();
        }

        this.release ();
    }

    public override bool dbus_register (DBusConnection connection,
                                        string         object_path) throws GLib.Error
    {
        if (!base.dbus_register (connection, object_path)) {
            return false;
        }

        if (this.timer == null) {
            this.timer = new Pomodoro.Timer ();
            this.timer.notify["state"].connect (() => {
                Pomodoro.Timer.save (this.timer);
            });
        }

        if (this.service == null) {
            this.hold ();

            this.service = new Pomodoro.Service (connection, this.timer);
            this.service.destroy.connect (() => {
                this.service = null;
                this.release ();
            });

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

        if (this.timer != null) {
            this.timer.destroy ();
            this.timer = null;
        }

        if (this.service != null) {
            this.service.destroy ();
            this.service = null;
        }
    }

//    private void on_settings_changed (GLib.Settings settings, string key)
//    {
//        var state_duration = this.state_duration;

//        switch (key)
//        {
//            case "pomodoro-duration":
//                if (this.timer.state == State.POMODORO) {
//                    state_duration = this.settings.get_double (key);
//                }
//                break;

//            case "short-break-duration":
//                if (this.timer.state == State.PAUSE && !this.is_long_break) {
//                    state_duration = this.settings.get_double (key);
//                }
//                break;

//            case "long-break-duration":
//                if (this.timer.state == State.PAUSE && this.is_long_break) {
//                    state_duration = this.settings.get_double (key);
//                }
//                break;

//            case "long-break-interval":
//                if (this.timer.session_limit != this.settings.get_double (key)) {
//                    this.timer.session_limit = this.settings.get_double (key);
//                }
//                break;
//        }

//        if (state_duration != this.state_duration)
//        {
//            this.state_duration = double.max (state_duration, this.elapsed);
//            this.timer.update ();
//        }
//    }
}

