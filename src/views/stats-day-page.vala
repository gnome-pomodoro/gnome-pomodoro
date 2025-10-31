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
    public class StatsDayPage : Adw.Bin, Pomodoro.StatsPage
    {
        private const int64 DEFAULT_INTERVAL = 1 * Pomodoro.Interval.HOUR;
        private const int64 MIN_INTERVAL = 15 * Pomodoro.Interval.MINUTE;
        private const int64 MAX_INTERVAL = 2 * Pomodoro.Interval.HOUR;

        // Default display hours for histogram x-axis
        private const int BASE_START_HOUR = 9;
        private const int BASE_END_HOUR = 17;

        // Minimum number of bars displayed
        private const int MIN_HISTOGRAM_BAR_COUNT = 8;

        // Minimum duration threshold for range expansion
        private const int64 MIN_SIGNIFICANT_DURATION = Pomodoro.Interval.MINUTE;

        public GLib.Date date { get; construct; }

        [CCode (notify = false)]
        public int64 interval {
            get {
                return this._interval;
            }
            set {
                value = value.clamp (MIN_INTERVAL, MAX_INTERVAL);

                if (this._interval == value) {
                    return;
                }

                this._interval = value;

                this.on_interval_notify ();
                this.notify_property ("interval");
            }
        }

        [GtkChild]
        private unowned Gtk.Revealer toolbar_revealer;
        [GtkChild]
        private unowned Gtk.Button zoom_in_button;
        [GtkChild]
        private unowned Gtk.Button zoom_out_button;
        [GtkChild]
        private unowned Pomodoro.BarChart histogram;
        [GtkChild]
        private unowned Pomodoro.StatsCard pomodoro_card;
        [GtkChild]
        private unowned Pomodoro.StatsCard breaks_card;
        [GtkChild]
        private unowned Pomodoro.StatsCard interruptions_card;
        [GtkChild]
        private unowned Pomodoro.StatsCard break_ratio_card;

        private int64                     _interval = DEFAULT_INTERVAL;
        private Pomodoro.StatsManager?    stats_manager;
        private Pomodoro.TimezoneHistory? timezone_history;
        private GLib.DateTime?            datetime;
        private int64                     timestamp;
        private int64                     start_time;
        private int64                     end_time;
        private int64                     entries_start_time = Pomodoro.Timestamp.UNDEFINED;
        private int64                     entries_end_time = Pomodoro.Timestamp.UNDEFINED;
        private string                    time_format;
        private Pomodoro.Matrix?          histogram_data;

        construct
        {
            this.stats_manager    = new Pomodoro.StatsManager ();
            this.timezone_history = new Pomodoro.TimezoneHistory ();
            this.datetime         = this.stats_manager.get_midnight (this.date);
            this.timestamp        = Pomodoro.Timestamp.from_datetime (this.datetime);

            this.histogram.set_category_label (
                    Pomodoro.StatsCategory.POMODORO, _("Pomodoro"));
            this.histogram.set_category_unit (
                    Pomodoro.StatsCategory.POMODORO, Pomodoro.Unit.INTERVAL);

            this.histogram.set_category_label (
                    Pomodoro.StatsCategory.BREAK, _("Breaks"));
            this.histogram.set_category_unit (
                    Pomodoro.StatsCategory.BREAK, Pomodoro.Unit.INTERVAL);

            this.update_time_format ();
            this.update_histogram_y_spacing ();

            this.stats_manager.entry_saved.connect (this.on_entry_saved);
            this.stats_manager.entry_deleted.connect (this.on_entry_deleted);

            this.populate.begin (
                (obj, res) => {
                    this.populate.end (res);
                });
        }

        public StatsDayPage (GLib.Date date)
        {
            GLib.Object (
                date: date
            );
        }

        /**
         * Create data container sampled at `MIN_INTERVAL` for the whole day.
         * `this.histogram` by comparison is holding displayed time range only.
         */
        private Pomodoro.Matrix create_histogram_data ()
        {
            // Add a buffer of 12h for potential timezone changes or other edge cases
            var bucket_count = (uint)(36 * Pomodoro.Interval.HOUR / MIN_INTERVAL);

            return new Pomodoro.Matrix (bucket_count, this.histogram.get_categories_count ());
        }

        private static string format_hours (double value)
        {
            return Pomodoro.Interval.format_short (Pomodoro.Interval.from_seconds (value),
                                                   Pomodoro.Interval.HOUR);
        }

        private static string format_minutes (double value)
        {
            return Pomodoro.Interval.format_short (Pomodoro.Interval.from_seconds (value),
                                                   Pomodoro.Interval.MINUTE);
        }

        private inline string format_time (GLib.DateTime datetime)
        {
            var time_string = datetime.format (this.time_format);

            if (time_string.has_prefix ("0")) {
                time_string = time_string.substring (1);
            }

            return time_string;
        }

        private void ensure_histogram_data ()
        {
            if (this.histogram_data == null) {
                this.histogram_data = this.create_histogram_data ();
            }
        }

        private void update_category_colors ()
        {
            var foreground_color = this.histogram.get_color ();
            var pomodoro_color = Pomodoro.get_chart_primary_color (foreground_color);
            var break_color = Pomodoro.get_chart_secondary_color (foreground_color);

            this.histogram.set_category_color (Pomodoro.StatsCategory.POMODORO, pomodoro_color);
            this.histogram.set_category_color (Pomodoro.StatsCategory.BREAK, break_color);
        }

        private void update_time_format ()
        {
            var use_12h_format = Pomodoro.Locale.use_12h_format ();
            var time_format = "%H";

            if (this._interval < Pomodoro.Interval.HOUR || !use_12h_format) {
                time_format += ":%M";
            }

            if (use_12h_format) {
                time_format = time_format.replace ("%H", "%I") + " %p";
            }

            this.time_format = time_format;
        }

        private void update_histogram_y_spacing ()
        {
            var y_spacing = this._interval <= Pomodoro.Interval.HOUR
                    ? (float) Pomodoro.Interval.to_seconds (this._interval) / 3.0f
                    : 3600.0f;

            this.histogram.y_spacing = y_spacing;
            this.histogram.reference_value = (float) Pomodoro.Interval.to_seconds (this._interval);

            if (y_spacing >= 3600.0f) {
                this.histogram.set_format_value_func (format_hours);
            }
            else {
                this.histogram.set_format_value_func (format_minutes);
            }
        }

        private void update_histogram_buckets ()
        {
            var datetimes = new GLib.DateTime[0];
            var timestamp = this.start_time;

            this.timezone_history.scan (
                this.start_time,
                this.end_time + this._interval,
                (start_time, end_time, timezone) => {
                    while (timestamp < end_time) {
                        datetimes += Pomodoro.Timestamp.to_datetime (timestamp, timezone);
                        timestamp += this._interval;
                    }
                });

            // Update bar labels
            this.histogram.remove_all_bars ();

            for (var bar_index = 0; bar_index < datetimes.length - 1; bar_index++)
            {
                var bar_label = this.format_time (datetimes[bar_index]);
                var tooltip_label = "%s － %s".printf (
                        bar_label,
                        this.format_time (datetimes[bar_index + 1]));

                this.histogram.set_bar_label (bar_index, bar_label, tooltip_label);
            }
        }

        /**
         * Set a transform from `bar_index` to `bucket_index`
         */
        private void update_histogram_transform ()
        {
            var bars_per_bucket = this._interval / MIN_INTERVAL;
            var bucket_start_index = (this.start_time - this.timestamp) / MIN_INTERVAL;

            this.histogram.set_transform (
                    (double) bars_per_bucket,
                    (double) bucket_start_index);
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
                GLib.critical ("Error while fetching daily stats: %s", error.message);

                return null;
            }
        }

        private void extend_time_range (int64 entry_start_time,
                                        int64 entry_end_time)
        {
            var changed = false;

            if (this.entries_start_time > entry_start_time) {
                this.entries_start_time = entry_start_time;
                changed = true;
            }

            if (this.entries_end_time < entry_end_time) {
                this.entries_end_time = entry_end_time;
                changed = true;
            }

            if (changed) {
                this.update_time_range ();
                this.update_histogram_transform ();
                this.update_histogram_buckets ();
            }
        }

        private void process_entry (Pomodoro.StatsEntry entry,
                                    int                 sign = 1)
                                    requires (sign == 1 || sign == -1)
        {
            GLib.return_if_fail (this.histogram_data != null);

            var entry_category = Pomodoro.StatsCategory.from_string (entry.category);
            var entry_time     = entry.time;
            var entry_duration = entry.duration;

            // Validate if entry is relevant
            if (entry_category == Pomodoro.StatsCategory.INVALID) {
                return;
            }

            if (entry.date != Pomodoro.Database.serialize_date (this.date)) {
                return;
            }

            // Validate time range
            if (entry_time < this.timestamp) {
                entry_duration -= this.timestamp - entry_time;
                entry_time = this.timestamp;
            }

            if (entry_category != Pomodoro.StatsCategory.INTERRUPTION &&
                entry_duration >= MIN_SIGNIFICANT_DURATION)
            {
                this.extend_time_range (entry_time, entry_time + entry_duration);
            }

            // Update histogram
            // Quantize entry range into buckets
            var bucket_index       = (int) ((entry_time - this.timestamp) / MIN_INTERVAL);
            var category_index     = (int) entry_category;
            var bars_per_bucket    = (int) (this._interval / MIN_INTERVAL);
            var bucket_start_index = (int) ((this.start_time - this.timestamp) / MIN_INTERVAL);
            var remaining_duration = entry_duration;
            var remaining_offset   = entry_time - (this.timestamp + bucket_index * MIN_INTERVAL);

            while (remaining_duration > 0 &&
                   bucket_index < this.histogram_data.shape[0] &&
                   category_index < this.histogram_data.shape[1] &&
                   category_index != Pomodoro.StatsCategory.INTERRUPTION)
            {
                var consumed_duration = int64.min (remaining_duration,
                                                   MIN_INTERVAL - remaining_offset);
                var bucket_value = Pomodoro.Interval.to_seconds (sign * consumed_duration);

                this.histogram_data.add_value (bucket_index, category_index, bucket_value);

                if (bucket_index >= bucket_start_index)
                {
                    var bar_index = (bucket_index - bucket_start_index) / bars_per_bucket;

                    this.histogram.add_value (bar_index, category_index, bucket_value);
                }

                remaining_duration -= consumed_duration;
                remaining_offset = 0;
                bucket_index++;
            }

            // Update cards
            switch (entry_category)
            {
                case Pomodoro.StatsCategory.POMODORO:
                    this.pomodoro_card.value += Pomodoro.Interval.to_seconds (sign * entry_duration);
                    break;

                case Pomodoro.StatsCategory.BREAK:
                    this.breaks_card.value += Pomodoro.Interval.to_seconds (sign * entry_duration);
                    break;

                case Pomodoro.StatsCategory.INTERRUPTION:
                    this.interruptions_card.value += (double) sign;
                    break;

                default:
                    // no matching card in UI
                    break;
            }

            var total = this.pomodoro_card.value + this.breaks_card.value;

            this.break_ratio_card.value = total >= 3600.0
                    ? this.breaks_card.value / total
                    : double.NAN;
        }

        /**
         * Fill histogram with aggregated data
         */
        private void aggregate_data ()
        {
            this.histogram.fill (0.0);

            if (this.histogram_data == null) {
                return;
            }

            assert (this.start_time >= this.timestamp);

            var bucket_start_index = (int) ((this.start_time - this.timestamp) / MIN_INTERVAL);
            var bucket_end_index   = (int) ((this.end_time - this.timestamp) / MIN_INTERVAL);
            var buckets_per_bar    = (int) (this._interval / MIN_INTERVAL);
            var categories_count   = (int) this.histogram_data.shape[1];

            if (bucket_start_index < 0) {
                bucket_start_index = 0;
            }

            for (var category_index = 0; category_index < categories_count; category_index++)
            {
                for (var bucket_index = bucket_start_index;
                     bucket_index < bucket_end_index;
                     bucket_index++)
                {
                    var bar_index = (bucket_index - bucket_start_index) / buckets_per_bar;
                    var bucket_value = this.histogram_data.@get (bucket_index, category_index, 0.0);

                    this.histogram.add_value (bar_index, category_index, bucket_value);
                }
            }
        }

        /**
         * Calculate time range for given entries
         */
        private void update_entries_time_range (Gom.ResourceGroup? entries)
        {
            this.entries_start_time = Pomodoro.Timestamp.UNDEFINED;
            this.entries_end_time = Pomodoro.Timestamp.UNDEFINED;

            if (entries == null) {
                return;
            }

            for (var index = 0U; index < entries.count; index++)
            {
                var entry = (Pomodoro.StatsEntry) entries.get_index (index);
                var entry_start_time = entry.time;
                var entry_end_time = entry.time + entry.duration;

                if (entry.duration < MIN_SIGNIFICANT_DURATION) {
                    continue;
                }

                // XXX: we do not validate category here

                if (entry_start_time < this.entries_start_time ||
                    Pomodoro.Timestamp.is_undefined (this.entries_start_time))
                {
                    this.entries_start_time = entry_start_time;
                }

                if (entry_end_time > this.entries_end_time ||
                    Pomodoro.Timestamp.is_undefined (this.entries_end_time))
                {
                    this.entries_end_time = entry_end_time;
                }
            }
        }

        /**
         * Calculate display time range based on default work hours and entries
         */
        private void update_time_range ()
        {
            var midnight_hour = (int)(
                    Pomodoro.StatsManager.MIDNIGHT_OFFSET / Pomodoro.Interval.HOUR);

            // Ensure time range includes working hours
            var start_time = Pomodoro.Timestamp.from_datetime (
                    this.datetime.add_hours (BASE_START_HOUR - midnight_hour));
            var end_time = Pomodoro.Timestamp.from_datetime (
                    this.datetime.add_hours (BASE_END_HOUR - midnight_hour));

            // Extend time range to entries
            if (Pomodoro.Timestamp.is_defined (this.entries_start_time) &&
                start_time > this.entries_start_time)
            {
                start_time = this.entries_start_time;
            }

            if (Pomodoro.Timestamp.is_defined (this.entries_end_time) &&
                end_time < this.entries_end_time)
            {
                end_time = this.entries_end_time;
            }

            // Round time range to `this._interval`
            start_time = this.timestamp + this._interval * (
                    (start_time - this.timestamp) / this._interval);
            end_time = (end_time - start_time) % this._interval != 0
                    ? start_time + this._interval * ((end_time - start_time) / this._interval + 1)
                    : start_time + this._interval * ((end_time - start_time) / this._interval);

            // Ensure minimum number of bars when zoomed out
            var bar_count = (int)((end_time - start_time) / this._interval);

            if (bar_count < MIN_HISTOGRAM_BAR_COUNT)
            {
                start_time = int64.max (
                        this.timestamp,
                        start_time - ((MIN_HISTOGRAM_BAR_COUNT - bar_count) / 2) * this._interval);
                end_time = int64.max (
                        end_time,
                        start_time + MIN_HISTOGRAM_BAR_COUNT * this._interval);
            }

            this.start_time = start_time;
            this.end_time = end_time;
        }

        private void reset ()
        {
            this.ensure_histogram_data ();

            this.histogram_data.fill (0.0);
            this.histogram.fill (0.0);
            this.pomodoro_card.value = 0.0;
            this.breaks_card.value = 0.0;
            this.interruptions_card.value = 0.0;
            this.break_ratio_card.value = double.NAN;
        }

        private async void populate ()
        {
            var entries = yield this.fetch_entries ();

            this.update_entries_time_range (entries);
            this.update_time_range ();
            this.update_histogram_y_spacing ();
            this.update_histogram_transform ();
            this.update_histogram_buckets ();

            this.reset ();

            for (var index = 0U; index < entries.count; index++) {
                this.process_entry ((Pomodoro.StatsEntry) entries.get_index (index));
            }
        }

        private void invalidate_histogram_data ()
        {
            this.histogram_data = null;
        }

        private void on_interval_notify ()
        {
            this.update_time_format ();
            this.update_time_range ();
            this.update_histogram_y_spacing ();
            this.update_histogram_transform ();
            this.update_histogram_buckets ();
            this.aggregate_data ();

            this.zoom_in_button.sensitive = this._interval > MIN_INTERVAL;
            this.zoom_out_button.sensitive = this._interval < MAX_INTERVAL;
        }

        private void on_entry_saved (Pomodoro.StatsEntry entry)
        {
            if (this.histogram_data != null) {
                this.process_entry (entry, 1);
            }
        }

        private void on_entry_deleted (Pomodoro.StatsEntry entry)
        {
            if (this.histogram_data != null) {
                this.process_entry (entry, -1);
            }
        }

        private void on_timezone_history_changed ()
        {
            if (this.get_mapped ()) {
                this.populate.begin (
                    (obj, res) => {
                        this.populate.end (res);
                    });
            }
            else {
                this.invalidate_histogram_data ();
            }
        }

        [GtkCallback]
        private void on_zoom_in ()
        {
            this.interval = (this._interval / 2).clamp (MIN_INTERVAL, MAX_INTERVAL);
        }

        [GtkCallback]
        private void on_zoom_out ()
        {
            this.interval = (this._interval * 2).clamp (MIN_INTERVAL, MAX_INTERVAL);
        }

        [GtkCallback]
        private void on_histogram_enter (double x,
                                         double y)
        {
            this.toolbar_revealer.reveal_child = true;
        }

        [GtkCallback]
        private void on_histogram_leave ()
        {
            this.toolbar_revealer.reveal_child = false;
        }

        public override void css_changed (Gtk.CssStyleChange change)
        {
            base.css_changed (change);

            this.update_category_colors ();
        }

        public override void dispose ()
        {
            this.histogram.set_format_value_func (null);
            this.stats_manager.entry_saved.disconnect (this.on_entry_saved);
            this.stats_manager.entry_deleted.disconnect (this.on_entry_deleted);
            this.timezone_history.changed.disconnect (this.on_timezone_history_changed);

            this.stats_manager = null;
            this.timezone_history = null;
            this.datetime = null;
            this.histogram_data = null;

            base.dispose ();
        }
    }
}

