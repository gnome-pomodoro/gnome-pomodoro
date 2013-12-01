/*
 * Copyright (c) 2011-2013 gnome-pomodoro contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * Authors: Arun Mahapatra <pratikarun@gmail.com>
 *          Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Pomodoro
{
    /* Pomodoro acceptance factor is useful in cases of disabling the timer,
     * accepted pomodoros increases session count and narrows time to
     * long pause.
     */
    const double POMODORO_ACCEPTANCE = 0.05;

    /* Minimum achieved score to choose a long break.
     * Value of 1.0 means to follow of Pomodoro Technique strictly.
     */
    const double LONG_BREAK_ACCEPTANCE = 0.90;

    /* Long pause acceptance is used to determine if user made or finished
     * a long pause. If long pause hasn't finished, it's repeated next time.
     * If user made a long pause during short one, it's treated as long one.
     * Acceptance treshold here is ratio between short pause time and long
     * pause time.
     */
    const double SHORT_LONG_PAUSE_ACCEPTANCE = 0.5;

    public enum State {
        NULL = 0,
        POMODORO = 1,
        PAUSE = 2,
        IDLE = 3
    }

    public string state_to_string (State state)
    {
        switch (state)
        {
            case State.NULL:
                return "null";

            case State.POMODORO:
                return "pomodoro";

            case State.PAUSE:
                return "pause";

            case State.IDLE:
                return "idle";
        }

        return "";
    }

    public State string_to_state (string state)
    {
        switch (state)
        {
            case "null":
                return State.NULL;

            case "pomodoro":
                return State.POMODORO;

            case "pause":
                return State.PAUSE;

            case "idle":
                return State.IDLE;
        }

        return State.NULL;
    }
}


public class Pomodoro.Timer : Object
{
    private uint timeout_source;
    private Gnome.IdleMonitor idle_monitor;
    private uint became_active_id;
    private GLib.Settings settings;
    private GLib.Settings settings_state;
    private double current_timestamp;
    private double pomodoro_end_timestamp;
    private bool is_long_break;

    private State _state;
    private double _elapsed;

    public double elapsed {
        get {
            return this._elapsed + this.current_timestamp - this.state_timestamp;
        }
        set {
            this._elapsed = value - this.current_timestamp + this.state_timestamp;
        }
    }

    public State state {
        get {
            return this._state;
        }
        set {
            this.set_state_full (value, 0);
        }
    }

    public double state_duration { get; set; }
    public double state_timestamp { get; set; }
    public double session { get; set; }
    public double session_limit { get; set; }

    public Timer ()
    {
        this._state = State.NULL;
        this._elapsed = 0.0;

        this.current_timestamp = 0.0;
        this.session = 0.0;
        this.session_limit = 0.0;
        this.state_duration = 0.0;
        this.state_timestamp = 0.0;
        this.is_long_break = false;

        this.timeout_source = 0;
        this.idle_monitor = new Gnome.IdleMonitor ();
        this.became_active_id = 0;

        var application = GLib.Application.get_default () as Pomodoro.Application;

        var settings = application.settings as GLib.Settings;

        this.settings = settings.get_child ("preferences");
        this.settings.changed.connect (this.on_settings_changed);

        this.settings_state = settings.get_child ("state");
    }

