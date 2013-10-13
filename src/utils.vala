/*
 * Copyright (c) 2013 gnome-pomodoro contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Pomodoro
{
    private const string DATETIME_FORMAT_RFC_2822 =
        "%a, %d %b %Y %H:%M:%S GMT";

    private const string[] DATETIME_ABBREVIATED_MONTH_NAMES = {
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    };

    private errordomain DateTimeError {
        PARSE
    }

    private DateTime datetime_from_string (string date_str) throws DateTimeError
    {
        /* strptime() works okay for local timezone, otherwise it's crap,
         * so we need to parse date string ourselves.
         */
        string day_name = "",
               month_name = "";
        int    year = 0,
               month = 0,
               day = 0,
               hour = 0,
               minutes = 0;
        double seconds = 0.0;

        var length = date_str.scanf ("%[^,], %2d %s %4d %02d:%02d:%02lf",
                                         day_name,
                                     out day,
                                         month_name,
                                     out year,
                                     out hour,
                                     out minutes,
                                     out seconds);

        if (length >= 3)
        {
            for (var i=0; i < DATETIME_ABBREVIATED_MONTH_NAMES.length; i++)
            {
                if (month_name == DATETIME_ABBREVIATED_MONTH_NAMES[i]) {
                    month = i + 1;
                    break;
                }
            }
        }

        if (length < 7 || month == 0) {
            throw new DateTimeError.PARSE ("Could not parse string '%s'",
                                           date_str);
        }

        return new DateTime.utc (year, month, day, hour, minutes, seconds);
    }

    private string datetime_to_string (DateTime datetime)
    {
        return datetime.to_utc ().format (DATETIME_FORMAT_RFC_2822);
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

    private double get_real_time ()
    {
        return (double) GLib.get_real_time () / 1000000.0;
    }
}
