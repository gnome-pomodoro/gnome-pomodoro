/*
 * Copyright (c) 2022 gnome-pomodoro contributors
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
    public enum TimerAction
    {
        NONE,
        RESET,
        START,
        STOP,
        PAUSE,
        RESUME,
        SKIP,
        REWIND,
        // SHORTEN,  // TODO: handle duration change
        // EXTEND,
        FINISH,
        SUSPEND;  // TODO: treat suspend as PAUSE/RESUME

        public string to_string ()
        {
            switch (this)
            {
                case NONE:
                    return "none";

                case RESET:
                    return "reset";

                case START:
                    return "start";

                case STOP:
                    return "stop";

                case PAUSE:
                    return "pause";

                case RESUME:
                    return "resume";

                case SKIP:
                    return "rewind";

                case FINISH:
                    return "finish";

                case SUSPEND:
                    return "suspend";

                default:
                    return "";
            }
        }
    }

    /**
     * Helper structure for changing several fields at once. Together they can be regarded as a timer state.
     *
     * `user_data` in our use refers to a time block, but don't over use it.
     */
    [Immutable]
    public struct TimerState
    {
        public int64 duration;
        public int64 offset;
        public int64 started_time;
        public int64 paused_time;
        public int64 finished_time;
        public void* user_data;

        public TimerState ()
        {
            this.duration = 0;
            this.offset = 0;
            this.started_time = Pomodoro.Timestamp.UNDEFINED;
            this.paused_time = Pomodoro.Timestamp.UNDEFINED;
            this.finished_time = Pomodoro.Timestamp.UNDEFINED;
            this.user_data = null;
        }

        /**
         * Make state copy
         *
         * This function is unnecesary. Structs in vala are copied by default. It's kept
         * to bring more clarity to our code.
         */
        public Pomodoro.TimerState copy ()
        {
            return Pomodoro.TimerState () {
                duration = this.duration,
                offset = this.offset,
                started_time = this.started_time,
                paused_time = this.paused_time,
                finished_time = this.finished_time,
                user_data = this.user_data
            };
        }

        public bool equals (Pomodoro.TimerState other)
        {
            return this.duration == other.duration &&
                   this.offset == other.offset &&
                   this.started_time == other.started_time &&
                   this.paused_time == other.paused_time &&
                   this.finished_time == other.finished_time &&
                   this.user_data == other.user_data;
        }

        public bool is_valid ()
        {
            // negative duration
            if (this.duration < 0) {
                return false;
            }

            // finished, but not started
            if (this.finished_time >= 0 && this.started_time < 0) {
                return false;
            }

            // finished and still paused
            if (this.finished_time >= 0 && this.paused_time >= 0) {
                return false;
            }

            // paused before started
            if (this.paused_time >= 0 && this.paused_time < this.started_time) {
                return false;
            }

            // finished before started
            if (this.finished_time >= 0 && this.finished_time < this.started_time) {
                return false;
            }

            return true;
        }

        /**
         * Convert structure to Variant.
         *
         * Used in tests.
         */
        public GLib.Variant to_variant ()
        {
            var builder = new GLib.VariantBuilder (new GLib.VariantType ("a{s*}"));
            builder.add ("{sv}", "duration", new GLib.Variant.int64 (this.duration));
            builder.add ("{sv}", "offset", new GLib.Variant.int64 (this.offset));
            builder.add ("{sv}", "started_time", new GLib.Variant.int64 (this.started_time));
            builder.add ("{sv}", "paused_time", new GLib.Variant.int64 (this.paused_time));
            builder.add ("{sv}", "finished_time", new GLib.Variant.int64 (this.finished_time));
            // builder.add ("{smh}", "user_data", this.user_data);

            return builder.end ();
        }

        /**
         * Represent state as string.
         *
         * Used in tests.
         */
        public string to_representation ()
        {
            var representation = new GLib.StringBuilder ("TimerState (\n");
            representation.append (@"    duration = $duration,\n");
            representation.append (@"    offset = $offset,\n");
            representation.append (@"    started_time = $started_time,\n");
            representation.append (@"    paused_time = $paused_time,\n");
            representation.append (@"    finished_time = $finished_time,\n");
            representation.append (this.user_data == null
                ? "    user_data = null\n"
                : "    user_data = not null\n");
            representation.append (")");

            return representation.str;
        }
    }


    /**
     * Timer class mimicks a physical countdown timer.
     *
     * It trigger events on state changes. To triger ticking event at regular intervals use TimerTicker.
     */
    public class Timer : GLib.Object
    {
        /**
         * Interval of the internal idle timeout.
         */
        private const uint IDLE_TIMEOUT_SECONDS = 2;

        /**
         * Time that is within tolerance not to schedule a timeout.
         */
        private const int64 MIN_TIMEOUT = 125000;  // 0.125s

        /**
         * Remaining time at which we no longer can rely on an idle timeout, and a higher precision timeout
         * should be scheduled. Should be higher than IDLE_TIMEOUT_SECONDS.
         */
        private const int64 MIN_IDLE_TIMEOUT = 2500000;  // 2.5s

        /**
         * Ignore minor deviations from expected elapsed time.
         */
        private const int64 MIN_SUSPEND_DURATION = 5 * Pomodoro.Interval.SECOND;

        private static unowned Pomodoro.Timer? instance = null;

        /**
         * Timer internal state.
         *
         * You should not change its fields directly.
         */
        public Pomodoro.TimerState state {
            get {
                return this._state;
            }
            set {
                this.set_state_full (value, Pomodoro.TimerAction.NONE);
            }
        }

        /**
         * The intended duration of the state, or running time of the timer.
         */
        public int64 duration {
            get {
                return this._state.duration;
            }
            construct set {
                if (value == this._state.duration) {
                    return;
                }

                if (value < 0) {
                    GLib.debug ("Trying to set a negative timer duration (%.1fs).",
                                Pomodoro.Timestamp.to_seconds (value));
                    value = 0;
                }

                var new_state = this._state.copy ();
                new_state.duration = value;

                if (new_state.duration > this._state.duration) {
                    new_state.finished_time = Pomodoro.Timestamp.UNDEFINED;
                }

                // TODO: log action: SHORTEN / EXTEND
                this.state = new_state;
            }
        }

        /**
         * Time when timer has been initialized/started.
         */
        public int64 timestamp {
            get {
                return this._state.started_time != Pomodoro.Timestamp.UNDEFINED
                    ? this._state.started_time
                    : this._state.paused_time;
            }
        }

        /**
         * Time lost during previous pauses. If pause is ongoing its not counted here yet.
         */
        public int64 offset {
            get {
                return this._state.offset;
            }
        }

        /**
         * Extra data associated with current state
         */
        public void* user_data {
            get {
                return this._state.user_data;
            }
            construct set {
                if (this.is_finished ()) {
                    GLib.debug ("Trying to set timer user-data after it finished");
                }

                var new_state = this._state.copy ();
                new_state.user_data = value;

                this.state = new_state;
            }
        }

        private Pomodoro.TimerState  _state = Pomodoro.TimerState () {
            duration = 0,
            offset = 0,
            started_time = Pomodoro.Timestamp.UNDEFINED,
            paused_time = Pomodoro.Timestamp.UNDEFINED,
            finished_time = Pomodoro.Timestamp.UNDEFINED,
            user_data = null
        };
        private uint                 timeout_id = 0;
        private Pomodoro.TimerAction last_action = Pomodoro.TimerAction.NONE;
        private int64                last_state_changed_time = Pomodoro.Timestamp.UNDEFINED;
        private int64                last_timeout_time = Pomodoro.Timestamp.UNDEFINED;
        private int64                last_timeout_elapsed = 0;
        private bool                 resolving_state = false;
        private Pomodoro.TimerState? state_to_resolve = null;
        private int                  suspended_freeze_count = 0;

        public Timer (int64 duration = 0,
                      void* user_data = null)
                      requires (duration >= 0)
        {
            this._state = Pomodoro.TimerState () {
                duration = duration,
                offset = 0,
                started_time = Pomodoro.Timestamp.UNDEFINED,
                paused_time = Pomodoro.Timestamp.UNDEFINED,
                finished_time = Pomodoro.Timestamp.UNDEFINED,
                user_data = user_data
            };
        }

        public Timer.with_state (Pomodoro.TimerState state)
        {
            this._state = state;

            if (this._state.started_time >= 0) {
                this.last_state_changed_time = Pomodoro.Timestamp.from_now ();

                this.update_timeout (this.last_state_changed_time);
            }

            // TODO: determine last action?
        }

        construct
        {
            // freeze suspend detection in unittests
            if (Pomodoro.Timestamp.is_frozen ()) {
                this.freeze_suspended ();
            }
        }

        ~Timer ()
        {
            if (Pomodoro.Timer.instance == null) {
                Pomodoro.Timer.instance = null;
            }
        }

        /**
         * Try to change state and update fields related to state change
         */
        private void set_state_full (Pomodoro.TimerState  state,
                                     Pomodoro.TimerAction action,
                                     int64                timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            this.resolve_state_internal (ref state);
            assert (state.is_valid ());

            if (!this._state.equals (state))
            {
                var previous_state = this._state;

                this._state = state;

                // note that some actions won't be recorded
                this.last_state_changed_time = timestamp;
                this.last_action = action;

                // TODO: notify properties?
                this.state_changed (this._state, previous_state);
            }
        }

        /**
         * Resolve timer state.
         *
         * It's a wrapper for `this.resolve_state`, handling a possible recursion.
         */
        private void resolve_state_internal (ref Pomodoro.TimerState state)
        {
            var recursion_count = 0;

            if (this.resolving_state) {
                this.state_to_resolve = state;
                return;
            }

            if (this._state.equals (state)) {
                return;
            }

            this.resolving_state = true;

            while (true)
            {
                this.resolve_state (ref state);

                if (this.state_to_resolve == null) {
                    break;
                }

                if (recursion_count > 1) {  // TODO: increase
                    GLib.error ("Reached recursion limit while resolving timer state");
                    break;
                }

                state = this.state_to_resolve;
                this.state_to_resolve = null;

                recursion_count++;
            }

            this.resolving_state = false;
        }


        /**
         * Return a default timer or `null` if none is set.
         */
        public static unowned Pomodoro.Timer? get_default ()
        {
            return Pomodoro.Timer.instance;
        }

        public void set_default ()
        {
            Pomodoro.Timer.instance = this;
        }

        public bool is_default ()
        {
            return Pomodoro.Timer.instance == this;
        }

        /**
         * Return whether timer is ticking -- whether timer has started and is not paused.
         */
        public bool is_running ()
        {
            return this.timeout_id != 0;
        }

        /**
         * Return whether timer has been started.
         */
        public bool is_started ()
        {
            return this._state.started_time >= 0;
        }

        /**
         * Return whether timer is paused.
         */
        public bool is_paused ()
        {
            return this._state.paused_time >= 0 && this._state.started_time >= 0 && this._state.finished_time < 0;
        }

        /**
         * Return whether timer has finished.
         *
         * It does not need to reach full time for timer to be marked as finished.
         */
        public bool is_finished ()
        {
            return this._state.finished_time >= 0;
        }


        /**
         * Reset timer to initial state.
         */
        public void reset (int64 duration = 0,
                           void* user_data = null)
                           requires (duration >= 0)
        {
            this.set_state_full (
                Pomodoro.TimerState () {
                    duration = duration,
                    offset = 0,
                    started_time = Pomodoro.Timestamp.UNDEFINED,
                    paused_time = Pomodoro.Timestamp.UNDEFINED,
                    finished_time = Pomodoro.Timestamp.UNDEFINED,
                    user_data = user_data
                },
                Pomodoro.TimerAction.RESET
            );
        }

        /**
         * Start the timer or continue where it left off.
         */
        public void start (int64 timestamp = -1)
        {
            if (this.is_started () || this.is_finished ()) {
                return;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            var new_state = this._state.copy ();
            new_state.started_time = timestamp;
            new_state.paused_time = Pomodoro.Timestamp.UNDEFINED;

            this.set_state_full (new_state, Pomodoro.TimerAction.START, timestamp);
        }

        /**
         * Stop the timer if it's running.
         */
        public void pause (int64 timestamp = -1)
        {
            if (this.is_paused () || !this.is_started () || this.is_finished ()) {
                return;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            var new_state = this._state.copy ();
            new_state.paused_time = timestamp;

            this.set_state_full (new_state, Pomodoro.TimerAction.PAUSE, timestamp);
        }

        /**
         * Resume timer if paused.
         */
        public void resume (int64 timestamp = -1)
        {
            if (!this.is_started () || this.is_finished () || !this.is_paused ()) {
                return;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            var new_state = this._state.copy ();
            new_state.offset += timestamp - new_state.paused_time;
            new_state.paused_time = Pomodoro.Timestamp.UNDEFINED;

            this.set_state_full (new_state, Pomodoro.TimerAction.RESUME, timestamp);
        }

        /**
         * Rewind and resume timer
         */
        public void rewind (int64 microseconds,
                            int64 timestamp = -1)
        {
            if (!this.is_started ()) {
                return;
            }

            if (microseconds == 0) {
                return;
            }

            if (microseconds < 0) {
                GLib.debug ("Rewinding timer with negative value (%.1fs).",
                            Pomodoro.Timestamp.to_seconds (microseconds));
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            var new_elapsed = int64.max (this.calculate_elapsed (timestamp) - microseconds, 0);
            var new_state = this._state.copy ();

            if (new_state.paused_time >= 0) {
                new_state.offset += timestamp - new_state.paused_time;
                new_state.paused_time = Pomodoro.Timestamp.UNDEFINED;
            }

            if (new_state.finished_time >= 0) {
                new_state.offset += timestamp - new_state.finished_time;
                new_state.finished_time = Pomodoro.Timestamp.UNDEFINED;
            }

            new_state.offset = timestamp - new_state.started_time - new_elapsed;

            this.set_state_full (new_state, Pomodoro.TimerAction.REWIND, timestamp);
        }

        /**
         * Jump to end position. Mark state as "finished".
         */
        public void skip (int64 timestamp = -1)
        {
            if (!this.is_started () || this.is_finished ()) {
                return;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            var new_state = this._state.copy ();
            new_state.finished_time = timestamp;

            if (new_state.paused_time >= 0) {
                new_state.offset += timestamp - new_state.paused_time;
                new_state.paused_time = Pomodoro.Timestamp.UNDEFINED;
            }

            this.set_state_full (new_state, Pomodoro.TimerAction.SKIP, timestamp);
        }

        /**
         * Mark state as "finished".
         */
        private void finish (int64 timestamp = -1)
        {
            this.stop_timeout ();

            if (this.is_finished ()) {
                return;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            var new_state = this._state.copy ();
            new_state.finished_time = timestamp;

            if (new_state.paused_time >= 0) {
                new_state.offset += timestamp - new_state.paused_time;
                new_state.paused_time = Pomodoro.Timestamp.UNDEFINED;
            }

            this.set_state_full (new_state, Pomodoro.TimerAction.FINISH, timestamp);
        }

        // TODO: Is there a better way to detect system suspension?
        //       How gdm/screensaver knows when system woke up?
        private bool check_suspended (int64 timestamp)
                                      requires (this.last_timeout_time >= 0)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            // MIN_SUSPEND_DURATION relates to a delay from expected elapsed time
            var suspend_duration_threshold = MIN_SUSPEND_DURATION + Pomodoro.Interval.SECOND * IDLE_TIMEOUT_SECONDS;
            var elapsed                    = timestamp - this._state.started_time - this._state.offset;
            var suspended_duration         = timestamp - this.last_timeout_time;

            if (this.suspended_freeze_count > 0 || suspended_duration < suspend_duration_threshold) {
                this.last_timeout_time = timestamp;
                this.last_timeout_elapsed = elapsed;

                return false;
            }
            else {
                GLib.debug ("Detected system suspension (%.1fs)",
                            (int) (Pomodoro.Timestamp.to_seconds (suspended_duration)));

                var suspended_start_time = this.last_timeout_time;
                var suspended_end_time = timestamp;
                var new_elapsed = int64.max (
                    this.calculate_elapsed (timestamp) - (suspended_end_time - suspended_start_time),
                    0);
                var new_state = this._state.copy ();

                if (new_state.paused_time >= 0) {
                    new_state.offset += timestamp - new_state.paused_time;
                    new_state.paused_time = Pomodoro.Timestamp.UNDEFINED;
                }

                new_state.offset = timestamp - new_state.started_time - new_elapsed;
                // new_state.paused_time = timestamp;  // TODO: after suspension timer should be paused, perhaps by a `suspended` handler

                this.set_state_full (new_state, Pomodoro.TimerAction.SUSPEND, timestamp);

                this.suspended (suspended_start_time, suspended_end_time);

                return true;
            }
        }

        /**
         * Idle timeout.
         *
         * Serves as a heartbeat. Checks whether there are delays or whether system has been suspended.
         */
        private bool on_timeout_idle ()
                                      requires (this.timeout_id != 0)
        {
            var timestamp = Pomodoro.Timestamp.from_now ();
            var remaining = this.calculate_remaining (timestamp);

            if (this.check_suspended (timestamp)) {
                return GLib.Source.REMOVE;
            }

            // Check if already finished
            if (remaining <= MIN_TIMEOUT) {
                this.stop_timeout ();
                this.finish (timestamp);

                return GLib.Source.REMOVE;
            }

            // Check whether to switch to a more precise timeout
            if (remaining <= MIN_IDLE_TIMEOUT) {
                this.stop_timeout ();
                this.start_timeout_internal (remaining, timestamp);

                return GLib.Source.REMOVE;
            }

            return GLib.Source.CONTINUE;
        }

        /**
         * Precise timeout.
         *
         * It's meant to be fired once at the end of current time-block.
         */
        private bool on_timeout ()
                                 requires (this.timeout_id != 0)
        {
            var timestamp = Pomodoro.Timestamp.from_now ();
            var remaining = this.calculate_remaining (timestamp);

            if (this.check_suspended (timestamp)) {
                return GLib.Source.REMOVE;
            }

            this.stop_timeout ();

            if (remaining > MIN_TIMEOUT) {
                this.start_timeout_internal (remaining, timestamp);
            }
            else {
                this.finish (timestamp);
            }

            return GLib.Source.REMOVE;
        }

        private void start_timeout_internal (int64 remaining,
                                             int64 timestamp)
        {
            this.last_timeout_time = timestamp;
            this.last_timeout_elapsed = this.calculate_elapsed (timestamp);

            if (remaining > MIN_IDLE_TIMEOUT) {
                this.timeout_id = GLib.Timeout.add_seconds_full (GLib.Priority.DEFAULT_IDLE, IDLE_TIMEOUT_SECONDS, this.on_timeout_idle);
                GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.Timer.on_timeout_idle");
            }
            else if (remaining > MIN_TIMEOUT) {
                this.timeout_id = GLib.Timeout.add_full (GLib.Priority.DEFAULT, (uint) (remaining / 1000), this.on_timeout);
                GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.Timer.on_timeout");
            }
            else {
                this.finish (timestamp);
            }
        }

        private void start_timeout (int64 timestamp = -1)
        {
            if (this.timeout_id != 0 ) {
                return;  // already running
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            this.start_timeout_internal (this.calculate_remaining (timestamp),
                                         timestamp);
        }

        private void stop_timeout ()
        {
            if (this.timeout_id == 0) {
                return;
            }

            GLib.Source.remove (this.timeout_id);

            this.timeout_id = 0;
            this.last_timeout_time = Pomodoro.Timestamp.UNDEFINED;
            this.last_timeout_elapsed = 0;
        }

        private void update_timeout (int64 timestamp = -1)
        {
            if (this._state.finished_time < 0
                && this._state.started_time >= 0
                && this._state.paused_time < 0)
            {
                this.start_timeout (timestamp);
            }
            else {
                this.stop_timeout ();
            }
        }

        /**
         * Increment freeze counter for suspended signal.
         */
        public void freeze_suspended ()
        {
            this.suspended_freeze_count++;
        }

        /**
         * Decrese freeze counter for suspended signal.
         */
        public void thaw_suspended ()
        {
            this.suspended_freeze_count--;
        }

        /**
         * Manually trigger internal timeout, which performs checks and may mark state as finished.
         *
         * Intended for unit tests.
         * Beaware that jumping between timestamps may trigger sespended signal. Use freeze_suspended / thaw_suspended.
         */
        public void tick ()  // TODO: rename to check / check_updates / iterate?
        {
            if (this.is_running ()) {
                this.on_timeout_idle ();
            }
        }

        /**
         * Return time of a last state change.
         *
         * It's deliberate that "last_state_changed_time" is not a property, as we don't want emitting
         * notify events for that.
         */
        public int64 get_last_state_changed_time ()
        {
            return this.last_state_changed_time;
        }

        public Pomodoro.TimerAction get_last_action ()
        {
            return this.last_action;
        }

        /**
         * Calculate elapsed time.
         *
         * It's only accurate when passing a current time. If you pass a historic time
         * the result will be just an estimate.
         */
        public int64 calculate_elapsed (int64 timestamp = -1)
        {
            if (this._state.started_time < 0) {
                return 0;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            if (this._state.paused_time >= 0) {
                timestamp = int64.min (this._state.paused_time, timestamp);
            }

            if (this._state.finished_time >= 0) {
                timestamp = int64.min (this._state.finished_time, timestamp);
            }

            return (
                timestamp - this._state.started_time - this._state.offset
            ).clamp (0, this._state.duration);
        }

        /**
         * Calculate remaining time.
         *
         * It's only accurate when passing a current time. If you pass a historic time
         * the result will be just an estimate.
         */
        public int64 calculate_remaining (int64 timestamp = -1)
        {
            return this._state.duration - this.calculate_elapsed (timestamp);
        }

        /**
         * Calculate progress.
         *
         * It's only accurate when passing a current time. If you pass a historic time
         * the result will be just an estimate.
         */
        public double calculate_progress (int64 timestamp = -1)
        {
            var elapsed = (double) this.calculate_elapsed (timestamp);
            var duration = (double) this._state.duration;

            return duration > 0.0 ? elapsed / duration : 0.0;
        }

        /**
         * Wait until timer finishes
         *
         * It will only have an effect after Timer.start() or after setting up timer state.
         *
         * Intended for unit tests.
         */
        public void run (GLib.Cancellable? cancellable = null)
        {
            var main_context = GLib.MainContext.@default ();

            while (this.is_running () && (cancellable == null || !cancellable.is_cancelled ()))
            {
                main_context.iteration (true);
            }
        }

        /**
         * Emitted before setting a new state.
         *
         * It allows for fine-tuning the state before emitting state-changed signal.
         * Default handler ensures that state is valid.
         */
        public signal void resolve_state (ref Pomodoro.TimerState state)
        {
            if (state.started_time < 0) {
                state.paused_time = Pomodoro.Timestamp.UNDEFINED;
                state.finished_time = Pomodoro.Timestamp.UNDEFINED;
            }

            if (state.paused_time >= 0 && state.paused_time < state.started_time) {
                state.paused_time = state.started_time;
            }

            if (state.finished_time >= 0 && state.finished_time < state.started_time) {
                state.finished_time = state.started_time;
            }
        }

        /**
         * Emitted on any state related changes. Default handler acknowledges the change.
         */
        public signal void state_changed (Pomodoro.TimerState current_state,
                                          Pomodoro.TimerState previous_state)
        {
            // assert (current_state == this._state);  // TODO?

            // if (current_state.started_time > 0 && current_state.started_time > this.last_state_changed_time) {
            //     this.last_state_changed_time = current_state.started_time;
            // }

            // if (current_state.paused_time > 0 && current_state.paused_time > this.last_state_changed_time) {
            //     this.last_state_changed_time = current_state.paused_time;
            // }

            this.update_timeout (this.last_state_changed_time);

            if (current_state.finished_time >= 0 && previous_state.finished_time < 0) {
                this.finished (current_state);
            }
        }

        /**
         * Emitted after system wakes up from suspension.
         */
        public signal void suspended (int64 start_time,
                                      int64 end_time);

        /**
         * Emitted when countdown is close to zero or passed it.
         */
        public signal void finished (Pomodoro.TimerState state);

        public override void dispose ()
        {
            this.stop_timeout ();

            base.dispose ();
        }


        // --------------------------------------------------------------------------

        // TODO: remove these

        public void stop (int64 timestamp = -1)
        {
            assert_not_reached ();
        }
    }
}
