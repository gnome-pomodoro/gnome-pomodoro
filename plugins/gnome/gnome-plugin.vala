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

// TODO: open screen notification when coming back from lockscreen and using fallback-only

namespace GnomePlugin
{
    public class DesktopExtension : Pomodoro.FallbackDesktopExtension  // Pomodoro.BaseDesktopExtension
    {
        private static const string[] SHELL_CAPABILITIES = {
            "notifications",
            "indicator",
            "hotkey",
            "reminders"
        };

        private Pomodoro.CapabilityGroup        capabilities;
        private GnomePlugin.GnomeShellExtension shell_extension;
        private Gnome.IdleMonitor               idle_monitor;
        private uint                            become_active_id = 0;
        private bool                            configured = false;

        construct
        {
            this.idle_monitor = new Gnome.IdleMonitor ();

//            this.notify["presence-status"].connect (this.on_presence_status_notify);

            this.shell_extension = new GnomePlugin.GnomeShellExtension (Config.EXTENSION_UUID);

            this.capabilities = new Pomodoro.CapabilityGroup ();
            this.capabilities.fallback = base.get_capabilities ();
            this.capabilities.enabled_changed.connect (this.on_capability_enabled_changed);
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
                var success = this.shell_extension.enable.end (res);

                if (success) {
                    GLib.debug ("Extension enabled");
                }
                else {
                    // TODO: disable extension
                }

                this.configure.callback ();
            });

            yield;

            /* add capabilities */
            this.on_shell_extension_is_enabled_notify ();

            yield base.configure ();

            this.shell_extension.notify["is-enabled"].connect (this.on_shell_extension_is_enabled_notify);
        }

        private void on_shell_extension_is_enabled_notify ()
        {
            if (this.shell_extension.is_enabled) {
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

//        private void on_presence_status_notify ()
//        {
//            if (this.presence_status == Pomodoro.PresenceStatus.IDLE)
//            {
//                if (this.become_active_id == 0) {
//                    this.become_active_id = this.idle_monitor.add_user_active_watch (this.on_become_active);
//                }
//            }
//            else {
//                if (this.become_active_id != 0) {
//                    this.idle_monitor.remove_watch (this.become_active_id);
//                    this.become_active_id = 0;
//                }
//            }
//        }

//        private void on_become_active (Gnome.IdleMonitor monitor,
//                                       uint              id)
//        {
//            this.presence_status = Pomodoro.PresenceStatus.AVAILABLE;
//        }
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
        }

        ~PreferencesDialogExtension ()
        {
            foreach (var row in this.rows) {
                row.destroy ();
            }

            this.rows = null;
        }

        private Gtk.ListBoxRow create_row (string label,
                                           string name,
                                           string settings_key)
        {
            var name_label = new Gtk.Label (label);
            name_label.halign = Gtk.Align.START;
            name_label.valign = Gtk.Align.BASELINE;

            var value_label = new Gtk.Label (null);
            value_label.halign = Gtk.Align.END;
            value_label.get_style_context ().add_class ("dim-label");

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 30);
            box.pack_start (name_label, true, true, 0);
            box.pack_start (value_label, false, true, 0);

            var row = new Gtk.ListBoxRow ();
            row.name = name;
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

    object_module.register_extension_type (typeof (Pomodoro.DesktopExtension),
                                           typeof (GnomePlugin.DesktopExtension));

    object_module.register_extension_type (typeof (Pomodoro.PreferencesDialogExtension),
                                           typeof (GnomePlugin.PreferencesDialogExtension));
}
