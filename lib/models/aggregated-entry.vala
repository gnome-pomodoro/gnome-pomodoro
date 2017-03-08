/*
 * Copyright (c) 2017 gnome-pomodoro contributors
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
    /**
     * Aggregate daily entries so that it's easier to display / analyse data.
     */
    private class AggregatedEntry : Gom.Resource
    {
        public int64 id { get; construct; }
        public string state_name { get; set; }
        public int64 state_duration { get; set; }
        public GLib.DateTime date { get; set; }
        public int64 elapsed { get; set; }

        static construct
        {
            set_table ("aggregated_entries");
            set_primary_key ("id");
            set_notnull ("state_name");
        }
    }
}
