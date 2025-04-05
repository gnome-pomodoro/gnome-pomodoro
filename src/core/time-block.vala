using GLib;


namespace Pomodoro
{
    /**
     * Pomodoro.TimeBlockStatus enum.
     *
     * A time-block status is managed at a session-level by `SessionManager`.
     */
    public enum TimeBlockStatus
    {
        SCHEDULED = 0,
        IN_PROGRESS = 1,
        COMPLETED = 2,
        UNCOMPLETED = 3;

        public string to_string ()
        {
            switch (this)
            {
                case SCHEDULED:
                    return "scheduled";

                case IN_PROGRESS:
                    return "in-progress";

                case COMPLETED:
                    return "completed";

                case UNCOMPLETED:
                    return "uncompleted";

                default:
                    assert_not_reached ();
            }
        }
    }


    /**
     * Pomodoro.TimeBlockMeta struct.
     *
     * Some properties of the `TimeBlock` are purely external and should not trigger
     * `TimeBlock.changed` signal. `TimeBlockMeta` is a convenience structure for read-only.
     */
    public struct TimeBlockMeta
    {
        public Pomodoro.TimeBlockStatus status;
        public int64                    intended_duration;
        public double                   weight;
        public int64                    completion_time;
        public bool                     is_extra;
    }


    public interface Schedulable : GLib.Object
    {
        public abstract int64 start_time { get; set; }
        public abstract int64 end_time { get; set; }
        public abstract int64 duration { get; set; }

