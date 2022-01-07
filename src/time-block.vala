using GLib;


namespace Pomodoro
{
    /**
     * Class describes an block of time - state, start and end time.
     * Blocks may have parent/child relationships. Currently its only used to define pauses, though class is kept
     * angnostic about it. A child block may exceed its parent time range. After a child block gets defined `end` time,
     * the parent block is update its `end` time.
     */
    public class TimeBlock : GLib.Object  // GLib.InitiallyUnowned
    {
        // TODO !!!!! any change to a block should be propagated to parent blocks
        // TODO !!!!! use MIN_TIMESTAMP and MAX_TIMESTAMP instead of -1

        public unowned Pomodoro.Session session { get; set; }

        public Pomodoro.State state { get; construct; }

        // TODO:
        // public Pomodoro.Context context { get; }

        // public int64 state_duration {
        //     get {
        //         return this._state_duration;
        //     }
        //     set {
        //         this._state_duration = value;
        //     }
        // }

        public int64 start_time {
            get {
                return this._start_time;
            }
            set {
                if (value < this._end_time) {
                    this.set_time_range (value, this._end_time);
                }
                else {
                    // TODO: log warning
                    this.set_time_range (value, value);
                }
            }
        }

        public int64 end_time {
            get {
                return this._end_time;
            }
            set {
                if (value >= this._start_time) {
                    this.set_time_range (this._start_time, value);
                }
                else {
                    // TODO: log warning
                    this.set_time_range (value, value);
                }
            }
        }

        // Beware that `duration` has a few edge cases:
        //  - when time block is infinite (`end` < 0 or `start` < 0) it returns -1
        //  - when one of the child is infinite, it returns duration according to its `end` and not the childs
        public int64 duration {  // TODO: change to calculate_duration
            get {
                return this._end_time - this._start_time;
            }
            // set {
            //     if (this._start_time >= 0) {
            //         this.schedule (this._start_time,
            //                         this._start_time + value,
            //                         Pomodoro.TimeBlockConflict.KEEP_START);
            //     }
            //     else if (this._end_time >= 0) {
            //         this.schedule (this._end_time - value,
            //                         this._end_time,
            //                         Pomodoro.TimeBlockConflict.KEEP_END);
            //     }
            //     else {
            //         GLib.warning ("Can't change TimeBlock.duration when both start and end are not defined");
            //     }
            // }
        }

        public unowned Pomodoro.TimeBlock? parent {
            get {
                return this._parent;
            }
            set {
                if (this._parent != value) {
                    // TODO: unparent properly, connect/disconnect signals
                    this._parent = value;
                }
            }
        }

        // Gaps should be defined as a child of a state, with first item as most recent.
        // A gap should not extend the time of parent block, it will be capped if it does.
        private GLib.SList<Pomodoro.TimeBlock> children = null;

        private unowned Pomodoro.TimeBlock? _parent = null;
        // private int64                       _state_duration = 0;
        // private Pomodoro.Context         _context = null;
        // private Pomodoro.Source          _source = Source.OTHER;
        private int64                       _start_time = Pomodoro.Timestamp.MIN;
        private int64                       _end_time = Pomodoro.Timestamp.MAX;

        public TimeBlock (Pomodoro.State state)
        {
            GLib.Object (
                state: state
            );

            // end_time = end_time == Pomodoro.Timestamp.UNDEFINED
            //     ? start_time + state.get_default_duration ()
            //     : Pomodoro.Timestamp.MAX;

            // this.set_time_range (start_time, end_time);

            // this._state_duration = state.get_default_duration ();

        //     this.schedule_internal (start, end, Pomodoro.TimeBlockConflict.KEEP_START);

            // this.children = null;
        }

        public TimeBlock.with_start_time (Pomodoro.State state,
                                          int64          start_time)
        {
            GLib.Object (
                state: state
            );

            this.set_time_range (
                start_time,
                Pomodoro.Timestamp.add (start_time, state.get_default_duration ())
            );
        }

        // construct
        // {
        //     if (this._timestamp == 0) {
        //         this._timestamp = Pomodoro.get_current_time ();
        //     }
        // }

