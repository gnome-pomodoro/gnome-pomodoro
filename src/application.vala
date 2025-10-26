/*
 * Copyright (c) 2013-2025 gnome-pomodoro contributors
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
    public class Application : Adw.Application, Pomodoro.BackgroundApplication
    {
        private enum ExitStatus
        {
            UNDEFINED = -1,
            SUCCESS   =  0,
            FAILURE   =  1
        }

        private class Options
        {
            public static bool no_default_window = false;
            public static bool preferences = false;
            public static bool quit = false;
            public static bool start_stop = false;
            public static bool start = false;
            public static bool stop = false;
            public static bool pause_resume = false;
            public static bool pause = false;
            public static bool resume = false;
            public static bool skip = false;
            public static bool extend = false;
            public static bool reset = false;

            public static ExitStatus exit_status = ExitStatus.UNDEFINED;

            public const GLib.OptionEntry[] ENTRIES = {
                { "start-stop", 0, 0, GLib.OptionArg.NONE,
                  ref start_stop, N_("Start/Stop"), null },

                { "start", 0, 0, GLib.OptionArg.NONE,
                  ref start, N_("Start"), null },

                { "stop", 0, 0, GLib.OptionArg.NONE,
                  ref stop, N_("Stop"), null },

                { "pause-resume", 0, 0, GLib.OptionArg.NONE,
                  ref pause_resume, N_("Pause/Resume"), null },

                { "pause", 0, 0, GLib.OptionArg.NONE,
                  ref pause, N_("Pause"), null },

                { "resume", 0, 0, GLib.OptionArg.NONE,
                  ref resume, N_("Resume"), null },

                { "skip", 0, 0, GLib.OptionArg.NONE,
                  ref skip, N_("Skip to a pomodoro or to a break"), null },

                { "extend", 0, 0, GLib.OptionArg.NONE,
                  ref extend, N_("Extend current pomodoro or break"), null },

                { "reset", 0, 0, GLib.OptionArg.NONE,
                  ref reset, N_("Reset current session"), null },

                { "no-default-window", 0, 0, GLib.OptionArg.NONE,
                  ref no_default_window, N_("Run as background service"), null },

                { "preferences", 0, 0, GLib.OptionArg.NONE,
                  ref preferences, N_("Show preferences"), null },

                { "quit", 0, 0, GLib.OptionArg.NONE,
                  ref quit, N_("Quit application"), null },

                { "version", 0, GLib.OptionFlags.NO_ARG, GLib.OptionArg.CALLBACK,
                  (void *) command_line_version_callback, N_("Print version information and exit"), null },

                { null }
            };

            public static void set_defaults ()
            {
                Options.no_default_window = false;
                Options.preferences = false;
                Options.quit = false;
                Options.start_stop = false;
                Options.start = false;
                Options.stop = false;
                Options.pause_resume = false;
                Options.pause = false;
                Options.resume = false;
                Options.skip = false;
                Options.extend = false;
                Options.reset = false;
            }

            public static bool has_timer_option ()
            {
                return Options.start_stop |
                       Options.start |
                       Options.stop |
                       Options.pause_resume |
                       Options.pause |
                       Options.resume |
                       Options.skip |
                       Options.extend |
                       Options.reset;
            }
        }

        public bool can_background {
            get {
                return this._can_background;
            }
            set {
                this._can_background = value;

                this.update_background_hold ();
            }
        }

        public Pomodoro.Timer?               timer;
        public Pomodoro.SessionManager?      session_manager;
        public Pomodoro.CapabilityManager?   capability_manager;

        private Pomodoro.KeyboardManager?    keyboard_manager;
        private Pomodoro.StatsManager?       stats_manager;
        private Pomodoro.EventProducer?      event_producer;
        private Pomodoro.EventBus?           event_bus;
        private Pomodoro.JobQueue?           job_queue;
        private Pomodoro.ActionManager?      action_manager;
        private Pomodoro.BackgroundManager?  background_manager;
        private Pomodoro.ApplicationService? service;
        private Pomodoro.TimerService?       timer_service;
        private Pomodoro.Logger?             logger;
        private GLib.Settings?               settings;
        private int                          background_holds_count = 0;
        private bool                         has_background_hold = false;
        private bool                         _can_background = false;
        private uint                         save_idle_id = 0;

        public Application ()
        {
            GLib.Object (
                application_id: Config.APPLICATION_ID,
                flags: GLib.ApplicationFlags.HANDLES_COMMAND_LINE,
                resource_base_path: "/org/gnomepomodoro/Pomodoro/"
            );
        }

        public new static unowned Pomodoro.Application get_default ()
        {
            return GLib.Application.get_default () as Pomodoro.Application;
        }

        public unowned Gtk.Window? get_last_focused_window ()
        {
            unowned GLib.List<Gtk.Window> link = this.get_windows ();

            return link != null
                ? link.first ().data
                : null;
        }

        public unowned T? get_window<T> ()
        {
            unowned GLib.List<Gtk.Window> link = this.get_windows ();

            var window_type = typeof (T);

            while (link != null)
            {
                if (link.data.get_type () == window_type) {
                    return link.data;
                }

                link = link.next;
            }

            return null;
        }

        private void setup_resources ()
        {
            debug ("setup_resources: begin");
            var display = Gdk.Display.get_default ();

            var icon_theme = Gtk.IconTheme.get_for_display (display);
            icon_theme.add_resource_path ("/org/gnomepomodoro/Pomodoro/icons");

            debug ("setup_resources: end");
        }

        private void setup_capabilities ()
        {
            this.hold ();

            this.capability_manager = new Pomodoro.CapabilityManager ();
            this.capability_manager.register (new Pomodoro.NotificationsCapability ());
            this.capability_manager.register (new Pomodoro.GlobalShortcutsCapability ());
            this.capability_manager.register (new Pomodoro.SoundsCapability ());

            var idle_id = GLib.Idle.add (() => {
                this.capability_manager.enable ("notifications");
                this.capability_manager.enable ("global-shortcuts");

                if (this.settings.get_boolean ("sounds")) {
                    this.capability_manager.enable ("sounds");
                }

                this.release ();

                return GLib.Source.REMOVE;
            });
            GLib.Source.set_name_by_id (idle_id, "Pomodoro.Application.setup_capabilities");
        }

        private void setup_database ()
        {
            this.hold ();

            Pomodoro.Database.open ();

            this.release ();
        }

        public void show_window (Pomodoro.WindowView view = Pomodoro.WindowView.DEFAULT)
        {
            var window = this.get_window<Pomodoro.Window> ();

            if (window == null)
            {
                window = new Pomodoro.Window ();
                this.add_window (window);

                if (this.application_id.has_suffix ("Devel")) {
                    window.add_css_class ("devel");
                }
            }

            if (view != Pomodoro.WindowView.DEFAULT) {
                window.view = view;
            }

            // TODO: test under GNOME 46, stealing focus does not work under wayland
            // if (window.visible && !window.is_active)
            // {
            //     var timestamp = (uint32) (Pomodoro.Timestamp.from_now () / Pomodoro.Interval.MILLISECOND);
            //
            //     var toplevel = window.get_surface () as Gdk.Toplevel;
            //     toplevel.focus (timestamp);
            // }
            // else {
                window.present ();
            // }
        }

        public void show_preferences ()
        {
            var preferences_window = this.get_window<Pomodoro.PreferencesWindow> ();

            if (preferences_window == null)
            {
                preferences_window = new Pomodoro.PreferencesWindow ();
                this.add_window (preferences_window);
            }

            preferences_window.present ();
        }

        public void show_about_dialog ()
        {
            var window = this.get_window<Pomodoro.Window> ();
            var about_dialog = this.get_window<Adw.AboutDialog> ();

            if (about_dialog == null) {
                about_dialog = Pomodoro.create_about_dialog ();
            }

            about_dialog.present (window);
        }

        private void activate_window (GLib.SimpleAction action,
                                      GLib.Variant?     parameter)
        {
            var view = Pomodoro.WindowView.from_string (parameter.get_string ());

            this.show_window (view);
        }

        private void activate_toggle_window (GLib.SimpleAction action,
                                             GLib.Variant?     parameter)
        {
            var window = this.get_window<Pomodoro.Window> ();

            if (window == null || !window.is_active) {
                this.show_window (Pomodoro.WindowView.TIMER);
            }
            else {
                window.destroy ();
            }
        }

        private void activate_timer (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            this.show_window (Pomodoro.WindowView.TIMER);
        }

        private void activate_stats (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            this.show_window (Pomodoro.WindowView.STATS);
        }

        private void activate_preferences (GLib.SimpleAction action,
                                           GLib.Variant?     parameter)
        {
            this.show_preferences ();
        }

        private void activate_log (GLib.SimpleAction action,
                                   GLib.Variant?     parameter)
        {
            var log_window = this.get_window<Pomodoro.LogWindow> ();

            if (log_window == null) {
                log_window = new Pomodoro.LogWindow ();
                this.add_window (log_window);
            }

            if (parameter != null) {
                log_window.select ((ulong) parameter.get_uint64 ());
            }

            log_window.present ();
        }

        private void activate_about (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            this.show_about_dialog ();
        }

        private void activate_screen_overlay (GLib.SimpleAction action,
                                              GLib.Variant?     parameter)
        {
            this.capability_manager.activate ("notifications");

            if (this.timer.is_paused ()) {
                this.timer.resume ();
            }
        }

        private void activate_visit_website (GLib.SimpleAction action,
                                             GLib.Variant?     parameter)
        {
            try {
                string[] spawn_args = { "xdg-open", Config.PACKAGE_WEBSITE };
                string[] spawn_env = GLib.Environ.get ();

                GLib.Process.spawn_async (null,
                                          spawn_args,
                                          spawn_env,
                                          GLib.SpawnFlags.SEARCH_PATH,
                                          null,
                                          null);
            }
            catch (GLib.SpawnError error) {
                GLib.warning ("Failed to spawn process: %s", error.message);
            }
        }

        private void activate_report_issue (GLib.SimpleAction action,
                                            GLib.Variant?     parameter)
        {
            try {
                string[] spawn_args = { "xdg-open", Config.PACKAGE_ISSUE_URL };
                string[] spawn_env = GLib.Environ.get ();

                GLib.Process.spawn_async (null,
                                          spawn_args,
                                          spawn_env,
                                          GLib.SpawnFlags.SEARCH_PATH,
                                          null,
                                          null);
            }
            catch (GLib.SpawnError error) {
                GLib.warning ("Failed to spawn process: %s", error.message);
            }
        }

        private void activate_quit (GLib.SimpleAction action,
                                    GLib.Variant?     parameter)
        {
            this.quit ();
        }

        private void activate_advance (GLib.SimpleAction action,
                                       GLib.Variant?     parameter)
        {
            this.session_manager.advance ();
        }

        private void activate_advance_to_state (GLib.SimpleAction action,
                                                GLib.Variant?     parameter)
        {
            var state = Pomodoro.State.from_string (parameter.get_string ());

            this.session_manager.advance_to_state (state);
        }

        private void activate_extend (GLib.SimpleAction action,
                                      GLib.Variant?     parameter)
        {
            var seconds = parameter != null ? parameter.get_uint32 () : 60;

            this.timer.duration += seconds * Pomodoro.Interval.SECOND;
        }

        // TODO: rename to swap_state?
        // private void activate_timer_switch_state (GLib.SimpleAction action,
        //                                           GLib.Variant?     parameter)
        // {
        //     try {
        //         // this.service.set_state (parameter.get_string (),
        //         //                         this.timer.state.timestamp);
        //     }
        //     catch (GLib.Error error) {
        //         // TODO: log warning
        //     }
        // }

        private void setup_actions ()
        {
            debug ("#### setup_actions");

            GLib.SimpleAction action;

            action = new GLib.SimpleAction ("window", GLib.VariantType.STRING);
            action.activate.connect (this.activate_window);
            this.add_action (action);

            action = new GLib.SimpleAction ("toggle-window", null);
            action.activate.connect (this.activate_toggle_window);
            this.add_action (action);

            action = new GLib.SimpleAction ("preferences", null);
            action.activate.connect (this.activate_preferences);
            this.add_action (action);

            action = new GLib.SimpleAction ("log", GLib.VariantType.UINT64);
            action.activate.connect (this.activate_log);
            this.add_action (action);

            action = new GLib.SimpleAction ("screen-overlay", null);
            action.activate.connect (this.activate_screen_overlay);
            this.add_action (action);

            action = new GLib.SimpleAction ("visit-website", null);
            action.activate.connect (this.activate_visit_website);
            this.add_action (action);

            action = new GLib.SimpleAction ("report-issue", null);
            action.activate.connect (this.activate_report_issue);
            this.add_action (action);

            action = new GLib.SimpleAction ("about", null);
            action.activate.connect (this.activate_about);
            this.add_action (action);

            action = new GLib.SimpleAction ("quit", null);
            action.activate.connect (this.activate_quit);
            this.add_action (action);

            // Include timer and session-manager actions under the "app" namespace for use in notifications.
            action = new GLib.SimpleAction ("advance", null);
            action.activate.connect (this.activate_advance);
            this.add_action (action);

            action = new GLib.SimpleAction ("advance-to-state", GLib.VariantType.STRING);
            action.activate.connect (this.activate_advance_to_state);
            this.add_action (action);

            action = new GLib.SimpleAction ("extend", GLib.VariantType.UINT32);
            action.activate.connect (this.activate_extend);
            this.add_action (action);

            this.set_accels_for_action ("app.preferences", {"<Primary>comma"});
            this.set_accels_for_action ("app.log", {"<Primary>l"});
            this.set_accels_for_action ("app.quit", {"<Primary>q"});
            this.set_accels_for_action ("window.close", {"<Primary>w"});
            this.set_accels_for_action ("win.toggle-compact-size", {"F9"});

            this.keyboard_manager = new Pomodoro.KeyboardManager ();
            this.keyboard_manager.add_shortcut ("timer.start-stop",
                                                _("Start or Stop"),
                                                "<Ctrl><Alt>p");
            this.keyboard_manager.add_shortcut ("timer.start-pause-resume",
                                                _("Start, Pause or Resume"));
            this.keyboard_manager.add_shortcut ("timer.start",
                                                _("Start"));
            this.keyboard_manager.add_shortcut ("timer.reset",
                                                _("Stop"));
            this.keyboard_manager.add_shortcut ("timer.pause",
                                                _("Pause"));
            this.keyboard_manager.add_shortcut ("timer.resume",
                                                _("Resume"));
            this.keyboard_manager.add_shortcut ("session-manager.advance",
                                                _("Skip"));
            this.keyboard_manager.add_shortcut ("timer.rewind",
                                                _("Rewind"));
            this.keyboard_manager.add_shortcut ("app.toggle-window",
                                                _("Bring to Focus"),
                                                "<Ctrl><Alt><Shift>p");
            this.keyboard_manager.shortcut_activated.connect (this.on_shortcut_activated);
        }

        private void update_color_scheme ()
        {
            var style_manager = Adw.StyleManager.get_default ();

            if (this.settings.get_boolean ("dark-theme")) {
                style_manager.set_color_scheme (Adw.ColorScheme.FORCE_DARK);
            }
            else {
                style_manager.set_color_scheme (Adw.ColorScheme.DEFAULT);
            }
        }

        private void update_background_hold ()
        {
            var should_hold = this._can_background && this.background_holds_count > 0;

            if (!this.has_background_hold && should_hold)
            {
                this.has_background_hold = true;
                this.hold ();
            }

            if (this.has_background_hold && !should_hold)
            {
                this.has_background_hold = false;
                this.release ();
            }
        }

        public void hold_background ()
        {
            this.background_holds_count++;

            this.update_background_hold ();
        }

        public void release_background ()
        {
            this.background_holds_count--;

            this.update_background_hold ();
        }

        public bool should_run_in_background ()
        {
            return this._can_background && this.background_holds_count > 0;
        }

        /**
         * This is just for local things, like showing help
         */
        private void parse_command_line (ref unowned string[] arguments) throws GLib.OptionError
        {
            var option_context = new GLib.OptionContext ();
            option_context.add_main_entries (Options.ENTRIES, Config.GETTEXT_PACKAGE);

            // TODO: add options from plugins

            option_context.parse (ref arguments);
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

            this.settings           = Pomodoro.get_settings ();
            this.session_manager    = Pomodoro.SessionManager.get_default ();
            this.timer              = this.session_manager.timer;
            this.stats_manager      = new Pomodoro.StatsManager ();
            this.event_producer     = new Pomodoro.EventProducer ();
            this.event_bus          = this.event_producer.bus;
            this.job_queue          = new Pomodoro.JobQueue ();
            this.action_manager     = new Pomodoro.ActionManager ();
            this.logger             = new Pomodoro.Logger ();
            this.background_manager = new Pomodoro.BackgroundManager ();

            this.setup_resources ();
            this.setup_database ();
            this.setup_capabilities ();
            this.setup_actions ();
            this.update_color_scheme ();

            this.settings.changed.connect (this.on_settings_changed);
            this.event_bus.event.connect (this.on_event);

            this.mark_busy ();

            this.session_manager.restore.begin (
                Pomodoro.Timestamp.UNDEFINED,
                (obj, res) => {
                    this.session_manager.restore.end (res);
                    this.session_manager.ensure_session ();

                    this.session_manager.enter_time_block.connect (this.on_enter_time_block);
                    this.session_manager.leave_time_block.connect (this.on_leave_time_block);
                    this.session_manager.advanced.connect (this.on_advanced);

                    this.unmark_busy ();
                    this.release ();
                });
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
            if (this.save_idle_id != 0) {
                GLib.Source.remove (this.save_idle_id);
                this.save_idle_id = 0;
            }

            this.settings.changed.disconnect (this.on_settings_changed);
            this.event_bus.event.disconnect (this.on_event);
            this.keyboard_manager.shortcut_activated.disconnect (this.on_shortcut_activated);

            base.shutdown ();

            // Stop emitting new events
            this.event_producer.destroy ();
            this.event_bus.destroy ();
            this.action_manager.destroy ();
            this.capability_manager.destroy ();
            this.session_manager.enter_time_block.disconnect (this.on_enter_time_block);
            this.session_manager.leave_time_block.disconnect (this.on_leave_time_block);
            this.session_manager.advanced.disconnect (this.on_advanced);

            if (this.session_manager.current_time_block != null) {
                this.session_manager.current_time_block.changed.disconnect (
                        this.on_current_time_block_changed);
            }

            // Disable plugins
            // var engine = Peas.Engine.get_default ();

            // foreach (var plugin_info in engine.get_plugin_list ()) {
            //     engine.try_unload_plugin (plugin_info);
            // }

            // Pause the timer before saving the session
            this.timer.pause ();

            // Wait until all async jobs are completed
            var main_context = GLib.MainContext.@default ();
            var remaining = 2;

            this.job_queue.wait.begin (
                (obj, res) => {
                    this.job_queue.wait.end (res);
                    remaining--;
                });

            this.session_manager.save.begin (
                (obj, res) => {
                    this.session_manager.save.end (res);
                    remaining--;
                });

            while (remaining > 0 && main_context.iteration (false));

            // Cleanup
            Pomodoro.Database.close ();
            Pomodoro.SessionManager.set_default (null);
            Pomodoro.Timer.set_default (null);

            this.event_producer = null;
            this.event_bus = null;
            this.job_queue = null;
            this.action_manager = null;
            this.logger = null;
            this.background_manager = null;
            this.keyboard_manager = null;
            this.capability_manager = null;
            this.stats_manager = null;
            this.session_manager = null;
            this.timer = null;
            this.settings = null;
        }

        /* Emitted on the primary instance when an activation occurs.
         * The application must be registered before calling this function.
         */
        public override void activate ()
        {
            this.hold ();

            Options.no_default_window |= Options.has_timer_option ();

            Gtk.Window.set_default_icon_name (this.application_id);

            if (Options.quit) {
                this.quit ();
            }
            else {
                if (Options.reset) {
                    this.timer.reset ();
                }

                if (Options.start_stop) {
                    if (!this.timer.is_running ()) {
                        this.timer.start ();
                    }
                    else {
                        this.timer.reset ();
                    }
                }
                else if (Options.start) {
                    this.timer.start ();
                }
                else if (Options.stop) {
                    this.timer.reset ();
                }

                if (Options.skip) {
                    this.session_manager.advance ();
                }
                else if (Options.extend && this.timer.duration > 0) {
                    this.timer.duration += Pomodoro.Interval.MINUTE;
                }

                if (Options.pause_resume) {
                    if (this.timer.is_paused ()) {
                        this.timer.resume ();
                    }
                    else {
                        this.timer.pause ();
                    }
                }
                else if (Options.pause) {
                    this.timer.pause ();
                }
                else if (Options.resume) {
                    this.timer.resume ();
                }

                if (Options.preferences) {
                    this.show_preferences ();
                }
                else if (!Options.no_default_window) {
                    this.show_window ();
                }

                Options.set_defaults ();
            }

            base.activate ();

            this.release ();
        }

        public override bool dbus_register (GLib.DBusConnection connection,
                                            string              object_path) throws GLib.Error
        {
            debug ("dbus_register: begin");

            if (!base.dbus_register (connection, object_path)) {
                return false;
            }

            /*
            if (this.service == null || this.timer_service == null) {
                this.hold ();
                this.service = new Pomodoro.ApplicationService (connection, this);
                this.timer_service = new Pomodoro.TimerService (connection, this.timer);

                try {
                    connection.register_object ("/org/gnomepomodoro/Pomodoro", this.service);
                    connection.register_object ("/org/gnomepomodoro/Pomodoro/Timer", this.timer_service);
                }
                catch (GLib.IOError error) {
                    GLib.warning ("%s", error.message);
                    return false;
                }
            }
            */

            debug ("dbus_register: end");

            return true;
        }

        public override void dbus_unregister (GLib.DBusConnection connection,
                                              string              object_path)
        {
            debug ("dbus_unregister: begin");

            base.dbus_unregister (connection, object_path);

            if (this.service != null) {
                this.service = null;

                this.release ();
            }

            debug ("dbus_unregister: end");
        }

        private void on_settings_changed (GLib.Settings settings,
                                          string        key)
        {
            switch (key)
            {
                case "dark-theme":
                    this.update_color_scheme ();
                    break;

                case "sounds":
                    if (settings.get_boolean (key)) {
                        this.capability_manager.enable ("sounds");
                    }
                    else {
                        this.capability_manager.disable ("sounds");
                    }
                    break;
            }
        }

        private void schedule_save ()
        {
            if (this.save_idle_id != 0) {
                return;
            }

            this.hold ();

            this.save_idle_id = GLib.Idle.add (() => {
                this.save_idle_id = 0;

                this.session_manager.save.begin ((obj, res) => {
                    this.session_manager.save.end (res);

                    this.release ();
                });

                return GLib.Source.REMOVE;
            });
            GLib.Source.set_name_by_id (this.save_idle_id, "Pomodoro.Application.schedule_save");
        }

        private void on_enter_time_block (Pomodoro.TimeBlock time_block)
        {
            time_block.changed.connect (this.on_current_time_block_changed);
        }

        private void on_leave_time_block (Pomodoro.TimeBlock time_block)
        {
            time_block.changed.disconnect (this.on_current_time_block_changed);
        }

        private void on_current_time_block_changed ()
        {
            this.schedule_save ();
        }

        private void on_advanced (Pomodoro.Session?   current_session,
                                  Pomodoro.TimeBlock? current_time_block,
                                  Pomodoro.Session?   previous_session,
                                  Pomodoro.TimeBlock? previous_time_block)
        {
            this.schedule_save ();
        }

        private void on_event (Pomodoro.Event event)
        {
            this.logger.log_event (event);
        }

        private void on_shortcut_activated (string shortcut_name)
        {
            GLib.ActionGroup action_group;

            var parts = shortcut_name.split (".", 2);

            if (parts.length != 2) {
                return;
            }

            switch (parts[0])
            {
                case "app":
                    action_group = (GLib.ActionGroup) this;
                    break;

                case "timer":
                    action_group = new Pomodoro.TimerActionGroup ();
                    break;

                case "session-manager":
                    action_group = new Pomodoro.SessionManagerActionGroup ();
                    break;

                default:
                    return;
            }

            action_group.activate_action (parts[1], null);
        }

        public override void dispose ()
        {
            assert (this.save_idle_id == 0);

            base.dispose ();
        }

        /*
        private void load_plugins ()
        {
            // var engine          = Peas.Engine.get_default ();
            // var enabled_plugins = this.settings.get_strv ("enabled-plugins");
            // var enabled_hash    = new GLib.HashTable<string, bool> (str_hash, str_equal);

            // foreach (var name in enabled_plugins)
            // {
            //     enabled_hash.insert (name, true);
            // }

            // foreach (var plugin_info in engine.get_plugin_list ())
            // {
            //     if (plugin_info.is_hidden () || enabled_hash.contains (plugin_info.get_module_name ())) {
            //         engine.try_load_plugin (plugin_info);
            //     }
            //     else {
            //         engine.try_unload_plugin (plugin_info);
            //     }
            // }
        }

        private void setup_desktop_extension ()
        {
            try {
                this.desktop_extension = new Pomodoro.DesktopExtension ();

                this.capabilities.add_group (this.desktop_extension.capabilities, Pomodoro.Priority.HIGH);
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while initializing desktop extension: %s",
                              error.message);
            }
        }

        private async void setup_plugins ()
        {
            var engine = Peas.Engine.get_default ();
            engine.add_search_path (Config.PLUGIN_LIB_DIR, Config.PLUGIN_DATA_DIR);

            var timeout_cancellable = new GLib.Cancellable ();
            var timeout_source = (uint) 0;
            var wait_count = 0;

            timeout_source = GLib.Timeout.add (SETUP_PLUGINS_TIMEOUT, () => {
                GLib.debug ("Timeout reached while setting up plugins");

                timeout_source = 0;
                timeout_cancellable.cancel ();

                return GLib.Source.REMOVE;
            });
            GLib.Source.set_name_by_id (timeout_source, "Pomodoro.Application.setup_plugins");

            this.extensions = new Peas.ExtensionSet (engine, typeof (Pomodoro.ApplicationExtension));
            this.extensions.extension_added.connect ((extension_set,
                                                      info,
                                                      extension_object) => {
                var extension = extension_object as GLib.AsyncInitable;

                if (extension != null)
                {
                    extension.init_async.begin (GLib.Priority.DEFAULT, timeout_cancellable, (obj, res) => {
                        try {
                            extension.init_async.end (res);
                        }
                        catch (GLib.Error error) {
                            GLib.warning ("Failed to initialize plugin \"%s\": %s",
                                          info.get_module_name (),
                                          error.message);
                        }

                        wait_count--;

                        this.setup_plugins.callback ();
                    });

                    wait_count++;
                }
            });

            this.load_plugins ();

            while (wait_count > 0) {
                yield;
            }

            timeout_cancellable = null;

            if (timeout_source != 0) {
                GLib.Source.remove (timeout_source);
            }
        }
        */
    }
}
