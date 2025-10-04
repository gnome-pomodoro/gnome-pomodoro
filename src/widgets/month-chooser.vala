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
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/month-chooser.ui")]
    public sealed class MonthChooser : Adw.Bin
    {
        private const int MONTHS_PER_ROW = 3;

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

                var display_year = this._selected_date.get_year ();

                if (this._display_year != display_year) {
                    this.set_display_year (display_year);
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
        private unowned Gtk.Widget selected_button = null;
        private GLib.DateYear      _display_year;

        static construct
        {
            set_css_name ("calendar");
        }

        private void set_display_year (GLib.DateYear  year)
        {
            if (this._display_year == year) {
                return;
            }

            this._display_year = year;

            this.update ();
        }

        private Gtk.Button create_month_button (GLib.Date date)
        {
            var button = new Gtk.Button ();
            button.label = Pomodoro.DateUtils.format_date (date, "%b");
            button.add_css_class ("pill");
            button.add_css_class ("flat");
            button.add_css_class ("month");

            button.set_data ("calendar-date", date.copy ());
            button.clicked.connect (this.on_month_button_clicked);

            return button;
        }

        private void clear_months ()
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

        private void update_previous_button ()
        {
            this.previous_button.sensitive = !this._min_date.valid () ||
                                             this._display_year > this._min_date.get_year ();
        }

        private void update_next_button ()
        {
            this.next_button.sensitive = !this._max_date.valid () ||
                                         this._display_year < this._max_date.get_year ();
        }

        private void update_header ()
        {
            var year = (int) this._display_year;

            this.header_label.label = @"$(year)";

            this.update_previous_button ();
            this.update_next_button ();
        }

        private void create_months ()
        {
            var date = GLib.Date ();
            date.set_dmy (1, 1, this._display_year);

            var is_min_date_valid = this._min_date.valid ();
            var is_max_date_valid = this._max_date.valid ();
            var row = 0;
            var column = 0;

            for (var month = 1; month <= 12; month++)
            {
                var button = this.create_month_button (date);
                button.sensitive =
                        (!is_min_date_valid || this._min_date.compare (date) <= 0) &&
                        (!is_max_date_valid || this._max_date.compare (date) >= 0);

                this.grid.attach (button, column, row, 1, 1);

                date.add_months (1U);
                column++;

                if (column >= MONTHS_PER_ROW) {
                    column = 0;
                    row++;
                }
            }
        }

        private void update_months ()
        {
            if (!this.get_mapped ()) {
                return;
            }

            this.clear_months ();
            this.create_months ();
        }

        private void update_selection ()
        {
            if (this.selected_button != null) {
                this.selected_button.unset_state_flags (Gtk.StateFlags.SELECTED);
                this.selected_button = null;
            }

            if (this._selected_date.valid () &&
                this._selected_date.get_year () == this._display_year)
            {
                var position = (int) this._selected_date.get_month () - 1;
                var column   = position % MONTHS_PER_ROW;
                var row      = (position - column) / MONTHS_PER_ROW;

                this.selected_button = this.grid.get_child_at (column, row);
                this.selected_button?.set_state_flags (Gtk.StateFlags.SELECTED, false);
            }
        }

        private void update ()
        {
            this.update_header ();
            this.update_months ();
            this.update_selection ();
        }

        [GtkCallback]
        private void on_previous_button_clicked ()
        {
            this.set_display_year (this._display_year - 1);
        }

        [GtkCallback]
        private void on_next_button_clicked ()
        {
            this.set_display_year (this._display_year + 1);
        }

        private void on_month_button_clicked (Gtk.Button button)
        {
            var date = button.get_data<GLib.Date?> ("calendar-date");

            if (date != null) {
                this.select (date);
            }
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
                this.set_display_year (this._selected_date.get_year ());
            }
            else {
                var today = Pomodoro.DateUtils.get_today ();

                this.set_display_year (today.get_year ());
            }
        }

        public override void map ()
        {
            this.reset ();
            this.create_months ();
            this.update_selection ();

            base.map ();
        }

        public override void unmap ()
        {
            base.unmap ();

            // HACK: CSS animations kick in when widgets gets mapped,
            //       to avoid them just remove children
            this.clear_months ();
        }

        public signal void selected (GLib.Date date);

        public override void dispose ()
        {
            this.selected_button = null;

            base.dispose ();
        }
    }
}