        public void set_time_range (int64 start_time,
                                    int64 end_time)
        {
            // start_time = start_time.clamp (Pomodoro.Timestamp.MIN, Pomodoro.Timestamp.MAX);
            // end_time = end_time.clamp (Pomodoro.Timestamp.MIN, Pomodoro.Timestamp.MAX);

            var old_start_time = this._start_time;
            var old_end_time = this._end_time;
            var old_duration = this._end_time - this._start_time;
            var changed = false;

            this._start_time = start_time;
            this._end_time = end_time;

            if (this._start_time != old_start_time) {
                this.notify_property ("start-time");
                changed = true;
            }

            if (this._end_time != old_end_time) {
                this.notify_property ("end-time");
                changed = true;
            }

            if (this._end_time - this._start_time != old_duration) {
                this.notify_property ("duration");
            }

            if (changed) {
                this.changed ();
            }
        }

        // /**
        //  * Return whether time block has bounds. It does not take into account children.
        //  */
        // public bool is_finite ()
        // {
        //     return this._start_time >= 0 && this._end_time >= 0;
        // }

        // /**
        //  * Return whether time block is missing bounds. It does not take into account children.
        //  */
        // public bool is_infinite ()
        // {
        //     return this._start_time < 0 || this._end_time < 0;
        // }

        // /**
        //  * Return whether time block has bounds.
        //  */
        // public bool has_bounds (bool include_children = false)
        // {
        //     if (this._start_time <= Pomodoro.Timestamp.MIN || this._end_time >= Pomodoro.Timestamp.MAX) {
        //         return false;
        //     }

        //     if (include_children) {
        //         var has_bounds = true;

        //         this.children.@foreach ((child) => {
        //             has_bounds = has_bounds && child.has_bounds (true);
        //         });

        //         return has_bounds;
        //     }

        //     return true;
        // }

        // public bool contains (int64 timestamp)  // TODO: rename to is_started
        // {
        //     return timestamp >= this._start_time && timestamp < this._end_time;
        // }

        // public bool intersects (Pomodoro.TimeBlock )  // TODO: rename to is_started
        // {
        //     if (this._start_time < 0) {
        //         return true;
        //     }
        // }

        // public bool has_started (int64 timestamp = -1)  // TODO: rename to is_scheduled
        // {
        //     if (this._start_time < 0) {
        //         return true;
        //     }
        //
        //     ensure_timestamp (ref timestamp);
        //
        //     return timestamp >= this._start_time;
        // }

        // public bool has_ended (int64 timestamp = -1)  // TODO: rename to is_finished
        // {
        //     if (this._end_time < 0) {
        //         return false;
        //     }
        //
        //     ensure_timestamp (ref timestamp);
        //
        //     return this._end_time <= timestamp;
        // }

        // public bool is_scheduled (int64 timestamp = -1)
        // {
        //     ensure_timestamp (ref timestamp);
        //
        //     return timestamp < this._start_time;
        // }

        // public bool is_finished (int64 timestamp = -1)
        // {
        //     ensure_timestamp (ref timestamp);
        //
        //     return timestamp >= this._end_time;
        // }

        // public bool is_in_progress (int64 timestamp = -1)
        // {
        //     ensure_timestamp (ref timestamp);
        //
        //     return timestamp >= this._start_time && timestamp < this._end_time;
        // }

        // Note: result won't make sense if block has no `start`
        // public int64 calculate_elapsed (int64 timestamp = -1)
        // {
        //     if (this._start_time < 0) {
        //         return -1;
        //     }

        //     ensure_timestamp (ref timestamp);

        //     return int64.max (timestamp - this._start_time, 0);
        // }

        // Note: result won't make sense if block has no `end`
        // public int64 calculate_remaining (int64 timestamp = -1)
        // {
        //     if (this._end < 0) {
        //         return -1;
        //     }

        //     ensure_timestamp (ref timestamp);

        //     return int64.max (this._end_time - timestamp, 0);
        // }

        // Note: result won't make sense if block have no bounds
        // public double calculate_progress (int64 timestamp = -1)
        // {
        //     if (this._start_time < 0) {
        //         return 0.0;
        //     }

        //     var duration = this.duration;

        //     return duration > 0
        //         ? this.get_elapsed (timestamp) / duration
        //         : 0.0;
        // }

        // /**
        //  * Return sum of childrens durations.
        //  */
        // public int64 get_children_duration ()
        // {
        //     int64 children_duration = 0;

        //     this.children.@foreach ((child) => {
                // TODO: handle overlapping children

