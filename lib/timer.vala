/*
 * Copyright (c) 2011-2015 gnome-pomodoro contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Arun Mahapatra <pratikarun@gmail.com>
 *          Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Pomodoro
{
    public enum State {
        NULL = 0,
        POMODORO = 1,
        PAUSE = 2,
        IDLE = 3
    }
}


/**
 * Pomodoro.Timer class.
 *
 * A class for a countdown timer. Timer works in an atomic manner, it acknowlegdes passage
 * of time after calling update() method.
 *
 * TODO: Ability to stop/continue after timer runs out
 */
public class Pomodoro.Timer : Object
{
    private uint timeout_source;
    private double current_timestamp;
    private double elapsed_offset;

    public double elapsed {
        get {
            return this._state.elapsed;
        }
        set {
            this._state.elapsed = value;
            this.update_offset ();
        }
    }

    private TimerState _state;
    public TimerState state {
        get {
            return this._state;
        }
        set {
            var previous_state = this._state;

            this.state_leave (this._state);

            this._state = value;
            this.current_timestamp = this._state.timestamp;

            this.update_offset ();

            this.state_enter (this._state);

            if (!this.resolve_state ()) {
                this.state_changed (this._state, previous_state);
            }
        }
    }

    public double offset {
        get {
            return this.elapsed_offset;
        }
        set {
            this.elapsed_offset = value;
        }
    }

    public double timestamp {
        get {
            return this.current_timestamp;
        }
    }

    public double session { get; set; default = 0.0; }  // TODO: rename to cycle or score
 
    private bool _is_paused;
    public bool is_paused {
        get {
            return this._is_paused;
        }
        set {
            this._is_paused = value;

            if (this._is_paused)
            {
                this.stop_timeout ();
            }
            else {
                this.update_offset ();

                this.start_timeout ();
            }
        }
    }

    public Timer ()
    {
        this.current_timestamp = Pomodoro.get_real_time ();
        this.timeout_source = 0;
        this.elapsed_offset = 0.0;

        this._state = new Pomodoro.DisabledState ();
    }

    /**
     * Check whether timer is ticking.
     *
     * Returns false if timer is paused or stopped.
     */
    public bool is_running ()
    {
        return this.timeout_source != 0;
    }

    public void start ()
    {
        this.resume ();

        if (this.state is Pomodoro.DisabledState) {
            this.state = new Pomodoro.PomodoroState ();
        }
    }

    public void stop ()
    {
        this.resume ();

        if (!(this.state is Pomodoro.DisabledState))
        {
            var timestamp = this.is_running () ? this.current_timestamp : 0.0;

            this.state = new Pomodoro.DisabledState.with_timestamp (timestamp);
        }
    }

    public void pause ()
    {
        if (!this.is_paused) {
            this.is_paused = true;
        }
    }

    public void resume ()
    {
        if (this.is_paused) {
            this.is_paused = false;
        }
    }

    public void reset ()
    {
        this.freeze_notify ();

        this.session = 0.0;
        this.elapsed = 0.0;

        this.resume ();

        this.thaw_notify ();
    }

    public void skip ()
    {
        this.state = this._state.create_next_state (this);
    }

    private bool on_timeout ()
    {
        this.update ();

        return true;
    }

    private void stop_timeout () {
        if (this.timeout_source != 0) {
            GLib.Source.remove (this.timeout_source);
            this.timeout_source = 0;
        }
    }

    private void start_timeout () {
        if (this.timeout_source == 0) {
            this.timeout_source = Timeout.add (1000, this.on_timeout);
        }
    }

    private void update_offset ()
    {
        this.elapsed_offset = this._state.elapsed - (this.current_timestamp - this._state.timestamp);
    }

    private void update_elapsed ()
    {
        assert (this.current_timestamp != 0.0);

        this._state.elapsed = this.elapsed_offset + this.current_timestamp - this._state.timestamp;
    }

    /**
     * Update timer state after timer elapse or state change.
     */
    private bool resolve_state ()
    {
        var original_state = this._state as TimerState;
        var state_changed = true;

        while (this._state.duration > 0.0 &&
               this._state.elapsed >= this._state.duration)
        {
            this.state_leave (this._state);

            this._state = this._state.create_next_state (this);
            this.update_offset ();

            state_changed = true;

            this.state_enter (this._state);
        }

        if (state_changed)
        {
            this.state_changed (this._state, original_state);
        }

        return state_changed;
    }

    public virtual signal void update (double timestamp = 0.0)
    {
        this.current_timestamp = (timestamp > 0.0) ? timestamp : Pomodoro.get_real_time ();

        this.update_elapsed ();

        if (!this.resolve_state ()) {
            this.notify_property ("elapsed");
        }
    }

    public virtual signal void state_enter (TimerState state)
    {
    }

