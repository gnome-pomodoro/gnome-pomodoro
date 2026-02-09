/*
 * Copyright (c) 2016-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;


namespace Ft
{
    public class SoundsCapability : Ft.Capability
    {
        private Ft.SoundManager? sound_manager = null;

        public SoundsCapability ()
        {
            base ("sounds", Ft.Priority.DEFAULT);
        }

        public override void enable ()
        {
            this.sound_manager = new Ft.SoundManager ();

            base.enable ();
        }

        public override void disable ()
        {
            this.sound_manager = null;

            base.disable ();
        }
    }
}
