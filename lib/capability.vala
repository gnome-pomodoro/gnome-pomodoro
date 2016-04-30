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
    public class Capability : GLib.InitiallyUnowned
    {
        public string name { get; set; }

        [CCode (notify = false)]
        public bool enabled {  /* TODO rename to "is_enabled" */
            get {
                return this.is_inhibited () ? false : this.enabled_request;
            }
        }

        [CCode (notify = false)]
        public bool enabled_request {  /* TODO rename to "is_requested" */
            get {
                return this._enabled_request;
            }
            set {
                if (this._enabled_request != value) {
                    this._enabled_request = value;

                    this.notify_property ("enabled-request");

                    if (!this.is_inhibited ()) {
                        this.notify_property ("enabled");
                    }
                }
            }
            default = false;
        }

        [CCode (notify = false)]
        public unowned Pomodoro.Capability? fallback {
            get {
                return this._fallback;
            }
            set {
                var new_fallback = value;

                if (this._fallback != new_fallback)
                {
                    if (this.enabled_binding != null) {
                        this.enabled_binding.unbind ();
                    }

                    if (new_fallback != null)
                    {
                        if (this.is_virtual ()) {
                            this.enabled_binding = this.bind_property ("enabled-request",
                                                                       new_fallback,
                                                                       "enabled-request",
                                                                       GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL);
                        }
                        else {
                            new_fallback.inhibit ();
                        }
                    }

                    if (this._fallback != null && !this.is_virtual ()) {
                        this._fallback.uninhibit ();
                    }

                    this._fallback = new_fallback;
                    this.notify_property ("fallback");
                }
            }
        }

        private Pomodoro.Capability? _fallback;
        private bool                 _enabled_request;
        private int                  inhibit_count = 0;
        private GLib.Binding         enabled_binding;

        construct
        {
            this.notify["enabled"].connect (() => {
                if (this.enabled) {
                    this.enabled_signal ();
                }
                else {
                    this.disabled_signal ();
                }
            });
        }

        public Capability (string name,
                           bool   enabled = false)
        {
            this.name            = name;
            this.enabled_request = enabled;
        }

        public Capability.with_fallback (Pomodoro.Capability fallback,
                                         bool                enabled = false)
        {
            this.name            = fallback.name;
            this.enabled_request = enabled;
            this.fallback        = fallback;
        }

        public bool is_enabled ()
        {
            return this.enabled;
        }

        public bool is_virtual ()
        {
            return this is Pomodoro.VirtualCapability;
        }

        public bool is_inhibited ()
        {
            return this.inhibit_count > 0;
        }

        public override void dispose ()
        {
            if (this.enabled_binding != null) {
                this.enabled_binding.unbind ();
            }

            if (this.fallback != null && !this.is_virtual ()) {
                this.fallback.uninhibit ();
            }

            base.dispose ();
        }

        public bool enable ()
        {
            this.enabled_request = true;

            return this.enabled == true;
        }

        public bool disable ()
        {
            this.enabled_request = false;

            return this.enabled == false;
        }

        public void inhibit ()
        {
            this.inhibit_count += 1;

            if (this.inhibit_count == 1) {
                this.notify_property ("enabled");
            }
        }

        public void uninhibit ()
        {
            this.inhibit_count -= 1;

            if (this.inhibit_count == 0) {
                this.notify_property ("enabled");
            }
        }

        public signal void enabled_signal ();

        public signal void disabled_signal ();

//        private void on_fallback_toggle_ref_notify (GLib.Object fallback_object, bool is_last_ref)
//        {
//            if (is_last_ref) {
//                this._fallback = null;
//
//                this.set_fallback_full (null, this.is_virtual);
//            }
//        }
    }

    public class VirtualCapability : Pomodoro.Capability
    {
        public VirtualCapability (string name,
                                  bool   enabled = true)
        {
            base (name, enabled);
        }

        public VirtualCapability.with_fallback (Pomodoro.Capability fallback,
                                                bool                enabled = true)
        {
            assert (fallback != null);

            base.with_fallback (fallback, enabled);
        }
    }
}
