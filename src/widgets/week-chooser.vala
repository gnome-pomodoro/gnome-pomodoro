/*
 * Copyright (c) 2025 gnome-pomodoro contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/week-chooser.ui")]
    public sealed class WeekChooser : Adw.Bin
    {
        private const int DAYS_PER_WEEK = 7;

        public GLib.Date selected_date {
            get {
                return this._selected_date;
            }
            set {
                this._selected_date = value.copy ();

                if (!this._selected_date.valid ()) {
                    this.update_selection ();
                    return;
                }

                var display_month = this._selected_date.get_month ();
                var display_year  = this._selected_date.get_year ();

                if (this._display_month != display_month ||
                    this._display_year != display_year)
                {
                    this.set_display_month_year (display_month, display_year);
                }
                else {
                    this.update_selection ();
                }
            }
        }

        public GLib.Date min_date {
            get {
                return this._min_date;
            }
            set {
                this._min_date = value.copy ();

                this.update_previous_button ();
            }
        }

        public GLib.Date max_date {
            get {
                return this._max_date;
            }
            set {
                this._max_date = value.copy ();

                this.update_next_button ();
            }
        }

        public GLib.DateMonth display_month {
            get {
                return this._display_month;
            }
        }

        public GLib.DateYear display_year {
            get {
                return this._display_year;
            }
        }

        [GtkChild]
        private unowned Gtk.Label header_label;
        [GtkChild]
        private unowned Gtk.Button previous_button;
        [GtkChild]
        private unowned Gtk.Button next_button;
        [GtkChild]
        private unowned Gtk.Box weekdays_box;
        [GtkChild]
        private unowned Gtk.Grid grid;

        private GLib.Date          _selected_date;
        private GLib.Date          _min_date;
        private GLib.Date          _max_date;
        private GLib.DateMonth     _display_month;
        private GLib.DateYear      _display_year;
        private unowned Gtk.Widget selected_button = null;
        private GLib.Date          display_start_date;
        private GLib.Date          display_end_date;

        static construct
        {
            set_css_name ("calendar");
        }

        private void set_display_month_year (GLib.DateMonth month,
                                             GLib.DateYear  year)
        {
            if (this._display_month == month && this._display_year == year) {
                return;
            }

            this._display_month = month;
            this._display_year  = year;

            var display_date = GLib.Date ();
            display_date.set_dmy (1, month, year);

            this.display_start_date = Pomodoro.Timeframe.WEEK.normalize_date (display_date);

            this.display_end_date = display_date.copy ();
            this.display_end_date.add_months (1U);
            this.display_end_date = Pomodoro.Timeframe.WEEK.normalize_date (this.display_end_date);

            if (this.display_end_date.get_month () == display_date.get_month ()) {
                this.display_end_date.add_days (7U);
            }

            this.display_end_date.subtract_days (1U);

            this.update ();

            if (this.get_mapped ()) {
                this.display_changed (this._display_month, this._display_year);
            }
        }

        internal void set_selected_date_full (GLib.Date      value,
                                              GLib.DateMonth display_month,
                                              GLib.DateYear  display_year)
        {
            this._selected_date = value.copy ();

            if (!this._selected_date.valid ()) {
                this.update_selection ();
                return;
            }

            if (this._display_month != display_month ||
                this._display_year != display_year)
            {
                this.set_display_month_year (display_month, display_year);
            }
            else {
                this.update_selection ();
            }
        }

        private Gtk.Button create_week_button (GLib.Date date,
                                               uint      week_number)
        {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            box.homogeneous = true;

            var week_label = new Gtk.Label (@"$(week_number)");
            week_label.add_css_class ("week-number");
            box.append (week_label);

            var day_date = date.copy ();

            for (var day = 1; day <= DAYS_PER_WEEK; day++)
            {
                var day_label = new Gtk.Label (@"$(day_date.get_day())");
                day_label.add_css_class ("day-number");

                if (day_date.get_month () != this._display_month) {
                    day_label.add_css_class ("dim-label");
                }

                box.append (day_label);
                day_date.add_days (1U);
            }

            var button = new Gtk.Button ();
            button.halign = Gtk.Align.FILL;
            button.valign = Gtk.Align.FILL;
            button.height_request = 32;
            button.child = box;
            button.add_css_class ("week");
            button.add_css_class ("pill");
            button.add_css_class ("flat");

            unowned var self = this;
            var date_copy = date.copy ();

            button.clicked.connect (
                () => {
                    self.select (date_copy);
                });

            return button;
        }

        private void clear_weekdays ()
        {
            var child = this.weekdays_box.get_first_child ();

            while (child != null)
            {
                var next_child = child.get_next_sibling ();
                this.weekdays_box.remove (child);
                child = next_child;
            }
        }

        private void clear_weeks ()
        {
            var child = this.grid.get_first_child ();

            while (child != null)
            {
                var next_child = child.get_next_sibling ();
                this.grid.remove (child);
                child = next_child;
            }

            this.selected_button = null;
        }

        /**
         * We place weekday labels as first row of the grid.
         */
        private void update_weekday_labels ()
        {
            this.clear_weekdays ();

            var date = this.display_start_date.copy ();

            var hash_label = new Gtk.Label ("");
            hash_label.xalign = 0.5f;
            hash_label.yalign = 0.5f;
            this.weekdays_box.append (hash_label);

            for (var column = 0; column < DAYS_PER_WEEK; column++)
            {
                var day_name = Pomodoro.DateUtils.format_date (date, "%a");
                var day_letter = day_name.get_char (0).to_string ();

                var label = new Gtk.Label (day_letter);
                label.xalign = 0.5f;
                label.yalign = 0.5f;

                this.weekdays_box.append (label);
                date.add_days (1U);
            }
        }

        private void update_previous_button ()
        {
            this.previous_button.sensitive = !this._min_date.valid () ||
                                             this._display_month > this._min_date.get_month () ||
                                             this._display_year > this._min_date.get_year ();
        }

        private void update_next_button ()
        {
            this.next_button.sensitive = !this._max_date.valid () ||
                                         this._display_month < this._max_date.get_month () ||
                                         this._display_year < this._max_date.get_year ();
        }

        private void update_header ()
        {
            var month_name = Pomodoro.DateUtils.get_month_name (this._display_month);
            var year = (int) this._display_year;

            this.header_label.label = @"$(month_name) $(year)";

            this.update_previous_button ();
            this.update_next_button ();
        }

        private void create_weeks ()
        {
            var week_start_date = this.display_start_date.copy ();
            var week_end_date = week_start_date.copy ();
            week_end_date.add_days (6U);

            var year_start_date = GLib.Date ();
            year_start_date.set_dmy (1, 1, this._display_year);

            var is_min_date_valid = this._min_date.valid ();
            var is_max_date_valid = this._max_date.valid ();
            var first_day_of_week = Pomodoro.Locale.get_first_day_of_week ();
            var week_number_offset = 1U - (
                    first_day_of_week == GLib.DateWeekday.MONDAY
                        ? year_start_date.get_monday_week_of_year ()
                        : year_start_date.get_sunday_week_of_year ()
                    );
            var row = 0;

            while (week_start_date.compare (this.display_end_date) <= 0)
            {
                var week_number = (
                        first_day_of_week == GLib.DateWeekday.MONDAY
                            ? week_end_date.get_monday_week_of_year ()
                            : week_end_date.get_sunday_week_of_year ()
                        ) + week_number_offset;
                var button = this.create_week_button (week_start_date, week_number);
                button.sensitive =
                        (!is_min_date_valid || this._min_date.compare (week_end_date) <= 0) &&
                        (!is_max_date_valid || this._max_date.compare (week_start_date) >= 0);

                this.grid.attach (button, 0, row, 1, 1);

                week_start_date.add_days (7U);
                week_end_date.add_days (7U);
                row++;
            }
        }

        private void update_weeks ()
        {
            if (!this.get_mapped ()) {
                return;
            }

            this.clear_weeks ();
            this.create_weeks ();
        }

        private void update_selection ()
        {
            if (this.selected_button != null) {
                this.selected_button.unset_state_flags (Gtk.StateFlags.SELECTED);
                this.selected_button = null;
            }

            if (this.display_start_date.valid () && this._selected_date.valid ())
            {
                var position = this.display_start_date.days_between (this._selected_date);
                var row      = position / DAYS_PER_WEEK;

                this.selected_button = this.grid.get_child_at (0, row);
                this.selected_button?.set_state_flags (Gtk.StateFlags.SELECTED, false);
            }
        }

        private void update ()
        {
            this.update_header ();
            this.update_weekday_labels ();
            this.update_weeks ();
            this.update_selection ();
        }

        [GtkCallback]
        private void on_previous_button_clicked ()
        {
            var month = this._display_month;
            var year  = this._display_year;

            if (month == GLib.DateMonth.JANUARY) {
                year--;
                month = GLib.DateMonth.DECEMBER;
            }
            else {
                month = (GLib.DateMonth)(Pomodoro.DateUtils.get_month_number (month) - 1U);
            }

            this.set_display_month_year (month, year);
        }

        [GtkCallback]
        private void on_next_button_clicked ()
        {
            var month = this._display_month;
            var year  = this._display_year;

            if (month == GLib.DateMonth.DECEMBER) {
                year++;
                month = GLib.DateMonth.JANUARY;
            }
            else {
                month = (GLib.DateMonth)(Pomodoro.DateUtils.get_month_number (month) + 1U);
            }

            this.set_display_month_year (month, year);
        }

        private bool select (GLib.Date date)
        {
            if (!date.valid ()) {
                return false;
            }

            if (this._selected_date.valid () && this._selected_date.compare (date) == 0) {
                return true;
            }

            this.selected_date = date;

            this.selected (this._selected_date);

            return true;
        }

        public void reset ()
        {
            if (this._selected_date.valid ()) {
                this.set_display_month_year (this._selected_date.get_month (),
                                             this._selected_date.get_year ());
            }
            else {
                var today = Pomodoro.DateUtils.get_today ();

                this.set_display_month_year (today.get_month (), today.get_year ());
            }
        }

        public override void map ()
        {
            this.reset ();
            this.create_weeks ();
            this.update_selection ();

            base.map ();
        }

        public override void unmap ()
        {
            base.unmap ();

            // HACK: CSS animations kick in when widgets gets mapped,
            //       to avoid them just remove children
            this.clear_weeks ();
        }

        public signal void selected (GLib.Date date);

        public signal void display_changed (GLib.DateMonth display_month,
                                            GLib.DateYear  display_year);

        public override void dispose ()
        {
            this.selected_button = null;

            base.dispose ();
        }
    }
}
