/*
 * This file is part of focus-timer
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Tests
{
    public class TimestampTest : Tests.TestSuite
    {
        public TimestampTest ()
        {
            this.add_test ("round",
                           this.test_round);
            this.add_test ("round__undefined",
                           this.test_round__undefined);

            this.add_test ("add_interval",
                           this.test_add_interval);
            this.add_test ("subtract",
                           this.test_subtract);
            this.add_test ("subtract_interval",
                           this.test_subtract_interval);

            this.add_test ("to_iso8601",
                           this.test_to_iso8601);
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        public void test_round ()
        {
            var unit            = Ft.Interval.SECOND;
            var timestamp_lower = 20 * unit;
            var timestamp_upper = timestamp_lower + unit;

            var timestamp_1 = timestamp_lower + 1;
            var timestamp_2 = timestamp_lower + (unit / 2 - 1);
            var timestamp_3 = timestamp_lower + (unit / 2);
            var timestamp_4 = timestamp_lower + (unit / 2 + 1);
            var timestamp_5 = timestamp_lower + (unit - 1);

            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.round (timestamp_1, unit)),
                new GLib.Variant.int64 (timestamp_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.round (timestamp_2, unit)),
                new GLib.Variant.int64 (timestamp_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.round (timestamp_3, unit)),
                new GLib.Variant.int64 (timestamp_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.round (timestamp_4, unit)),
                new GLib.Variant.int64 (timestamp_upper)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.round (timestamp_5, unit)),
                new GLib.Variant.int64 (timestamp_upper)
            );
        }

        public void test_round__undefined ()
        {
            var unit = Ft.Interval.SECOND;

            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.round (Ft.Timestamp.UNDEFINED, unit)),
                new GLib.Variant.int64 (Ft.Timestamp.UNDEFINED)
            );
        }

        public void test_add_interval ()
        {
            var interval    = Ft.Interval.MINUTE;
            var timestamp_1 = Ft.Timestamp.from_now ();
            var timestamp_2 = timestamp_1 + interval;

            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.add_interval (timestamp_1, 0)),
                new GLib.Variant.int64 (timestamp_1)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.add_interval (timestamp_1, interval)),
                new GLib.Variant.int64 (timestamp_2)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.add_interval (Ft.Timestamp.UNDEFINED, interval)),
                new GLib.Variant.int64 (Ft.Timestamp.UNDEFINED)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.add_interval (Ft.Timestamp.MIN, interval)),
                new GLib.Variant.int64 (interval)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.add_interval (Ft.Timestamp.MAX, interval)),
                new GLib.Variant.int64 (Ft.Timestamp.MAX)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.add_interval (Ft.Timestamp.MIN, -interval)),
                new GLib.Variant.int64 (Ft.Timestamp.MIN)
            );
        }

        public void test_subtract ()
        {
            var interval    = Ft.Interval.MINUTE;
            var timestamp_1 = Ft.Timestamp.from_now ();
            var timestamp_2 = timestamp_1 + interval;

            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.subtract (timestamp_1, 0)),
                new GLib.Variant.int64 (timestamp_1)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.subtract (timestamp_2, timestamp_1)),
                new GLib.Variant.int64 (interval)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.subtract (timestamp_1, timestamp_2)),
                new GLib.Variant.int64 (-interval)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.subtract (timestamp_1, Ft.Timestamp.UNDEFINED)),
                new GLib.Variant.int64 (0)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.subtract (Ft.Timestamp.UNDEFINED, timestamp_1)),
                new GLib.Variant.int64 (0)
            );
        }

        public void test_subtract_interval ()
        {
            var interval    = Ft.Interval.MINUTE;
            var timestamp_1 = Ft.Timestamp.from_now ();
            var timestamp_2 = timestamp_1 + interval;

            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.subtract_interval (timestamp_1, 0)),
                new GLib.Variant.int64 (timestamp_1)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.subtract_interval (timestamp_2, interval)),
                new GLib.Variant.int64 (timestamp_1)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.subtract_interval (Ft.Timestamp.UNDEFINED, interval)),
                new GLib.Variant.int64 (Ft.Timestamp.UNDEFINED)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.subtract_interval (Ft.Timestamp.MIN, interval)),
                new GLib.Variant.int64 (Ft.Timestamp.MIN)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Timestamp.subtract_interval (Ft.Timestamp.MAX, -interval)),
                new GLib.Variant.int64 (Ft.Timestamp.MAX)
            );
        }

        public void test_to_iso8601 ()
        {
            var timestamp_1 = (int64) 0;
            var timestamp_2 = timestamp_1 + Ft.Interval.MICROSECOND;
            var timestamp_3 = timestamp_1 + Ft.Interval.MILLISECOND;
            var timestamp_4 = timestamp_1 + Ft.Interval.SECOND - Ft.Interval.MICROSECOND;
            var timestamp_5 = Ft.Timestamp.from_seconds_uint (1014304205);

            assert_cmpstr (
                Ft.Timestamp.to_iso8601 (timestamp_1),
                GLib.CompareOperator.EQ,
                "1970-01-01T00:00:00Z"
            );
            assert_cmpstr (
                Ft.Timestamp.to_iso8601 (timestamp_2),
                GLib.CompareOperator.EQ,
                "1970-01-01T00:00:00.000001Z"
            );
            assert_cmpstr (
                Ft.Timestamp.to_iso8601 (timestamp_3),
                GLib.CompareOperator.EQ,
                "1970-01-01T00:00:00.001000Z"
            );
            assert_cmpstr (
                Ft.Timestamp.to_iso8601 (timestamp_4),
                GLib.CompareOperator.EQ,
                "1970-01-01T00:00:00.999999Z"
            );
            assert_cmpstr (
                Ft.Timestamp.to_iso8601 (timestamp_5),
                GLib.CompareOperator.EQ,
                "2002-02-21T15:10:05Z"
            );
        }
    }


    public class IntervalTest : Tests.TestSuite
    {
        public IntervalTest ()
        {
            this.add_test ("round__positive",
                           this.test_round__positive);
            this.add_test ("round__negative",
                           this.test_round__negative);
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        public void test_round__positive ()
        {
            var unit            = Ft.Interval.SECOND;
            var interval_lower = 20 * unit;
            var interval_upper = interval_lower + unit;

            var interval_1 = interval_lower + 1;
            var interval_2 = interval_lower + (unit / 2 - 1);
            var interval_3 = interval_lower + (unit / 2);
            var interval_4 = interval_lower + (unit / 2 + 1);
            var interval_5 = interval_lower + (unit - 1);

            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Interval.round (interval_1, unit)),
                new GLib.Variant.int64 (interval_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Interval.round (interval_2, unit)),
                new GLib.Variant.int64 (interval_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Interval.round (interval_3, unit)),
                new GLib.Variant.int64 (interval_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Interval.round (interval_4, unit)),
                new GLib.Variant.int64 (interval_upper)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Interval.round (interval_5, unit)),
                new GLib.Variant.int64 (interval_upper)
            );
        }

        public void test_round__negative ()
        {
            var unit           = Ft.Interval.SECOND;
            var interval_upper = -20 * unit;
            var interval_lower = interval_upper - unit;

            var interval_1 = interval_upper - 1;
            var interval_2 = interval_upper - (unit / 2 - 1);
            var interval_3 = interval_upper - (unit / 2);
            var interval_4 = interval_upper - (unit / 2 + 1);
            var interval_5 = interval_upper - (unit - 1);

            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Interval.round (interval_1, unit)),
                new GLib.Variant.int64 (interval_upper)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Interval.round (interval_2, unit)),
                new GLib.Variant.int64 (interval_upper)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Interval.round (interval_3, unit)),
                new GLib.Variant.int64 (interval_upper)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Interval.round (interval_4, unit)),
                new GLib.Variant.int64 (interval_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Ft.Interval.round (interval_5, unit)),
                new GLib.Variant.int64 (interval_lower)
            );
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.TimestampTest (),
        new Tests.IntervalTest ()
    );
}
