/*
 * Copyright (c) 2024-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Ft
{
    [CCode (has_target = false)]
    public delegate Ft.Value EvaluateFunc (Ft.Context context);


    public class VariableSpec
    {
        public string          name;
        public string          description;
        public GLib.Type       value_type;
        public Ft.EvaluateFunc evaluate_func;

        public VariableSpec (string                name,
                             string                description,
                             GLib.Type             value_type,
                             owned Ft.EvaluateFunc evaluate_func)
        {
            this.name = name;
            this.description = description;
            this.value_type = value_type;
            this.evaluate_func = evaluate_func;
        }

        public inline Ft.Value evaluate (Ft.Context context)
                                         requires (this.evaluate_func != null)
        {
            return this.evaluate_func (context);
        }
    }


    private Ft.VariableSpec[] variable_specs = null;
    private GLib.HashTable<string, unowned Ft.VariableSpec> variable_spec_by_name = null;


    namespace Variables
    {
        private Ft.Value get_timestamp (Ft.Context context)
        {
            return new Ft.TimestampValue (context.timestamp);
        }

        private Ft.StateValue get_state (Ft.Context context)
        {
            return new Ft.StateValue (context.time_block != null
                                      ? context.time_block.state
                                      : Ft.State.STOPPED);
        }

        private Ft.StatusValue get_status (Ft.Context context)
        {
            return new Ft.StatusValue (context.time_block != null
                                             ? context.time_block.get_status ()
                                             : Ft.TimeBlockStatus.SCHEDULED);
        }

        private Ft.BooleanValue get_is_started (Ft.Context context)
        {
            return new Ft.BooleanValue (context.timer_state.is_started ());
        }

        private Ft.BooleanValue get_is_paused (Ft.Context context)
        {
            return new Ft.BooleanValue (context.timer_state.is_paused ());
        }

        private Ft.BooleanValue get_is_finished (Ft.Context context)
        {
            return new Ft.BooleanValue (context.timer_state.is_finished ());
        }

        private Ft.BooleanValue get_is_running (Ft.Context context)
        {
            return new Ft.BooleanValue (context.timer_state.is_running ());
        }

        private Ft.IntervalValue get_duration (Ft.Context context)
        {
            return new Ft.IntervalValue (context.timer_state.duration);
        }

        private Ft.IntervalValue get_offset (Ft.Context context)
        {
            return new Ft.IntervalValue (context.timer_state.offset);
        }

        private Ft.IntervalValue get_elapsed (Ft.Context context)
        {
            return new Ft.IntervalValue (context.timer_state.calculate_elapsed (context.timestamp));
        }

        private Ft.IntervalValue get_remaining (Ft.Context context)
        {
            return new Ft.IntervalValue (context.timer_state.calculate_remaining (context.timestamp));
        }

        private Ft.TimestampValue get_start_time (Ft.Context context)
        {
            return new Ft.TimestampValue (context.timer_state.started_time);
        }

        private void initialize ()
        {
            variable_specs = new Ft.VariableSpec[0];
            variable_spec_by_name = new GLib.HashTable<string, unowned Ft.VariableSpec> (GLib.str_hash, GLib.str_equal);

            Ft.install_variable (
                new Ft.VariableSpec ("timestamp",
                                     _("The exact time of the current event."),
                                     typeof (Ft.TimestampValue),
                                     get_timestamp));
            Ft.install_variable (
                new Ft.VariableSpec ("state",
                                     _("The current phase of the Pomodoro cycle. Possible values: <tt>stopped</tt>, <tt>pomodoro</tt>, <tt>break</tt>, <tt>short-break</tt>, <tt>long-break</tt>."),
                                     typeof (Ft.StateValue),
                                     get_state));
            Ft.install_variable (
                new Ft.VariableSpec ("status",
                                     _("Status of the current time-block. Possible values: <tt>scheduled</tt>, <tt>in-progress</tt>, <tt>completed</tt>, <tt>uncompleted</tt>."),
                                     typeof (Ft.StatusValue),
                                     get_status));
            Ft.install_variable (
                new Ft.VariableSpec ("is-started",
                                     _("A flag indicating whether countdown has begun."),
                                     typeof (Ft.BooleanValue),
                                     get_is_started));
            Ft.install_variable (
                new Ft.VariableSpec ("is-paused",
                                     _("A flag indicating whether countdown is paused."),
                                     typeof (Ft.BooleanValue),
                                     get_is_paused));
            Ft.install_variable (
                new Ft.VariableSpec ("is-finished",
                                     _("A flag indicating whether countdown has finished."),
                                     typeof (Ft.BooleanValue),
                                     get_is_finished));
            Ft.install_variable (
                new Ft.VariableSpec ("is-running",
                                     _("A flag indicating whether the timer is actively counting down."),
                                     typeof (Ft.BooleanValue),
                                     get_is_running));
            Ft.install_variable (
                new Ft.VariableSpec ("duration",
                                     _("Duration of the current countdown."),
                                     typeof (Ft.IntervalValue),
                                     get_duration));
            Ft.install_variable (
                new Ft.VariableSpec ("offset",
                                     // translators: Time difference between displayed value on the timer and real time. Think of it as a lost time.
                                     _("Discrepancy between elapsed time and the time passed."),
                                     typeof (Ft.IntervalValue),
                                     get_offset));
            Ft.install_variable (
                new Ft.VariableSpec ("elapsed",
                                     // translators: Time since the start of countdown
                                     _("The amount of time spent on the countdown."),
                                     typeof (Ft.IntervalValue),
                                     get_elapsed));
            Ft.install_variable (
                new Ft.VariableSpec ("remaining",
                                     // translators: Displayed timer value.
                                     _("The amount of time left before the countdown ends."),
                                     typeof (Ft.IntervalValue),
                                     get_remaining));
            Ft.install_variable (
                new Ft.VariableSpec ("start-time",
                                     _("Time when the countdown has started."),
                                     typeof (Ft.TimestampValue),
                                     get_start_time));
        }

        internal inline void ensure_initialized ()
        {
            if (variable_spec_by_name == null) {
                initialize ();
            }
        }
    }


    public void install_variable (Ft.VariableSpec variable_spec)
    {
        variable_specs += variable_spec;
        variable_spec_by_name.insert (variable_spec.name, variable_spec);
    }

    public unowned Ft.VariableSpec? find_variable (string variable_name)
    {
        Ft.Variables.ensure_initialized ();

        return variable_spec_by_name.lookup (variable_name);
    }

    public (unowned Ft.VariableSpec)[] list_variables ()
    {
        Ft.Variables.ensure_initialized ();

        return variable_specs;
    }

    public bool find_variable_format (string variable_name,
                                      string variable_format)
    {
        if (variable_format == "") {
            return true;
        }

        var variable_spec = Ft.find_variable (variable_name);

        if (variable_spec != null)
        {
            foreach (var format in Ft.list_value_formats (variable_spec.value_type))
            {
                if (variable_format == format) {
                    return true;
                }
            }
        }

        return false;
    }
}
