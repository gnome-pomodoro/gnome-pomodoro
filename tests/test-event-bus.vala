/*
 * This file is part of focus-timer
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Tests
{
    public class EventBusTest : Tests.TestSuite
    {
        private Ft.Timer                     timer;
        private Ft.SessionManager            session_manager;
        private Ft.EventProducer             producer;
        private Ft.EventBus                  bus;
        private Ft.SessionManagerActionGroup session_manager_action_group;
        private Ft.TimerActionGroup          timer_action_group;

        public EventBusTest ()
        {
            this.add_test ("add_event_watch__start", this.test_add_event_watch__start);
            this.add_test ("add_event_watch__pause", this.test_add_event_watch__pause);
            this.add_test ("add_event_watch__with_condition", this.test_add_event_watch__with_condition);
            this.add_test ("remove_event_watch", this.test_remove_event_watch);

            this.add_test ("add_condition_watch", this.test_add_condition_watch);

            this.add_test ("destroy", this.test_destroy);
        }

        public override void setup ()
        {
            Ft.Timestamp.freeze_to (2000000000 * Ft.Interval.SECOND);
            Ft.Timestamp.set_auto_advance (Ft.Interval.MICROSECOND);

            var settings = Ft.get_settings ();
            settings.set_uint ("pomodoro-duration", 1500);
            settings.set_uint ("short-break-duration", 300);
            settings.set_uint ("long-break-duration", 900);
            settings.set_uint ("cycles", 4);
            settings.set_boolean ("confirm-starting-break", false);
            settings.set_boolean ("confirm-starting-pomodoro", false);

            this.timer = new Ft.Timer ();
            Ft.Timer.set_default (this.timer);

            this.session_manager = new Ft.SessionManager.with_timer (this.timer);
            Ft.SessionManager.set_default (this.session_manager);

            this.session_manager_action_group = new Ft.SessionManagerActionGroup ();
            assert (this.session_manager_action_group.session_manager == this.session_manager);

            this.timer_action_group = new Ft.TimerActionGroup ();
            assert (this.timer_action_group.timer == this.timer);

            this.producer = new Ft.EventProducer ();
            assert (producer.session_manager == this.session_manager);
            assert (producer.timer == this.timer);

            this.bus = this.producer.bus;
        }

        public override void teardown ()
        {
            this.producer = null;
            this.bus = null;
            this.session_manager = null;
            this.timer = null;

            Ft.SessionManager.set_default (null);
            Ft.Timer.set_default (null);

            Ft.Context.unset_event_source ();

            var settings = Ft.get_settings ();
            settings.revert ();
        }

        /*
         * Events
         */

        public void test_add_event_watch__start ()
        {
            var expected_timestamp = Ft.Timestamp.from_now ();
            var event_triggered_count = 0;

            this.bus.add_event_watch ("start", null, (event) => {
                event_triggered_count++;

                assert_cmpvariant (
                    new GLib.Variant.int64 (event.context.timestamp),
                    new GLib.Variant.int64 (expected_timestamp)
                );
            });

            Ft.Timestamp.freeze_to (expected_timestamp);
            this.timer_action_group.activate_action ("start", null);

            assert_cmpuint (event_triggered_count, GLib.CompareOperator.EQ, 1);
        }

        public void test_add_event_watch__pause ()
        {
            this.timer.start ();

            var expected_timestamp = Ft.Timestamp.from_now ();
            var event_triggered_count = 0;

            this.bus.add_event_watch ("pause", null, (event) => {
                event_triggered_count++;

                assert_cmpvariant (
                    new GLib.Variant.int64 (event.context.timestamp),
                    new GLib.Variant.int64 (expected_timestamp)
                );
            });

            Ft.Timestamp.freeze_to (expected_timestamp);
            this.timer_action_group.activate_action ("pause", null);

            assert_cmpuint (event_triggered_count, GLib.CompareOperator.EQ, 1);
        }

        public void test_add_event_watch__with_condition ()
        {
            var condition = new Ft.Comparison (
                new Ft.Variable ("state"),
                Ft.Operator.EQ,
                new Ft.Constant (new Ft.StateValue (Ft.State.BREAK))
            );
            var event_triggered_count = 0;

            this.bus.add_event_watch ("pause", condition, (event) => {
                event_triggered_count++;

                assert_true (event.context.timer_state.is_paused ());
            });

            this.session_manager.advance_to_state (Ft.State.POMODORO);

            // Make condition unmet.
            this.timer_action_group.activate_action ("pause", null);
            assert_cmpuint (event_triggered_count, GLib.CompareOperator.EQ, 0);

            // Make condition met.
            this.session_manager_action_group.activate_action ("advance", null);
            assert_cmpuint (event_triggered_count, GLib.CompareOperator.EQ, 0);
            assert_false (this.timer.is_paused ());

            this.timer_action_group.activate_action ("pause", null);
            assert_cmpuint (event_triggered_count, GLib.CompareOperator.EQ, 1);
        }

        public void test_remove_event_watch ()
        {
            var expected_refcount = this.ref_count;

            var event_triggered_count = 0;
            var watch_id = this.bus.add_event_watch ("start", null, (event) => {
                event_triggered_count++;
            });

            this.bus.remove_event_watch (watch_id);

            this.timer.start ();
            assert_cmpuint (event_triggered_count, GLib.CompareOperator.EQ, 0);
            assert_cmpuint (this.ref_count, GLib.CompareOperator.EQ, expected_refcount);
        }

        /*
         * Conditions
         */

        public void test_add_condition_watch ()
        {
            var start_timestamp = Ft.Timestamp.peek ();
            var pause_timestamp = start_timestamp + Ft.Interval.MINUTE;
            var stop_timestamp = pause_timestamp + Ft.Interval.MINUTE;
            var signals = new string[0];
            var paused_called = false;
            var resumed_called = false;

            this.bus.add_condition_watch (
                    new Ft.Comparison.is_true (new Ft.Variable ("is-started")),
                    (context) => {
                        signals += "enter-condition";

                        assert_cmpvariant (
                            new GLib.Variant.int64 (context.timestamp),
                            new GLib.Variant.int64 (start_timestamp)
                        );
                    },
                    (context) => {
                        signals += "leave-condition";

                        assert_cmpvariant (
                            new GLib.Variant.int64 (context.timestamp),
                            new GLib.Variant.int64 (stop_timestamp)
                        );
                    });

            this.bus.add_condition_watch (
                    new Ft.Comparison.is_true (new Ft.Variable ("is-paused")),
                    (context) => {
                        paused_called = true;

                        assert_cmpvariant (
                            new GLib.Variant.int64 (context.timestamp),
                            new GLib.Variant.int64 (pause_timestamp)
                        );
                    },
                    (context) => {
                        resumed_called = true;

                        assert_cmpvariant (
                            new GLib.Variant.int64 (context.timestamp),
                            new GLib.Variant.int64 (stop_timestamp)
                        );
                    });

            Ft.Timestamp.freeze_to (start_timestamp);
            this.timer.start ();

            Ft.Timestamp.freeze_to (pause_timestamp);
            this.timer.pause ();

            Ft.Timestamp.freeze_to (stop_timestamp);
            this.timer.reset ();

            assert_cmpstrv (signals, {
                "enter-condition",
                "leave-condition"
            });
            assert_true (paused_called);
            assert_true (resumed_called);
        }

        /**
         * Test that destroy calls leave on active watches.
         */
        public void test_destroy ()
        {
            var start_timestamp = Ft.Timestamp.peek ();
            var destroy_timestamp = start_timestamp + Ft.Interval.MINUTE;
            var signals = new string[0];

            this.bus.add_condition_watch (
                    new Ft.Comparison.is_true (new Ft.Variable ("is-started")),
                    (context) => {
                        signals += "enter-condition";

                        assert_cmpvariant (
                            new GLib.Variant.int64 (context.timestamp),
                            new GLib.Variant.int64 (start_timestamp)
                        );
                    },
                    (context) => {
                        signals += "leave-condition";

                        assert_cmpvariant (
                            new GLib.Variant.int64 (context.timestamp),
                            new GLib.Variant.int64 (destroy_timestamp)
                        );
                    });

            // Activate the condition so the watch becomes active.
            Ft.Timestamp.freeze_to (start_timestamp);
            this.timer.start ();

            // Destroy should call leave on active watches with current context.
            Ft.Timestamp.freeze_to (destroy_timestamp);
            this.bus.destroy ();

            // Ensure no duplicate leave after a subsequent reset.
            var after_destroy_timestamp = destroy_timestamp + Ft.Interval.SECOND;
            Ft.Timestamp.freeze_to (after_destroy_timestamp);
            this.timer.reset ();

            assert_cmpstrv (signals, {
                "enter-condition",
                "leave-condition"
            });
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.EventBusTest ()
    );
}
