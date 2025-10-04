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
            // `Posix.NLTime.WEEK_1STDAY.to_string()` underneath calls `nl_langinfo()`.
            // `nl_langinfo()` produces a string pointer whose address is the number we want.
            // Using the result as a string will cause segfault.
            var week_origin = (long) Posix.NLTime.WEEK_1STDAY.to_string ();
            var week_1stday = 0;

            if (week_origin == 19971130) {  // Sunday
                week_1stday = 0;
            }
            else if (week_origin == 19971201) {  // Monday
                week_1stday = 1;
            }
            else {
                GLib.warning ("Unknown value of _NL_TIME_WEEK_1STDAY: %ld", week_origin);
            }

            var first_weekday = (int) Posix.NLTime.FIRST_WEEKDAY.to_string ().data[0];
            var first_day_of_week_int = (week_1stday + first_weekday - 1) % 7;

            first_day_of_week = first_day_of_week_int == 0
                    ? GLib.DateWeekday.SUNDAY
                    : GLib.DateWeekday.MONDAY;
        }

        return first_day_of_week;
    }


    public string get_month_name (uint month_number)
    {
        return month_number >= 1 && month_number <= 12
                ? MONTHS[month_number - 1].to_string ()
                : "";
    }


    /**
     * Return whether to prefer 12h (AM/PM) format.
     */
    public bool use_12h_format ()
    {
        // return true;
        return Posix.NLItem.T_FMT.to_string ().ascii_casecmp ("%I") == 0;
    }
}

