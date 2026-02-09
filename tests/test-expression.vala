/*
 * This file is part of focus-timer
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Tests
{
    public inline void assert_value_equals (Ft.Value value,
                                            Ft.Value expected_value)
    {
        assert_cmpstr (value.get_type_name (),
                       GLib.CompareOperator.EQ,
                       expected_value.get_type_name ());

        assert_cmpvariant (value.to_variant (),
                           expected_value.to_variant ());
    }


    public class ConstantTest : Tests.TestSuite
    {
        private Ft.Context? context;

        public ConstantTest ()
        {
            this.add_test ("state", this.test_state);
            this.add_test ("timestamp", this.test_timestamp);
            this.add_test ("interval", this.test_interval);
            this.add_test ("boolean", this.test_boolean);
        }

        public override void setup ()
        {
            this.context = new Ft.Context ();
        }

        public override void teardown ()
        {
            this.context = null;
        }

        public void test_state ()
        {
            var state = Ft.State.BREAK;
            var constant = new Ft.Constant (new Ft.StateValue (state));

            try {
                assert_value_equals (constant.evaluate (this.context),
                                     new Ft.StateValue (state));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }

            assert_cmpstr (constant.to_string (),
                           GLib.CompareOperator.EQ,
                           @"\"$(state.to_string())\"");
        }

        public void test_timestamp ()
        {
            var timestamp = Ft.Timestamp.from_now ();
            var constant = new Ft.Constant (new Ft.TimestampValue (timestamp));

            try {
                assert_value_equals (constant.evaluate (this.context),
                                     new Ft.TimestampValue (timestamp));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }

            assert_cmpstr (constant.to_string (),
                           GLib.CompareOperator.EQ,
                           @"\"$(Ft.Timestamp.to_iso8601(timestamp))\"");
        }

        public void test_interval ()
        {
            var interval = Ft.Interval.HOUR;
            var constant = new Ft.Constant (new Ft.IntervalValue (interval));

            try {
                assert_value_equals (
                    constant.evaluate (this.context),
                    new Ft.IntervalValue (interval)
                );
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }

            assert_cmpstr (constant.to_string (),
                           GLib.CompareOperator.EQ,
                           interval.to_string ());
        }

        public void test_boolean ()
        {
            var constant = new Ft.Constant (new Ft.BooleanValue (true));

            try {
                assert_value_equals (constant.evaluate (this.context),
                                     new Ft.BooleanValue (true));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }

            assert_cmpstr (constant.to_string (),
                           GLib.CompareOperator.EQ,
                           "true");
        }
    }


    public class VariableTest : Tests.TestSuite
    {
        private Ft.Context? context;

        public VariableTest ()
        {
            this.add_test ("timestamp", this.test_timestamp);
            this.add_test ("state", this.test_state);
            this.add_test ("status", this.test_status);
            this.add_test ("is_started", this.test_is_started);
            this.add_test ("is_paused", this.test_is_paused);
            this.add_test ("is_finished", this.test_is_finished);
            this.add_test ("is_running", this.test_is_running);
            this.add_test ("duration", this.test_duration);
            this.add_test ("offset", this.test_offset);
            this.add_test ("elapsed", this.test_elapsed);
            this.add_test ("remaining", this.test_remaining);

            this.add_test ("to_string", this.test_to_string);
        }

        public override void setup ()
        {
            var time_block = new Ft.TimeBlock (Ft.State.SHORT_BREAK);
            time_block.set_time_range (1000, 1600);
            time_block.set_status (Ft.TimeBlockStatus.COMPLETED);

            var context = new Ft.Context ();
            context.timestamp = 1000;
            context.timer_state = Ft.TimerState () {
                duration = 600,
                user_data = time_block
            };
            context.time_block = time_block;

            this.context = context;
        }

        public override void teardown ()
        {
            this.context = null;
        }

        public void test_timestamp ()
        {
            var variable = new Ft.Variable ("timestamp");

            try {
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.TimestampValue (1000));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_state ()
        {
            var variable = new Ft.Variable ("state");

            try {
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.StateValue (Ft.State.SHORT_BREAK));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_status ()
        {
            var variable = new Ft.Variable ("status");

            try {
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.StatusValue (Ft.TimeBlockStatus.COMPLETED));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_is_started ()
        {
            var variable = new Ft.Variable ("is-started");

            try {
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.BooleanValue (false));

                this.context.timer_state.started_time = 1200;
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.BooleanValue (true));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_is_paused ()
        {
            var variable = new Ft.Variable ("is-paused");

            try {
                this.context.timer_state.started_time = 1200;
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.BooleanValue (false));

                this.context.timer_state.paused_time = 1400;
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.BooleanValue (true));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_is_finished ()
        {
            var variable = new Ft.Variable ("is-finished");

            try {
                this.context.timer_state.started_time = 1200;
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.BooleanValue (false));

                this.context.timer_state.finished_time = 1600;
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.BooleanValue (true));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_is_running ()
        {
            var variable = new Ft.Variable ("is-running");

            try {
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.BooleanValue (false));

                this.context.timer_state.started_time = 1200;
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.BooleanValue (true));

                this.context.timer_state.paused_time = 1400;
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.BooleanValue (false));

                this.context.timer_state.paused_time = Ft.Timestamp.UNDEFINED;
                this.context.timer_state.finished_time = 1600;
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.BooleanValue (false));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_duration ()
        {
            var variable = new Ft.Variable ("duration");

            try {
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.IntervalValue (600));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_offset ()
        {
            var variable = new Ft.Variable ("offset");

            try {
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.IntervalValue (0));

                this.context.timer_state.offset = 60;
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.IntervalValue (60));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_elapsed ()
        {
            var variable = new Ft.Variable ("elapsed");

            try {
                this.context.timestamp = 1300;
                this.context.timer_state.started_time = 1200;
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.IntervalValue (100));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_remaining ()
        {
            var variable = new Ft.Variable ("remaining");

            try {
                this.context.timestamp = 1300;
                this.context.timer_state.started_time = 1200;
                assert_value_equals (variable.evaluate (this.context),
                                     new Ft.IntervalValue (500));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_to_string ()
        {
            var variable = new Ft.Variable ("is-paused");

            assert_cmpstr (variable.to_string (),
                           GLib.CompareOperator.EQ,
                           "isPaused");
        }
    }


    public class OperationTest : Tests.TestSuite
    {
        private Ft.Context? context;

        public OperationTest ()
        {
            this.add_test ("and__boolean", this.test_and__boolean);
            this.add_test ("and__timestamp", this.test_and__timestamp);
            this.add_test ("and__state", this.test_and__state);

            this.add_test ("to_string__single_argument", this.test_to_string__single_argument);
            this.add_test ("to_string__nested", this.test_to_string__nested);
            this.add_test ("to_string__wrap_argument", this.test_to_string__wrap_argument);
        }

        public override void setup ()
        {
            this.context = new Ft.Context ();
        }

        public override void teardown ()
        {
            this.context = null;
        }

        public void test_and__boolean ()
        {
            bool[,] cases = {
                { false, false, false },
                { false, true, false },
                { true, false, false },
                { true, true, true }
            };

            for (var index=0; index < 4; index++)
            {
                var value_1 = new Ft.BooleanValue (cases[index, 0]);
                var value_2 = new Ft.BooleanValue (cases[index, 1]);
                var expected_result = new Ft.BooleanValue (cases[index, 2]);

                var operation = new Ft.Operation (Ft.Operator.AND,
                                                        new Ft.Constant (value_1),
                                                        new Ft.Constant (value_2));
                try {
                    assert_value_equals (operation.evaluate (this.context),
                                         expected_result);
                }
                catch (Ft.ExpressionError error) {
                    assert_no_error (error);
                }
            }
        }

        public void test_and__timestamp ()
        {
            var value_1 = new Ft.TimestampValue (Ft.Timestamp.UNDEFINED);
            var value_2 = new Ft.TimestampValue (Ft.Timestamp.from_now ());
            var value_3 = new Ft.BooleanValue (true);

            try {
                var operation_1 = new Ft.Operation (Ft.Operator.AND,
                                                          new Ft.Constant (value_1),
                                                          new Ft.Constant (value_3));
                assert_value_equals (operation_1.evaluate (this.context),
                                     new Ft.BooleanValue (false));

                var operation_2 = new Ft.Operation (Ft.Operator.AND,
                                                          new Ft.Constant (value_2),
                                                          new Ft.Constant (value_3));
                assert_value_equals (operation_2.evaluate (this.context),
                                     new Ft.BooleanValue (true));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_and__state ()
        {
            var value_1 = new Ft.StateValue (Ft.State.STOPPED);
            var value_2 = new Ft.StateValue (Ft.State.POMODORO);
            var value_3 = new Ft.BooleanValue (true);

            try {
                var operation_1 = new Ft.Operation (Ft.Operator.AND,
                                                          new Ft.Constant (value_1),
                                                          new Ft.Constant (value_3));
                assert_value_equals (operation_1.evaluate (this.context),
                                     new Ft.BooleanValue (false));

                var operation_2 = new Ft.Operation (Ft.Operator.AND,
                                                          new Ft.Constant (value_2),
                                                          new Ft.Constant (value_3));
                assert_value_equals (operation_2.evaluate (this.context),
                                     new Ft.BooleanValue (true));
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_to_string__single_argument ()
        {
            var argument_1 = new Ft.Variable ("is-paused");
            var argument_2 = new Ft.Constant (
                new Ft.IntervalValue (Ft.Interval.HOUR));
            var argument_3 = new Ft.Comparison (
                new Ft.Variable ("state"),
                Ft.Operator.EQ,
                new Ft.Constant (new Ft.StateValue (Ft.State.POMODORO)));
            var argument_4 = new Ft.Operation (Ft.Operator.OR, argument_1, argument_3);

            var operation_1 = new Ft.Operation (Ft.Operator.AND, argument_1);
            assert_cmpstr (operation_1.to_string (),
                           GLib.CompareOperator.EQ,
                           argument_1.to_string ());

            var operation_2 = new Ft.Operation (Ft.Operator.AND, argument_2);
            assert_cmpstr (operation_2.to_string (),
                           GLib.CompareOperator.EQ,
                           argument_2.to_string ());

            var operation_3 = new Ft.Operation (Ft.Operator.AND, argument_3);
            assert_cmpstr (operation_3.to_string (),
                           GLib.CompareOperator.EQ,
                           argument_3.to_string ());

            var operation_4 = new Ft.Operation (Ft.Operator.AND, argument_4);
            assert_cmpstr (operation_4.to_string (),
                           GLib.CompareOperator.EQ,
                           argument_4.to_string ());
        }

        public void test_to_string__nested ()
        {
            var argument_1 = new Ft.Variable ("is-started");
            var argument_2 = new Ft.Variable ("is-paused");
            var argument_3 = new Ft.Variable ("is-running");
            var argument_4 = new Ft.Variable ("is-finished");

            var operation_1 = new Ft.Operation (
                Ft.Operator.AND,
                new Ft.Operation (Ft.Operator.OR, argument_1, argument_2),
                new Ft.Operation (Ft.Operator.OR, argument_3, argument_4)
            );
            assert_cmpstr (operation_1.to_string (),
                           GLib.CompareOperator.EQ,
                           "(isStarted || isPaused) && (isRunning || isFinished)");

            var operation_2 = new Ft.Operation (
                Ft.Operator.OR,
                new Ft.Operation (Ft.Operator.AND, argument_1, argument_2),
                new Ft.Operation (Ft.Operator.AND, argument_3, argument_4)
            );
            assert_cmpstr (operation_2.to_string (),
                           GLib.CompareOperator.EQ,
                           "isStarted && isPaused || isRunning && isFinished");
        }

        public void test_to_string__wrap_argument ()
        {
            var argument_1 = new Ft.Variable ("state");
            var argument_2 = new Ft.Constant (new Ft.StateValue (Ft.State.POMODORO));
            var argument_3 = new Ft.Variable ("is-started");
            var argument_4 = new Ft.Variable ("is-paused");

            var operation = new Ft.Operation (
                Ft.Operator.AND,
                new Ft.Comparison (argument_1, Ft.Operator.EQ, argument_2),
                new Ft.Operation (Ft.Operator.OR, argument_3, argument_4)
            );
            assert_cmpstr (operation.to_string (),
                           GLib.CompareOperator.EQ,
                           "state == \"pomodoro\" && (isStarted || isPaused)");
        }
    }


    public class ComparisonTest : Tests.TestSuite
    {
        private Ft.Context? context;

        public ComparisonTest ()
        {
            this.add_test ("eq__state", this.test_eq__state);
            this.add_test ("not_eq__state", this.test_not_eq__state);

            this.add_test ("to_string__simple", this.test_to_string__simple);
            this.add_test ("to_string__nested", this.test_to_string__nested);
            this.add_test ("to_string__is_true", this.test_to_string__is_true);
        }

        public override void setup ()
        {
            this.context = new Ft.Context ();
        }

        public override void teardown ()
        {
            this.context = null;
        }

        public void test_eq__state ()
        {
            var comparison_1 = new Ft.Comparison (
                new Ft.Constant (new Ft.StateValue (Ft.State.POMODORO)),
                Ft.Operator.EQ,
                new Ft.Constant (new Ft.StateValue (Ft.State.POMODORO)));

            try {
                assert_true (comparison_1.evaluate (this.context)?.to_boolean ());
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }

            var comparison_2 = new Ft.Comparison (
                new Ft.Constant (new Ft.StateValue (Ft.State.SHORT_BREAK)),
                Ft.Operator.EQ,
                new Ft.Constant (new Ft.StateValue (Ft.State.BREAK)));

            try {
                assert_true (comparison_2.evaluate (this.context)?.to_boolean ());
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_not_eq__state ()
        {
            var comparison = new Ft.Comparison (
                new Ft.Constant (new Ft.StateValue (Ft.State.STOPPED)),
                Ft.Operator.NOT_EQ,
                new Ft.Constant (new Ft.StateValue (Ft.State.POMODORO)));

            try {
                assert_true (comparison.evaluate (this.context)?.to_boolean ());
            }
            catch (Ft.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_to_string__simple ()
        {
            var comparison = new Ft.Comparison (
                new Ft.Variable ("state"),
                Ft.Operator.EQ,
                new Ft.Constant (new Ft.StateValue (Ft.State.POMODORO)));
            assert_cmpstr (comparison.to_string (),
                           GLib.CompareOperator.EQ,
                           "state == \"pomodoro\"");
        }

        public void test_to_string__nested ()
        {
            var comparison_1 = new Ft.Comparison (
                new Ft.Variable ("state"),
                Ft.Operator.EQ,
                new Ft.Constant (new Ft.StateValue (Ft.State.POMODORO)));
            var comparison_2 = new Ft.Comparison (
                new Ft.Variable ("duration"),
                Ft.Operator.GT,
                new Ft.Constant (new Ft.IntervalValue (Ft.Interval.MINUTE)));

            var comparison = new Ft.Comparison (comparison_1,
                                                      Ft.Operator.EQ,
                                                      comparison_2);
            assert_cmpstr (comparison.to_string (),
                           GLib.CompareOperator.EQ,
                           "(state == \"pomodoro\") == (duration > 60000000)");
        }

        public void test_to_string__is_true ()
        {
            var comparison = new Ft.Comparison.is_true (new Ft.Variable ("is-started"));
            assert_cmpstr (comparison.to_string (),
                           GLib.CompareOperator.EQ,
                           "isStarted");
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.ConstantTest (),
        new Tests.VariableTest (),
        new Tests.OperationTest (),
        new Tests.ComparisonTest ()
    );
}
