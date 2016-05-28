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

namespace Pomodoro
{
    public class CapabilityGroup : GLib.Object
    {
        public Pomodoro.CapabilityGroup? fallback {
            get {
                return this._fallback;
            }
            set {
                var capability_group = value;

                if (capability_group != null) {
                    var capability_names = capability_group.list_names ();

                    for (var i=0; i < capability_names.length; i++) {
                        this.set_capability_fallback (capability_names[i],
                                                      capability_group.lookup (capability_names[i]));
                    }

                    capability_group.added.connect (this.on_fallback_capability_added);
                    capability_group.removed.connect (this.on_fallback_capability_removed);
                }

                if (this._fallback != null) {
                    this._fallback.added.disconnect (this.on_fallback_capability_added);
                    this._fallback.removed.disconnect (this.on_fallback_capability_removed);
                }

                this._fallback = capability_group;
            }
        }

        private GLib.HashTable<string,Pomodoro.Capability> capabilities;
        private Pomodoro.CapabilityGroup                   _fallback;

        construct
        {
            this.capabilities = new GLib.HashTable<string,Pomodoro.Capability?> (str_hash, str_equal);
        }

        public bool contains (string capability_name)
        {
            return this.capabilities.contains (capability_name);
        }

        public unowned Pomodoro.Capability lookup (string capability_name)
        {
            return this.capabilities.lookup (capability_name);
        }

        public string[] list_names ()
        {
            return this.capabilities.get_keys_as_array ();
        }

        public void add (Pomodoro.Capability capability)
        {
            var current_capability = this.capabilities.lookup (capability.name);

            if (capability != current_capability)
            {
                this.connect_capability (capability);

                if (current_capability != null) {
                    this.disconnect_capability (current_capability);

                    capability.fallback = current_capability.is_virtual ()
                                            ? current_capability.fallback : current_capability;

                    this.capabilities.replace (capability.name, capability);
                }
                else {
                    this.capabilities.insert (capability.name, capability);

                    this.added (capability.name);
                }
            }
        }

        public void replace (Pomodoro.Capability capability)
        {
            var current_capability = this.capabilities.lookup (capability.name);

            this.connect_capability (capability);

            if (current_capability != null) {
                this.disconnect_capability (current_capability);

                capability.fallback = current_capability.is_virtual ()
                                        ? current_capability.fallback : current_capability;

                this.capabilities.replace (capability.name, capability);
            }
            else {
                this.capabilities.insert (capability.name, capability);

                this.added (capability.name);
            }
        }

        public void remove (string capability_name)
        {
            var capability = this.lookup (capability_name);

            if (capability != null && !capability.is_virtual ()) {
                this.disconnect_capability (capability);

                if (capability.fallback != null) {
                    var virtual_capability = new Pomodoro.VirtualCapability.with_fallback (capability.fallback);
                    virtual_capability.enabled_request = capability.enabled_request;

                    this.capabilities.replace (capability_name, virtual_capability);
                }
                else {
                    this.capabilities.remove (capability_name);

                    this.removed (capability_name);
                }
            }
        }

        public void add_virtual_capability (Pomodoro.Capability capability)
        {
            this.add (new Pomodoro.VirtualCapability.with_fallback (capability,
                                                                    capability.enabled));
        }

        public void remove_virtual_capability (string capability_name)
        {
            var capability = this.lookup (capability_name);

            if (capability != null && capability.is_virtual ()) {
                this.disconnect_capability (capability);

                this.capabilities.remove (capability_name);

                this.removed (capability_name);
            }
        }

        public bool get_enabled (string capability_name)
        {
            var capability = this.lookup (capability_name);

            return capability != null ? capability.enabled : false;
        }

        public void set_enabled (string capability_name,
                                 bool   enabled)
        {
            var capability = this.lookup (capability_name);

            if (capability != null) {
                capability.enabled_request = enabled;
            }
        }

        public void disable_all ()
        {
            var capability_names = this.list_names ();

            for (var i=0; i < capability_names.length; i++)
            {
                this.set_enabled (capability_names[i], false);
            }
        }

        public void remove_all ()
        {
            var capability_names = this.list_names ();

            for (var i=0; i < capability_names.length; i++)
            {
                this.remove (capability_names[i]);
                this.remove_virtual_capability (capability_names[i]);
            }
        }

        public void set_capability_fallback (string              capability_name,
                                             Pomodoro.Capability fallback_capability)
        {
            var capability = this.lookup (capability_name);

            if (capability != null) {
                capability.fallback = fallback_capability;
            }
            else {
                this.add_virtual_capability (fallback_capability);
            }
        }

        private void connect_capability (Pomodoro.Capability capability)
        {
            capability.notify["enabled"].connect (this.on_capability_enabled_notify);
        }

        private void disconnect_capability (Pomodoro.Capability capability)
        {
            capability.notify["enabled"].disconnect (this.on_capability_enabled_notify);
        }

        private void on_capability_enabled_notify (GLib.Object    object,
                                                   GLib.ParamSpec pspec)
        {
            var capability = object as Pomodoro.Capability;

            this.enabled_changed (capability.name, capability.enabled);
        }

        private void on_fallback_capability_added (Pomodoro.CapabilityGroup capability_group,
                                                   string                   capability_name)
        {
            this.set_capability_fallback (capability_name, capability_group.lookup (capability_name));
        }

        private void on_fallback_capability_removed (Pomodoro.CapabilityGroup capability_group,
                                                     string                   capability_name)
        {
            var capability = this.lookup (capability_name);

            if (capability.is_virtual ()) {
                this.remove_virtual_capability (capability_name);
            }
        }

        public signal void added (string capability_name);

        public signal void removed (string capability_name);

        public signal void enabled_changed (string capability_name,
                                            bool   enabled);
    }
}
