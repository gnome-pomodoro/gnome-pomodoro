/*
 * Copyright (c) 2011-2013 gnome-shell-pomodoro contributors
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
    const double SESSION_ACCEPTANCE = 20.0 / 25.0;

    /* Short pause acceptance is used to catch quick "Start a new pomodoro"
     * clicks, declining short pause narrows time to long pause.
     */
    const double SHORT_PAUSE_ACCEPTANCE = 1.0 / 5.0;

    /* Long pause acceptance is used to determine if user made or finished
     * a long pause. If long pause hasn't finished, it's repeated next time.
     * If user made a long pause during short one, it's treated as long one.
     * Acceptance value here is a factor between short pause time and long
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
    private Up.Client power;
    private GLib.Settings settings;
    private GLib.Settings settings_state;

    private uint64 _elapsed;
    private uint _session;
    private uint _session_limit;
    private State _state;
    private uint64 _state_duration;
    private int64 _state_timestamp;

    /*
     * Intenally all time values are in milliseconds, but public API exposes
     * them as seconds for simplicity.
     */

    public uint64 elapsed {
        get {
            return this._elapsed / 1000;
        }
        set {
            this.set_elapsed_milliseconds (value * 1000);
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

    public uint64 state_duration {
        get {
            return this._state_duration / 1000;
        }
        set {
            this._state_duration = value * 1000;
        }
    }

    public int64 state_timestamp {
        get {
            return this._state_timestamp / 1000;
        }
        set {
            this._state_timestamp = value * 1000;
        }
    }

    public uint session {
        get {
            return this._session;
        }
        set {
            this._session = value;
        }
    }

    public uint session_limit {
        get {
            return this._session_limit;
        }
        set {
            this._session_limit = value;
        }
    }

    public Timer ()
    {
        this._elapsed = 0;
        this._state_duration = 0;
        this._session = 0;
        this._session_limit = 4;
        this._state = State.NULL;
        this._state_timestamp = 0;

        this.timeout_source = 0;
        this.idle_monitor = new Gnome.IdleMonitor ();
        this.became_active_id = 0;

        this.power = new Up.Client ();
        this.power.notify_resume.connect (this.restore);

        var application = GLib.Application.get_default () as Pomodoro.Application;

        var settings = application.settings as GLib.Settings;

        this.settings = settings.get_child ("preferences");
        this.settings.changed.connect (this.on_settings_changed);

        this.settings_state = settings.get_child ("state");
    }

    private void set_elapsed_milliseconds (uint64 value)
    {
        var state_tmp = this._state;

        if (this._elapsed == value) {
            return;
        }

        this._elapsed = value;

        this.notify_property ("elapsed");

        switch (this._state)
        {
            case State.IDLE:
                break;

            case State.PAUSE:
                /* Pause is over */
                if (this._elapsed >= this._state_duration) {
                    this.state = this.settings.get_boolean ("pause-when-idle")
                                   ? State.IDLE
                                   : State.POMODORO;
                }
                break;

            case State.POMODORO:
                /* Pomodoro is over, a pause is needed :) */
                if (this._elapsed >= this._state_duration) {
                    this.state = State.PAUSE;
                }
                break;
        }

        if (this._state == state_tmp) {
            this.elapsed_changed ();
        }
    }

    private bool do_set_state_full (State new_state,
                                    uint64 state_duration = 0,
                                    int64 timestamp = 0)
    {
        var current_timestamp = GLib.get_real_time () / 1000;
        var is_requested = (this._elapsed < this._state_duration);

        var new_elapsed = (uint64) 0;
        var new_state_duration = state_duration;

        if (timestamp > current_timestamp) {
            timestamp = current_timestamp;
        }

        this.disable_idle_monitor ();
        this.freeze_notify ();

        /* Reset timeout when change was requested by user,
         * run smoothly otherwise.
         */
        if (this.timeout_source != 0 && is_requested) {
            GLib.Source.remove (this.timeout_source);
            this.timeout_source = 0;
        }

        if (this.timeout_source == 0 && new_state != State.NULL) {
            this.timeout_source = Timeout.add (1000, this.on_timeout);
        }

        if (new_state == this._state)
        {
            if (new_state_duration == 0) {
                new_state_duration = this._state_duration;
            }

            if (timestamp == 0) {
                timestamp = this._state_timestamp;
            }

            new_elapsed = current_timestamp - timestamp;
        }
        else
        {
            if (timestamp == 0) {
                timestamp = current_timestamp;
            }

            if (this._state == State.IDLE)
            {
                /* TODO: Move this compensation to 'on_become_active' callback */

                timestamp -= (current_timestamp - this._state_timestamp).clamp (0, 1000);
            }

            if (this._state == State.POMODORO)
            {
                if (this._elapsed >= SESSION_ACCEPTANCE * this.settings.get_uint ("pomodoro-duration")) {
                    this.session += 1;
                }
                else {
                    /* Pomodoro not completed, it doesn't get counted */
                }
            }

            new_elapsed = current_timestamp - timestamp;
            new_state_duration = state_duration;

            switch (new_state)
            {
                case State.IDLE:
                    this.enable_idle_monitor ();
                    new_elapsed = 0;
                    new_state_duration = 0;
                    break;

                case State.POMODORO:
                    var long_pause_acceptance_time = (uint64)(
                            (1.0 - SHORT_LONG_PAUSE_ACCEPTANCE) * this.settings.get_uint ("short-break-duration") * 1000 +
                            SHORT_LONG_PAUSE_ACCEPTANCE * this.settings.get_uint ("long-break-duration") * 1000);

                    if (this._state == State.PAUSE || this._state == State.IDLE)
                    {
                        /* If skipped a break make long break sooner */
                        if (this._elapsed < SHORT_PAUSE_ACCEPTANCE * this.settings.get_uint ("short-break-duration") * 1000) {
                            this.session += 1;
                        }

                        /* Reset work cycle when finished long break or was too lazy on a short one,
                         * and if skipped a long break try again next time.
                         */
                        if (this._elapsed >= long_pause_acceptance_time) {
                            this.session = 0;
                        }
                    }

                    if (this._state == State.NULL)
                    {
                        /* Reset work cycle when disabled for some time */
                        var idle_time = timestamp - this._state_timestamp;

                        if (this._state_timestamp > 0 && idle_time >= long_pause_acceptance_time) {
                            this.session = 0;
                        }
                    }

                    if (new_state_duration == 0) {
                        new_state_duration = this.settings.get_uint ("pomodoro-duration") * 1000;
                    }

                    break;

                case State.PAUSE:
                    if (new_elapsed < 0)
                    {
                        /* Wrap time to pause */
                        if (this._state == State.POMODORO && this._elapsed > this._state_duration) {
                            new_elapsed = this._elapsed - this._state_duration;
                        }
                        else {
                            new_elapsed = 0;
                        }
                    }

                    if (new_state_duration == 0)
                    {
                        /* Determine which pause type user should have */
                        if (this._session >= this._session_limit) {
                            new_state_duration = this.settings.get_uint ("long-break-duration") * 1000;
                        }
                        else {
                            new_state_duration = this.settings.get_uint ("short-break-duration") * 1000;;
                        }
                    }

                    break;

                case State.NULL:
                    if (this.timeout_source != 0) {
                        GLib.Source.remove (this.timeout_source);
                        this.timeout_source = 0;
                    }

                    new_elapsed = 0;
                    new_state_duration = 0;
                    break;
            }
        }

        this._state = new_state;
        this._state_timestamp = timestamp;
        this._state_duration = new_state_duration;

        this.notify_property ("state");
        this.notify_property ("state-timestamp");
        this.notify_property ("state-duration");

        this.set_elapsed_milliseconds (new_elapsed);

        this.thaw_notify ();

        this.state_changed ();

        return true;
    }

    public void set_state_full (State state,
                                uint64 duration)
    {
        var state_tmp = this._state;
        var state_duration_tmp = this._state_duration;
        var elapsed_tmp = this._elapsed;
        var session_tmp = this._session;
        var changed_state = this.do_set_state_full (state,
                                                    duration * 1000);

        if (changed_state)
        {
            var state_changed_date = new DateTime.from_unix_utc ((int64) (this._state_timestamp / 1000));
            var notify_start = (this._state == State.POMODORO) ||
                               (this._state == State.IDLE && this.settings.get_boolean ("pause-when-idle"));

            var is_completed = this._session != session_tmp;
            var is_requested = elapsed_tmp < state_duration_tmp;

            this.settings_state.set_double ("session-count",
                                            (double) this.session);
            this.settings_state.set_string ("state",
                                            state_to_string (this.state));
            this.settings_state.set_string ("state-changed-date",
                                            datetime_to_string (state_changed_date));

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

        if (this._elapsed != elapsed_tmp || this._state_duration != state_duration_tmp) {
            this.elapsed_changed ();
        }
    }

    public void restore ()
    {
        var session = this.settings_state.get_double ("session-count");
        var state = string_to_state (this.settings_state.get_string ("state"));
        var state_duration = this.settings_state.get_uint ("state-duration") * 1000; /* TODO: Rename to 'state-duration' */
        var current_timestamp = GLib.get_real_time () / 1000;
        var state_timestamp = current_timestamp;

        try {
            var state_changed_date = datetime_from_string (
                    this.settings_state.get_string ("state-changed-date"));

            state_timestamp = state_changed_date.to_unix () * 1000;
        }
        catch (DateTimeError error) {
            /* In case there is no valid state-changed-date, elapsed time
             * will be lost.
             */
            GLib.warning ("Could not restore state time");

            return;
        }

        this.freeze_notify ();

        /* Set timer initial state */
        this._elapsed = 0;
        this._state_duration = 0;
        this._state = State.NULL;
        this._state_timestamp = state_timestamp;
        this.session = (uint) session;

        this.do_set_state_full (state, state_duration, state_timestamp);

        if (this._state != State.NULL)
        {
            /* Skip through states silently to avoid unnecessary notifications
             * and signal emits stacking up
             */
            while (this._elapsed >= this._state_duration)
            {
                if (this._state == State.POMODORO) {
                    this.do_set_state_full (State.PAUSE);
                    continue;
                }

                if (this._state == State.PAUSE) {
                    this.do_set_state_full (State.IDLE);
                    continue;
                }

                break;
            }
        }

        /* Update timestamp to the beginning of current state */
        var state_changed_date = new DateTime.from_unix_utc ((int64) (this._state_timestamp / 1000));

        this.settings_state.set_double ("session-count",
                                        (double) this._session);
        this.settings_state.set_string ("state",
                                        state_to_string (this._state));
        this.settings_state.set_string ("state-changed-date",
                                        datetime_to_string (state_changed_date));
        this.settings_state.set_uint ("state-duration",
                                      (uint) this._state_duration / 1000);

        this.thaw_notify ();
        this.state_changed ();
        this.elapsed_changed ();

        if (this._state != State.NULL)
        {
            var is_completed = false;
            var is_requested = false;

            if ((this._state == State.POMODORO) ||
                (this._state == State.IDLE && this.settings.get_boolean ("pause-when-idle")))
            {
                this.pomodoro_start (is_requested);
                this.notify_pomodoro_start (is_requested);
            }

            if (this._state == State.PAUSE)
            {
                this.pomodoro_end (is_completed);
                this.notify_pomodoro_end (is_completed);
            }
        }
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

        this.session = 0;
        this.state = State.NULL;

        if (is_running) {
            this.state = State.POMODORO;
        }

        this.thaw_notify ();
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
        var elapsed = this._elapsed;
        var state_duration = this._state_duration;
        var elapsed_tmp = this._elapsed;
        var state_duration_tmp = this._state_duration;

        switch (key) {
            case "pomodoro-duration":
                if (this.state == State.POMODORO) {
                    state_duration = this.settings.get_uint (key) * 1000;
                }
                elapsed = uint64.min (elapsed, state_duration);
                break;

            case "short-break-duration":
                if (this.state == State.PAUSE && this.session < this.session_limit) {
                    state_duration = this.settings.get_uint (key) * 1000;
                }
                elapsed = uint64.min (elapsed, state_duration);
                break;

            case "long-break-duration":
                if (this.state == State.PAUSE && this.session >= this.session_limit) {
                    state_duration = this.settings.get_uint (key) * 1000;
                }
                elapsed = uint64.min (elapsed, state_duration);
                break;
        }

        if (state_duration != state_duration_tmp) {
            this._state_duration = state_duration;
            this.notify_property ("state-duration");
        }

        this.set_elapsed_milliseconds (elapsed);

        if (this._elapsed != elapsed_tmp || this._state_duration != state_duration_tmp) {
            this.elapsed_changed ();
        }
    }

    private bool on_timeout ()
    {
        if (this.state != State.NULL) {
            var timestamp = GLib.get_real_time () / 1000;
            this.set_elapsed_milliseconds (timestamp - this._state_timestamp);
        }

        return true;
    }

    private void on_idle_monitor_became_active (Gnome.IdleMonitor monitor)
    {
        if (this.state == State.IDLE) {
            this.state = State.POMODORO;
        }
    }

    public override void dispose ()
    {
        this.disable_idle_monitor ();

        if (this.timeout_source != 0) {
            GLib.Source.remove (this.timeout_source);
            this.timeout_source = 0;
        }

        this.power = null;
        this.settings = null;
        this.settings_state = null;
        this.idle_monitor = null;

        base.dispose ();
    }

    public signal void state_changed ();
    public signal void elapsed_changed ();
    public signal void pomodoro_start (bool is_requested);
    public signal void pomodoro_end (bool is_completed);
    public signal void notify_pomodoro_start (bool is_requested);
    public signal void notify_pomodoro_end (bool is_completed);

    public virtual signal void destroy ()
    {
        this.dispose ();
    }
}
