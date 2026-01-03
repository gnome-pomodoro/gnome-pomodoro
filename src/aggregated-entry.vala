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
    internal class AggregatedEntry : Gom.Resource
    {
        public const string DATE_FORMAT = "%Y-%m-%d";

        public int64 id { get; set; }
        public string date_string { get; set; }
        public string state_name { get; set; }
        public int64 state_duration { get; set; }
        public int64 elapsed { get; set; }

        static construct
        {
            set_table ("aggregated-entries");
            set_primary_key ("id");
            set_notnull ("state-name");
            set_notnull ("date-string");
        }

        private static async int64 get_max_elapsed_sum (string group_by_sql)
        {
            var adapter = get_repository ().get_adapter ();
            var elapsed = (int64) 0;

            adapter.queue_read (() => {
                // var cursor = (Gom.Cursor) GLib.Object.@new (typeof (Gom.Cursor));
                Gom.Cursor cursor;

                var command = (Gom.Command) GLib.Object.@new (typeof (Gom.Command),
                                                              adapter: adapter);
                command.set_sql ("""
SELECT """ + group_by_sql + """ AS "group", SUM("elapsed") AS "elapsed-sum"
    FROM "aggregated-entries"
    GROUP BY "group"
    ORDER BY "elapsed-sum" DESC
    LIMIT 1;
""");

                try {
                    command.execute (out cursor);

                    if (cursor != null && cursor.next ()) {
                        elapsed = cursor.get_column_int64 (1);
                    }
                    else {
                        GLib.assert_not_reached ();
                    }
                }
                catch (GLib.Error error) {
                    GLib.critical ("%s", error.message);
                }

                Idle.add (get_max_elapsed_sum.callback);
            });

            yield;

            return elapsed;
        }

        public static async int64 get_baseline_daily_elapsed ()
        {
            return yield get_max_elapsed_sum ("\"date-string\"");
        }

        public static async int64 get_baseline_weekly_elapsed ()
        {
            return yield get_max_elapsed_sum ("strftime('%Y-%W', \"date-string\")");
        }

        public static async int64 get_baseline_monthly_elapsed ()
        {
            return yield get_max_elapsed_sum ("strftime('%Y-%m', \"date-string\")");
        }

        public static async int64 get_baseline_yearly_elapsed ()
        {
            return yield get_max_elapsed_sum ("strftime('%Y', \"date-string\")");
        }

        public struct TodayStats
        {
            public int64 focus_time;
            public int64 break_time;
            public int focus_count;
            public int break_count;
        }

        /**
         * Get statistics for today (focus time, break time, session counts)
         */
        public static async TodayStats get_today_stats ()
        {
            var adapter = get_repository ().get_adapter ();
            TodayStats stats = TodayStats ();
            stats.focus_time = 0;
            stats.break_time = 0;
            stats.focus_count = 0;
            stats.break_count = 0;

            adapter.queue_read (() => {
                Gom.Cursor cursor;

                var today = new GLib.DateTime.now_local ();
                var date_string = today.format (DATE_FORMAT);

                var command = (Gom.Command) GLib.Object.@new (typeof (Gom.Command),
                                                              adapter: adapter);
                command.set_sql ("""
SELECT "state-name", SUM("elapsed") AS "total-elapsed", SUM("state-duration") AS "total-duration"
    FROM "aggregated-entries"
    WHERE "date-string" = '%s'
    GROUP BY "state-name";
""".printf (date_string));

                try {
                    command.execute (out cursor);

                    while (cursor != null && cursor.next ()) {
                        var state_name = cursor.get_column_string (0);
                        var elapsed = cursor.get_column_int64 (1);
                        var duration = cursor.get_column_int64 (2);

                        if (state_name == "pomodoro") {
                            stats.focus_time = elapsed;
                            stats.focus_count = (int) (duration > 0 ? duration / 1500 : 0);  // assuming 25min pomodoros
                        }
                        else if (state_name == "short-break" || state_name == "long-break") {
                            stats.break_time += elapsed;
                            stats.break_count++;
                        }
                    }
                }
                catch (GLib.Error error) {
                    GLib.critical ("%s", error.message);
                }

                Idle.add (get_today_stats.callback);
            });

            yield;

            return stats;
        }

        public struct LifetimeStats
        {
            public int64 total_focus_time;
            public int64 total_break_time;
            public int total_sessions;
            public int total_days_active;
        }

        /**
         * Get lifetime statistics (total focus time, total break time, total sessions)
         */
        public static async LifetimeStats get_lifetime_stats ()
        {
            var adapter = get_repository ().get_adapter ();
            LifetimeStats stats = LifetimeStats ();
            stats.total_focus_time = 0;
            stats.total_break_time = 0;
            stats.total_sessions = 0;
            stats.total_days_active = 0;

            adapter.queue_read (() => {
                Gom.Cursor cursor;

                var command = (Gom.Command) GLib.Object.@new (typeof (Gom.Command),
                                                              adapter: adapter);
                command.set_sql ("""
SELECT "state-name", SUM("elapsed") AS "total-elapsed", COUNT(DISTINCT "date-string") AS "days"
    FROM "aggregated-entries"
    GROUP BY "state-name";
""");

                try {
                    command.execute (out cursor);

                    while (cursor != null && cursor.next ()) {
                        var state_name = cursor.get_column_string (0);
                        var elapsed = cursor.get_column_int64 (1);
                        var days = (int) cursor.get_column_int64 (2);

                        if (state_name == "pomodoro") {
                            stats.total_focus_time = elapsed;
                            stats.total_sessions = (int) (elapsed / 1500);  // rough estimate
                            stats.total_days_active = int.max (stats.total_days_active, days);
                        }
                        else if (state_name == "short-break" || state_name == "long-break") {
                            stats.total_break_time += elapsed;
                            stats.total_days_active = int.max (stats.total_days_active, days);
                        }
                    }
                }
                catch (GLib.Error error) {
                    GLib.critical ("%s", error.message);
                }

                Idle.add (get_lifetime_stats.callback);
            });

            yield;

            return stats;
        }

        /**
         * Get yearly data for chart (monthly breakdown)
         */
        public static async int64[] get_year_data (int year)
        {
            var adapter = get_repository ().get_adapter ();
            int64[] monthly_data = new int64[12];

            // Initialize with zeros for all 12 months
            for (int i = 0; i < 12; i++) {
                monthly_data[i] = 0;
            }

            adapter.queue_read (() => {
                Gom.Cursor cursor;

                var command = (Gom.Command) GLib.Object.@new (typeof (Gom.Command),
                                                              adapter: adapter);
                command.set_sql ("""
SELECT strftime('%%m', "date-string") AS "month", SUM("elapsed") AS "total-elapsed"
    FROM "aggregated-entries"
    WHERE strftime('%%Y', "date-string") = '%d' AND "state-name" = 'pomodoro'
    GROUP BY "month"
    ORDER BY "month";
""".printf (year));

                try {
                    command.execute (out cursor);

                    while (cursor != null && cursor.next ()) {
                        var month_str = cursor.get_column_string (0);
                        var elapsed = cursor.get_column_int64 (1);
                        var month_index = int.parse (month_str) - 1;

                        if (month_index >= 0 && month_index < 12) {
                            monthly_data[month_index] = elapsed;
                        }
                    }
                }
                catch (GLib.Error error) {
                    GLib.critical ("%s", error.message);
                }

                Idle.add (get_year_data.callback);
            });

            yield;

            return monthly_data;
        }
    }
}
