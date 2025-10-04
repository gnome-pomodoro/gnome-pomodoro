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

                this.update ();
            }
        }

        public double value {
            get {
                return this._value;
            }
            set {
                this._value = value;

                this.update ();
            }
        }

        [GtkChild]
        private unowned Gtk.Label value_label;

        private Pomodoro.Unit _unit = Pomodoro.Unit.AMOUNT;
        private double        _value = double.NAN;

        static construct
        {
            set_css_name ("statscard");
        }

        private void update ()
        {
            this.value_label.label = this._unit.format (this._value);
        }
    }
}
