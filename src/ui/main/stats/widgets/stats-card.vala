/*
 * Copyright (c) 2025 gnome-pomodoro contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;


namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/main/stats/widgets/stats-card.ui")]
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
