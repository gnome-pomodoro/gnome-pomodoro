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
    [GtkTemplate (ui = "/org/gnome/pomodoro/stats-today-page.ui")]
    private class StatsTodayPage : Gtk.Box, Gtk.Buildable
    {
        [GtkChild]
        private unowned Gtk.Label focus_time_label;
        [GtkChild]
        private unowned Gtk.Label break_time_label;
        [GtkChild]
        private unowned Gtk.Label focus_sessions_label;
        [GtkChild]
        private unowned Gtk.Label break_sessions_label;
        [GtkChild]
        private unowned Gtk.ProgressBar focus_progress;

        private Gom.Repository repository;
        private uint update_timeout_id = 0;

        construct
        {
            this.repository = Pomodoro.get_repository ();
        }

        public StatsTodayPage (Gom.Repository repository)
        {
            GLib.Object ();

            this.repository = repository;

            this.update ();
            this.schedule_update ();
        }

        ~StatsTodayPage ()
        {
            if (this.update_timeout_id != 0) {
                GLib.Source.remove (this.update_timeout_id);
                this.update_timeout_id = 0;
            }
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

        private void schedule_update ()
        {
            if (this.update_timeout_id != 0) {
                GLib.Source.remove (this.update_timeout_id);
            }

            // Update every minute
            this.update_timeout_id = GLib.Timeout.add_seconds (60, () => {
                this.update ();
                return GLib.Source.CONTINUE;
            });
        }

        private async void update ()
        {
            var stats = yield AggregatedEntry.get_today_stats ();

            this.focus_time_label.label = format_time (stats.focus_time);
            this.break_time_label.label = format_time (stats.break_time);
            this.focus_sessions_label.label = stats.focus_count.to_string ();
            this.break_sessions_label.label = stats.break_count.to_string ();

            // Show progress towards a goal (e.g., 4 hours = 14400 seconds)
            var daily_goal = 14400.0;  // 4 hours
            var progress = double.min (1.0, stats.focus_time / daily_goal);
            this.focus_progress.fraction = progress;
        }
    }
}
