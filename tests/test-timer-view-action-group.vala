/*
 * This file is part of focus-timer
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Tests
{
    public class TimerViewActionGroupTest : Tests.TestSuite
    {
        private Ft.Timer?          timer;
        private Ft.SessionManager? session_manager;

        public TimerViewActionGroupTest ()
        {
            this.add_test ("new",
                           this.test_new);
            this.add_test ("start",
                           this.test_start);
            // this.add_test ("stop",
            //                this.test_stop);
        }

        public override void setup ()
        {
            Ft.Timestamp.freeze_to (2000000000 * Ft.Interval.SECOND);

            this.timer = new Ft.Timer ();
            this.session_manager = new Ft.SessionManager.with_timer (this.timer);
        }

        public override void teardown ()
        {
            Ft.Timestamp.thaw ();

            this.timer = null;
            this.session_manager = null;
        }


        public void test_new ()
        {
            var action_group = new Ft.TimerViewActionGroup (this.session_manager);

            assert_true (action_group.session_manager == this.session_manager);
            assert_true (action_group.timer == this.timer);

            // TODO: check added actions
        }

        public void test_start ()
        {
            var now = Ft.Timestamp.tick (0);
            var action_group = new Ft.TimerViewActionGroup (this.session_manager);

            action_group.activate_action ("start", null);

            assert_true (this.timer.is_running ());
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (0)
            );

            // TODO: check current session
            assert_nonnull (this.session_manager.current_session);


            // TODO: check current time-block
            assert_nonnull (this.session_manager.current_time_block);
        }

        public void test_stop ()
        {
            // TODO
            assert_not_reached ();
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.TimerViewActionGroupTest ()
    );
}
