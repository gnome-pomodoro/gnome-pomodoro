/*
 * Copyright (c) 2024 gnome-pomodoro contributors
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
