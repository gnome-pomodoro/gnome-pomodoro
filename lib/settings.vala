/*
 * Copyright (c) 2014 gnome-pomodoro contributors
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
    private GLib.Settings settings = null;

    public void set_settings (GLib.Settings settings)
    {
        Pomodoro.settings = settings;
    }

    public unowned GLib.Settings get_settings ()
    {
        if (Pomodoro.settings == null) {
            Pomodoro.settings = new GLib.Settings ("org.gnome.pomodoro");
        }

        return Pomodoro.settings;
    }

    public void save_timer (Pomodoro.Timer timer)
    {
        var state_settings = Pomodoro.get_settings ()
                                     .get_child ("state");

        var state_datetime = new DateTime.from_unix_utc (
                             (int64) Math.floor (timer.state.timestamp));

        state_settings.set_double ("session",
                                   timer.session);
        state_settings.set_string ("state",
                                   timer.state.name);
        state_settings.set_string ("state-date",
                                   datetime_to_string (state_datetime));
        state_settings.set_double ("state-offset",
                                   timer.offset);  // - timer.state.timestamp % 1.0);
        state_settings.set_double ("state-duration",
                                   timer.state.duration);
    }

    public void restore_timer (Pomodoro.Timer timer)
    {
        timer.stop ();

        var state_settings = Pomodoro.get_settings ()
                                     .get_child ("state");

        var state = TimerState.lookup (state_settings.get_string ("state"));

        if (state != null)
        {
            state.elapsed = state_settings.get_double ("state-offset");
            state.duration = state_settings.get_double ("state-duration");

            try {
                var state_date = state_settings.get_string ("state-date");

                if (state_date != "") {
                    var state_datetime = datetime_from_string (state_date);
                    state.timestamp = (double) state_datetime.to_unix ();
                }
            }
            catch (DateTimeError error) {
                /* In case there is no valid state-date, elapsed time
                 * will be lost.
                 */
                state = null;
            }
        }

        if (state != null)
        {
            timer.state = state;
            timer.session = state_settings.get_double ("session");
        }
        else {
            GLib.warning ("Could not restore time");
        }

        timer.update ();
    }
}