        //         if (children_duration >= 0) {
        //             if (child.has_bounds ()) {
        //                 children_duration += child.duration;
        //             }
        //             else {
        //                 children_duration = -1;
        //             }
        //         }
        //     });

        //     return children_duration;
        // }

        // /**
        //  * Similar to .get_children_duration(), but counts elapsed time in case blocks have no `end`
        //  *
        //  * Return sum of childrens durations.
        //  */
        // public int64 get_children_elapsed (int64 timestamp = -1)
        // {
        //     int64 children_elapsed = 0;

        //     ensure_timestamp (ref timestamp);
            // if (timestamp < 0) {
            //     timestamp = Pomodoro.get_current_time ();
            // }

        //     this.children.@foreach ((child) => {
                // TODO: handle overlapping children

        //         if (children_elapsed >= 0 ) {
        //             children_elapsed += child.duration;
        //         }

        //         children_elapsed += child.get_elapsed (timestamp);
        //     });

        //     return children_elapsed;
        // }

        public static int compare (Pomodoro.TimeBlock a,
                                   Pomodoro.TimeBlock b)
        {
            return - ((int) (a.start_time > b.start_time) - (int) (a.start_time < b.start_time));  // in descending order
        }

        public void add_child (Pomodoro.TimeBlock child)
        {
            this.children.insert_sorted (child, Pomodoro.TimeBlock.compare);
        }

        public void remove_child (Pomodoro.TimeBlock child)
        {
            this.children.remove (child);
        }

        public Pomodoro.TimeBlock? get_last_child ()
        {
            unowned SList<Pomodoro.TimeBlock> link = this.children.last ();

            return link != null ? link.data : null;
        }

        public void foreach_child (GLib.Func<Pomodoro.TimeBlock> func)
        {
            this.children.@foreach (func);
        }



        public Pomodoro.TimerState to_timer_state (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            var start_time = this._start_time;

            if (start_time <= Pomodoro.Timestamp.MIN) {
                start_time = timestamp;
            }

            return Pomodoro.TimerState () {
                duration = this.state.get_default_duration (),  // TODO: should be state_duration
                started_time = start_time,
                stopped_time = Pomodoro.Timestamp.UNDEFINED,
                is_finished = false
            };
        }


        // -----------------------------------------------------------------

        // public bool is_paused (int64 timestamp = -1)
        // {
        //     if (timestamp < 0) {
        //         timestamp = Pomodoro.get_current_time ();
        //     }
        //
        //     var gap = this.gaps.first ();
        //
        //     return gap != null && gap.state == State.PAUSED && !gap.is_finished (timestamp);
        // }

        // public bool is_completed ()
        // {
        // }

        /*
        public void schedule (int64 timestamp)
        {
        }

        public void start (int64 timestamp = Pomodoro.get_current_time ())
        {
        }
        */

        // /**
        //  * Normally, you should alter `duration` to specify timeblock end.
        //  * Once
        //  */
        // public void finish (int64 timestamp = -1)  // TODO: capture context and source
        // {
        //     if (this.duration >= 0) {
        //         // already finished
        //         return;
        //     }
        //
        //     if (timestamp < 0) {
        //         timestamp = Pomodoro.get_current_time ();
        //     }
        //
        //     var gap = this.gaps.first ();
        //     if (gap != null) {
        //         gap.finish (timestamp);
        //     }
        //
        //     this.duration = int64.max (timestamp - this.timestamp, 0);
        // }

        /*
        public static TimerState? lookup (string name)
        {
            TimerState state;

            switch (name)
            {
                case "pomodoro":
                    state = new PomodoroState ();
                    break;

                case "short-break":
                    state = new ShortBreakState ();
                    break;

                case "long-break":
                    state = new LongBreakState ();
                    break;

                case "null":
                    state = new DisabledState ();
                    break;

                default:
                    state = null;
                    break;
            }

            return state;
        }
        */

        // /**
        //  *
        //  */
        // public signal void scheduled ();

        public signal void changed ();

        /*
        public void pause (int64 timestamp = -1)  // TODO: capture context
        {
            if (this.is_paused (timestamp)) {
                // already paused
                return;
            }

            this.gaps.prepend (
                new TimeBlock () {
                    timestamp = timestamp,
                    duration = -1
                }
            );

            this.changed ();
        }

        public void resume (int64 timestamp = -1)  // TODO: store source
        {
            if (!this.is_paused ()) {
                // ignore, wasn't paused
                return;
            }

            var gap = this.gaps.last ();
            gap.duration = int64.max (timestamp - gap.timestamp, 0);

            this.changed ();
        }
        */

