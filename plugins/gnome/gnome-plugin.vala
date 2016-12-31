/*
 * Copyright (c) 2016 gnome-pomodoro contributors
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


namespace GnomePlugin
{
    /* Leas amount of time in seconds between detected events
     * to say that user become active
     */
    private const double IDLE_MONITOR_MIN_IDLE_TIME = 0.5;

    private const string CURRENT_DESKTOP_VARIABLE = "XDG_CURRENT_DESKTOP";

    public class ApplicationExtension : Peas.ExtensionBase, Pomodoro.ApplicationExtension, GLib.AsyncInitable
    {
        private const string[] SHELL_CAPABILITIES = {
            "notifications",
            "indicator",
            "accelerator",
            "reminders",
            "hide-system-notifications"
        };

        private Pomodoro.Timer                  timer;
        private GLib.Settings                   settings;
        private Pomodoro.CapabilityGroup        capabilities;
        private Pomodoro.CapabilityGroup        shell_capabilities;
        private GnomePlugin.GnomeShellExtension shell_extension;
        private GnomePlugin.IdleMonitor         idle_monitor;
        private uint                            become_active_id = 0;
        private bool                            can_enable = false;
        private double                          last_activity_time = 0.0;

        construct
        {
            this.settings = Pomodoro.get_settings ().get_child ("preferences");
            this.can_enable = GLib.Environment.get_variable (CURRENT_DESKTOP_VARIABLE) == "GNOME";

            // try {
            //     this.init_async.begin (GLib.Priority.DEFAULT, null);
            // }
            // catch (GLib.Error error) {
            //     warning ("Failed to initialize ApplicationExtension");
            // }
        }

        public async bool init_async (int               io_priority = GLib.Priority.DEFAULT,
                                      GLib.Cancellable? cancellable = null)
                                      throws GLib.Error
        {
            var application = Pomodoro.Application.get_default ();

            /* Mutter IdleMonitor */
            if (this.idle_monitor == null) {
                this.capabilities = new Pomodoro.CapabilityGroup ("gnome");

                try {
                    this.idle_monitor = new GnomePlugin.IdleMonitor ();

                    this.timer = Pomodoro.Timer.get_default ();
                    this.timer.state_changed.connect_after (this.on_timer_state_changed);

                    this.capabilities.add (new Pomodoro.Capability ("idle-monitor"));

                    application.capabilities.add_group (this.capabilities, Pomodoro.Priority.HIGH);
                }
                catch (GLib.Error error) {
                    // Gnome.IdleMonitor not available
                }
            }

            /* GNOME Shell extension */
            if (this.can_enable && this.shell_extension == null) {
                this.shell_extension = new GnomePlugin.GnomeShellExtension (Config.EXTENSION_UUID);
                this.shell_extension.notify["enabled"].connect (this.on_shell_extension_enabled_notify);

                this.shell_capabilities = new Pomodoro.CapabilityGroup ("gnome-shell");

                for (var i=0; i < SHELL_CAPABILITIES.length; i++) {
                    this.shell_capabilities.add (new Pomodoro.Capability (SHELL_CAPABILITIES[i]));
                }

                yield this.shell_extension.enable ();
            }

            return true;
        }

        ~ApplicationExtension ()
        {
            this.timer.state_changed.disconnect (this.on_timer_state_changed);

            if (this.become_active_id != 0) {
                this.idle_monitor.remove_watch (this.become_active_id);
                this.become_active_id = 0;
            }
        }

        private void on_shell_extension_enabled_notify ()
        {
            var application = Pomodoro.Application.get_default ();

            if (this.shell_extension.enabled) {
                application.capabilities.add_group (this.shell_capabilities, Pomodoro.Priority.HIGH);
            }
            else {
                application.capabilities.remove_group (this.shell_capabilities);
            }
        }

        private void on_timer_state_changed (Pomodoro.TimerState state,
                                             Pomodoro.TimerState previous_state)
        {
            if (this.become_active_id != 0) {
                this.idle_monitor.remove_watch (this.become_active_id);
                this.become_active_id = 0;
            }

            if (state is Pomodoro.PomodoroState &&
                previous_state is Pomodoro.BreakState &&
                previous_state.is_completed () &&
                this.settings.get_boolean ("pause-when-idle"))
            {
                this.become_active_id = this.idle_monitor.add_user_active_watch (this.on_become_active);

                this.timer.pause ();
            }
        }

        /**
         * on_become_active callback
         *
         * We want to detect user/human activity so it sparse events.
         */
        private void on_become_active (GnomePlugin.IdleMonitor monitor,
                                       uint                    id)
        {
            var timestamp = Pomodoro.get_current_time ();

            if (timestamp - this.last_activity_time < IDLE_MONITOR_MIN_IDLE_TIME) {
                this.become_active_id = 0;

                this.timer.resume ();
            }
            else {
                this.become_active_id = this.idle_monitor.add_user_active_watch (this.on_become_active);
            }

            this.last_activity_time = timestamp;
        }
    }

    public class PreferencesDialogExtension : Peas.ExtensionBase, Pomodoro.PreferencesDialogExtension
    {
        private Pomodoro.PreferencesDialog dialog;

        private GLib.Settings settings;
        private GLib.List<Gtk.ListBoxRow> rows;

        construct
        {
            this.settings = new GLib.Settings ("org.gnome.pomodoro.plugins.gnome");
            this.dialog = Pomodoro.PreferencesDialog.get_default ();

            this.setup_main_page ();
        }

        private void setup_main_page ()
        {
            var main_page = this.dialog.get_page ("main") as Pomodoro.PreferencesMainPage;

            var hide_system_notifications_toggle = new Gtk.Switch ();
            hide_system_notifications_toggle.valign = Gtk.Align.CENTER;

            var row = this.create_row (_("Hide other notifications"),
                                       hide_system_notifications_toggle);
            row.name = "hide-system-notifications";
            main_page.lisboxrow_sizegroup.add_widget (row);
            main_page.desktop_listbox.add (row);
            this.rows.prepend (row);

            this.settings.bind ("hide-system-notifications",
                                hide_system_notifications_toggle,
                                "active",
                                GLib.SettingsBindFlags.DEFAULT);
        }

        ~PreferencesDialogExtension ()
        {
            foreach (var row in this.rows) {
                row.destroy ();
            }

            this.rows = null;
        }

        private Gtk.ListBoxRow create_row (string     label,
                                           Gtk.Widget widget)
        {
            var name_label = new Gtk.Label (label);
            name_label.halign = Gtk.Align.START;
            name_label.valign = Gtk.Align.BASELINE;

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box.pack_start (name_label, true, true, 0);
            box.pack_start (widget, false, true, 0);

            var row = new Gtk.ListBoxRow ();
            row.activatable = false;
            row.selectable = false;
            row.add (box);
            row.show_all ();

            return row;
        }
    }
}


[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
    var object_module = module as Peas.ObjectModule;

    object_module.register_extension_type (typeof (Pomodoro.ApplicationExtension),
                                           typeof (GnomePlugin.ApplicationExtension));

   object_module.register_extension_type (typeof (Pomodoro.PreferencesDialogExtension),
                                          typeof (GnomePlugin.PreferencesDialogExtension));
}