        public bool has_started (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            var start_time = this.start_time;

            if (Pomodoro.Timestamp.is_undefined (start_time)) {
                return true;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            return timestamp >= start_time;
        }

        public bool has_ended (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            var end_time = this.end_time;

            if (Pomodoro.Timestamp.is_undefined (end_time)) {
                return false;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            return timestamp > end_time;
        }

        public static int compare (Pomodoro.Schedulable a,
                                   Pomodoro.Schedulable b)
        {
            return (int) (a.start_time > b.start_time) - (int) (a.start_time < b.start_time);
        }

        public abstract void set_time_range (int64 start_time,
                                             int64 end_time);

        public abstract void move_by (int64 offset);

        public abstract void move_to (int64 start_time);
    }


    public class TimeBlock : GLib.InitiallyUnowned, Pomodoro.Schedulable
    {
        public Pomodoro.State state {
            get {
                return this._state;
            }
            construct {
                this._state = value;
            }
        }
        public weak Pomodoro.Session session { get; set; }

        [CCode(notify = false)]
        public int64 start_time {
            get {
                return this._start_time;
            }
            set {
                if (this._start_time == value) {
                    return;
                }

                if (value < this._end_time || Pomodoro.Timestamp.is_undefined (this._end_time)) {
                    this.set_time_range (value, this._end_time);
                }
                else {
                    // TODO: log warning that change of `start-time` will affect `end-time`
                    this.set_time_range (value, value);
                }
            }
        }

        [CCode(notify = false)]
        public int64 end_time {
            get {
                return this._end_time;
            }
            set {
                if (this._end_time == value) {
                    return;
                }

                if (value >= this._start_time || Pomodoro.Timestamp.is_undefined (this._start_time)) {
                    this.set_time_range (this._start_time, value);
                }
                else {
                    // TODO: log warning that change of `end-time` will affect `start-time`
                    this.set_time_range (value, value);
                }
            }
        }

        /**
         * `duration` of a time block, including gaps
         */
        [CCode(notify = false)]
        public int64 duration {
            get {
                return Pomodoro.Timestamp.subtract (this._end_time, this._start_time);
            }
            set {
                if (Pomodoro.Timestamp.is_defined (this._start_time)) {
                    this.set_time_range (this._start_time,
                                         Pomodoro.Timestamp.add_interval (this._start_time, value));
                }
                else {
                    GLib.warning ("Can't change time-block duration without a defined start-time.");
                }
            }
        }

        internal ulong                    version = 0;
        internal Pomodoro.TimeBlockEntry? entry = null;

        private GLib.List<Pomodoro.Gap>   gaps = null;
        private int64                     _start_time = Pomodoro.Timestamp.UNDEFINED;
        private int64                     _end_time = Pomodoro.Timestamp.UNDEFINED;
        private Pomodoro.State            _state = Pomodoro.State.STOPPED;
        private int                       changed_freeze_count = 0;
        private bool                      changed_is_pending = false;
        private Pomodoro.TimeBlockMeta    meta;

        construct
        {
            this.meta = Pomodoro.TimeBlockMeta() {
                status = Pomodoro.TimeBlockStatus.SCHEDULED,
                intended_duration = 0,
                weight = double.NAN,
                completion_time = Pomodoro.Timestamp.UNDEFINED,
                is_extra = false,
            };
        }

        public TimeBlock (Pomodoro.State  state = Pomodoro.State.STOPPED)
        {
            GLib.Object (
                state: state
            );
        }

        public TimeBlock.with_start_time (int64           start_time,
                                          Pomodoro.State  state = Pomodoro.State.STOPPED)
        {
            GLib.Object (
                state: state
            );

            this.set_time_range (
                start_time,
                Pomodoro.Timestamp.add_interval (start_time, state.get_default_duration ())
            );
        }

        private void emit_changed ()
        {
            this.version++;

            if (this.changed_freeze_count > 0) {
                this.changed_is_pending = true;
            }
            else {
                this.changed_is_pending = false;
                this.changed ();
            }
        }

        /**
         * Increases the freeze count on this.
         */
        public void freeze_changed ()
        {
            this.changed_freeze_count++;
        }

        /**
         * Decrease the freeze count on this.
         */
        public void thaw_changed ()
        {
            this.changed_freeze_count--;

            if (this.changed_freeze_count == 0) {
                this.emit_changed ();
            }
        }

        public void set_time_range (int64 start_time,
                                    int64 end_time)
        {
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
                this.emit_changed ();
            }
        }

        public void move_by (int64 offset)
        {
            // this.freeze_changed ();  // TODO

            this.gaps.@foreach ((gap) => gap.move_by (offset));

            var start_time = Pomodoro.Timestamp.is_defined (this._start_time)
                ? Pomodoro.Timestamp.add_interval (this._start_time, offset)
                : Pomodoro.Timestamp.UNDEFINED;
            var end_time = Pomodoro.Timestamp.is_defined (this._end_time)
                ? Pomodoro.Timestamp.add_interval (this._end_time, offset)
                : Pomodoro.Timestamp.UNDEFINED;

            this.set_time_range (start_time, end_time);
            // this.thaw_changed ();
        }

        public void move_to (int64 start_time)
        {
            if (Pomodoro.Timestamp.is_undefined (this._start_time) &&
                Pomodoro.Timestamp.is_undefined (this._end_time))
            {
                if (!this.gaps.is_empty ()) {
                    GLib.warning ("Unable to move time-block gaps. Time-block start-time is undefined.");
                }

                this.set_time_range (start_time, this._end_time);
                return;
            }

            if (Pomodoro.Timestamp.is_undefined (this._start_time)) {
                GLib.warning ("Unable to move time-block. Time-block start-time is undefined.");
                return;
            }

            this.move_by (Pomodoro.Timestamp.subtract (start_time, this._start_time));
        }

        /**
         * Calculate elapsed time excluding gaps/interruptions.
         */
        public int64 calculate_elapsed (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            if (Pomodoro.Timestamp.is_undefined (this._start_time)) {
                return 0;  // Result won't make sense if block has no `start`.
            }

            if (this._start_time >= timestamp || this._start_time >= this._end_time) {
                return 0;
            }

            var range_start = this._start_time;
            var range_end   = Pomodoro.Timestamp.is_defined (this._end_time)
                ? int64.min (this._end_time, timestamp)
                : timestamp;
            var elapsed     = Pomodoro.Timestamp.subtract (range_end, range_start);

            this.gaps.@foreach ((gap) => {
                if (Pomodoro.Timestamp.is_undefined (gap.end_time)) {
                    range_start = range_end;
                    return;
                }

                if (gap.end_time <= gap.start_time) {
                    return;
                }

                elapsed = Pomodoro.Interval.subtract (
                    elapsed,
                    Pomodoro.Timestamp.subtract (
                        gap.end_time.clamp (range_start, range_end),
                        gap.start_time.clamp (range_start, range_end)
                    )
                );
                range_start = gap.end_time.clamp (range_start, range_end);
            });

            return elapsed;
        }

        /**
         * Calculate remaining time excluding gaps/interruptions.
         */
        public int64 calculate_remaining (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            if (Pomodoro.Timestamp.is_undefined (this._end_time)) {
                return 0;  // Result won't make sense if block has no `start`.
            }

            if (timestamp >= this._end_time || this._start_time >= this._end_time) {
                return 0;
            }

            var range_start = int64.max (this._start_time, timestamp);
            var range_end   = this._end_time;
            var remaining   = Pomodoro.Timestamp.subtract (range_end, range_start);

            this.gaps.@foreach ((gap) => {
                if (gap.end_time <= gap.start_time) {
                    return;
                }

                remaining = Pomodoro.Interval.subtract (
                    remaining,
                    Pomodoro.Timestamp.subtract (
                        gap.end_time.clamp (range_start, range_end),
                        gap.start_time.clamp (range_start, range_end)
                    )
                );
                range_start = gap.end_time.clamp (range_start, range_end);
            });

            return remaining;
        }

        /**
         * Calculate progress - elapsed time compared to completion-time.
         */
        public double calculate_progress (int64 timestamp)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            if (Pomodoro.Timestamp.is_undefined (this._start_time) ||
                Pomodoro.Timestamp.is_undefined (this._end_time))
            {
                return 0.0;  // Result won't make sense if block has no `start`.
            }

            if (this._start_time >= timestamp || this._start_time >= this._end_time) {
                return 0.0;
            }

            var range_start = this._start_time;
            var range_end   = Pomodoro.Timestamp.is_defined (this.meta.completion_time)
                ? this.meta.completion_time
                : this._end_time;
            var duration = Pomodoro.Timestamp.subtract (range_end, range_start);
            var elapsed  = Pomodoro.Timestamp.subtract (timestamp, range_start);

            this.gaps.@foreach (
                (gap) => {
                    if (Pomodoro.Timestamp.is_undefined (gap.end_time)) {
                        elapsed = Pomodoro.Interval.subtract (
                            elapsed,
                            Pomodoro.Timestamp.subtract (
                                timestamp,
                                gap.start_time.clamp (range_start, timestamp)
                            )
                        );
                        range_start = range_end;
                        return;
                    }

                    if (gap.end_time <= gap.start_time) {
                        return;
                    }

                    duration = Pomodoro.Interval.subtract (
                        duration,
                        Pomodoro.Timestamp.subtract (
                            gap.end_time.clamp (range_start, range_end),
                            gap.start_time.clamp (range_start, range_end)
                        )
                    );
                    elapsed = Pomodoro.Interval.subtract (
                        elapsed,
                        Pomodoro.Timestamp.subtract (
                            gap.end_time.clamp (range_start, timestamp),
                            gap.start_time.clamp (range_start, timestamp)
                        )
                    );
                    range_start = gap.end_time.clamp (range_start, range_end);
                }
            );

            return duration > 0 ? (double) elapsed / (double) duration : 0.0;
        }

