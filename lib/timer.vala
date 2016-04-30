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
    /**
     * Pomodoro.Timer class.
     *
     * A class for a countdown timer. Timer works in an atomic manner, it acknowlegdes passage
     * of time after calling update() method.
     *
     * TODO: Ability to stop/continue after timer runs out
     */
    public class Timer : GLib.Object
    {
        private static Pomodoro.Timer? instance = null;

        public static unowned Pomodoro.Timer get_default ()
        {
            if (Timer.instance == null) {
                Timer.instance = new Timer ();
                Timer.instance.destroy.connect (() => {
                    Timer.instance = null;
                });
            }

            return Timer.instance;
        }

        private uint timeout_source;
        private double current_timestamp;
        private double elapsed_offset;
        private TimerState _state;
        private bool _is_paused;

        public double elapsed {
            get {
                return this._state.elapsed;
            }
            set {
                this._state.elapsed = value;
                this.update_offset ();
            }
        }

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

        [CCode (notify = false)]
        public double state_duration {
            get {
                return this._state != null ? this._state.duration : 0.0;
            }
            set {
                if (this._state != null) {
                    this._state.duration = value;
                }
            }
        }

        [CCode (notify = false)]
        public double remaining {
            get {
                return (this._state != null ? this._state.duration : 0.0) - this._state.elapsed;
            }
        }

        [CCode (notify = false)]
        public bool is_paused {
            get {
                return this._is_paused;
            }
            set {
                if (value != this._is_paused) {
                    this._is_paused = value;
                    this.update_timeout ();

                    this.notify_property ("is-paused");
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

        public void toggle ()
        {
            if (this.state is Pomodoro.DisabledState) {
                this.start ();
            }
            else {
                this.stop ();
            }
        }

        public void pause ()
        {
            this.is_paused = true;
        }

        public void resume ()
        {
            if (this.timeout_source == 0) {
                this.current_timestamp = Pomodoro.get_real_time ();

                this.update_offset ();
            }

            this.is_paused = false;
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
                this.timeout_source = GLib.Timeout.add (1000, this.on_timeout);
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
            var state_changed = false;

            while (this._state.duration > 0.0 &&
                   this._state.elapsed >= this._state.duration)
            {
                this.state_leave (this._state);

                this._state = this._state.create_next_state (this);
                this.update_offset ();

                state_changed = true;

                this.state_enter (this._state);
            }

            if (state_changed) {
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
            state.notify["duration"].connect (this.on_state_duration_notify);
        }

        public virtual signal void state_leave (TimerState state)
        {
            state.notify["duration"].disconnect (this.on_state_duration_notify);

            this.session += state.get_score (this);
        }

        public virtual signal void state_changed (TimerState state, TimerState previous_state)
        {
            // TODO: Notifications module should determine wether timer timeouted (and need notification) or change was made uppon request.

            /* Run the timer */
            this.update_timeout ();

            this.notify_property ("state");  // TODO: is it needed?
            this.notify_property ("elapsed");
        }

        private void update_timeout ()
        {
            if (this.state is DisabledState || this.is_paused) {
                this.stop_timeout ();
            }
            else {
                this.start_timeout ();  // TODO: align to miliseconds
            }
        }

        private void on_state_duration_notify ()
        {
            this.update ();

            this.notify_property ("state-duration");
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
    }
}
