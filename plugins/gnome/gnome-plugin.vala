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
    public class DesktopExtension : Pomodoro.FallbackDesktopExtension
    {
        private static const string[] SHELL_CAPABILITIES = {
            "notifications",
            "indicator",
            "reminders"
        };

        private GLib.Settings                   settings;
        private Pomodoro.CapabilityGroup        capabilities;
        private GnomePlugin.GnomeShellExtension shell_extension;
        private Gnome.IdleMonitor               idle_monitor;
        private Gnome.Shell                     shell_proxy;
//        private uint                            become_active_id = 0;
        private uint                            accelerator_id = 0;

        construct
        {
            this.settings = Pomodoro.get_settings ().get_child ("preferences");

            this.idle_monitor = new Gnome.IdleMonitor ();

//            this.notify["presence-status"].connect (this.on_presence_status_notify);

            this.shell_extension = new GnomePlugin.GnomeShellExtension (Config.EXTENSION_UUID);

            this.capabilities = new Pomodoro.CapabilityGroup ();
            this.capabilities.fallback = base.get_capabilities ();
            this.capabilities.enabled_changed.connect (this.on_capability_enabled_changed);

            this.settings.changed["toggle-timer-key"].connect (this.on_toggle_timer_key_changed);
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
            yield this.connect_shell ();

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

        private async void connect_shell ()
        {
            if (this.shell_proxy == null)
            {
                GLib.Bus.get_proxy.begin<Gnome.Shell> (GLib.BusType.SESSION,
                                                       "org.gnome.Shell",
                                                       "/org/gnome/Shell",
                                                       GLib.DBusProxyFlags.DO_NOT_AUTO_START,
                                                       null,
                                                       (obj, res) =>
                {
                    try
                    {
                        this.shell_proxy = GLib.Bus.get_proxy.end (res);

                        this.shell_connected (this.shell_proxy);
                    }
                    catch (GLib.IOError error)
                    {
                        GLib.critical ("%s", error.message);
                    }

                    this.connect_shell.callback ();
                });

                yield;
            }
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

        private void on_toggle_timer_key_changed ()
        {
            var capability = this.capabilities.lookup ("hotkey");

            if (capability != null && capability.enabled) {
                capability.disable ();
                capability.enable ();
            }
        }

        public virtual signal void shell_connected (Gnome.Shell proxy)
        {
            var hotkey_capability = new Pomodoro.Capability (Pomodoro.Capabilities.HOTKEY);

            hotkey_capability.enabled_signal.connect (() => {
                try {
                    this.accelerator_id = proxy.grab_accelerator (this.settings.get_string ("toggle-timer-key"),
                                                                  Gnome.ActionMode.ALL);

                    proxy.accelerator_activated.connect (this.on_accelerator_activated);
                }
                catch (GLib.IOError error) {
                    GLib.warning ("error while grabbing accelerator: %s", error.message);
                }
            });

            hotkey_capability.disabled_signal.connect (() => {
                try {
                    if (this.accelerator_id != 0) {
                        proxy.ungrab_accelerator (this.accelerator_id);
                        this.accelerator_id = 0;
                    }
                }
                catch (GLib.IOError error) {
                    GLib.warning ("error while ungrabbing accelerator: %s", error.message);
                }

                proxy.accelerator_activated.disconnect (this.on_accelerator_activated);
            });

            hotkey_capability.enable ();

            this.capabilities.add (hotkey_capability);
        }

        public virtual signal void shell_disconnected (Gnome.Shell proxy)
        {
            this.capabilities.remove (Pomodoro.Capabilities.HOTKEY);
        }

        private void on_accelerator_activated (uint32 action,
                                               GLib.HashTable<string, GLib.Variant> accelerator_params)
        {
            var timer = Pomodoro.Timer.get_default ();

            timer.toggle ();
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

        construct
        {
            this.dialog = Pomodoro.PreferencesDialog.get_default ();
        }

        ~PreferencesDialogExtension ()
        {
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
