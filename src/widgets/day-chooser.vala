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
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/day-chooser.ui")]
    public sealed class DayChooser : Adw.Bin
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

            var month_start_date = GLib.Date ();
            month_start_date.set_dmy (1, month, year);

            var month_end_date = GLib.Date ();
            month_end_date.set_dmy (GLib.Date.get_days_in_month (month, year), month, year);

            this._display_month     = month;
            this._display_year      = year;
            this.display_start_date = Pomodoro.Timeframe.WEEK.normalize_date (month_start_date);
            this.display_end_date   = Pomodoro.Timeframe.WEEK.normalize_date (month_end_date);
            this.display_end_date.add_days (6U);

            this.update ();
        }

        private Gtk.Button create_day_button (GLib.Date date)
        {
            var button = new Gtk.Button ();
            button.label = date.get_day ().to_string ();
            button.add_css_class ("circular");
            button.add_css_class ("flat");
            button.add_css_class ("day");
            button.width_request = 32;
            button.height_request = 32;

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
            var child = this.grid.get_first_child ();
            int row;

            while (child != null)
            {
                this.grid.query_child (child, null, out row, null, null);

                if (row == 0) {
                    var next_child = child.get_next_sibling ();
                    this.grid.remove (child);
                    child = next_child;
                }
                else {
                    child = child.get_next_sibling ();
                }
            }
        }

        private void clear_days ()
        {
            var child = this.grid.get_first_child ();
            int row;

            while (child != null)
            {
                this.grid.query_child (child, null, out row, null, null);

                if (row != 0) {
                    var next_child = child.get_next_sibling ();
                    this.grid.remove (child);
                    child = next_child;
                }
                else {
                    child = child.get_next_sibling ();
                }
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

            for (var column = 0; column < DAYS_PER_WEEK; column++)
            {
                var day_name = Pomodoro.DateUtils.format_date (date, "%a");
                var day_letter = day_name.get_char (0).to_string ();

                var label = new Gtk.Label (day_letter);
                label.add_css_class ("dim-label");
                label.add_css_class ("weekday");
                label.xalign = 0.5f;
                label.yalign = 0.5f;

                this.grid.attach (label, column, 0, 1, 1);

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

        private void create_days ()
        {
            var date = this.display_start_date.copy ();
            var is_min_date_valid = this._min_date.valid ();
            var is_max_date_valid = this._max_date.valid ();
            var row = 1;
            var column = 0;

            while (date.compare (this.display_end_date) <= 0)
            {
                var button = this.create_day_button (date);
                button.sensitive =
                        (!is_min_date_valid || this._min_date.compare (date) <= 0) &&
                        (!is_max_date_valid || this._max_date.compare (date) >= 0);

                if (date.get_month () != this._display_month) {
                    button.add_css_class ("dim-label");
                }

                this.grid.attach (button, column, row, 1, 1);

                date.add_days (1U);
                column++;

                if (column >= DAYS_PER_WEEK) {
                    column = 0;
                    row++;
                }
            }
        }

        private void update_days ()
        {
            if (!this.get_mapped ()) {
                return;
            }

            this.clear_days ();
            this.create_days ();
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
                var column   = position % DAYS_PER_WEEK;
                var row      = 1 + (position - column) / DAYS_PER_WEEK;

                this.selected_button = this.grid.get_child_at (column, row);
                this.selected_button?.set_state_flags (Gtk.StateFlags.SELECTED, false);
            }
        }

        private void update ()
        {
            this.update_header ();
            this.update_weekday_labels ();
            this.update_days ();
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
            this.create_days ();
            this.update_selection ();

            base.map ();
        }

        public override void unmap ()
        {
            base.unmap ();

            // HACK: CSS animations kick in when widgets gets mapped,
            //       to avoid them just remove children
            this.clear_days ();
        }

        public signal void selected (GLib.Date date);

        public override void dispose ()
        {
            this.selected_button = null;

            base.dispose ();
        }
    }
}