        private void on_gap_changed (Pomodoro.Gap gap)
        {
            this.emit_changed ();
        }

        public void add_gap (Pomodoro.Gap gap)
        {
            if (gap.time_block == this) {
                return;
            }

            if (gap.time_block != null) {
                gap.time_block.remove_gap (gap);
            }

            gap.time_block = this;
            gap.changed.connect (this.on_gap_changed);

            this.gaps.insert_sorted (gap, Pomodoro.Schedulable.compare);

            this.emit_changed ();
        }

        public void remove_gap (Pomodoro.Gap gap)
        {
            if (gap.time_block != this) {
                return;
            }

            gap.changed.disconnect (this.on_gap_changed);
            gap.time_block = null;

            this.gaps.remove (gap);

            this.emit_changed ();
        }

        public Pomodoro.Gap? get_last_gap ()
        {
            unowned GLib.List<Pomodoro.Gap> link = this.gaps.last ();

            return link != null ? link.data : null;
        }

        public void foreach_gap (GLib.Func<Pomodoro.Gap> func)
        {
            this.gaps.@foreach (func);
        }

        private void remove_link (GLib.List<Pomodoro.Gap>? link)
        {
            if (link == null) {
                return;
            }

            link.data = null;
            this.gaps.delete_link (link);
        }

