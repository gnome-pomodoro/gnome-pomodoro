/*
 * Copyright (c) 2014-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;


namespace Ft
{
    private GLib.Settings settings = null;

    public void set_settings (GLib.Settings settings)
    {
        Ft.settings = settings;
    }

    public unowned GLib.Settings get_settings ()
    {
        if (Ft.settings == null) {
            Ft.settings = new GLib.Settings ("io.github.focustimerhq.FocusTimer");

            // TODO: unset Pomodoro.settings at application exit
        }

        return Ft.settings;
    }
}
