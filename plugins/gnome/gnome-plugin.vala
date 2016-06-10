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
    private double IDLE_MONITOR_MIN_IDLE_TIME = 0.5;

    public class DesktopExtension : Pomodoro.FallbackDesktopExtension
    {
        private static const string[] SHELL_CAPABILITIES = {
            "notifications",
            "indicator",
            "hotkey",
            "reminders"
        };

        private Pomodoro.Timer                  timer;
        private GLib.Settings                   settings;
        private Pomodoro.CapabilityGroup        capabilities;
        private GnomePlugin.GnomeShellExtension shell_extension;
        private Gnome.IdleMonitor               idle_monitor;
        private uint                            become_active_id = 0;
        private bool                            configured = false;
        private double                          last_activity_time = 0.0;

        construct
        {
            this.settings = Pomodoro.get_settings ().get_child ("preferences");

            this.idle_monitor = new Gnome.IdleMonitor ();

            this.shell_extension = new GnomePlugin.GnomeShellExtension (Config.EXTENSION_UUID);

            this.capabilities = new Pomodoro.CapabilityGroup ();
            this.capabilities.fallback = base.get_capabilities ();
            this.capabilities.enabled_changed.connect (this.on_capability_enabled_changed);

            this.timer = Pomodoro.Timer.get_default ();
            this.timer.state_changed.connect_after (this.on_timer_state_changed);
        }

        ~DesktopExtension ()
        {
            this.timer.state_changed.disconnect (this.on_timer_state_changed);

            if (this.become_active_id != 0) {
                this.idle_monitor.remove_watch (this.become_active_id);
                this.become_active_id = 0;
            }
        }

        public override unowned Pomodoro.CapabilityGroup get_capabilities ()
        {
            return this.capabilities != null ? this.capabilities : base.get_capabilities ();
        }

        private void on_capability_enabled_changed (string capability_name,
                                                    bool   enabled)
        {
            if (enabled) {
                this.on_capability_enabled (capability_name);
            }
            else {
                this.on_capability_disabled (capability_name);
            }
        }

        private void on_capability_enabled (string capability_name)
        {
        }

        private void on_capability_disabled (string capability_name)
        {
        }

        public override async void configure ()
        {
            /* wait for status of gnome-shell extension */
            this.shell_extension.enable.begin ((obj, res) => {
                this.shell_extension.enable.end (res);

                if (this.shell_extension.enabled) {
                    GLib.debug ("Extension enabled");
                }

                this.configure.callback ();
            });

            yield;

            /* add capabilities */
            this.on_shell_extension_enabled_notify ();

            yield base.configure ();

            this.shell_extension.notify["enabled"].connect (this.on_shell_extension_enabled_notify);
        }

        private void on_shell_extension_enabled_notify ()
        {
            if (this.shell_extension.enabled) {
                for (var i=0; i < SHELL_CAPABILITIES.length; i++)
                {
                    var capability = new Pomodoro.Capability (SHELL_CAPABILITIES[i]);

                    this.capabilities.add (capability);

                    capability.enable ();
                }
            }
            else {
                for (var i=0; i < SHELL_CAPABILITIES.length; i++)
                {
                    var capability = this.capabilities.lookup (SHELL_CAPABILITIES[i]);

                    if (capability == null) {
                        continue;
                    }

                    this.capabilities.remove (capability.name);
                }
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
        private void on_become_active (Gnome.IdleMonitor monitor,
                                       uint              id)
        {
            var timestamp = Pomodoro.get_real_time ();

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
            this.settings = Pomodoro.get_settings ()
                                    .get_child ("preferences");

            this.dialog = Pomodoro.PreferencesDialog.get_default ();

            this.setup_main_page ();
        }

        private void setup_main_page ()
        {
            var main_page = this.dialog.get_page ("main") as Pomodoro.PreferencesMainPage;

            /* toggle/row is defined in the .ui because we would like same feature for other desktops.
             */
            foreach (var child in main_page.other_listbox.get_children ()) {
                if (child.name == "pause-when-idle") {
                    child.show ();
                }
                else if (child.name == "disable-other-notifications") {
                    child.show ();
                }
            }
       }
    }
}


[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
    var object_module = module as Peas.ObjectModule;

    object_module.register_extension_type (typeof (Pomodoro.DesktopExtension),
                                           typeof (GnomePlugin.DesktopExtension));

    object_module.register_extension_type (typeof (Pomodoro.PreferencesDialogExtension),
                                           typeof (GnomePlugin.PreferencesDialogExtension));
}
