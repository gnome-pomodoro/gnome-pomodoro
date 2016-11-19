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
    private errordomain DateTimeError {
        PARSE
    }

    private DateTime datetime_from_string (string date_string)
                                           throws DateTimeError
    {
        var timeval = TimeVal();

        if (!timeval.from_iso8601 (date_string)) {
            throw new DateTimeError.PARSE ("Could not parse string '%s'",
                                           date_string);
        }

        return new DateTime.from_timeval_local (timeval);
    }

    private string datetime_to_string (DateTime datetime)
    {
        var timeval = TimeVal();
        string date_string;

        if (datetime.to_utc().to_timeval (out timeval)) {
            date_string = timeval.to_iso8601 ();
        }
        else {
            date_string = null;
        }

        return date_string;
    }

    private string format_time (long seconds)
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

    public double get_current_time ()
    {
        return (double) GLib.get_real_time () / 1000000.0;
    }
}