    private bool do_set_state_full (State state,
                                    double duration = 0,
                                    double timestamp = 0)
    {
        this.current_timestamp = get_real_time ();

        var elapsed = this.elapsed;
        var wrap_elapsed = false;

        var is_long_break = false;

        var is_requested = this.elapsed < this.state_duration ||
                           this.state == State.IDLE;

        var pomodoro_duration =
                this.settings.get_double ("pomodoro-duration");

        var short_break_duration =
                this.settings.get_double ("short-break-duration");

        var long_break_duration =
                this.settings.get_double ("long-break-duration");

        var long_pause_acceptance_time =
                short_break_duration * (1.0 - SHORT_LONG_PAUSE_ACCEPTANCE) +
                long_break_duration * SHORT_LONG_PAUSE_ACCEPTANCE;

        if (timestamp > this.current_timestamp) {
            timestamp = this.current_timestamp;
        }

        if (state == this.state)
        {
            if (duration == 0) {
                duration = this.state_duration;
            }

            if (timestamp == 0) {
                timestamp = this.state_timestamp;
            }

            wrap_elapsed = true;
        }
        else
        {
            if (this.timeout_source != 0 && is_requested) {
                GLib.Source.remove (this.timeout_source);
                this.timeout_source = 0;
            }

            if (state != State.IDLE) {
                this.disable_idle_monitor ();
            }

            if (timestamp == 0) {
                timestamp = this.current_timestamp;
            }

            if ((this.state == State.POMODORO) &&
                (this.elapsed >= this.state_duration * POMODORO_ACCEPTANCE))
            {
                this.session += this.elapsed / this.state_duration;

                this.pomodoro_end_timestamp = timestamp;
            }

            switch (state)
            {
                case State.IDLE:
                    this.enable_idle_monitor ();

                    break;

                case State.POMODORO:
                    if (duration == 0) {
                        duration = pomodoro_duration;
                    }

                    /* Reset work cycle when finished long break
                     * or was inactive for as long.
                     */
                    var break_time = timestamp - this.pomodoro_end_timestamp;

                    if (break_time >= long_pause_acceptance_time) {
                        this.session = 0.0;
                    }

                    break;

                case State.PAUSE:
                    is_long_break = (this.session >= this.session_limit *
                                    LONG_BREAK_ACCEPTANCE);

                    /* Wrap time */
                    if ((this.state == State.POMODORO) &&
                        (this.elapsed > this.state_duration))
                    {
                        elapsed -= this.state_duration;
                        wrap_elapsed = true;
                    }

                    /* Determine which pause type user should have */
                    if (duration == 0.0) {
                        duration = is_long_break
                                ? long_break_duration
                                : short_break_duration;
                    }

                    break;

                case State.NULL:
                    if (this.timeout_source != 0) {
                        GLib.Source.remove (this.timeout_source);
                        this.timeout_source = 0;
                    }

                    break;
            }
        }

        if (this.timeout_source == 0 && state != State.NULL) {
            this.timeout_source = Timeout.add (1000, this.on_timeout);
        }

        if (state == State.NULL || state == State.IDLE) {
            duration = 0.0;
            wrap_elapsed = false;
        }

        this.freeze_notify ();

        this._state = state;
        this._elapsed = 0.0;

        this.state_timestamp = timestamp;
        this.state_duration = duration;
        this.is_long_break = is_long_break;

        if (wrap_elapsed) {
            this.elapsed = elapsed;
        }

        this.notify_property ("state");

        this.thaw_notify ();

        return true;
    }

    public void set_state_full (State state,
                                double duration,
                                double timestamp = 0.0)
    {
        var state_tmp = this._state;
        var state_duration_tmp = this.state_duration;
        var elapsed_tmp = this.elapsed;
        var session_tmp = this.session;

        var changed = this.do_set_state_full (state, duration, timestamp);

        if (changed)
        {
            var state_date = new DateTime.from_unix_utc (
                            (int64) Math.floor (this.state_timestamp));

            var pomodoro_end_date = new DateTime.from_unix_utc (
                    (int64) Math.floor (this.pomodoro_end_timestamp));

            var notify_start = (this._state == State.POMODORO) ||
                               (this._state == State.IDLE && this.settings.get_boolean ("pause-when-idle"));

            var is_requested = elapsed_tmp < state_duration_tmp;
            var is_completed = !is_requested;

            var pomodoro_end_date_string = this.pomodoro_end_timestamp > 0.0
                    ? datetime_to_string (pomodoro_end_date)
                    : "";

            this.settings_state.set_double ("session",
                                            this.session);
            this.settings_state.set_string ("state",
                                            state_to_string (this.state));
            this.settings_state.set_string ("state-date",
                                            datetime_to_string (state_date));
            this.settings_state.set_double ("state-duration",
                                            this.state_duration);
            this.settings_state.set_string ("pomodoro-end-date",
                                            pomodoro_end_date_string);

            this.state_changed ();

            if (this._state == State.POMODORO) {
                this.pomodoro_start (is_requested);
            }

            if (state_tmp == State.PAUSE && notify_start) {
                this.notify_pomodoro_start (is_requested);
            }

            if (state_tmp == State.POMODORO) {
                this.pomodoro_end (is_completed);
            }

            if (state_tmp == State.POMODORO && this._state == State.PAUSE) {
                this.notify_pomodoro_end (is_completed);
            }
        }

        this.update ();
    }