        /*
        public double get_progress (int64 timestamp = Pomodoro.get_current_time ())
        {
            // TODO

            if (this.duration <= 0) {
                return 0.0;
            }

            return (
                ((double) timestamp) / USEC_PER_SEC - this.timestamp - offset
            ) / this.duration;
        }
        */

        // public abstract TimerState create_next_state (double score,
        //                                               double timestamp);
    }


    /*
    public class DisabledState : TimerState
    {
        construct
        {
            this.name = "null";
        }

        public DisabledState.with_timestamp (double timestamp)
        {
            this.timestamp = timestamp;
        }

        public override TimerState create_next_state (double score,
                                                      double timestamp)
        {
            return new DisabledState.with_timestamp (this.timestamp) as TimerState;
        }

        public override double calculate_progress (double score,
                                                   double timestamp)
        {
            var elapsed = timestamp - this.timestamp;

            return elapsed < TIME_TO_RESET_SCORE ? score : 0.0;
        }
    }

    public class PomodoroState : TimerState
    {
        construct
        {
            this.name = "pomodoro";

            this.duration = (double) PomodoroState.get_default_duration ();
        }

        public PomodoroState.with_timestamp (double timestamp)
        {
            this.timestamp = timestamp;
        }

        //
        // Return duration of a pomodoro from settings
        //
        public static uint get_default_duration ()
        {
            return Pomodoro.get_settings ()
                                      .get_uint ("pomodoro-duration");
        }

        public override TimerState create_next_state (double score,
                                                      double timestamp)
        {
            var score_limit = Pomodoro.get_settings ()
                                      .get_uint ("pomodoros-per-session");

            var min_long_break_score = double.max (score_limit * POMODORO_THRESHOLD,
                                                   score_limit - MISSING_SCORE_THRESHOLD);

            var next_state = score >= min_long_break_score
                    ? new LongBreakState.with_timestamp (timestamp) as TimerState
                    : new ShortBreakState.with_timestamp (timestamp) as TimerState;

            next_state.elapsed = double.max (this.elapsed - this.duration, 0.0);

            return next_state;
        }

        public override double calculate_progress (double score,
                                                   double timestamp)
        {
            var achieved_score = this.duration > 0.0
                    ? double.min (this.elapsed, this.duration) / this.duration
                    : 0.0;

            return this.duration <= MIN_POMODORO_TIME || this.elapsed >= MIN_POMODORO_TIME
                    ? score + achieved_score : score;
        }
    }

    public abstract class BreakState : TimerState
    {
        public override TimerState create_next_state (double score,
                                                      double timestamp)
        {
            return new PomodoroState.with_timestamp (timestamp) as TimerState;
        }
    }

    public class ShortBreakState : BreakState
    {
        construct
        {
            this.name = "short-break";

            this.duration = (double) ShortBreakState.get_default_duration ();
        }

        public ShortBreakState.with_timestamp (double timestamp)
        {
            this.timestamp = timestamp;
        }

        //
        // Return duration of a short break from settings
        //
        public static uint get_default_duration ()
        {
            return Pomodoro.get_settings ()
                                      .get_uint ("short-break-duration");
        }
    }

    public class LongBreakState : BreakState
    {
        construct
        {
            this.name = "long-break";

            this.duration = (double) LongBreakState.get_default_duration ();
        }

        public LongBreakState.with_timestamp (double timestamp)
        {
            this.timestamp = timestamp;
        }

        //
        // Return duration of a long break from settings
        //
        public static uint get_default_duration ()
        {
            return Pomodoro.get_settings ()
                                      .get_uint ("long-break-duration");
        }

        public override double calculate_progress (double score,
                                                   double timestamp)
        {
            var short_break_duration = Pomodoro.get_settings ()
                                               .get_uint ("short-break-duration");
            var long_break_duration = this.duration;

            var min_elapsed =
                    short_break_duration +
                    (long_break_duration - short_break_duration) * SHORT_TO_LONG_BREAK_THRESHOLD;

            return this.elapsed >= min_elapsed || timestamp - this.timestamp >= min_elapsed
                    ? 0.0 : score;
        }
    }
    */
}