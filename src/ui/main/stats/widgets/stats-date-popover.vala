/*
 * Copyright (c) 2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;


namespace Pomodoro
{
    [GtkTemplate (ui = "/io/github/focustimerhq/FocusTimer/ui/main/stats/widgets/stats-date-popover.ui")]
    public class StatsDatePopover : Gtk.Popover
    {
        [CCode (notify = false)]
        public Pomodoro.Timeframe timeframe {
            get {
                return this._timeframe;
            }
            set {
                var date = this.refine_date (this._date, this._timeframe);

                this.set_date_timeframe (date, value);
            }
        }

        [CCode (notify = false)]
        public GLib.Date date {
            get {
                return this._date;
            }
            set {
                if (!value.valid ()) {
                    return;
                }

                this.set_date_timeframe (value, this._timeframe);
            }
        }

        public GLib.Date min_date {
            get {
                return this._min_date;
            }
            set {
                if (this._min_date.valid () && this._min_date.compare (value) == 0) {
                    return;
                }

                this._min_date = value;

                this.update_date_range ();
            }
        }

        public GLib.Date max_date {
            get {
                return this._max_date;
            }
            set {
                if (this._max_date.valid () && this._max_date.compare (value) == 0) {
                    return;
                }

                this._max_date = value;

                this.update_date_range ();
            }
        }

        [GtkChild]
        private unowned Adw.ToggleGroup timeframe_toggle_group;
        [GtkChild]
        private unowned Pomodoro.DayChooser day_chooser;
        [GtkChild]
        private unowned Pomodoro.WeekChooser week_chooser;
        [GtkChild]
        private unowned Pomodoro.MonthChooser month_chooser;

        private Pomodoro.Timeframe _timeframe = Pomodoro.Timeframe.DAY;
        private GLib.Date          _date;
        private GLib.Date          _min_date;
        private GLib.Date          _max_date;
        private GLib.Date          user_selected_date;

        construct
        {
            this.bind_property (
                    "timeframe",
                    this.timeframe_toggle_group,
                    "active-name",
                    GLib.BindingFlags.SYNC_CREATE,
                    transform_from_timeframe,
                    transform_to_timeframe);
        }

        private static bool transform_from_timeframe (GLib.Binding   binding,
                                                      GLib.Value     source_value,
                                                      ref GLib.Value target_value)
        {
            var timeframe = (Pomodoro.Timeframe) source_value.get_enum ();

            target_value.set_string (timeframe.to_string ());

            return true;
        }

        private static bool transform_to_timeframe (GLib.Binding   binding,
                                                    GLib.Value     source_value,
                                                    ref GLib.Value target_value)
        {
            var timeframe = Pomodoro.Timeframe.from_string (source_value.get_string ());

            target_value.set_enum (timeframe);

            return true;
        }

        private void get_display_month_year (out GLib.DateMonth display_month,
                                             out GLib.DateYear  display_year)
        {
            switch (this._timeframe)
            {
                case Pomodoro.Timeframe.DAY:
                    display_month = this.day_chooser.display_month;
                    display_year = this.day_chooser.display_year;
                    break;

                case Pomodoro.Timeframe.WEEK:
                    display_month = this.week_chooser.display_month;
                    display_year = this.week_chooser.display_year;
                    break;

                case Pomodoro.Timeframe.MONTH:
                    display_month = this._date.valid () ? this._date.get_month () : GLib.DateMonth.BAD_MONTH;
                    display_year = this.month_chooser.display_year;
                    break;

                default:
                    assert_not_reached ();
            }

            if (!display_month.valid () || !display_year.valid ())
            {
                var today = Pomodoro.DateUtils.get_today ();

                display_month = today.get_month ();
                display_year = today.get_year ();
            }
        }

        private void update_selection (GLib.DateMonth display_month,
                                       GLib.DateYear  display_year)
        {
            if (!this._date.valid ())
            {
                this.day_chooser.selected_date = GLib.Date ();
                this.week_chooser.selected_date = GLib.Date ();
                this.month_chooser.selected_date = GLib.Date ();

                return;
            }

            this.day_chooser.selected_date = this._timeframe == Pomodoro.Timeframe.DAY
                    ? Pomodoro.Timeframe.DAY.normalize_date (this._date)
                    : GLib.Date ();
            this.month_chooser.selected_date = this._timeframe == Pomodoro.Timeframe.MONTH
                    ? Pomodoro.Timeframe.MONTH.normalize_date (this._date)
                    : GLib.Date ();

            if (this._timeframe == Pomodoro.Timeframe.WEEK)
            {
                var week_start_date = Pomodoro.Timeframe.WEEK.normalize_date (this._date);
                var week_end_date = week_start_date.copy ();
                week_end_date.add_days (6U);

                var display_date = GLib.Date ();
                display_date.set_dmy (1, display_month, display_year);

                if (week_start_date.compare (display_date) >= 0) {
                    this.week_chooser.set_selected_date_full (
                            Pomodoro.Timeframe.WEEK.normalize_date (this._date),
                            week_start_date.get_month (),
                            week_start_date.get_year ());
                }
                else {
                    this.week_chooser.set_selected_date_full (
                            Pomodoro.Timeframe.WEEK.normalize_date (this._date),
                            week_end_date.get_month (),
                            week_end_date.get_year ());
                }
            }
            else {
                this.week_chooser.selected_date = GLib.Date ();
            }
        }

        private void update_date_range ()
        {
            this.day_chooser.min_date = Pomodoro.Timeframe.DAY.normalize_date (this._min_date);
            this.day_chooser.max_date = Pomodoro.Timeframe.DAY.normalize_date (this._max_date);

            this.week_chooser.min_date = Pomodoro.Timeframe.WEEK.normalize_date (this._min_date);
            this.week_chooser.max_date = Pomodoro.Timeframe.WEEK.normalize_date (this._max_date);

            this.month_chooser.min_date = Pomodoro.Timeframe.MONTH.normalize_date (this._min_date);
            this.month_chooser.max_date = Pomodoro.Timeframe.MONTH.normalize_date (this._max_date);
        }

        private void set_date_timeframe (GLib.Date          date,
                                         Pomodoro.Timeframe timeframe)
        {
            GLib.DateMonth display_month;
            GLib.DateYear  display_year;

            this.get_display_month_year (out display_month, out display_year);

            date = timeframe.normalize_date (date);

            var date_changed = this._date.valid ()
                    ? this._date.compare (date) != 0
                    : date.valid ();
            var timeframe_changed = this._timeframe != timeframe;

            this._timeframe = timeframe;
            this._date = date;

            if (timeframe_changed || date_changed) {
                this.update_selection (display_month, display_year);
            }

            if (timeframe_changed) {
                this.notify_property ("timeframe");
            }

            if (date_changed) {
                this.notify_property ("date");
            }
        }

        /**
         * Refinement tries to recover lost resolution at higher timeframes.
         *
         * When selecting a higher timeframes we may loose user intent. We want to transition
         * between "this month", "this week" and "today" while switching timeframes.
         */
        private GLib.Date refine_date (GLib.Date          date,
                                       Pomodoro.Timeframe date_timeframe,
                                       GLib.DateMonth     display_month = GLib.DateMonth.BAD_MONTH,
                                       GLib.DateYear      display_year = GLib.DateYear.BAD_YEAR)
        {
            var today = Pomodoro.DateUtils.get_today ();
            var refined_date = date.copy ();

            if (!date.valid ()) {
                return this.user_selected_date.valid ()
                        ? this.user_selected_date : today;
            }

            switch (date_timeframe)
            {
                case Pomodoro.Timeframe.DAY:
                    break;

                case Pomodoro.Timeframe.WEEK:
                    var week_start_date = date.copy ();
                    var week_end_date = date.copy ();
                    week_end_date.add_days (6U);

                    var display_date = GLib.Date ();

                    if (display_month.valid () && display_year.valid ()) {
                        display_date.set_dmy (1, display_month, display_year);
                    }

                    if (display_date.valid () &&
                        week_start_date.get_month () != week_end_date.get_month ())
                    {
                        if (display_date.compare (week_start_date) <= 0)
                        {
                            var month = week_start_date.get_month ();
                            var year = week_start_date.get_year ();

                            week_end_date.set_dmy (
                                    GLib.Date.get_days_in_month (month, year),
                                    month,
                                    year);
                        }
                        else {
                            week_start_date.set_dmy (
                                    1,
                                    week_end_date.get_month (),
                                    week_end_date.get_year ());
                        }
                    }

                    if (this.user_selected_date.valid () &&
                        this.user_selected_date.compare (week_start_date) >= 0 &&
                        this.user_selected_date.compare (week_end_date) <= 0)
                    {
                        refined_date = this.user_selected_date.copy ();
                    }
                    else if (today.compare (week_start_date) >= 0 &&
                             today.compare (week_end_date) <= 0)
                    {
                        refined_date = today.copy ();
                    }
                    else if (date.compare (week_start_date) < 0) {
                        refined_date = week_start_date.copy ();
                    }
                    else if (date.compare (week_end_date) > 0) {
                        refined_date = week_end_date.copy ();
                    }

                    break;

                case Pomodoro.Timeframe.MONTH:
                    if (this.user_selected_date.valid () &&
                        this.user_selected_date.get_month () == date.get_month () &&
                        this.user_selected_date.get_year () == date.get_year ())
                    {
                        refined_date = this.user_selected_date.copy ();
                    }
                    else if (date.get_month () == today.get_month () &&
                             date.get_year () == today.get_year ())
                    {
                        refined_date = today.copy ();
                    }

                    break;

                default:
                    assert_not_reached ();
            }

            if (this._min_date.valid () && this._min_date.compare (refined_date) > 0) {
                refined_date = this._min_date.copy ();
            }

            if (this._max_date.valid () && this._max_date.compare (refined_date) < 0) {
                refined_date = this._max_date.copy ();
            }

            return refined_date;
        }

        [GtkCallback]
        private void on_notify_active_name (GLib.Object    object,
                                            GLib.ParamSpec pspec)
        {
            // Detect user selection
            var timeframe = Pomodoro.Timeframe.from_string (
                    this.timeframe_toggle_group.active_name);

            if (timeframe != this._timeframe) {
                this.timeframe_selected (timeframe);
            }
        }

        [GtkCallback]
        private void on_day_selected (GLib.Date date)
        {
            this.user_selected_date = date.copy ();

            this.date_selected (this.user_selected_date);
        }

        [GtkCallback]
        private void on_week_selected (GLib.Date date)
        {
            this.user_selected_date = this.refine_date (date, Pomodoro.Timeframe.WEEK);

            this.date_selected (this.user_selected_date);
        }

        [GtkCallback]
        private void on_month_selected (GLib.Date date)
        {
            this.user_selected_date = this.refine_date (date, Pomodoro.Timeframe.MONTH);

            this.date_selected (this.user_selected_date);
        }

        [GtkCallback]
        private void on_week_display_changed (GLib.DateMonth display_month,
                                              GLib.DateYear  display_year)
        {
            this.user_selected_date = this.refine_date (this._date,
                                                        Pomodoro.Timeframe.WEEK,
                                                        display_month,
                                                        display_year);
            this.date_selected (this.user_selected_date);
        }

        public override void unmap ()
        {
            base.unmap ();

            this.user_selected_date = GLib.Date ();
        }

        [Signal (run = "last")]
        public signal void timeframe_selected (Pomodoro.Timeframe timeframe)
        {
            this.timeframe = timeframe;
        }

        [Signal (run = "last")]
        public signal void date_selected (GLib.Date date)
        {
            this.date = date;
        }
    }
}
