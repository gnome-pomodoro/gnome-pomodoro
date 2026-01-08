/*
 * Copyright (c) 2016-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;


namespace Pomodoro
{
    public class SoundsCapability : Pomodoro.Capability
    {
        private Pomodoro.SoundManager? sound_manager = null;

        public SoundsCapability ()
        {
            base ("sounds", Pomodoro.Priority.DEFAULT);
        }

        public override void enable ()
        {
            this.sound_manager = new Pomodoro.SoundManager ();

            base.enable ();
        }

        public override void disable ()
        {
            this.sound_manager = null;

            base.disable ();
        }
    }
}
