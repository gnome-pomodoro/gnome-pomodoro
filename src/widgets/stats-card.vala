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
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/stats-card.ui")]
    public class StatsCard : Adw.Bin
    {
        public string label { get; set; }

        public Pomodoro.Unit unit {
            get {
                return this._unit;
            }
            set {
                this._unit = value;

                this.schedule_update ();
            }
        }

        public double value {
            get {
                return this._value;
            }
            set {
                this._value = value;

                this.schedule_update ();
            }
        }

        public double reference_value {
            get {
                return this._reference_value;
            }
            set {
                this._reference_value = value;

                this.schedule_update ();
            }
        }

        [GtkChild]
        private unowned Gtk.Label value_label;
        [GtkChild]
        private unowned Gtk.Label value_difference_label;

        private Pomodoro.Unit _unit = Pomodoro.Unit.AMOUNT;
        private double        _value;
        private double        _reference_value = double.NAN;
        private uint          update_idle_id = 0;

        static construct
        {
            set_css_name ("statscard");
        }

        private void update ()
        {
            this.value_label.label = this._unit.format (this._value);

            if (this._reference_value.is_finite () && this._reference_value != 0.0)
            {
                var difference         = this._value - this._reference_value;
                var difference_value   = this._unit.format (difference.abs ());
                var difference_percent = (int) Math.floor (
                        100.0 * (difference / this._reference_value).abs ());
                var difference_sign    = difference >= 0 ? "+" : "-";

                this.value_difference_label.label = @"$(difference_sign)$(difference_value)" +
                                                    @" ($(difference_sign)$(difference_percent)%)";
                this.value_difference_label.remove_css_class ("positive");
                this.value_difference_label.remove_css_class ("negative");
                this.value_difference_label.visible = true;

                if (difference > 0.0) {
                    this.value_difference_label.add_css_class ("positive");
                }
                else if (difference < 0.0) {
                    this.value_difference_label.add_css_class ("negative");
                }
            }
            else {
                this.value_difference_label.label = "";
                this.value_difference_label.visible = false;
            }
        }

        private void schedule_update ()
        {
            if (this.update_idle_id != 0) {
                return;
            }

            this.update_idle_id = this.add_tick_callback (() => {
                this.update_idle_id = 0;
                this.update ();

                return GLib.Source.REMOVE;
            });
        }

        public override void dispose ()
        {
            if (this.update_idle_id != 0) {
                this.remove_tick_callback (this.update_idle_id);
                this.update_idle_id = 0;
            }

            base.dispose ();
        }
    }
}
