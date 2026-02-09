/*
 * Copyright (c) 2024-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Ft
{
    private inline string quote_string (string text)
    {
        // TODO: escape quotes

        return @"\"$(text)\"";
    }


    public errordomain ExpressionError
    {
        EMPTY,
        VALUE,
        TYPE,
        INVALID
    }


    public enum OperatorCategory
    {
        LOGICAL,
        COMPARISON
    }


    /**
     * Operator takes two inputs and produces one output.
     *
     * By this definition a "NOT" operation would not be an operator, but a function.
     */
    public enum Operator
    {
        INVALID,

        // Logical
        AND,
        OR,

        // Comparison
        EQ,
        LT,
        LTE,
        GT,
        GTE,
        NOT_EQ;

        public Ft.OperatorCategory get_category ()
        {
            switch (this)
            {
                case AND:
                case OR:
                    return Ft.OperatorCategory.LOGICAL;

                case EQ:
                case LT:
                case LTE:
                case GT:
                case GTE:
                case NOT_EQ:
                    return Ft.OperatorCategory.COMPARISON;

                default:
                    assert_not_reached ();
            }
        }

        internal uint get_precedence ()
        {
            switch (this)
            {
                case OR:
                    return 1;

                case AND:
                    return 2;

                case EQ:
                case LT:
                case LTE:
                case GT:
                case GTE:
                case NOT_EQ:
                    return 3;

                default:
                    assert_not_reached ();
            }
        }

        public static void @foreach (GLib.Func<Ft.Operator> func)
        {
            Ft.Operator[] operators = {
                AND,
                OR,
                EQ,
                LT,
                LTE,
                GT,
                GTE,
                NOT_EQ,
            };

            foreach (var operator in operators) {
                func (operator);
            }
        }

        private static inline Ft.Value apply_and (Ft.Value value_1,
                                                  Ft.Value value_2)
        {
            return new Ft.BooleanValue (value_1.to_boolean () && value_2.to_boolean ());
        }

        private static inline Ft.Value apply_or (Ft.Value value_1,
                                                 Ft.Value value_2)
        {
            return new Ft.BooleanValue (value_1.to_boolean () || value_2.to_boolean ());
        }

        public Ft.Value apply (Ft.Value value_1,
                               Ft.Value value_2)
                               throws Ft.ExpressionError
        {
            switch (this)
            {
                case AND:
                    return apply_and (value_1, value_2);

                case OR:
                    return apply_or (value_1, value_2);

                case EQ:
                    return value_1.apply_eq (value_2);

                case LT:
                    return value_1.apply_lt (value_2);

                case LTE:
                    return apply_or (value_1.apply_lt (value_2),
                                     value_1.apply_eq (value_2));

                case GT:
                    return value_1.apply_gt (value_2);

                case GTE:
                    return apply_or (value_1.apply_gt (value_2),
                                     value_1.apply_eq (value_2));

                case NOT_EQ:
                    return new Ft.BooleanValue (!value_1.apply_eq (value_2).to_boolean ());

                default:
                    assert_not_reached ();
            }
        }

        public GLib.Type get_result_type (GLib.Type value_type_1,
                                          GLib.Type value_type_2)
        {
            switch (this.get_category ())
            {
                case Ft.OperatorCategory.COMPARISON:
                    return typeof (Ft.BooleanValue);

                case Ft.OperatorCategory.LOGICAL:
                    return typeof (Ft.BooleanValue);  // TODO: the result type should vary at runtime; make it work like in javascript

                default:
                    assert_not_reached ();
            }
        }

        public string to_string ()
        {
            switch (this)
            {
                case AND:
                    return "&&";

                case OR:
                    return "||";

                case EQ:
                    return "==";

                case LT:
                    return "<";

                case LTE:
                    return "<=";

                case GT:
                    return ">";

                case GTE:
                    return ">=";

                case NOT_EQ:
                    return "!=";

                default:
                    assert_not_reached ();
            }
        }
    }


    public abstract class Value
    {
        public abstract GLib.Type get_value_type ();

        public abstract string get_type_name ();

        public abstract bool to_boolean ();

        public abstract string to_representation ();

        public abstract GLib.Variant to_variant ();

        public virtual GLib.Variant format (string name) throws Ft.ExpressionError
        {
            if (name != "") {
                throw new Ft.ExpressionError.INVALID (_("Unknown format \"%s\""), name);
            }

            return this.to_variant ();
        }

        internal virtual Ft.Value apply_eq (Ft.Value other)
                                            throws Ft.ExpressionError
        {
            throw new Ft.ExpressionError.INVALID (
                "Comparison operation not supported for types '%s' and '%s'",  // TODO: gettext
                this.get_type_name (),
                other.get_type_name ());
        }

        internal virtual Ft.Value apply_gt (Ft.Value other)
                                            throws Ft.ExpressionError
        {
            throw new Ft.ExpressionError.INVALID (
                "Relational operation not supported for types '%s' and '%s'",  // TODO: gettext
                this.get_type_name (),
                other.get_type_name ());
        }

        internal virtual Ft.Value apply_lt (Ft.Value other)
                                                  throws Ft.ExpressionError
        {
            throw new Ft.ExpressionError.INVALID (
                "Relational operation not supported for types '%s' and '%s'",  // TODO: gettext
                this.get_type_name (),
                other.get_type_name ());
        }
    }


    public class BooleanValue : Ft.Value
    {
        public bool data;

        public BooleanValue (bool value)
        {
            this.data = value;
        }

        public override GLib.Type get_value_type ()
        {
            return typeof (Ft.BooleanValue);
        }

        public override string get_type_name ()
        {
            return "boolean";
        }

        public override bool to_boolean ()
        {
            return this.data;
        }

        public override string to_representation ()
        {
            return this.data.to_string ();
        }

        public override GLib.Variant to_variant ()
        {
            return new GLib.Variant.boolean (this.data);
        }

        internal override Ft.Value apply_eq (Ft.Value other)
                                             throws Ft.ExpressionError
        {
            var other_boolean = other as Ft.BooleanValue;
            if (other_boolean != null) {
                return new Ft.BooleanValue (this.data == other_boolean.data);
            }

            return base.apply_eq (other);
        }
    }


    public class TimestampValue : Ft.Value
    {
        public int64 data;

        public TimestampValue (int64 timestamp)
        {
            this.data = timestamp;
        }

        public override GLib.Type get_value_type ()
        {
            return typeof (Ft.TimestampValue);
        }

        public override string get_type_name ()
        {
            return "timestamp";
        }

        public override bool to_boolean ()
        {
            return Ft.Timestamp.is_defined (this.data);
        }

        public override string to_representation ()
        {
            // TODO: figure out how to represent undefined timestamp; just use null?

            return quote_string (this.to_string ());
        }

        public override GLib.Variant to_variant ()
        {
            return new GLib.Variant.int64 (this.data);
        }

        public override GLib.Variant format (string name)
                                             throws Ft.ExpressionError
        {
            switch (name)
            {
                case "iso8601":
                    return new GLib.Variant.string (Ft.Timestamp.to_iso8601 (this.data));

                case "seconds":
                    return new GLib.Variant.double (Ft.Timestamp.to_seconds (this.data));

                case "microseconds":
                    return this.to_variant ();

                default:
                    return base.format (name);
            }
        }

        private inline string to_string ()
        {
            return Ft.Timestamp.to_iso8601 (this.data);
        }

        internal override Ft.Value apply_eq (Ft.Value other)
                                             throws Ft.ExpressionError
        {
            var other_timestamp = other as Ft.TimestampValue;
            if (other_timestamp != null) {
                return new Ft.BooleanValue (this.data == other_timestamp.data);
            }

            var other_string = other as Ft.StringValue;
            if (other_string != null) {
                return new Ft.BooleanValue (this.to_string () == other_string.data);
            }

            return base.apply_eq (other);
        }

        internal override Ft.Value apply_lt (Ft.Value other)
                                             throws Ft.ExpressionError
        {
            var other_timestamp = other as Ft.TimestampValue;
            if (other_timestamp != null) {
                return new Ft.BooleanValue (this.data < other_timestamp.data);
            }

            return base.apply_lt (other);
        }

        internal override Ft.Value apply_gt (Ft.Value other)
                                             throws Ft.ExpressionError
        {
            var other_timestamp = other as Ft.TimestampValue;
            if (other_timestamp != null) {
                return new Ft.BooleanValue (this.data > other_timestamp.data);
            }

            return base.apply_gt (other);
        }
    }


    public class IntervalValue : Ft.Value
    {
        public int64 data;

        public IntervalValue (int64 interval)
        {
            this.data = interval;
        }

        public override GLib.Type get_value_type ()
        {
            return typeof (Ft.IntervalValue);
        }

        public override string get_type_name ()
        {
            return "interval";
        }

        public override bool to_boolean ()
        {
            return this.data != 0;
        }

        public override string to_representation ()
        {
            return this.data.to_string ();
        }

        public override GLib.Variant to_variant ()
        {
            return new GLib.Variant.int64 (this.data);
        }

        public override GLib.Variant format (string name)
                                             throws Ft.ExpressionError
        {
            switch (name)
            {
                case "minutes":
                    return new GLib.Variant.double (
                        Ft.Timestamp.to_seconds (this.data) / 60.0);

                case "seconds":
                    return new GLib.Variant.double (Ft.Timestamp.to_seconds (this.data));

                case "microseconds":
                    return this.to_variant ();

                default:
                    return base.format (name);
            }
        }

        internal override Ft.Value apply_eq (Ft.Value other)
                                             throws Ft.ExpressionError
        {
            var other_interval = other as Ft.IntervalValue;
            if (other_interval != null) {
                return new Ft.BooleanValue (this.data == other_interval.data);
            }

            return base.apply_eq (other);
        }

        internal override Ft.Value apply_lt (Ft.Value other)
                                             throws Ft.ExpressionError
        {
            var other_interval = other as Ft.IntervalValue;
            if (other_interval != null) {
                return new Ft.BooleanValue (this.data < other_interval.data);
            }

            return base.apply_lt (other);
        }

        internal override Ft.Value apply_gt (Ft.Value other)
                                             throws Ft.ExpressionError
        {
            var other_interval = other as Ft.IntervalValue;
            if (other_interval != null) {
                return new Ft.BooleanValue (this.data > other_interval.data);
            }

            return base.apply_gt (other);
        }
    }


    public class StringValue : Ft.Value
    {
        public string data;

        public StringValue (string data)
        {
            this.data = data;
        }

        public override GLib.Type get_value_type ()
        {
            return typeof (Ft.StringValue);
        }

        public override string get_type_name ()
        {
            return "string";
        }

        public override bool to_boolean ()
        {
            return (this.data != null) && (this.data != "");
        }

        public override string to_representation ()
        {
            return quote_string (this.data);
        }

        public override GLib.Variant to_variant ()
        {
            return new GLib.Variant.string (this.data);
        }

        internal override Ft.Value apply_eq (Ft.Value other)
                                             throws Ft.ExpressionError
        {
            var other_string = other as Ft.StringValue;
            if (other_string != null) {
                return new Ft.BooleanValue (this.data == other_string.data);
            }

            return other.apply_eq (this);
        }

        internal override Ft.Value apply_lt (Ft.Value other)
                                             throws Ft.ExpressionError
        {
            var other_string = other as Ft.StringValue;
            if (other_string != null) {
                return new Ft.BooleanValue (this.data < other_string.data);
            }

            return other.apply_gt (this);
        }

        internal override Ft.Value apply_gt (Ft.Value other)
                                             throws Ft.ExpressionError
        {
            var other_string = other as Ft.StringValue;
            if (other_string != null) {
                return new Ft.BooleanValue (this.data > other_string.data);
            }

            return other.apply_lt (this);
        }
    }


    public class StateValue : Ft.Value
    {
        public Ft.State data;

        public StateValue (Ft.State state)
        {
            this.data = state;
        }

        public override GLib.Type get_value_type ()
        {
            return typeof (Ft.StateValue);
        }

        public override string get_type_name ()
        {
            return "state";
        }

        public override bool to_boolean ()
        {
            return this.data != Ft.State.STOPPED;
        }

        public override string to_representation ()
        {
            return quote_string (this.data.to_string ());
        }

        public override GLib.Variant to_variant ()
        {
            return new GLib.Variant.string (this.data.to_string ());
        }

        public override GLib.Variant format (string name)
                                             throws Ft.ExpressionError
        {
            switch (name)
            {
                case "base":
                    return new GLib.Variant.string (this.data.is_break ()
                                                    ? "break" : this.data.to_string ());

                case "full":
                    return this.to_variant ();

                default:
                    return base.format (name);
            }
        }

        internal override Ft.Value apply_eq (Ft.Value other)
                                                   throws Ft.ExpressionError
        {
            /**
             * XXX: When serialized, we allow comparisons like `"short-break" == "break"`,
             *      which is questionable. It would be more intuitive to use functions,
             *      for this example `isBreak("short-break")`.
             */

            var other_state = other as Ft.StateValue;
            if (other_state != null) {
                return new Ft.BooleanValue (this.data.is_a (other_state.data));
            }

            var other_string = other as Ft.StringValue;
            if (other_string != null) {
                var other_data = Ft.State.from_string (other_string.data);

                if (other_data == Ft.State.STOPPED && other_string.data != "stopped") {
                    return new Ft.BooleanValue (false);
                }

                return new Ft.BooleanValue (this.data.is_a (other_data));
            }

            return base.apply_eq (other);
        }
    }


    public class StatusValue : Ft.Value
    {
        public Ft.TimeBlockStatus data;

        public StatusValue (Ft.TimeBlockStatus status)
        {
            this.data = status;
        }

        public override GLib.Type get_value_type ()
        {
            return typeof (Ft.StatusValue);
        }

        public override string get_type_name ()
        {
            return "status";
        }

        public override bool to_boolean ()
        {
            return this.data != Ft.TimeBlockStatus.SCHEDULED;
        }

        public override string to_representation ()
        {
            return quote_string (this.data.to_string());
        }

        public override GLib.Variant to_variant ()
        {
            return new GLib.Variant.string (this.data.to_string ());
        }

        internal override Ft.Value apply_eq (Ft.Value other)
                                             throws Ft.ExpressionError
        {
            var other_status = other as Ft.StatusValue;
            if (other_status != null) {
                return new Ft.BooleanValue (this.data == other_status.data);
            }

            var other_string = other as Ft.StringValue;
            if (other_string != null) {
                return new Ft.BooleanValue (this.data.to_string () == other_string.data);
            }

            return base.apply_eq (other);
        }
    }


    public string[] list_value_formats (GLib.Type value_type)
    {
        switch (value_type.name ())
        {
            case "FtTimestampValue":
                return { "iso8601", "seconds", "microseconds" };

            case "FtIntervalValue":
                return { "minutes", "seconds", "microseconds" };

            case "FtStateValue":
                return { "base", "full" };

            default:
                return {};
        }
    }


    public string get_default_value_format (GLib.Type value_type)
    {
        switch (value_type.name ())
        {
            case "FtTimestampValue":
                return "microseconds";

            case "FtIntervalValue":
                return "microseconds";

            case "FtStateValue":
                return "full";

            default:
                return "";
        }
    }


    private bool get_inner_operator (Ft.Expression   expression,
                                     out Ft.Operator inner_operator)
    {
        if (expression is Ft.Operation)
        {
            inner_operator = ((Ft.Operation) expression).operator;

            return true;
        }

        if (expression is Ft.Comparison)
        {
            inner_operator = ((Ft.Comparison) expression).operator;

            return true;
        }

        inner_operator = Ft.Operator.INVALID;

        return false;
    }


    /**
     * Wrap argument with parentheses if inner operator has higher priority
     */
    private inline string wrap_argument (string      argument_string,
                                         Ft.Operator inner_operator,
                                         Ft.Operator outer_operator)
    {
        return inner_operator != outer_operator &&
               inner_operator.get_precedence () < outer_operator.get_precedence ()
            ? @"($argument_string)"
            : argument_string;
    }


    public abstract class Expression
    {
        public abstract GLib.Type get_result_type ();

        public abstract Ft.Value evaluate (Ft.Context context)
                                           throws Ft.ExpressionError;

        public abstract string to_string ();

        public static Ft.Expression? parse (string text)
                                            throws Ft.ExpressionParserError
        {
            var parser = new Ft.ExpressionParser ();

            return parser.parse (text);
        }
    }


    public class Constant : Ft.Expression
    {
        public Ft.Value value;

        public Constant (Ft.Value value)
        {
            this.value = value;
        }

        public override GLib.Type get_result_type ()
        {
            return this.value.get_value_type ();
        }

        public override Ft.Value evaluate (Ft.Context context)
                                           throws Ft.ExpressionError
        {
            return this.value;
        }

        public override string to_string ()
        {
            return this.value.to_representation ();
        }

        public inline string get_string ()
        {
            var string_value = this.value as Ft.StringValue;

            return string_value != null ? string_value.data : "";
        }
    }


    public class Variable : Ft.Expression
    {
        public string name;

        public Variable (string name)
        {
            this.name = name;
        }

        public override GLib.Type get_result_type ()
        {
            var variable_spec = Ft.find_variable (this.name);

            return variable_spec?.value_type;
        }

        public override Ft.Value evaluate (Ft.Context context)
                                           throws Ft.ExpressionError
        {
            var value = context.evaluate_variable (this.name);

            if (value == null) {
                throw new Ft.ExpressionError.INVALID (_("Unknown variable \"%s\""), this.name);
            }

            return value;
        }

        public override string to_string ()
        {
            return Ft.to_camel_case (this.name);
        }
    }


    public class Operation : Ft.Expression
    {
        public Ft.Operator     operator;
        public Ft.Expression[] arguments;

        public Operation (Ft.Operator operator, ...)
        {
            var arguments_list = va_list ();
            var arguments = new Ft.Expression[0];

            while (true)
            {
                Ft.Expression? argument = arguments_list.arg ();

                if (argument != null) {
                    arguments += argument;
                }
                else {
                    break;
                }
            }

            this.operator  = operator;
            this.arguments = arguments;
        }

        public Operation.with_argv (Ft.Operator           operator,
                                    owned Ft.Expression[] arguments)
        {
            this.operator  = operator;
            this.arguments = arguments;
        }

        public override GLib.Type get_result_type ()
        {
            GLib.Type? result_type = null;

            foreach (var expression in this.arguments)
            {
                if (result_type == null) {
                    result_type = expression.get_result_type ();
                }
                else {
                    result_type = this.operator.get_result_type (result_type,
                                                                 expression.get_result_type ());
                }
            }

            return result_type;
        }

        public override Ft.Value evaluate (Ft.Context context)
                                           throws Ft.ExpressionError
        {
            if (this.arguments.length == 0) {
                throw new Ft.ExpressionError.EMPTY ("No arguments to perform '%s' operation",
                                                    this.operator.to_string ());
            }

            Ft.Value? result = null;

            foreach (var expression in this.arguments)
            {
                var expression_result = expression.evaluate (context);

                if (result == null) {
                    result = expression_result;
                }
                else {
                    result = this.operator.apply (result, expression_result);
                }
            }

            return result;
        }

        private string argument_to_string (Ft.Expression expression)
        {
            var expression_string = expression.to_string ();
            Ft.Operator expression_operator;

            return get_inner_operator (expression, out expression_operator)
                ? wrap_argument (expression_string, expression_operator, this.operator)
                : expression_string;
        }

        public override string to_string ()
        {
            if (this.arguments.length != 1)
            {
                var string_builder = new GLib.StringBuilder ();
                var operator_string = @" $(this.operator.to_string()) ";

                for (var index = 0; index < this.arguments.length; index++)
                {
                    if (index > 0) {
                        string_builder.append (operator_string);
                    }

                    string_builder.append (argument_to_string (this.arguments[index]));
                }

                return string_builder.str;
            }
            else {
                return this.arguments[0].to_string ();
            }
        }
    }


    public class Comparison : Ft.Expression
    {
        public Ft.Expression  argument_lhs;
        public Ft.Expression? argument_rhs;
        public Ft.Operator    operator;

        public Comparison (Ft.Expression  argument_lhs,
                           Ft.Operator    operator,
                           Ft.Expression? argument_rhs)
        {
            this.argument_lhs = argument_lhs;
            this.operator     = operator;
            this.argument_rhs = argument_rhs;
        }

        public Comparison.is_true (Ft.Expression expression)
        {
            this.argument_lhs = expression;
            this.operator     = Ft.Operator.EQ;
            this.argument_rhs = new Ft.Constant (new Ft.BooleanValue (true));
        }

        public override GLib.Type get_result_type ()
        {
            return typeof (Ft.BooleanValue);
        }

        public override Ft.Value evaluate (Ft.Context context)
                                                 throws Ft.ExpressionError
        {
            if (this.operator.get_category () != Ft.OperatorCategory.COMPARISON) {
                throw new Ft.ExpressionError.INVALID ("Expecting comparison operator, not %s",
                                                      this.operator.to_string ());
            }

            if (this.argument_lhs == null || this.argument_rhs == null) {
                throw new Ft.ExpressionError.EMPTY ("Missing an argument for a comparison");
            }

            var result_lhs = this.argument_lhs.evaluate (context);
            var result_rhs = this.argument_rhs.evaluate (context);

            return operator.apply (result_lhs, result_rhs);
        }

        private string argument_to_string (Ft.Expression expression)
        {
            var expression_string = expression.to_string ();

            return get_inner_operator (expression, null)
                ? @"($expression_string)"
                : expression_string;
        }

        private bool argument_is_true (Ft.Expression expression)
        {
            var constant = expression as Ft.Constant;

            if (this.operator != Ft.Operator.EQ || constant == null) {
                return false;
            }

            return constant != null &&
                   (constant.value is Ft.BooleanValue) &&
                   ((Ft.BooleanValue) constant.value).data;
        }

        public override string to_string ()
        {
            if (this.argument_is_true (this.argument_rhs)) {
                return this.argument_lhs.to_string ();
            }

            if (this.argument_is_true (this.argument_lhs)) {
                return this.argument_rhs.to_string ();
            }

            var argument_lhs_string = this.argument_to_string (this.argument_lhs);
            var argument_rhs_string = this.argument_to_string (this.argument_rhs);
            var operator_string     = this.operator.to_string ();

            return @"$argument_lhs_string $operator_string $argument_rhs_string";
        }
    }
}
