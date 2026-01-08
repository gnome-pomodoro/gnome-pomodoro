/*
 * Copyright (c) 2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
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
