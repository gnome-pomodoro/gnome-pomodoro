/*
 * Copyright (c) 2025 gnome-pomodoro contributors
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
    public class GlobalShortcutsCapability : Pomodoro.Capability
    {
        private Pomodoro.KeyboardManager? keyboard_manager = null;

        public GlobalShortcutsCapability ()
        {
            base ("global-shortcuts", Pomodoro.Priority.DEFAULT);
        }

        private void update_status ()
        {
            this.status = this.keyboard_manager.global_shortcuts_supported
                ? Pomodoro.CapabilityStatus.DISABLED
                : Pomodoro.CapabilityStatus.UNAVAILABLE;
        }

        private void on_global_shortcuts_supported_notify (GLib.Object    object,
                                                           GLib.ParamSpec pspec)
        {
            this.update_status ();
        }

        public override void initialize ()
        {
            if (this.keyboard_manager == null) {
                this.keyboard_manager = new Pomodoro.KeyboardManager ();
                this.keyboard_manager.notify["global-shortcuts-supported"].connect (
                        this.on_global_shortcuts_supported_notify);
            }

            this.update_status ();
        }

        public override void uninitialize ()
        {
            if (this.keyboard_manager != null) {
                this.keyboard_manager.notify["global-shortcuts-supported"].disconnect (
                        this.on_global_shortcuts_supported_notify);
                this.keyboard_manager = null;
            }

            base.uninitialize ();
        }

        public override void enable ()
        {
            this.keyboard_manager.enable_global_shortcuts ();

            base.enable ();
        }

        public override void disable ()
        {
            this.keyboard_manager.disable_global_shortcuts ();

            base.disable ();
        }
    }
}
