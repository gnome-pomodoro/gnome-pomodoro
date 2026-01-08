/*
 * This file is part of focus-timer
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Tests
{
    private int64[] generate_random_timestamps (uint size)
    {
        var timestamps = new int64[size];
        var timestamp = (int64) 0;

        for (var index = 0; index < size; index++)
        {
            timestamp += GLib.Random.int_range (1, 1000);

            timestamps[index] = timestamp;
        }

        return timestamps;
    }


    private GLib.Variant int64_array_to_variant (int64[] values)
    {
        var children = new GLib.Variant[values.length];

        for (var index = 0; index < values.length; index++) {
            children[index] = new GLib.Variant.int64 (values[index]);
        }

        return new GLib.Variant.array (GLib.VariantType.INT64, children);
    }


    public class TimezoneHistoryTest : Tests.TestSuite
    {
        private GLib.TimeZone? new_york_timezone;
        private GLib.TimeZone? london_timezone;
        private GLib.TimeZone? tokyo_timezone;

        public TimezoneHistoryTest ()
        {
            this.add_test ("insert__reverse_order",
                           this.test_insert__reverse_order);
            this.add_test ("insert__replace",
                           this.test_insert__replace);
            this.add_test ("insert__duplicate",
                           this.test_insert__duplicate);

            this.add_test ("search__null",
                           this.test_search__null);
            this.add_test ("search__exact",
                           this.test_search__exact);
            this.add_test ("search__closest",
                           this.test_search__closest);

            this.add_test ("scan__timezones",
                           this.test_scan__timezones);
            this.add_test ("scan__dst_switch",
                           this.test_scan__dst_switch);

            this.add_test ("fetch", this.test_fetch);
            this.add_test ("fetch__max", this.test_fetch__max);
        }

        public override void setup ()
        {
            try {
                this.new_york_timezone = new GLib.TimeZone.identifier ("America/New_York");
                this.london_timezone = new GLib.TimeZone.identifier ("Europe/London");
                this.tokyo_timezone = new GLib.TimeZone.identifier ("Asia/Tokyo");
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }

            Pomodoro.Database.open ();
        }

        public override void teardown ()
        {
            Pomodoro.Database.close ();
        }

        public void test_insert__reverse_order ()
        {
            var timezone_history = new Pomodoro.TimezoneHistory ();
            timezone_history.insert (400, this.new_york_timezone);
            timezone_history.insert (300, this.london_timezone);
            timezone_history.insert (200, this.new_york_timezone);

            unowned var timezone_1 = timezone_history.search (200);
            assert_nonnull (timezone_1);
            assert_cmpstr (timezone_1.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");

            unowned var timezone_2 = timezone_history.search (300);
            assert_nonnull (timezone_2);
            assert_cmpstr (timezone_2.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "Europe/London");

            unowned var timezone_3 = timezone_history.search (400);
            assert_nonnull (timezone_3);
            assert_cmpstr (timezone_3.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");
        }

        public void test_insert__replace ()
        {
            GLib.TimeZone? timezone;

            var timezone_history = new Pomodoro.TimezoneHistory ();

            timezone_history.insert (200, this.new_york_timezone);
            timezone = timezone_history.search (200);
            assert_nonnull (timezone);
            assert_cmpstr (timezone.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");

            timezone_history.insert (200, this.london_timezone);
            timezone = timezone_history.search (200);
            assert_nonnull (timezone);
            assert_cmpstr (timezone.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "Europe/London");
        }

        public void test_insert__duplicate ()
        {
            var timezone_history = new Pomodoro.TimezoneHistory ();
            timezone_history.insert (200, this.new_york_timezone);
            timezone_history.insert (300, this.new_york_timezone);

            unowned var timezone = timezone_history.search (300);
            assert_nonnull (timezone);
            assert_cmpstr (timezone.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");
        }

        public void test_search__null ()
        {
            var timezone_history = new Pomodoro.TimezoneHistory ();
            timezone_history.insert (200, this.new_york_timezone);

            unowned var timezone = timezone_history.search (199);
            assert_null (timezone);
        }

        public void test_search__exact ()
        {
            var timezone_history = new Pomodoro.TimezoneHistory ();
            timezone_history.insert (200, this.new_york_timezone);
            timezone_history.insert (300, this.london_timezone);
            timezone_history.insert (400, this.new_york_timezone);

            unowned var timezone_1 = timezone_history.search (200);
            assert_nonnull (timezone_1);
            assert_cmpstr (timezone_1.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");

            unowned var timezone_2 = timezone_history.search (300);
            assert_nonnull (timezone_2);
            assert_cmpstr (timezone_2.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "Europe/London");

            unowned var timezone_3 = timezone_history.search (400);
            assert_nonnull (timezone_3);
            assert_cmpstr (timezone_3.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");
        }

        public void test_search__closest ()
        {
            var timezone_history = new Pomodoro.TimezoneHistory ();
            timezone_history.insert (200, this.new_york_timezone);
            timezone_history.insert (300, this.london_timezone);

            unowned var timezone_1 = timezone_history.search (201);
            assert_nonnull (timezone_1);
            assert_cmpstr (timezone_1.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");

            unowned var timezone_2 = timezone_history.search (400);
            assert_nonnull (timezone_2);
            assert_cmpstr (timezone_2.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "Europe/London");
        }

        private void test_scan (Pomodoro.TimezoneHistory timezone_history,
                                int64                    start_time,
                                int64                    end_time,
                                int64[]                  expected_start_times,
                                int64[]                  expected_end_times,
                                string[]                 expected_timezone_identifiers)
        {
            int64[] start_times = {};
            int64[] end_times = {};
            string[] timezone_identifiers = {};

            timezone_history.scan (
                start_time,
                end_time,
                (_start_time, _end_time, timezone) => {
                    start_times          += _start_time;
                    end_times            += _end_time;
                    timezone_identifiers += timezone.get_identifier ();
                });

            assert_cmpstrv (
                    timezone_identifiers,
                    expected_timezone_identifiers);
            assert_cmpvariant (
                    int64_array_to_variant (start_times),
                    int64_array_to_variant (expected_start_times));
            assert_cmpvariant (
                    int64_array_to_variant (end_times),
                    int64_array_to_variant (expected_end_times));
        }

        public void test_scan__timezones ()
        {
            var timezone_history = new Pomodoro.TimezoneHistory ();
            timezone_history.insert (200, this.new_york_timezone);
            timezone_history.insert (300, this.london_timezone);
            timezone_history.insert (400, this.tokyo_timezone);

            this.test_scan (
                    timezone_history, 250, 450,
                    {250, 300, 400},
                    {300, 400, 450},
                    {"America/New_York", "Europe/London", "Asia/Tokyo"});
            this.test_scan (
                    timezone_history, 100, 199,
                    {},
                    {},
                    {});
            this.test_scan (
                    timezone_history, 450, 500,
                    {450},
                    {500},
                    {"Asia/Tokyo"});
        }

        public void test_scan__dst_switch ()
        {
            var dst_switch_time = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 4, 2, 2, 0, 0));
            var start_time = dst_switch_time - Pomodoro.Interval.MINUTE;
            var end_time = dst_switch_time + Pomodoro.Interval.MINUTE;

            var timezone_history = new Pomodoro.TimezoneHistory ();
            timezone_history.insert (start_time, this.new_york_timezone);

            this.test_scan (
                    timezone_history, start_time, end_time,
                    {start_time, dst_switch_time},
                    {dst_switch_time, end_time},
                    {"America/New_York", "America/New_York"});
        }

        public void test_fetch ()
        {
            var timezone_history = new Pomodoro.TimezoneHistory ();
            var timestamps = generate_random_timestamps (1000);

            for (var index = 0; index < timestamps.length; index++)
            {
                timezone_history.insert (
                    timestamps[index],
                    (index & 1) == 0 ? this.new_york_timezone : this.london_timezone);
            }

            // Destroy one instance to check if entries have been saved and a new instance is
            // fetching it properly.
            timezone_history = null;
            timezone_history = new Pomodoro.TimezoneHistory ();

            for (var index = 0; index < timestamps.length; index++)
            {
                unowned var timezone = timezone_history.search (timestamps[index]);
                assert_nonnull (timezone);
                assert_cmpstr (
                    timezone.get_identifier (),
                    GLib.CompareOperator.EQ,
                    (index & 1) == 0 ? "America/New_York" : "Europe/London"
                );
            }
        }

        public void test_fetch__max ()
        {
            var timestamp = Pomodoro.Timestamp.MAX;

            var timezone_history = new Pomodoro.TimezoneHistory ();
            timezone_history.insert (timestamp, this.new_york_timezone);

            // Destroy one instance to check if entries have been saved and a new instance is
            // fetching it properly.
            timezone_history = null;
            timezone_history = new Pomodoro.TimezoneHistory ();

            unowned var timezone = timezone_history.search (timestamp);
            assert_nonnull (timezone);
            assert_cmpstr (
                timezone.get_identifier (),
                GLib.CompareOperator.EQ,
                "America/New_York"
            );
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.TimezoneHistoryTest ()
    );
}
