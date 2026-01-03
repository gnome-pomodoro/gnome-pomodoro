/*
 * Copyright (c) 2017 gnome-pomodoro contributors
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
    [GtkTemplate (ui = "/org/gnome/pomodoro/stats-lifetime-page.ui")]
    private class StatsLifetimePage : Gtk.Box, Gtk.Buildable
    {
        [GtkChild]
        private unowned Gtk.Label total_focus_time_label;
        [GtkChild]
        private unowned Gtk.Label total_break_time_label;
        [GtkChild]
        private unowned Gtk.Label total_sessions_label;
        [GtkChild]
        private unowned Gtk.Label total_days_label;
        [GtkChild]
        private unowned Gtk.Label average_daily_label;

        private Gom.Repository repository;

        construct
        {
            this.repository = Pomodoro.get_repository ();
        }

        public StatsLifetimePage (Gom.Repository repository)
        {
            GLib.Object ();

            this.repository = repository;

            this.update ();
        }

        private static string format_time (int64 seconds)
        {
            if (seconds < 3600) {
                return _("%d minutes").printf ((int) seconds / 60);
            }

            var hours = seconds / 3600;
            var minutes = (seconds % 3600) / 60;

            if (minutes == 0) {
                return ngettext ("%d hour", "%d hours", (ulong) hours).printf ((int) hours);
            }

            return _("%d h %d min").printf ((int) hours, (int) minutes);
        }

        private async void update ()
        {
            var stats = yield AggregatedEntry.get_lifetime_stats ();

            this.total_focus_time_label.label = format_time (stats.total_focus_time);
            this.total_break_time_label.label = format_time (stats.total_break_time);
            this.total_sessions_label.label = stats.total_sessions.to_string ();
            this.total_days_label.label = stats.total_days_active.to_string ();

            if (stats.total_days_active > 0) {
                var average_daily = stats.total_focus_time / stats.total_days_active;
                this.average_daily_label.label = format_time (average_daily);
            }
            else {
                this.average_daily_label.label = "-";
            }
        }
    }
}