        /**
         * Cleanup gaps.
         *
         * Handling of overlapped gaps is tailored for the rewind action.
         */
        public void normalize_gaps (int64 timestamp)
        {
            unowned GLib.List<Pomodoro.Gap> link = this.gaps.last ();
            unowned GLib.List<Pomodoro.Gap> tmp;
            var changed = false;

            this.freeze_changed ();

            while (link != null)
            {
                // Handle invalid gaps.
                if (Pomodoro.Timestamp.is_defined (link.data.end_time) && link.data.end_time < link.data.start_time ||
                    Pomodoro.Timestamp.is_undefined (link.data.start_time))
                {
                    GLib.debug ("normalize_gaps: removing invalid gap");
                    tmp = link.prev;
                    this.remove_link (link);
                    link = tmp;
                    changed = true;
                    continue;
                }

                // Handle overlapping gaps.
                if (link.next != null && link.data.end_time >= link.next.data.start_time)
                {
                    var overlap = link.data.end_time - link.next.data.start_time;

                    if (Pomodoro.Timestamp.is_undefined (link.next.data.end_time)) {
                        link.data.move_by (-overlap);
                        link = link.prev;
                        changed = overlap > 0 ? true : changed;
                    }
                    else {
                        tmp = link.prev;
                        link.next.data.start_time = Pomodoro.Timestamp.subtract_interval (link.data.start_time, overlap);
                        this.remove_link (link);
                        link = tmp;
                        changed = true;
                    }

                    continue;
                }

                link = link.prev;
            }

            if (changed) {
                this.emit_changed ();
            }

            this.thaw_changed ();
        }

        /**
         * We don't allow changing of `TimeBlock.state` after the time-block changes status to in-progress.
         * However, it's allowed to change state of a scheduled time-block.
         */
        internal void set_state_internal (Pomodoro.State state)
        {
            this._state = state;

            this.notify_property ("state");
            this.emit_changed ();
        }


        /*
         * Metadata
         */

        public Pomodoro.TimeBlockMeta get_meta ()
        {
            return this.meta;
        }

        public void set_meta (Pomodoro.TimeBlockMeta meta)
        {
            this.meta = meta;
        }

        /**
         * Convenience alias for `Session.get_time_block_status(...)`
         */
        public Pomodoro.TimeBlockStatus get_status ()
        {
            return this.meta.status;
        }

        /**
         * Convenience alias for `Session.set_time_block_status(...)`
         */
        public void set_status (Pomodoro.TimeBlockStatus status)
        {
            this.meta.status = status;
        }

        public int64 get_intended_duration ()
        {
            return this.meta.intended_duration;
        }

        public void set_intended_duration (int64 intended_duration)
        {
            this.meta.intended_duration = intended_duration;
        }

        public double get_weight ()
        {
            return this.meta.weight;
        }

        public void set_weight (double weight)
        {
            this.meta.weight = weight;
        }

        public int64 get_completion_time ()
        {
            return this.meta.completion_time;
        }

        public void set_completion_time (int64 completion_time)
        {
            this.meta.completion_time = completion_time;
        }

        public bool get_is_extra ()
        {
            return this.meta.is_extra;
        }

        public void set_is_extra (bool is_extra)
        {
            this.meta.is_extra = is_extra;
        }


        /*
         * Database
         */

        internal bool should_create_entry ()
        {
            // XXX: we may want to save SCHEDULED time-blocks in future, e.g. when setting up
            //      a custom session / warm-up.
            return this.meta.status != Pomodoro.TimeBlockStatus.SCHEDULED &&
                   Pomodoro.Timestamp.is_defined (this.start_time);
        }

        internal bool should_update_entry ()
        {
            if (this.entry == null || this.entry.id == 0) {
                return true;
            }

            return this.entry.version != this.version ||
                   this.entry.status != this.meta.status.to_string ();
        }

        internal Pomodoro.TimeBlockEntry create_or_update_entry ()
                                                                 requires (this.session != null)
        {
            if (this.entry == null)
            {
                this.entry = new Pomodoro.TimeBlockEntry ();
                this.entry.repository = Pomodoro.Database.get_repository ();

                this.session.entry.bind_property ("id",
                                                  this.entry,
                                                  "session-id",
                                                  GLib.BindingFlags.SYNC_CREATE);
            }

            this.entry.start_time = this.start_time;
            this.entry.end_time = this.end_time;
            this.entry.state = this.state.to_string ();
            this.entry.status = this.meta.status.to_string ();
            this.entry.intended_duration = this.meta.intended_duration;
            this.entry.version = this.version;

            return this.entry;
        }

        internal void unset_entry ()
        {
            unowned GLib.List<Pomodoro.Gap> link = this.gaps.first ();

            while (link != null)
            {
                link.data.unset_entry ();
                link = link.next;
            }

            this.entry = null;
        }


        /*
         * Signals
         */

        public signal void changed ();
    }
}
