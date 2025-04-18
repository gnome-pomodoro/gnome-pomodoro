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
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/stats-day-page.ui")]
    public class StatsDayPage : Gtk.Box, Pomodoro.StatsPage
    {
        private const int64 BUCKET_INTERVAL = 2 * Pomodoro.Interval.HOUR;

        private struct Data
        {
            int64[] histogram_data;
        }

        public GLib.Date date { get; construct; }

        [GtkChild]
        private unowned Pomodoro.Histogram histogram;
        [GtkChild]
        private unowned Pomodoro.StatsCard pomodoro_card;
        [GtkChild]
        private unowned Pomodoro.StatsCard screen_time_card;

        private Pomodoro.StatsManager?    stats_manager;
        private Pomodoro.TimezoneHistory? timezone_history;
        private int64                     start_time;
        private int64                     end_time;
        private Data                      data;

        construct
        {
            this.stats_manager    = new Pomodoro.StatsManager ();
            this.timezone_history = new Pomodoro.TimezoneHistory ();

            this.histogram.set_category_label (Pomodoro.StatsCategory.POMODORO, _("Pomodoro"));
            this.histogram.set_category_label (Pomodoro.StatsCategory.SCREEN_TIME, _("Screen Time"));
            this.histogram.reference_value = 3600.0;  // 1 hour (same as bucket size)
            this.histogram.y_spacing = 1800.0;  // 30 minutes
            this.histogram.set_format_value_func (
                (value) => {
                    return Pomodoro.Interval.format_short (Pomodoro.Interval.from_seconds (value));
                });

            this.timezone_history.changed.connect (this.on_timezone_history_changed);
        }

        public StatsDayPage (GLib.Date date)
        {
            GLib.Object (
                date: date
            );
        }

        /**
         * Update histograms timeline. It may change when user changes timezones.
         */
        private void update_histogram_buckets ()
        {
            var start_datetime = this.stats_manager.get_midnight (this.date);
            var end_datetime   = start_datetime.add_days (1);

            this.start_time    = Pomodoro.Timestamp.from_datetime (start_datetime);
            this.end_time      = Pomodoro.Timestamp.from_datetime (end_datetime);   // TODO: update on time zone change

            // var index = int.max ((int) this.histogram.get_buckets_count () - 1, 0);

            // for (; index <= bucket_index; index++)
            // {
            //     var timestamp = this.start_time + index * BUCKET_INTERVAL;
            //     var timezone  = this.timezone_history.search (timestamp);
            //     var datetime  = Pomodoro.Timestamp.to_datetime (timestamp, timezone);

                // TODO
                // this.histogram.set_bucket_label (
                //     datetime. (),
                // );
            // }
        }

        private void update_buckets ()
        {
            // this.timezone_history.scan (
            //     this.start_time,
            //     this.end_time,
            //     (start_time, end_time, timezone) => {
            //         var datetime = this.transform_timestamp (start_time);
            //     });

            // var hour_start = Pomodoro.StatsManager.MIDNIGHT_OFFSET / Pomodoro.Interval.HOUR;
            // var hour_end = 22;
            // var bucket_interval = BUCKET_INTERVAL / Pomodoro.Interval.HOUR;
            // var bucket_index = 0;

            // for (var hour = hour_start; hour <= hour_end; hour += bucket_interval)
            // {
            //     var hour_value = GLib.Value (typeof (uint));
            //     hour_value.set_uint (hour);

            //     this.histogram.add_bucket ("%d:00".printf (hour), hour_value);
            // }
        }

        private void ensure_bucket (uint bucket_index)
        {
            var index = int.max ((int) this.histogram.get_buckets_count () - 1, 0);

            for (; index <= bucket_index; index++)
            {
                var timestamp = this.start_time + index * BUCKET_INTERVAL;
                var timezone  = this.timezone_history.search (timestamp);
                var datetime  = Pomodoro.Timestamp.to_datetime (timestamp, timezone);

                // TODO
                // this.histogram.set_bucket_label (
                //     datetime. (),
                // );
            }
        }

        private async Gom.ResourceGroup? fetch_entries ()
        {
            var repository = Pomodoro.Database.get_repository ();

            var date_value = GLib.Value (typeof (string));
            date_value.set_string (Pomodoro.Database.serialize_date (this.date));

            var date_filter = new Gom.Filter.eq (
                    typeof (Pomodoro.StatsEntry),
                    "date",
                    date_value);

            var sorting = (Gom.Sorting) GLib.Object.@new (typeof (Gom.Sorting));
            sorting.add (typeof (Pomodoro.StatsEntry), "time", Gom.SortingMode.ASCENDING);

            try {
                var entries = yield repository.find_sorted_async (typeof (Pomodoro.StatsEntry),
                                                                  date_filter,
                                                                  sorting);
                yield entries.fetch_async (0U, entries.count);

                return entries;
            }
            catch (GLib.Error error) {
                GLib.critical ("Error while populating daily stats: %s", error.message);

                return null;
            }
        }

        // private async Data fetch_reference_data (GLib.Date start_date,
        //                                          GLib.Date end_date)
        // {
            // TODO: use aggregated entries
        // }

        private void process_entry (Pomodoro.StatsEntry entry,
                                    int                 sign = 1)
                                    requires (sign == 1 || sign == -1)
        {
            // if (entry.time < this.start_time ||
            //     entry.time >= this.end_time)
            // {
            //     return;
            // }
            if (entry.date != Pomodoro.Database.serialize_date (this.date)) {
                return;
            }

            var category_index = 0U;

            switch (entry.category)
            {
                case "pomodoro":
                    category_index = Pomodoro.StatsCategory.POMODORO;
                    break;

                case "screen-time":
                    category_index = Pomodoro.StatsCategory.SCREEN_TIME;
                    break;

                default:
                    return;
            }

            var bucket_index = (uint) ((entry.time - this.start_time) / BUCKET_INTERVAL);
            this.ensure_bucket (bucket_index);

            this.histogram.add_value (bucket_index,
                                      category_index,
                                      sign * entry.duration);
        }

        private async void populate ()
        {
            // TODO: handle loader?

            this.update_histogram_buckets ();
            // this.update_bucket_labels ();

            var entries = yield this.fetch_entries ();

            this.data = Data () {
                // buckets = new int64[0,2]
            };

            for (var index = 0U; index < entries.count; index++)
            {
                this.process_entry ((Pomodoro.StatsEntry) entries.get_index (index));
            }

            this.pomodoro_card.value = this.histogram.get_category_total (Pomodoro.StatsCategory.POMODORO);
            // this.pomodoro_card.reference_value = random.double_range (0.0, 8.0 * 3600.0);  // TODO

            this.screen_time_card.value = this.histogram.get_category_total (Pomodoro.StatsCategory.SCREEN_TIME);
            // this.screen_time_card.reference_value = this.pomodoro_card.reference_value + random.double_range (0.0, 3.0 * 3600.0);  // TODO
        }

        private void on_entry_saved (Pomodoro.StatsEntry entry)
        {
            // if (entry.date != Pomodoro.Database.serialize_date (this.date)) {
            //     return;
            // }

            if (entry.get_data<bool> ("updated")) {
                assert_not_reached ();  // TODO: schedule populate
            }
            else {
                this.process_entry (entry);
            }
        }

        private void on_entry_deleted (Pomodoro.StatsEntry entry)
        {
            // if (entry.date != Pomodoro.Database.serialize_date (this.date)) {
            //     return;
            // }

            this.process_entry (entry, -1);
        }

        private void on_timezone_history_changed ()
        {
            if (!this.get_mapped ()) {
                return;
            }

            this.populate.begin (
                (obj, res) => {
                    this.populate.end (res);
                });
        }

        private void update_category_colors ()
        {
            var foreground_color = get_foreground_color (this.histogram);
            var background_color = get_background_color (this.histogram);

            foreground_color = blend_colors (background_color, foreground_color);

            var pomodoro_color = foreground_color;
            var screen_time_color = mix_colors (background_color, foreground_color, 0.2f);

            this.histogram.set_category_color (0U, pomodoro_color);
            this.histogram.set_category_color (1U, screen_time_color);
        }

        public override void css_changed (Gtk.CssStyleChange change)
        {
            base.css_changed (change);

            this.update_category_colors ();
        }

        public override void map ()
        {
            this.populate.begin (
                (obj, res) => {
                    this.populate.end (res);

                    this.stats_manager.entry_saved.connect (this.on_entry_saved);
                    this.stats_manager.entry_deleted.connect (this.on_entry_deleted);
                });
        }

        public override void unmap ()
        {
            this.stats_manager.entry_saved.disconnect (this.on_entry_saved);
            this.stats_manager.entry_deleted.disconnect (this.on_entry_deleted);
        }
    }
}


            // SELECT category, SUM(duration) AS total_duration
            //     FROM your_table_name
            //     GROUP BY category;


            /*
            var adapter = Pomodoro.Database.get_repository ().get_adapter ();
            var elapsed = (int64) 0;

            adapter.queue_read (() => {
                Gom.Cursor? cursor = null;

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

                GLib.Idle.add (get_max_elapsed_sum.callback);
            });

            yield;
            */
