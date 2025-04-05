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
    public class StatsEntry : Gom.Resource
    {
        public int64 id { get; set; }
        public int64 time { get; set; }
        public string date { get; set; }
        public int64 offset { get; set; }
        public int64 duration { get; set; }
        public string category { get; set; }
        public int64 source_id { get; set; default = 0; }

        static construct
        {
            set_table ("stats");
            set_primary_key ("id");
            set_notnull ("time");
            set_notnull ("date");
            set_notnull ("offset");
            set_notnull ("category");

            // `source-id` may reference `timeblocks` and `gaps` tables.
            // Therefore, we treat it like an integer.
        }
    }


    /**
     * Model for aggregated daily stats
     */
    public class AggregatedStatsEntry : Gom.Resource
    {
        public int64 id { get; set; }
        public string date { get; set; }
        public string category { get; set; }
        public int64 duration { get; set; }

        static construct
        {
            set_table ("aggregatedstats");
            set_primary_key ("id");
            set_notnull ("date");
            set_notnull ("category");
        }
    }
}
