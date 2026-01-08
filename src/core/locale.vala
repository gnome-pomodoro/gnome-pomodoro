/*
 * Copyright (c) 2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[CCode (cprefix = "")]
namespace Pomodoro.Locale
{
    #if HAVE_ALTMON
    [CCode (cheader_filename = "langinfo.h", cprefix = "", has_type_id = false)]
    private enum NLItem {
	    ALTMON_1,
	    ALTMON_2,
	    ALTMON_3,
	    ALTMON_4,
	    ALTMON_5,
	    ALTMON_6,
	    ALTMON_7,
	    ALTMON_8,
	    ALTMON_9,
	    ALTMON_10,
	    ALTMON_11,
	    ALTMON_12;

	    [CCode (cheader_filename = "langinfo.h", cname = "nl_langinfo")]
	    public extern unowned string to_string ();
    }

    private const NLItem[] MONTHS = {
        NLItem.ALTMON_1,
        NLItem.ALTMON_2,
        NLItem.ALTMON_3,
        NLItem.ALTMON_4,
        NLItem.ALTMON_5,
        NLItem.ALTMON_6,
        NLItem.ALTMON_7,
        NLItem.ALTMON_8,
        NLItem.ALTMON_9,
        NLItem.ALTMON_10,
        NLItem.ALTMON_11,
        NLItem.ALTMON_12
    };
    #else
    private const Posix.NLItem[] MONTHS = {
        Posix.NLItem.MON_1,
        Posix.NLItem.MON_2,
        Posix.NLItem.MON_3,
        Posix.NLItem.MON_4,
        Posix.NLItem.MON_5,
        Posix.NLItem.MON_6,
        Posix.NLItem.MON_7,
        Posix.NLItem.MON_8,
        Posix.NLItem.MON_9,
        Posix.NLItem.MON_10,
        Posix.NLItem.MON_11,
        Posix.NLItem.MON_12
    };
    #endif

    private GLib.DateWeekday first_day_of_week = GLib.DateWeekday.BAD_WEEKDAY;


    /**
     * Based on gtkcalendar.c and https://sourceware.org/glibc/wiki/Locales
     */
    public GLib.DateWeekday get_first_day_of_week ()
    {
        if (!first_day_of_week.valid ())
        {
            // `nl_langinfo(_NL_TIME_WEEK_1STDAY)` returns a pointer whose VALUE encodes
            // the date. GTK uses a union to extract the lower 32 bits. We do the same via casting.
            unowned string week_origin_ptr = Posix.NLTime.WEEK_1STDAY.to_string ();
            var week_1stday = 0;

            if (week_origin_ptr != null)
            {
                // Extract lower 32 bits of the pointer value (like GTK's union trick)
                // The pointer value itself encodes the date on little-endian systems
                var ptr_value = (size_t) ((void*) week_origin_ptr);
                var week_origin = (uint32) (ptr_value & 0xFFFFFFFF);

                if (week_origin == 19971130) {  // Sunday
                    week_1stday = 0;
                }
                else if (week_origin == 19971201) {  // Monday
                    week_1stday = 1;
                }
                else {
                    GLib.warning ("Unknown value of _NL_TIME_WEEK_1STDAY: %u", week_origin);
                }
            }

            // FIRST_WEEKDAY is different from WEEK_1STDAY - it returns a pointer to a string
            // containing a byte value (1-7)
            unowned string first_weekday_str = Posix.NLTime.FIRST_WEEKDAY.to_string ();
            var first_weekday = 1;

            if (first_weekday_str != null && first_weekday_str.length > 0)
            {
                // Read the first byte (like GTK does with langinfo.string[0])
                var weekday_byte = (uint8) first_weekday_str[0];

                if (weekday_byte >= 1 && weekday_byte <= 7) {
                    first_weekday = (int) weekday_byte;
                }
                else {
                    GLib.warning ("Unexpected _NL_TIME_FIRST_WEEKDAY byte value: %u", weekday_byte);
                }
            }

            first_day_of_week = (week_1stday + first_weekday - 1) % 7 == 0
                    ? GLib.DateWeekday.SUNDAY
                    : GLib.DateWeekday.MONDAY;
        }

        return first_day_of_week;
    }


    public string get_month_name (uint month_number)
    {
        if (month_number < 1 || month_number > 12) {
            return "";
        }

        var month_name = MONTHS[month_number - 1].to_string ();

        // Convert to UTF-8 if needed
        if (!month_name.validate ())
        {
            try {
                string charset;
                GLib.get_charset (out charset);

                var bytes = month_name.data;
                month_name = GLib.convert ((string) bytes, -1, "UTF-8",
                                           charset, null, null);
            }
            catch (GLib.ConvertError error) {
                GLib.warning ("Failed to convert month name to UTF-8: %s", error.message);
            }
        }

        return month_name;
    }


    /**
     * Return whether to prefer 12h (AM/PM) format.
     */
    public bool use_12h_format ()
    {
        unowned string t_fmt_ptr = Posix.NLItem.T_FMT.to_string ();

        return t_fmt_ptr != null
                ? t_fmt_ptr.ascii_casecmp ("%I") == 0
                : false;
    }
}

