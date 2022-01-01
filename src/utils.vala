/*
 * Copyright (c) 2013 gnome-pomodoro contributors
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
 */

using GLib;


namespace Pomodoro
{
    public const double USEC_PER_SEC = 1000000.0;  // TODO: remove, use Timestamp.from_seconds() and Timestamp.to_seconds()

    private int64 reference_time = -1;  // TODO: move to timer-progress-bar.vala
    // private int64 frozen_time = -1;

    private void ensure_timestamp (ref int64 timestamp)
    {
        if (timestamp < 0) {
            timestamp = Pomodoro.Timestamp.from_now ();
        }
    }

    private string format_time (int seconds)
    {
        var minutes = (seconds / 60) % 60;
        var hours = (seconds / 3600);
        var str = "";

        if (hours > 0) {
            str = ngettext ("%d hour", "%d hours", hours)
                            .printf (hours);
        }

        if (minutes > 0 && str != null) {
            str += " ";
        }

        if (minutes > 0) {
            str += ngettext ("%d minute", "%d minutes", minutes)
                            .printf (minutes);
        }

        return str;
    }

    // /**
    //  * Fake Pomodoro.get_current_time (). Added for unittesting.
    //  */
    // public void freeze_time (int64 timestamp = Pomodoro.get_current_time ())
    // {
    //     Pomodoro.frozen_time = timestamp;
    // }

    // /**
    //  * Revert freeze_time() call
    //  */
    // public void unfreeze_time ()
    // {
    //     Pomodoro.frozen_time = -1;
    // }

    /**
     * Returns the number of microseconds since January 1, 1970 UTC or frozen time
     *
     * TODO deprecated, use Timestamp.from_now()
     */
    public int64 get_current_time ()
    {
        return Pomodoro.Timestamp.from_now ();
    }

    /**
     * Synchronize monotonic time with real time
     *
     * TODO move to timer-progress-bar.vala
     */
    public void sync_monotonic_time ()
    {
        Pomodoro.reference_time = GLib.get_real_time () - GLib.get_monotonic_time ();
    }

    /**
     * Convert monotonic timestamp to real time, in microseconds
     *
     * TODO move to timer-progress-bar.vala
     */
    public int64 to_real_time (int64 monotonic_time)
    {
        if (Pomodoro.reference_time == -1) {
            Pomodoro.sync_monotonic_time ();
        }

        return monotonic_time + Pomodoro.reference_time;
    }
}