    public virtual signal void state_leave (TimerState state)
    {
        this.session += state.get_score (this);
    }

    public virtual signal void state_changed (TimerState state, TimerState previous_state)
    {
        // TODO: Notifications module should determine wether timer timeouted (and need notification) or change was made uppon request.

        /* Run the timer */
        if (state is DisabledState) {
            this.stop_timeout ();
        }
        else {
            this.start_timeout ();  // TODO: align to miliseconds
        }

        this.notify_property ("state");  // TODO: is it needed?
        this.notify_property ("elapsed");
    }

    public override void dispose ()
    {
        if (this.timeout_source != 0) {
            GLib.Source.remove (this.timeout_source);
            this.timeout_source = 0;
        }

        base.dispose ();
    }

    public virtual signal void destroy ()
    {
        this.dispose ();
    }

    public static void save (Timer timer)
    {
        var state_settings = Pomodoro.get_settings ()
                                     .get_child ("state");

        var state_datetime = new DateTime.from_unix_utc (
                             (int64) Math.floor (timer.state.timestamp));

        state_settings.set_double ("session",
                                   timer.session);
        state_settings.set_string ("state",
                                   timer.state.name);
        state_settings.set_string ("state-date",
                                   datetime_to_string (state_datetime));
        state_settings.set_double ("state-offset",
                                   timer.offset);  // - timer.state.timestamp % 1.0);
        state_settings.set_double ("state-duration",
                                   timer.state.duration);
    }

    public static void restore (Timer timer)
    {
        timer.stop ();

        var state_settings = Pomodoro.get_settings ()
                                     .get_child ("state");

        var state = TimerState.lookup (state_settings.get_string ("state"));

        if (state != null)
        {
            state.elapsed = state_settings.get_double ("state-offset");
            state.duration = state_settings.get_double ("state-duration");

            try {
                var state_date = state_settings.get_string ("state-date");

                if (state_date != "") {
                    var state_datetime = datetime_from_string (state_date);
                    state.timestamp = (double) state_datetime.to_unix ();
                }
            }
            catch (DateTimeError error) {
                /* In case there is no valid state-date, elapsed time
                 * will be lost.
                 */
                state = null;
            }
        }

        if (state != null)
        {
            timer.state = state;
            timer.session = state_settings.get_double ("session");
        }
        else {
            GLib.warning ("Could not restore time");
        }

        timer.update ();
    }

//    private void on_settings_changed (GLib.Settings settings, string key)
//    {
//        var state_duration = this.state_duration;

//        switch (key)
//        {
//            case "pomodoro-duration":
//                if (this.timer.state == State.POMODORO) {
//                    state_duration = this.settings.get_double (key);
//                }
//                break;

//            case "short-break-duration":
//                if (this.timer.state == State.PAUSE && !this.is_long_break) {
//                    state_duration = this.settings.get_double (key);
//                }
//                break;

//            case "long-break-duration":
//                if (this.timer.state == State.PAUSE && this.is_long_break) {
//                    state_duration = this.settings.get_double (key);
//                }
//                break;

//            case "long-break-interval":
//                if (this.timer.session_limit != this.settings.get_double (key)) {
//                    this.timer.session_limit = this.settings.get_double (key);
//                }
//                break;
//        }

//        if (state_duration != this.state_duration)
//        {
//            this.state_duration = double.max (state_duration, this.elapsed);
//            this.timer.update ();
//        }
//    }
}

namespace Pomodoro
{
    /*
     * TODO Move out to gnome-desktop module
     */
    public class IdleMonitor : GLib.Object
    {
        private Gnome.IdleMonitor idle_monitor;
        private uint became_active_id;

        public IdleMonitor ()
        {
            this.idle_monitor = new Gnome.IdleMonitor ();
            this.became_active_id = 0;
        }

        protected void enable ()
        {
            if (this.became_active_id == 0) {
                this.became_active_id = this.idle_monitor.add_user_active_watch (this.on_became_active);
            }
        }

        protected void disable ()
        {
            if (this.became_active_id != 0) {
                this.idle_monitor.remove_watch (this.became_active_id);
                this.became_active_id = 0;
            }
        }

        private void on_became_active (Gnome.IdleMonitor monitor)
        {
            // TODO
//            if (this.state == State.IDLE)
//            {
//                this.current_timestamp = Pomodoro.get_time ();
//
//                /* Treat last second as if it were already pomodoro */
//                var elapsed = this.current_timestamp - this.state.timestamp;
//                var timestamp = this.current_timestamp - elapsed.clamp (0.0, 1.0);
//
//                this.set_state_full (State.POMODORO, 0.0, timestamp);
//            }
        }

        public override void dispose ()
        {
            this.disable ();
            this.idle_monitor = null;

            base.dispose ();
        }
    }
}
