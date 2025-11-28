/*
 * Copyright (c) 2024-2025 gnome-pomodoro contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;


namespace Pomodoro
{
    public enum StatsCategory
    {
        POMODORO = 0,
        BREAK = 1,
        INTERRUPTION = 2,
        INVALID = -1;

        public static int from_string (string category)
        {
            switch (category)
            {
                case "pomodoro":
                    return POMODORO;

                case "break":
                    return BREAK;

                case "interruption":
                    return INTERRUPTION;

                default:
                    return INVALID;
            }
        }
    }


    public interface StatsPage : Gtk.Widget
    {
        public abstract GLib.Date date { get; construct; }
    }
}
