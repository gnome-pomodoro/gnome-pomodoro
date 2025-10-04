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
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/stats-month-page.ui")]
    public class StatsMonthPage : Adw.Bin, Pomodoro.StatsPage
    {
        private const int DAYS_PER_WEEK = 7;

        public GLib.Date date { get; construct; }

        [GtkChild]
        private unowned Pomodoro.BubbleChart bubble_chart;
        [GtkChild]
        private unowned Pomodoro.StatsCard pomodoro_card;
        [GtkChild]
        private unowned Pomodoro.StatsCard breaks_card;
        [GtkChild]
        private unowned Pomodoro.StatsCard interruptions_card;
        [GtkChild]
        private unowned Pomodoro.StatsCard break_ratio_card;

        private Pomodoro.StatsManager? stats_manager;
        private GLib.Date              display_start_date;
        private GLib.Date              display_end_date;

        construct
        {
            this.stats_manager = new Pomodoro.StatsManager ();
            this.stats_manager.entry_saved.connect (this.on_entry_saved);
            this.stats_manager.entry_deleted.connect (this.on_entry_deleted);

            this.bubble_chart.category = Pomodoro.StatsCategory.POMODORO;

            this.bubble_chart.set_category_label (
                    Pomodoro.StatsCategory.POMODORO, _("Pomodoro"));
            this.bubble_chart.set_category_unit (
                    Pomodoro.StatsCategory.POMODORO, Pomodoro.Unit.INTERVAL);

            this.bubble_chart.set_category_label (
                    Pomodoro.StatsCategory.BREAK, _("Breaks"));
            this.bubble_chart.set_category_unit (
                    Pomodoro.StatsCategory.BREAK, Pomodoro.Unit.INTERVAL);

            this.bubble_chart.set_category_label (
                    Pomodoro.StatsCategory.INTERRUPTION, _("Interruptions"));
            this.bubble_chart.set_category_unit (
                    Pomodoro.StatsCategory.INTERRUPTION, Pomodoro.Unit.AMOUNT);

            var month = this.date.get_month ();
            var year = this.date.get_year ();

            var month_start_date = GLib.Date ();
            month_start_date.set_dmy (1, month, year);

            var month_end_date = GLib.Date ();
            month_end_date.set_dmy (GLib.Date.get_days_in_month (month, year), month, year);

            this.display_start_date = Pomodoro.Timeframe.WEEK.normalize_date (month_start_date);
            this.display_end_date   = Pomodoro.Timeframe.WEEK.normalize_date (month_end_date);
            this.display_end_date.add_days (6U);

            this.populate.begin (
                (obj, res) => {
                    this.populate.end (res);
                });
        }

        public StatsMonthPage (GLib.Date date)
        {
            GLib.Object (
                date: date
            );
        }

        private bool transform_date (GLib.Date date,
                                     out uint  row,
                                     out uint  column)
        {
            var position = this.display_start_date.days_between (date);

            if (position >= 0) {
                column = position % DAYS_PER_WEEK;
                row    = position / DAYS_PER_WEEK;

                return true;
            }
            else {
                column = 0;
                row = 0;

                return false;
            }
        }

        private GLib.Date transform_position (uint row,
                                              uint column)
        {
            var date = this.display_start_date.copy ();
            date.add_days (DAYS_PER_WEEK * row + column);

            return date;
        }

        private void reset ()
        {
            this.bubble_chart.fill (0.0);
            this.pomodoro_card.value = 0.0;
            this.breaks_card.value = 0.0;
            this.interruptions_card.value = 0.0;
            this.break_ratio_card.value = double.NAN;
        }

        private void update_category_colors ()
        {
            var foreground_color = get_foreground_color (this.bubble_chart);
            var background_color = get_background_color (this.bubble_chart);

            foreground_color = blend_colors (background_color, foreground_color);

            var pomodoro_color = foreground_color;
            var break_color = mix_colors (background_color, foreground_color, 0.2f);

            this.bubble_chart.set_category_color (Pomodoro.StatsCategory.POMODORO, pomodoro_color);
            this.bubble_chart.set_category_color (Pomodoro.StatsCategory.BREAK, break_color);
        }

        private void update_bubble_chart_labels ()
        {
            var year_start_date = GLib.Date ();
            year_start_date.set_dmy (1, 1, this.date.get_year ());

            var date = this.display_start_date.copy ();
            var first_day_of_week = Pomodoro.Locale.get_first_day_of_week ();
            var week_number_offset = 1U - (
                    first_day_of_week == GLib.DateWeekday.MONDAY
                        ? year_start_date.get_monday_week_of_year ()
                        : year_start_date.get_sunday_week_of_year ()
                    );
            var row = 0;
            var column = 0;

            while (date.compare (this.display_end_date) <= 0)
            {
                var tooltip_label = capitalize_words (
                        Pomodoro.DateUtils.format_date (date, "%e %B"));

                this.bubble_chart.set_bubble_tooltip_label (row, column, tooltip_label);

                if (row == 0)
                {
                    var weekday_name = capitalize_words (
                        Pomodoro.DateUtils.format_date (date, "%a"));

                    this.bubble_chart.set_column_label (column, weekday_name);
                }

                if (column == 0)
                {
                    var week_end_date = date.copy ();
                    week_end_date.add_days (6U);

                    var week_number = (
                        first_day_of_week == GLib.DateWeekday.MONDAY
                            ? week_end_date.get_monday_week_of_year ()
                            : week_end_date.get_sunday_week_of_year ()
                        ) + week_number_offset;

                    this.bubble_chart.set_row_label (row, @"$(week_number)");
                }

                if (date.get_month () != this.date.get_month ()) {
                    this.bubble_chart.set_bubble_inverted (row, column, true);
                }

                date.add_days (1U);
                column++;

                if (column >= DAYS_PER_WEEK) {
                    column = 0;
                    row++;
                }
            }
        }

        private async Gom.ResourceGroup? fetch_aggregated_entries ()
        {
            var repository = Pomodoro.Database.get_repository ();

            var start_date_value = GLib.Value (typeof (string));
            start_date_value.set_string (Pomodoro.Database.serialize_date (this.display_start_date));

            var end_date_value = GLib.Value (typeof (string));
            end_date_value.set_string (Pomodoro.Database.serialize_date (this.display_end_date));

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

            // Update bubble chart
            var category_index = (uint) entry_category;
            uint row, column;

            if (!this.transform_date (entry_date, out row, out column)) {
                return;
            }

            var bucket_value = entry_category != Pomodoro.StatsCategory.INTERRUPTION
                    ? Pomodoro.Interval.to_seconds (entry_duration)
                    : (double) entry.count;

            this.bubble_chart.add_value (row,
                                         column,
                                         category_index,
                                         bucket_value);

            // Update cards
            if (entry_date.get_month () == this.date.get_month ())
            {
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
            if (entry_date.compare (this.display_start_date) < 0 ||
                entry_date.compare (this.display_end_date) > 0)
            {
                return;
            }

            // Update bubble chart
            uint row, column;

            if (!this.transform_date (entry_date, out row, out column)) {
                return;
            }

            var bucket_value = entry_category != Pomodoro.StatsCategory.INTERRUPTION
                    ? Pomodoro.Interval.to_seconds (sign * entry_duration)
                    : (double) sign;

            this.bubble_chart.add_value (row,
                                         column,
                                         (uint) entry_category,
                                         bucket_value);

            // Update cards
            if (entry_date.get_month () != this.date.get_month ()) {
                return;
            }

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

            this.update_bubble_chart_labels ();

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
        private void on_bubble_activated (uint row,
                                          uint column)
        {
            var date = this.transform_position (row, column);

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
            if (this.stats_manager != null) {
                this.stats_manager.entry_saved.disconnect (this.on_entry_saved);
                this.stats_manager.entry_deleted.disconnect (this.on_entry_deleted);
                this.stats_manager = null;
            }

            base.dispose ();
        }
    }
}
