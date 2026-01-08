/*
 * Copyright (c) 2017-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;


namespace Pomodoro
{
    [GtkTemplate (ui = "/io/github/focustimerhq/FocusTimer/ui/main/stats/stats-week-page.ui")]
    public class StatsWeekPage : Adw.Bin, Pomodoro.StatsPage
    {
        public GLib.Date date { get; construct; }

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

        private Pomodoro.StatsManager? stats_manager;
        private GLib.Date              start_date;
        private GLib.Date              end_date;

        construct
        {
            this.stats_manager = new Pomodoro.StatsManager ();
            this.stats_manager.entry_saved.connect (this.on_entry_saved);
            this.stats_manager.entry_deleted.connect (this.on_entry_deleted);

            this.histogram.set_format_value_func (format_hours);

            this.histogram.set_category_label (
                    Pomodoro.StatsCategory.POMODORO, _("Pomodoro"));
            this.histogram.set_category_unit (
                    Pomodoro.StatsCategory.POMODORO, Pomodoro.Unit.INTERVAL);

            this.histogram.set_category_label (
                    Pomodoro.StatsCategory.BREAK, _("Breaks"));
            this.histogram.set_category_unit (
                    Pomodoro.StatsCategory.BREAK, Pomodoro.Unit.INTERVAL);

            this.histogram.set_category_label (
                    Pomodoro.StatsCategory.INTERRUPTION, _("Interruptions"));
            this.histogram.set_category_unit (
                    Pomodoro.StatsCategory.INTERRUPTION, Pomodoro.Unit.AMOUNT);
            this.histogram.set_category_visible (
                    Pomodoro.StatsCategory.INTERRUPTION, false);

            this.start_date = Pomodoro.Timeframe.WEEK.normalize_date (this.date);
            this.end_date = this.start_date.copy ();
            this.end_date.add_days (6U);

            this.populate.begin (
                (obj, res) => {
                    this.populate.end (res);
                });
        }

        public StatsWeekPage (GLib.Date date)
        {
            GLib.Object (
                date: date
            );
        }

        private static string format_hours (double value)
        {
            return Pomodoro.Interval.format_short (Pomodoro.Interval.from_seconds (value),
                                                   Pomodoro.Interval.HOUR);
        }

        private GLib.Date transform_position (uint bar_index)
        {
            var date = this.start_date.copy ();
            date.add_days (bar_index);

            return date;
        }

        private void reset ()
        {
            this.histogram.fill (0.0);
            this.pomodoro_card.value = 0.0;
            this.breaks_card.value = 0.0;
            this.interruptions_card.value = 0.0;
            this.break_ratio_card.value = double.NAN;
        }

        private void update_category_colors ()
        {
            var foreground_color = this.histogram.get_color ();
            var pomodoro_color = Pomodoro.get_chart_primary_color (foreground_color);
            var break_color = Pomodoro.get_chart_secondary_color (foreground_color);

            this.histogram.set_category_color (Pomodoro.StatsCategory.POMODORO, pomodoro_color);
            this.histogram.set_category_color (Pomodoro.StatsCategory.BREAK, break_color);
        }

        private void update_histogram_labels ()
        {
            var date = this.start_date.copy ();

            for (var bar_index = 0; bar_index <= 6; bar_index++)
            {
                var bar_label = capitalize_words (
                        Pomodoro.DateUtils.format_date (date, "%a"));
                var tooltip_label = capitalize_words (
                        Pomodoro.DateUtils.format_date (date, "%e %B"));

                this.histogram.set_bar_label (bar_index, bar_label, tooltip_label);

                date.add_days (1U);
            }
        }

        private async Gom.ResourceGroup? fetch_aggregated_entries ()
        {
            var repository = Pomodoro.Database.get_repository ();

            var start_date_value = GLib.Value (typeof (string));
            start_date_value.set_string (Pomodoro.Database.serialize_date (this.start_date));

            var end_date_value = GLib.Value (typeof (string));
            end_date_value.set_string (Pomodoro.Database.serialize_date (this.end_date));

            var start_date_filter = new Gom.Filter.gte (
                    typeof (Pomodoro.AggregatedStatsEntry),
                    "date",
                    start_date_value);
            var end_date_filter = new Gom.Filter.lte (
                    typeof (Pomodoro.AggregatedStatsEntry),
                    "date",
                    end_date_value);
            var date_filter = new Gom.Filter.and (start_date_filter, end_date_filter);

            try {
                var aggregated_entries = yield repository.find_async (
                        typeof (Pomodoro.AggregatedStatsEntry),
                        date_filter);
                yield aggregated_entries.fetch_async (0U, aggregated_entries.count);

                return aggregated_entries;
            }
            catch (GLib.Error error) {
                GLib.critical ("Error while fetching weekly stats: %s", error.message);

                return null;
            }
        }

        private void process_aggregated_entry (Pomodoro.AggregatedStatsEntry entry)
        {
            var entry_category = Pomodoro.StatsCategory.from_string (entry.category);
            var entry_date     = Pomodoro.Database.parse_date (entry.date);
            var entry_duration = entry.duration;

            // Validate if entry is relevant
            if (entry_category == Pomodoro.StatsCategory.INVALID) {
                return;
            }

            // Update histogram
            var bar_index      = (uint) int.max (this.start_date.days_between (entry_date), 0);
            var category_index = (int) entry_category;
            var bucket_value   = entry_category != Pomodoro.StatsCategory.INTERRUPTION
                    ? Pomodoro.Interval.to_seconds (entry_duration)
                    : (double) entry.count;

            this.histogram.add_value (bar_index,
                                      category_index,
                                      bucket_value);

            // Update cards
            switch (entry_category)
            {
                case Pomodoro.StatsCategory.POMODORO:
                    this.pomodoro_card.value += bucket_value;
                    break;

                case Pomodoro.StatsCategory.BREAK:
                    this.breaks_card.value += bucket_value;
                    break;

                case Pomodoro.StatsCategory.INTERRUPTION:
                    this.interruptions_card.value += bucket_value;
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

        private void process_entry (Pomodoro.StatsEntry entry,
                                    int                 sign = 1)
                                    requires (sign == 1 || sign == -1)
        {
            var entry_category = Pomodoro.StatsCategory.from_string (entry.category);
            var entry_date     = Pomodoro.Database.parse_date (entry.date);
            var entry_duration = entry.duration;

            // Validate if entry is relevant
            if (entry_category == Pomodoro.StatsCategory.INVALID) {
                return;
            }

            // Validate date range
            if (entry_date.compare (this.start_date) < 0 ||
                entry_date.compare (this.end_date) > 0)
            {
                return;
            }

            // Update histogram
            var bar_index      = (uint) int.max (this.start_date.days_between (entry_date), 0);
            var category_index = (int) entry_category;
            var bucket_value   = entry_category != Pomodoro.StatsCategory.INTERRUPTION
                    ? Pomodoro.Interval.to_seconds (sign * entry_duration)
                    : (double) sign;

            this.histogram.add_value (bar_index,
                                      category_index,
                                      bucket_value);

            // Update cards
            switch (entry_category)
            {
                case Pomodoro.StatsCategory.POMODORO:
                    this.pomodoro_card.value += bucket_value;
                    break;

                case Pomodoro.StatsCategory.BREAK:
                    this.breaks_card.value += bucket_value;
                    break;

                case Pomodoro.StatsCategory.INTERRUPTION:
                    this.interruptions_card.value += bucket_value;
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

        private async void populate ()
        {
            var aggregated_entries = yield this.fetch_aggregated_entries ();

            this.update_histogram_labels ();

            this.reset ();

            for (var index = 0U; index < aggregated_entries.count; index++) {
                this.process_aggregated_entry (
                        (Pomodoro.AggregatedStatsEntry) aggregated_entries.get_index (index));
            }
        }

        private void on_entry_saved (Pomodoro.StatsEntry entry)
        {
            this.process_entry (entry, 1);
        }

        private void on_entry_deleted (Pomodoro.StatsEntry entry)
        {
            this.process_entry (entry, -1);
        }

        [GtkCallback]
        private void on_bar_activated (uint bar_index)
        {
            var date = this.transform_position (bar_index);

            this.activate_action_variant (
                    "stats.select-day",
                    Pomodoro.DateUtils.date_to_variant (date));
        }

        public override void css_changed (Gtk.CssStyleChange change)
        {
            base.css_changed (change);

            this.update_category_colors ();
        }

        public override void dispose ()
        {
            this.histogram.set_format_value_func (null);

            if (this.stats_manager != null) {
                this.stats_manager.entry_saved.disconnect (this.on_entry_saved);
                this.stats_manager.entry_deleted.disconnect (this.on_entry_deleted);
                this.stats_manager = null;
            }

            base.dispose ();
        }
    }
}
