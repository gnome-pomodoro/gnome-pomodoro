/*
 * Copyright (c) 2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[CCode (cprefix = "")]
namespace Pomodoro.DateUtils
{
    public GLib.Date get_today ()
    {
        var datetime = new GLib.DateTime.now_local ();
        var date = GLib.Date ();

        date.set_dmy ((GLib.DateDay) datetime.get_day_of_month (),
                      (GLib.DateMonth) datetime.get_month (),
                      (GLib.DateYear) datetime.get_year ());
        return date;
    }


    public string format_date (GLib.Date date,
                               string    format)
    {
        // Avoid using `GLib.Date.strftime`, as it doesn't handle encodings
        // properly.
        var datetime = new GLib.DateTime.local (
                date.get_year (),
                date.get_month (),
                date.get_day (),
                0, 0, 0.0);

        return datetime.format (format);
    }


    private uint get_weekday_number_internal (GLib.DateWeekday weekday)
    {
        switch (weekday)
        {
            case GLib.DateWeekday.MONDAY:
                return 1U;

            case GLib.DateWeekday.TUESDAY:
                return 2U;

            case GLib.DateWeekday.WEDNESDAY:
                return 3U;

            case GLib.DateWeekday.THURSDAY:
                return 4U;

            case GLib.DateWeekday.FRIDAY:
                return 5U;

            case GLib.DateWeekday.SATURDAY:
                return 6U;

            case GLib.DateWeekday.SUNDAY:
                return 7U;

            default:
                return 0U;
        }
    }


    /**
     * Convert GLib.DateWeekday to integer
     *
     * The result is locale dependant. Starts from 1 - first day of a work week.
     */
    public uint get_weekday_number (GLib.DateWeekday weekday)
    {
        var weekday_number = (int) get_weekday_number_internal (weekday);

        if (weekday_number != 0)
        {
            var first_day_of_week_number = (int) get_weekday_number_internal (
                    Pomodoro.Locale.get_first_day_of_week ());
            if (first_day_of_week_number == 0) {
                first_day_of_week_number = 7;  // default to SUNDAY as the first day of week
            }

            var result = 1 + weekday_number - first_day_of_week_number;

            if (result < 1) {
                result += 7;
            }

            return (uint) result;
        }
        else {
            return 0U;
        }
    }


    public uint get_month_number (GLib.DateMonth month)
    {
        switch (month)
        {
            case GLib.DateMonth.JANUARY:
                return 1U;

            case GLib.DateMonth.FEBRUARY:
                return 2U;

            case GLib.DateMonth.MARCH:
                return 3U;

            case GLib.DateMonth.APRIL:
                return 4U;

            case GLib.DateMonth.MAY:
                return 5U;

            case GLib.DateMonth.JUNE:
                return 6U;

            case GLib.DateMonth.JULY:
                return 7U;

            case GLib.DateMonth.AUGUST:
                return 8U;

            case GLib.DateMonth.SEPTEMBER:
                return 9U;

            case GLib.DateMonth.OCTOBER:
                return 10U;

            case GLib.DateMonth.NOVEMBER:
                return 11U;

            case GLib.DateMonth.DECEMBER:
                return 12U;

            default:
                return 0U;
        }
    }


    public string get_month_name (GLib.DateMonth month)
    {
        return Locale.get_month_name (get_month_number (month));
    }


    public GLib.Variant date_to_variant (GLib.Date date)
    {
        var day   = new GLib.Variant.uint16 ((uint16) date.get_day ());
        var month = new GLib.Variant.uint16 ((uint16) date.get_month ());
        var year  = new GLib.Variant.uint16 ((uint16) date.get_year ());

        return new GLib.Variant.tuple ({ day, month, year });
    }


    public GLib.Date date_from_variant (GLib.Variant variant)
    {
        var date = GLib.Date ();

        if (variant.get_type_string () == "(qqq)")
        {
            var day   = (GLib.DateDay) variant.get_child_value (0).get_uint16 ();
            var month = (GLib.DateMonth) variant.get_child_value (1).get_uint16 ();
            var year  = (GLib.DateYear) variant.get_child_value (2).get_uint16 ();

            if (day   != GLib.DateDay.BAD_DAY &&
                month != GLib.DateMonth.BAD_MONTH &&
                year  != GLib.DateYear.BAD_YEAR)
            {
                date.set_dmy (day, month, year);
            }
        }

        return date;
    }
}
