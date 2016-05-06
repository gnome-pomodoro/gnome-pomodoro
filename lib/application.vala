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


namespace Pomodoro
{
    public interface ApplicationExtension : Peas.ExtensionBase
    {
    }

    public class Application : Gtk.Application
    {
        public Pomodoro.Service service;
        public Pomodoro.Timer timer;
        public Pomodoro.Desktop desktop { get; private set; }

        private Pomodoro.PreferencesDialog preferences_dialog;
        private Pomodoro.Window window;
        private Gtk.Window about_dialog;
        private Peas.ExtensionSet extensions;
        private GLib.Settings settings;

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

        public new static unowned Application get_default ()
        {
            return GLib.Application.get_default () as Pomodoro.Application;
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
            css_provider.load_from_resource ("/org/gnome/pomodoro/ui/style.css");

            Gtk.StyleContext.add_provider_for_screen (
                                         Gdk.Screen.get_default (),
                                         css_provider,
                                         Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        private void setup_plugins ()
        {
            var engine = Peas.Engine.get_default ();
            engine.add_search_path (Config.PLUGIN_LIB_DIR, Config.PLUGIN_DATA_DIR);

            this.load_plugins ();

            this.extensions = new Peas.ExtensionSet (engine, typeof (Pomodoro.ApplicationExtension));
        }

        private void setup_desktop ()
        {
            this.desktop = new Pomodoro.Desktop ();
        }

        private void load_plugins ()
        {
            var engine          = Peas.Engine.get_default ();
            var enabled_plugins = this.settings.get_strv ("enabled-plugins");
            var enabled_hash    = new GLib.HashTable<string, bool> (str_hash, str_equal);

            foreach (var name in enabled_plugins)
            {
                enabled_hash.insert (name, true);
            }

            foreach (var plugin_info in engine.get_plugin_list ())
            {
                if (plugin_info.is_hidden ()) {
                    continue;
                }

                if (enabled_hash.contains (plugin_info.get_module_name ())) {
                    engine.try_load_plugin (plugin_info);
                }
                else {
                    engine.try_unload_plugin (plugin_info);
                }
            }
        }

        public void show_window ()
        {
            if (this.window == null) {
                this.window = new Pomodoro.Window ();
                this.window.application = this;
                this.window.destroy.connect (() => {
                    this.remove_window (this.window);
                    this.window = null;
                });

                this.add_window (this.window);
            }

            this.window.present ();
        }

        public void show_preferences_full (string? page,
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
                if (page != null) {
                    this.preferences_dialog.set_page (page);
                }

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

        private void action_timer (GLib.SimpleAction action,
                                   GLib.Variant?     parameter)
        {
            this.show_window ();
        }

        private void action_preferences (GLib.SimpleAction action,
                                         GLib.Variant?     parameter)
        {
            this.show_preferences ();
        }

        private void action_visit_website (GLib.SimpleAction action,
                                           GLib.Variant?     parameter)
        {
            try {
                string[] spawn_args = { "xdg-open", Config.PACKAGE_URL };
                string[] spawn_env = GLib.Environ.get ();

                GLib.Process.spawn_async (null,
                                          spawn_args,
                                          spawn_env,
                                          GLib.SpawnFlags.SEARCH_PATH,
                                          null,
                                          null);
            }
            catch (GLib.SpawnError error) {
                GLib.warning ("Failed to spawn proccess: %s", error.message);
            }
        }

        private void action_report_issue (GLib.SimpleAction action,
                                          GLib.Variant?     parameter)
        {
            try {
                string[] spawn_args = { "xdg-open", Config.PACKAGE_BUGREPORT };
                string[] spawn_env = GLib.Environ.get ();

                GLib.Process.spawn_async (null,
                                          spawn_args,
                                          spawn_env,
                                          GLib.SpawnFlags.SEARCH_PATH,
                                          null,
                                          null);
            }
            catch (GLib.SpawnError error) {
                GLib.warning ("Failed to spawn proccess: %s", error.message);
            }
        }

        private void action_about (GLib.SimpleAction action,
                                   GLib.Variant?     parameter)
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

        private void action_quit (GLib.SimpleAction action,
                                  GLib.Variant?     parameter)
        {
            this.quit ();
        }

        private void action_timer_skip (GLib.SimpleAction action,
                                        GLib.Variant?     parameter)
        {
            this.service.skip ();
        }

        private void action_timer_set_state (GLib.SimpleAction action,
                                             GLib.Variant?     parameter)
        {
            this.service.set_state (parameter.get_string (), 0.0);
        }

        private void action_timer_switch_state (GLib.SimpleAction action,
                                                GLib.Variant? parameter)
        {
            this.service.set_state (parameter.get_string (),
                                    this.timer.state.timestamp);
        }

        private void setup_actions ()
        {
            var timer_action = new GLib.SimpleAction ("timer", null);
            timer_action.activate.connect (this.action_timer);

            var preferences_action = new GLib.SimpleAction ("preferences", null);
            preferences_action.activate.connect (this.action_preferences);

            var visit_website_action = new GLib.SimpleAction ("visit-website", null);
            visit_website_action.activate.connect (this.action_visit_website);

            var report_issue_action = new GLib.SimpleAction ("report-issue", null);
            report_issue_action.activate.connect (this.action_report_issue);

            var about_action = new GLib.SimpleAction ("about", null);
            about_action.activate.connect (this.action_about);

            var quit_action = new GLib.SimpleAction ("quit", null);
            quit_action.activate.connect (this.action_quit);

            var timer_skip_action = new GLib.SimpleAction ("timer-skip", null);
            timer_skip_action.activate.connect (this.action_timer_skip);

            var timer_set_state_action = new GLib.SimpleAction ("timer-set-state", GLib.VariantType.STRING);
            timer_set_state_action.activate.connect (this.action_timer_set_state);

            var timer_switch_state_action = new GLib.SimpleAction ("timer-switch-state", GLib.VariantType.STRING);
            timer_switch_state_action.activate.connect (this.action_timer_switch_state);

            this.add_action (timer_action);
            this.add_action (preferences_action);
            this.add_action (visit_website_action);
            this.add_action (report_issue_action);
            this.add_action (about_action);
            this.add_action (quit_action);

            this.add_action (timer_skip_action);
            this.add_action (timer_set_state_action);
            this.add_action (timer_switch_state_action);
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

        /**
         * Emitted on the primary instance immediately after registration.
         */
        public override void startup ()
        {
            this.hold ();

            base.startup ();

            this.setup_resources ();
            this.setup_actions ();
            this.setup_menu ();
            this.setup_plugins ();
            this.setup_desktop ();

            this.restore_timer ();

            this.release ();
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

        protected override bool local_command_line ([CCode (array_length = false, array_null_terminated = true)]
                                                    ref unowned string[] arguments,
                                                    out int              exit_status)
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

        public override int command_line (GLib.ApplicationCommandLine command_line)
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
            base.shutdown ();

            if (this.desktop != null) {
                this.desktop = null;
            }
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
            else {
                this.show_window ();
            }

            this.release ();
        }

        public override bool dbus_register (GLib.DBusConnection connection,
                                            string              object_path) throws GLib.Error
        {
            if (!base.dbus_register (connection, object_path)) {
                return false;
            }

            if (this.timer == null) {
                this.timer = Pomodoro.Timer.get_default ();
                this.timer.state_changed.connect (this.on_timer_state_changed);
                this.timer.notify["state"].connect (this.on_timer_state_notify);
            }

            if (this.settings == null) {
                this.settings = Pomodoro.get_settings ()
                                        .get_child ("preferences");
                this.settings.changed.connect (this.on_settings_changed);
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
                catch (GLib.IOError error) {
                    GLib.warning ("%s", error.message);
                    return false;
                }
            }

            return true;
        }

        public override void dbus_unregister (GLib.DBusConnection connection,
                                              string              object_path)
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

        private void save_timer ()
        {
            Pomodoro.save_timer (this.timer);
        }

        private void restore_timer ()
        {
            Pomodoro.restore_timer (this.timer);
        }

        private void on_settings_changed (GLib.Settings settings,
                                          string        key)
        {
            var state_duration = this.timer.state_duration;

            switch (key)
            {
                case "pomodoro-duration":
                    if (this.timer.state is Pomodoro.PomodoroState) {
                        state_duration = settings.get_double (key);
                    }
                    break;

                case "short-break-duration":
                    if (this.timer.state is Pomodoro.ShortBreakState) {
                        state_duration = settings.get_double (key);
                    }
                    break;

                case "long-break-duration":
                    if (this.timer.state is Pomodoro.LongBreakState) {
                        state_duration = settings.get_double (key);
                    }
                    break;

                case "enabled-plugins":
                    this.load_plugins ();

                    break;
            }

            if (state_duration != this.timer.state_duration)
            {
                this.timer.state_duration = double.max (state_duration, this.timer.elapsed);
            }
        }

        /**
         * Save timer state, assume user is idle when break is completed.
         */
        private void on_timer_state_changed (Pomodoro.Timer      timer,
                                             Pomodoro.TimerState state,
                                             Pomodoro.TimerState previous_state)
        {
            if (this.desktop != null &&
                previous_state is Pomodoro.BreakState &&
                state is Pomodoro.PomodoroState)
            {
//                this.desktop.presence_status = Pomodoro.PresenceStatus.IDLE;
            }

            this.save_timer ();
        }

        private void on_timer_state_notify ()
        {
            if (this.timer.is_paused) {
                this.timer.resume ();
            }
        }

//        /**
//         * Pause timer when idle.
//         */
//        private void on_desktop_presence_status_notify ()
//        {
//            GLib.debug ("on_desktop_presence_status_notify %s", this.desktop.presence_status.to_string ());
//
//            if (this.desktop.presence_status == Pomodoro.PresenceStatus.IDLE) {
//                this.timer.pause ();
//            }
//            else {
//                this.timer.resume ();
//            }
//        }
    }
}