    public void restore ()
    {
        var state = string_to_state (this.settings_state.get_string ("state"));
        var state_duration = this.settings_state.get_double ("state-duration");
        var session = this.settings_state.get_double ("session");

        var current_timestamp = get_real_time ();
        var state_timestamp = current_timestamp;
        var pomodoro_end_timestamp = 0.0;

        try {
            var state_date = datetime_from_string (
                    this.settings_state.get_string ("state-date"));

            state_timestamp = (double) state_date.to_unix ();
        }
        catch (DateTimeError error) {
            /* In case there is no valid state-date, elapsed time
             * will be lost.
             */
            GLib.warning ("Could not restore time");

            return;
        }

        try {
            var pomodoro_end_date = datetime_from_string (
                    this.settings_state.get_string ("pomodoro-end-date"));

            pomodoro_end_timestamp = (double) pomodoro_end_date.to_unix ();
        }
        catch (DateTimeError error) {
            /* Ignore error */
        }

        this.freeze_notify ();

        /* Set timer initial state */
        this._state = State.NULL;
        this._elapsed = 0.0;

        this.state_duration = 0.0;
        this.state_timestamp = state_timestamp;
        this.session = session;
        this.pomodoro_end_timestamp = pomodoro_end_timestamp;

        this.set_state_full (state, state_duration, state_timestamp);

        this.thaw_notify ();
    }

    public void start ()
    {
        if (this._state == State.NULL || this._state == State.IDLE) {
            this.state = State.POMODORO;
        }
    }

    public void stop ()
    {
        this.state = State.NULL;
    }

    public void reset ()
    {
        var is_running = (this._state != State.NULL);

        this.freeze_notify ();

        this.session = 0.0;
        this.pomodoro_end_timestamp = 0.0;
        this.state = State.NULL;

        if (is_running) {
            this.state = State.POMODORO;
        }

        this.thaw_notify ();
    }

    public void update ()
    {
        this.current_timestamp = get_real_time ();

        switch (this.state)
        {
            case State.IDLE:
                break;

            case State.PAUSE:
                this.notify_property ("elapsed");

                /* Pause is over */
                if (this.elapsed >= this.state_duration) {
                    this.state = this.settings.get_boolean ("pause-when-idle")
                                   ? State.IDLE
                                   : State.POMODORO;
                }
                break;

            case State.POMODORO:
                this.notify_property ("elapsed");

                /* Pomodoro is over, a pause is needed :) */
                if (this.elapsed >= this.state_duration) {
                    this.state = State.PAUSE;
                }
                break;
        }

        this.updated ();
    }

    protected void enable_idle_monitor ()
    {
        if (this.became_active_id == 0) {
            this.became_active_id = this.idle_monitor.add_user_active_watch (this.on_idle_monitor_became_active);
        }
    }

    protected void disable_idle_monitor ()
    {
        if (this.became_active_id != 0) {
            this.idle_monitor.remove_watch (this.became_active_id);
            this.became_active_id = 0;
        }
    }

    private void on_settings_changed (GLib.Settings settings, string key)
    {
        var state_duration = this.state_duration;

        switch (key)
        {
            case "pomodoro-duration":
                if (this.state == State.POMODORO) {
                    state_duration = this.settings.get_double (key);
                }
                break;

            case "short-break-duration":
                if (this.state == State.PAUSE && !this.is_long_break) {
                    state_duration = this.settings.get_double (key);
                }
                break;

            case "long-break-duration":
                if (this.state == State.PAUSE && this.is_long_break) {
                    state_duration = this.settings.get_double (key);
                }
                break;

            case "long-break-interval":
                if (this.session_limit != this.settings.get_double (key)) {
                    this.session_limit = this.settings.get_double (key);
                }
                break;
        }

        if (state_duration != this.state_duration)
        {
            this.state_duration = double.max (state_duration, this.elapsed);
            this.update ();
        }
    }

    private bool on_timeout ()
    {
        if (this.state != State.NULL)
        {
            this.update ();
        }

        return true;
    }

    private void on_idle_monitor_became_active (Gnome.IdleMonitor monitor)
    {
        if (this.state == State.IDLE)
        {
            this.current_timestamp = get_real_time ();

            /* Treat last second as if it were already pomodoro */
            var elapsed = this.current_timestamp - this.state_timestamp;
            var timestamp = this.current_timestamp - elapsed.clamp (0.0, 1.0);

            this.set_state_full (State.POMODORO, 0.0, timestamp);
        }
    }

    public override void dispose ()
    {
        this.disable_idle_monitor ();

        if (this.timeout_source != 0) {
            GLib.Source.remove (this.timeout_source);
            this.timeout_source = 0;
        }

        this.settings = null;
        this.settings_state = null;
        this.idle_monitor = null;

        base.dispose ();
    }

    public signal void updated ();
    public signal void state_changed ();
    public signal void pomodoro_start (bool is_requested);
    public signal void pomodoro_end (bool is_completed);
    public signal void notify_pomodoro_start (bool is_requested);
    public signal void notify_pomodoro_end (bool is_completed);

    public virtual signal void destroy ()
    {
        this.dispose ();
    }
}
