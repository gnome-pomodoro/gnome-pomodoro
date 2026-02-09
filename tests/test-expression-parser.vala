/*
 * This file is part of focus-timer
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Tests
{
    private inline void assert_value_equals (Ft.Value? value,
                                             Ft.Value  expected_value)
    {
        assert_nonnull (value);

        assert_cmpstr (
                value.get_type_name (),
                GLib.CompareOperator.EQ,
                expected_value.get_type_name ());

        assert_cmpvariant (
                value.to_variant (),
                expected_value.to_variant ());
    }


    private inline void assert_root_has_operator (Ft.Expression expression,
                                                  Ft.Operator   operator)
    {
        if (expression is Ft.Operation)
        {
            var operation = (Ft.Operation) expression;
            assert_cmpstr (operation.operator.to_string (),
                           GLib.CompareOperator.EQ,
                           operator.to_string ());
            return;
        }

        if (expression is Ft.Comparison)
        {
            var comparison = (Ft.Comparison) expression;
            assert_cmpstr (comparison.operator.to_string (),
                           GLib.CompareOperator.EQ,
                           operator.to_string ());
            return;
        }

        assert_not_reached ();
    }


    public class ExpressionParserTest : Tests.TestSuite
    {
        private GLib.Quark error_domain;

        public ExpressionParserTest ()
        {
            this.add_test ("parse_empty", this.test_parse_empty);

            this.add_test ("parse_string_literal__string", this.test_parse_string_literal__string);
            this.add_test ("parse_string_literal__state", this.test_parse_string_literal__state);
            this.add_test ("parse_string_literal__status", this.test_parse_string_literal__status);
            this.add_test ("parse_string_literal__timestamp", this.test_parse_string_literal__timestamp);
            this.add_test ("parse_string_literal__syntax_error", this.test_parse_string_literal__syntax_error);

            this.add_test ("parse_numeric_literal__interval", this.test_parse_numeric_literal__interval);
            this.add_test ("parse_numeric_literal__syntax_error", this.test_parse_numeric_literal__syntax_error);

            this.add_test ("parse_identifier__variable", this.test_parse_identifier__variable);
            this.add_test ("parse_identifier__boolean", this.test_parse_identifier__boolean);
            this.add_test ("parse_identifier__syntax_error", this.test_parse_identifier__syntax_error);
            this.add_test ("parse_identifier__unknown_identifier_error", this.test_parse_identifier__unknown_identifier_error);

            this.add_test ("parse_operator__or", this.test_parse_operator__or);
            this.add_test ("parse_operator__and", this.test_parse_operator__and);
            this.add_test ("parse_operator__eq", this.test_parse_operator__eq);
            this.add_test ("parse_operator__gt", this.test_parse_operator__gt);

            this.add_test ("parse_parentheses", this.test_parse_parentheses);
            this.add_test ("parse_parentheses__syntax_error", this.test_parse_parentheses__syntax_error);

            this.add_test ("precedence__logical_operator", this.test_precedence__logical_operator);
            this.add_test ("precedence__comparison_operator", this.test_precedence__comparison_operator);

            this.add_test ("syntax_error", this.test_syntax_error);
        }

        public override void setup ()
        {
            this.error_domain = GLib.Quark.from_string ("ft-expression-parser-error-quark");
        }

        public void test_parse_empty ()
        {
            try {
                assert_null (Ft.Expression.parse (""));
                assert_null (Ft.Expression.parse (" "));
                assert_null (Ft.Expression.parse ("\n"));
                assert_null (Ft.Expression.parse ("\t"));
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        /*
         * String Literal
         */

        public void test_parse_string_literal__string ()
        {
            try {
                var expression_1 = Ft.Expression.parse ("\"hello\"");
                var expression_2 = Ft.Expression.parse (" \"hello\" ");
                var expression_3 = Ft.Expression.parse ("\"a\nb\"");
                var expression_4 = Ft.Expression.parse (""" "a\"b" """);

                assert_cmpstr ((expression_1 as Ft.Constant)?.get_string (),
                               GLib.CompareOperator.EQ,
                               "hello");
                assert_cmpstr ((expression_2 as Ft.Constant)?.get_string (),
                               GLib.CompareOperator.EQ,
                               "hello");
                assert_cmpstr ((expression_3 as Ft.Constant)?.get_string (),
                               GLib.CompareOperator.EQ,
                               "a\nb");
                assert_cmpstr ((expression_4 as Ft.Constant)?.get_string (),
                               GLib.CompareOperator.EQ,
                               "a\"b");
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_string_literal__state ()
        {
            try {
                var expression_1 = Ft.Expression.parse ("\"pomodoro\"") as Ft.Constant;
                assert_value_equals (expression_1?.value,
                                     new Ft.StateValue (Ft.State.POMODORO));

                var expression_2 = Ft.Expression.parse ("\"break\"") as Ft.Constant;
                assert_value_equals (expression_2?.value,
                                     new Ft.StateValue (Ft.State.BREAK));

                var expression_3 = Ft.Expression.parse ("\"short-break\"") as Ft.Constant;
                assert_value_equals (expression_3?.value,
                                     new Ft.StateValue (Ft.State.SHORT_BREAK));

                var expression_4 = Ft.Expression.parse ("\"long-break\"") as Ft.Constant;
                assert_value_equals (expression_4?.value,
                                     new Ft.StateValue (Ft.State.LONG_BREAK));

                var expression_5 = Ft.Expression.parse ("\"stopped\"") as Ft.Constant;
                assert_value_equals (expression_5?.value,
                                     new Ft.StateValue (Ft.State.STOPPED));
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_string_literal__status ()
        {
            try {
                var expression_1 = Ft.Expression.parse ("\"scheduled\"") as Ft.Constant;
                assert_value_equals (expression_1?.value,
                                     new Ft.StatusValue (Ft.TimeBlockStatus.SCHEDULED));

                var expression_2 = Ft.Expression.parse ("\"in-progress\"") as Ft.Constant;
                assert_value_equals (expression_2?.value,
                                     new Ft.StatusValue (Ft.TimeBlockStatus.IN_PROGRESS));

                var expression_3 = Ft.Expression.parse ("\"completed\"") as Ft.Constant;
                assert_value_equals (expression_3?.value,
                                     new Ft.StatusValue (Ft.TimeBlockStatus.COMPLETED));

                var expression_4 = Ft.Expression.parse ("\"uncompleted\"") as Ft.Constant;
                assert_value_equals (expression_4?.value,
                                     new Ft.StatusValue (Ft.TimeBlockStatus.UNCOMPLETED));
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_string_literal__timestamp ()
        {
            try {
                var expected_timestamp = Ft.Timestamp.from_seconds_uint (1014304205);

                var expression = Ft.Expression.parse ("\"2002-02-21T15:10:05Z\"") as Ft.Constant;
                assert_value_equals (expression?.value,
                                     new Ft.TimestampValue (expected_timestamp));
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_string_literal__syntax_error ()
        {
            string[] invalid_texts = {
                "\"hello",
                " \"hello\" \"world\" ",
                "'hello'"
            };

            foreach (var text in invalid_texts)
            {
                try {
                    Ft.Expression.parse (text);
                }
                catch (Ft.ExpressionParserError error) {
                    assert_error (error,
                                  this.error_domain,
                                  Ft.ExpressionParserError.SYNTAX_ERROR);
                }
            }
        }

        /*
         * Numeric Literal / Intervals
         */

        public void test_parse_numeric_literal__interval ()
        {
            try {
                var expression_1 = Ft.Expression.parse ("1") as Ft.Constant;
                assert_value_equals (expression_1?.value,
                                     new Ft.IntervalValue (Ft.Interval.MICROSECOND));

                var expression_2 = Ft.Expression.parse ("0") as Ft.Constant;
                assert_value_equals (expression_2?.value,
                                     new Ft.IntervalValue (0));

                var expression_3 = Ft.Expression.parse ("1000000") as Ft.Constant;
                assert_value_equals (expression_3?.value,
                                     new Ft.IntervalValue (Ft.Interval.SECOND));

                var expression_4 = Ft.Expression.parse ("-1000000") as Ft.Constant;
                assert_value_equals (expression_4?.value,
                                     new Ft.IntervalValue (-Ft.Interval.SECOND));
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_numeric_literal__syntax_error ()
        {
            string[] invalid_texts = {
                "-",
                "123D"
            };

            foreach (var text in invalid_texts)
            {
                try {
                    Ft.Expression.parse (text);
                }
                catch (Ft.ExpressionParserError error) {
                    assert_error (error,
                                  this.error_domain,
                                  Ft.ExpressionParserError.SYNTAX_ERROR);
                }
            }
        }

        /*
         * Identifier
         */

        public void test_parse_identifier__variable ()
        {
            try {
                var expression_1 = Ft.Expression.parse ("isPaused");
                assert_true (expression_1 is Ft.Variable);
                assert_cmpstr ((expression_1 as Ft.Variable)?.name,
                                GLib.CompareOperator.EQ,
                                "is-paused");

                var expression_2 = Ft.Expression.parse (" isPaused ");
                assert_true (expression_2 is Ft.Variable);
                assert_cmpstr ((expression_2 as Ft.Variable)?.name,
                                GLib.CompareOperator.EQ,
                                "is-paused");
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_identifier__boolean ()
        {
            try {
                var true_constant = Ft.Expression.parse ("true") as Ft.Constant;
                assert_nonnull (true_constant);
                assert_true (true_constant.value is Ft.BooleanValue);

                var true_value = (Ft.BooleanValue) true_constant.value;
                assert_true (true_value.data);
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }

            try {
                var false_constant = Ft.Expression.parse ("false") as Ft.Constant;
                assert_nonnull (false_constant);
                assert_true (false_constant.value is Ft.BooleanValue);

                var false_value = (Ft.BooleanValue) false_constant.value;
                assert_false (false_value.data);
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_identifier__syntax_error ()
        {
            string[] invalid_texts = {
                "isPaused isPaused",
                "123abc",
            };

            foreach (var text in invalid_texts)
            {
                try {
                    Ft.Expression.parse (text);
                }
                catch (Ft.ExpressionParserError error) {
                    assert_error (error, this.error_domain, Ft.ExpressionParserError.SYNTAX_ERROR);
                }
            }
        }

        public void test_parse_identifier__unknown_identifier_error ()
        {
            string[] unknown_names = {
                "abc123",
                "Foo",
                "TRUE",
                "True",
                "FALSE",
                "False",
                "null",
                "undefined",
                "NaN",
            };

            foreach (var name in unknown_names)
            {
                try {
                    Ft.Expression.parse (name);
                }
                catch (Ft.ExpressionParserError error) {
                    assert_error (error, this.error_domain, Ft.ExpressionParserError.UNKNOWN_IDENTIFIER);
                }
            }
        }

        /*
         * Operators
         */

        public void test_parse_operator__or ()
        {
            try {
                var expression_1 = Ft.Expression.parse (
                    "isPaused || isFinished") as Ft.Operation;
                assert_nonnull (expression_1);
                assert_true (expression_1.operator == Ft.Operator.OR);
                assert_cmpstr (expression_1.to_string (),
                               GLib.CompareOperator.EQ,
                               "isPaused || isFinished");

                var expression_2 = Ft.Expression.parse (
                    "isPaused||isFinished||isStarted") as Ft.Operation;
                assert_nonnull (expression_2);
                assert_true (expression_2.operator == Ft.Operator.OR);
                assert_cmpstr (expression_2.to_string (),
                               GLib.CompareOperator.EQ,
                               "isPaused || isFinished || isStarted");
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_operator__and ()
        {
            try {
                var expression_1 = Ft.Expression.parse (
                    "isPaused && isFinished") as Ft.Operation;
                assert_nonnull (expression_1);
                assert_true (expression_1.operator == Ft.Operator.AND);
                assert_cmpstr (expression_1.to_string (),
                               GLib.CompareOperator.EQ,
                               "isPaused && isFinished");

                var expression_2 = Ft.Expression.parse (
                    "isPaused&&isFinished&&isStarted") as Ft.Operation;
                assert_nonnull (expression_2);
                assert_true (expression_2.operator == Ft.Operator.AND);
                assert_cmpstr (expression_2.to_string (),
                               GLib.CompareOperator.EQ,
                               "isPaused && isFinished && isStarted");
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_operator__eq ()
        {
            try {
                var expression_1 = Ft.Expression.parse (
                    "isPaused == isFinished") as Ft.Comparison;
                assert_nonnull (expression_1);
                assert_true (expression_1.operator == Ft.Operator.EQ);
                var expression_1_lhs = expression_1.argument_lhs as Ft.Variable;
                assert_cmpstr (expression_1_lhs.name,
                               GLib.CompareOperator.EQ,
                               "is-paused");
                var expression_1_rhs = expression_1.argument_rhs as Ft.Variable;
                assert_cmpstr (expression_1_rhs.name,
                               GLib.CompareOperator.EQ,
                               "is-finished");

                // TODO: make a chain of comparisons using AND operator
                // var expression_2 = Ft.Expression.parse (
                //     "isPaused == isFinished == isRunning") as Ft.Operation;
                // assert_nonnull (expression_1);
                // assert_true (expression_1.operator == Ft.Operator.AND);
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_operator__gt ()
        {
            try {
                var expression_1 = Ft.Expression.parse (
                    "isPaused > isFinished") as Ft.Comparison;
                assert_nonnull (expression_1);
                assert_true (expression_1.operator == Ft.Operator.GT);
                var expression_1_lhs = expression_1.argument_lhs as Ft.Variable;
                assert_cmpstr (expression_1_lhs.name,
                               GLib.CompareOperator.EQ,
                               "is-paused");
                var expression_1_rhs = expression_1.argument_rhs as Ft.Variable;
                assert_cmpstr (expression_1_rhs.name,
                               GLib.CompareOperator.EQ,
                               "is-finished");
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }


        /*
         * Parentheses
         */

        public void test_parse_parentheses ()
        {
            try {
                var expression_1 = Ft.Expression.parse ("(isPaused)") as Ft.Variable;
                assert_nonnull (expression_1);
                assert_cmpstr (expression_1.name,
                               GLib.CompareOperator.EQ,
                               "is-paused");
                assert_cmpstr (expression_1.to_string (),
                               GLib.CompareOperator.EQ,
                               "isPaused");

                var expression_2 = Ft.Expression.parse ("((isPaused))") as Ft.Variable;
                assert_nonnull (expression_2);
                assert_cmpstr (expression_2.name,
                                GLib.CompareOperator.EQ,
                                "is-paused");
                assert_cmpstr (expression_2.to_string (),
                               GLib.CompareOperator.EQ,
                               "isPaused");

                var expression_3 = Ft.Expression.parse (
                    "(isPaused && isStarted)") as Ft.Operation;
                assert_nonnull (expression_3);
                assert_true (expression_3.operator == Ft.Operator.AND);
                assert_cmpstr (expression_3.to_string (),
                               GLib.CompareOperator.EQ,
                               "isPaused && isStarted");

                var expression_4 = Ft.Expression.parse (
                    "(isPaused || isStarted) && isFinished") as Ft.Operation;
                assert_nonnull (expression_4);
                assert_true (expression_4.operator == Ft.Operator.AND);
                assert_cmpstr (expression_4.to_string (),
                               GLib.CompareOperator.EQ,
                               "(isPaused || isStarted) && isFinished");

                var expression_5 = Ft.Expression.parse ("()");
                assert_null (expression_5);
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_parentheses__syntax_error ()
        {
            string[] invalid_texts = {
                "(",
                ")",
                "())",
                "(()",
            };

            foreach (var text in invalid_texts)
            {
                try {
                    Ft.Expression.parse (text);

                    GLib.error ("No error raised for '%s'", text);
                }
                catch (Ft.ExpressionParserError error) {
                    assert_error (error,
                                  this.error_domain,
                                  Ft.ExpressionParserError.SYNTAX_ERROR);
                }
            }
        }


        /*
         * Precedence
         */

        public void test_precedence__logical_operator ()
        {
            try {
                /*
                 *      ||
                 *     /  \
                 * false   &&
                 *        /  \
                 *    false   true
                 */
                var expression_1 = Ft.Expression.parse ("false || false && true");
                assert_cmpstr (expression_1.to_string (),
                               GLib.CompareOperator.EQ,
                               "false || false && true");
                assert_root_has_operator (expression_1, Ft.Operator.OR);

                /*
                 *         ||
                 *        /  \
                 *      &&    true
                 *     /  \
                 * false   true
                 */
                var expression_2 = Ft.Expression.parse ("false && false || true");
                assert_cmpstr (expression_2.to_string (),
                               GLib.CompareOperator.EQ,
                               "false && false || true");
                assert_root_has_operator (expression_2, Ft.Operator.OR);

                var expression_3 = Ft.Expression.parse (
                    "false && false && false || true || true");
                assert_cmpstr (expression_3.to_string (),
                               GLib.CompareOperator.EQ,
                               "false && false && false || true || true");
                assert_root_has_operator (expression_3, Ft.Operator.OR);
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_precedence__comparison_operator ()
        {
            try {
                var expression_1 = Ft.Expression.parse ("true && false != true");
                assert_cmpstr (expression_1.to_string (),
                               GLib.CompareOperator.EQ,
                               "true && false != true");
                assert_root_has_operator (expression_1, Ft.Operator.AND);

                var expression_2 = Ft.Expression.parse ("true != false && true");
                assert_cmpstr (expression_2.to_string (),
                               GLib.CompareOperator.EQ,
                               "true != false && true");
                assert_root_has_operator (expression_2, Ft.Operator.AND);

                var expression_3 = Ft.Expression.parse ("true || false != true");
                assert_cmpstr (expression_3.to_string (),
                               GLib.CompareOperator.EQ,
                               "true || false != true");
                assert_root_has_operator (expression_3, Ft.Operator.OR);
            }
            catch (Ft.ExpressionParserError error) {
                assert_no_error (error);
            }
        }


        /*
         * Misc
         */

        public void test_syntax_error ()
        {
            string[] invalid_texts = {
                "/* comment */",
                "// comment",
                ";",
                "arr[0]",
                "[1, 2, 3]",
                "**",
                "(&& isStarted)",
                "^",
                "isPaused ==",
            };

            foreach (var text in invalid_texts)
            {
                try {
                    Ft.Expression.parse (text);
                }
                catch (Ft.ExpressionParserError error) {
                    assert_error (error, this.error_domain, Ft.ExpressionParserError.SYNTAX_ERROR);
                }
            }
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.ExpressionParserTest ()
    );
}
