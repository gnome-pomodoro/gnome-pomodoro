using GLib;


namespace Pomodoro
{
    public struct SessionTemplate
    {
        public int64 pomodoro_duration;
        public int64 short_break_duration;
        public int64 long_break_duration;
        public uint  cycles;

        public SessionTemplate.with_defaults ()
        {
            var settings = Pomodoro.get_settings ();

            this.pomodoro_duration = Pomodoro.Timestamp.from_seconds_uint (
                settings.get_uint ("pomodoro-duration")
            );
            this.short_break_duration = Pomodoro.Timestamp.from_seconds_uint (
                settings.get_uint ("short-break-duration")
            );
            this.long_break_duration = Pomodoro.Timestamp.from_seconds_uint (
                settings.get_uint ("long-break-duration")
            );
            this.cycles = settings.get_uint ("pomodoros-per-session");
        }

        public bool equals (Pomodoro.SessionTemplate other)
        {
            return this.pomodoro_duration == other.pomodoro_duration &&
                   this.short_break_duration == other.short_break_duration &&
                   this.long_break_duration == other.long_break_duration &&
                   this.cycles == other.cycles;
        }

        // /**
        //  * Calculate ratio between time elapsed on pomodoros compared to breaks.
        //  */
        // public float calculate_pomodoro_break_ratio ()
        // {
        //     var pomodoros_time = this.pomodoro_duration * this.cycles;
        //     var breaks_time = this.short_break_duration * (this.cycles - 1) + this.long_break_duration;
        //
        //     var ratio = breaks_time > 0
        //         ? (double) pomodoros_time / (double) breaks_time
        //         : 0.0;
        //
        //     return (float) ratio;
        // }

        /**
         * Calculate percentage of time allocated for breaks compared to total.
         *
         * Result is in 0 - 100 range.
         */
        public float calculate_break_percentage ()
        {
            var breaks_total = this.short_break_duration * (this.cycles - 1) + this.long_break_duration;
            var total        = this.pomodoro_duration * this.cycles + breaks_total;

            var ratio = total > 0
                ? 100.0 * (double) breaks_total / (double) total
                : 0.0;

            return (float) ratio;
        }

        public GLib.Variant to_variant ()
        {
            var builder = new GLib.VariantBuilder (new GLib.VariantType ("a{s*}"));
            builder.add ("{sv}", "pomodoro_duration", new GLib.Variant.int64 (this.pomodoro_duration));
            builder.add ("{sv}", "short_break_duration", new GLib.Variant.int64 (this.short_break_duration));
            builder.add ("{sv}", "long_break_duration", new GLib.Variant.int64 (this.long_break_duration));
            builder.add ("{sv}", "cycles", new GLib.Variant.uint32 (this.cycles));

            return builder.end ();
        }

        /**
         * Represent template as string.
         *
         * Used in tests.
         */
        public string to_representation ()
        {
            var representation = new GLib.StringBuilder ("SessionTemplate (\n");
            representation.append (@"    pomodoro_duration = $pomodoro_duration,\n");
            representation.append (@"    short_break_duration = $short_break_duration,\n");
            representation.append (@"    long_break_duration = $long_break_duration,\n");
            representation.append (@"    cycles = $cycles\n");
            representation.append (")");

            return representation.str;
        }
    }


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
        UNCOMPLETED = 3
    }


    /**
     * Pomodoro.TimeBlockMeta struct.
     *
     * A `TimeBlock` on its own do not have a session context nor status. These are considered as annotations
     * that should not trigger `TimeBlock.changed` signal, but `Session.changed`.
     *
     * `TimeBlockMeta` is a public representation of `Session.Child` and is read-only.
     */
    public struct TimeBlockMeta
    {
        public Pomodoro.TimeBlockStatus status;
        public uint                     cycle;
        public int64                    intended_duration;
        public bool                     is_long_break;
    }


    /**
     * Pomodoro.Session class.
     *
     * By "session" in this project we mean mostly a streak of pomodoros interleaved with breaks.
     * Session ends with either by a long break or inactivity.
     *
     * Class acts as a container. It merely defines a group of time blocks. It can be used to represent
     * historic sessions.
     */
    public class Session : GLib.Object
    {
        /**
         * A child is a wrapper over a time-block with session-specific context.
         */
        protected class Child
        {
            public Pomodoro.TimeBlock       time_block;
            public Pomodoro.TimeBlockStatus status;
            public uint                     cycle;  // first pomodoro starts with "1""
            public int64                    intended_duration;
            public bool                     is_long_break;
            public ulong                    changed_id;

            public Child (Pomodoro.TimeBlock time_block)
            {
                this.time_block = time_block;
                this.status = Pomodoro.TimeBlockStatus.SCHEDULED;
                this.cycle = 0;
                this.intended_duration = time_block.duration;
                this.is_long_break = false;
                this.changed_id = 0;
            }
        }

        public int64 start_time {
            get {
                return this._start_time;
            }
        }

        public int64 end_time {
            get {
                return this._end_time;
            }
        }

        /**
         * Duration of a session.
         *
         * It will include interruptions / gap times. For real time spent use `calculate_elapsed()`.
         */
        public int64 duration {
            get {
                return this._end_time - this._start_time;
            }
        }

        /**
         * Number of cycles.
         */
        public uint cycles {
            get {
                return this._cycles;
            }
        }

        /**
         * Manually set expiry time.
         *
         * A session can't determine whether it expired on its own in some circumstances.
         * For instance it's not aware when the timer gets paused, so the responsibility of managing expiry
         * passes on to a session manager.
         */
        [CCode(notify = false)]
        public int64 expiry_time {
            get {
                return this._expiry_time;
            }
            set {
                if (this._expiry_time == value) {
                    return;
                }

                this._expiry_time = value;

                this.notify_property ("expiry-time");
            }
        }

        private GLib.List<Child> children;
        private int64            _start_time = Pomodoro.Timestamp.UNDEFINED;
        private int64            _end_time = Pomodoro.Timestamp.UNDEFINED;
        private uint             _cycles = 0;
        private int64            _expiry_time = Pomodoro.Timestamp.UNDEFINED;
        private int              changed_freeze_count = 0;
        private bool             changed_is_pending = false;


        /**
         * Create empty session.
         */
        public Session ()
        {
        }

        /**
         * Create session with according to given template.
         *
         * Doesn't take into account schedule.
         *
         * It's intended to be used in unit tests. In real world, session should be built by `Scheduler`.
         */
        public Session.from_template (Pomodoro.SessionTemplate template,
                                      int64                    timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            this.freeze_changed ();

            var start_time = timestamp;

            this._start_time = start_time;
            this._end_time = start_time;

            for (var cycle = 1; cycle <= template.cycles; cycle++)
            {
                var has_long_break = cycle >= template.cycles;

                var pomodoro_time_block = new Pomodoro.TimeBlock.with_start_time (start_time, Pomodoro.State.POMODORO);
                pomodoro_time_block.duration = template.pomodoro_duration;
                var pomodoro_child = new Child (pomodoro_time_block);
                this.children.append (pomodoro_child);
                this.emit_added (pomodoro_child);

                start_time += pomodoro_time_block.duration;

                var break_time_block = new Pomodoro.TimeBlock.with_start_time (start_time, Pomodoro.State.BREAK);
                break_time_block.duration = has_long_break ? template.long_break_duration : template.short_break_duration;
                var break_child = new Child (break_time_block);
                break_child.is_long_break = has_long_break;
                this.children.append (break_child);
                this.emit_added (break_child);

                start_time += break_time_block.duration;
            }

            this.update_time_range ();
            this.update_cycles ();

            this.thaw_changed ();
        }

        private void update_time_range ()
        {
            unowned Pomodoro.TimeBlock first_time_block = this.get_first_time_block ();
            unowned Pomodoro.TimeBlock last_time_block = this.get_last_time_block ();

            var old_duration = this._end_time - this._start_time;

            var start_time = first_time_block != null
                ? first_time_block.start_time
                : Pomodoro.Timestamp.UNDEFINED;

            var end_time = last_time_block != null
                ? last_time_block.end_time
                : Pomodoro.Timestamp.UNDEFINED;

            if (this._start_time != start_time) {
                this._start_time = start_time;
                this.notify_property ("start-time");
            }

            if (this._end_time != end_time) {
                this._end_time = end_time;
                this.notify_property ("end-time");
            }

            if (this._end_time - this._start_time != old_duration) {
                this.notify_property ("duration");
            }
        }

        private void update_cycles ()
        {
            unowned GLib.List<Child> link = this.children.first ();
            var cycles = 0;

            while (link != null)
            {
                if (link.data.time_block.state == Pomodoro.State.POMODORO &&
                    link.data.status != Pomodoro.TimeBlockStatus.UNCOMPLETED)
                {
                    cycles++;
                }

                link.data.cycle = cycles;
                link = link.next;
            }

            if (this._cycles != cycles) {
                this._cycles = cycles;
                this.notify_property ("cycles");
            }
        }

        private void emit_added (Child child)
        {
            unowned Pomodoro.TimeBlock time_block = child.time_block;

            time_block.session = this;

            if (child.changed_id == 0) {
                child.changed_id = time_block.changed.connect (() => {
                    this.emit_changed ();
                });
            }

            this.added (time_block);
        }

        private void emit_removed (Child child)
        {
            unowned Pomodoro.TimeBlock time_block = child.time_block;

            if (child.changed_id != 0) {
                GLib.SignalHandler.disconnect (time_block, child.changed_id);
            }

            child.changed_id = 0;
            time_block.session = null;

            this.removed (time_block);
        }

        private void emit_changed ()
        {
            if (this.changed_freeze_count > 0) {
                this.changed_is_pending = true;
            }
            else {
                this.changed_is_pending = false;
                this.changed ();
            }
        }

        public void freeze_changed ()
        {
            this.changed_freeze_count++;
        }

        public void thaw_changed ()
        {
            this.changed_freeze_count--;

            if (this.changed_freeze_count == 0 && this.changed_is_pending) {
                this.emit_changed ();
            }
        }


        /*
         * Methods for managing session as a whole
         */

        /**
         * Check whether a session is suitable for reuse after being unused.
         */
        public bool is_expired (int64 timestamp = -1)
        {
            var original_timestamp = timestamp;

            Pomodoro.ensure_timestamp (ref timestamp);

            var result = this._expiry_time >= 0
                ? timestamp >= this._expiry_time
                : false;

            return this._expiry_time >= 0
                ? timestamp >= this._expiry_time
                : false;
        }

        /**
         * Calculate elapsed time excluding gaps/interruptions.
         *
         * Time between blocks is counted like gaps. It doesn't handle time block overlapping,
         * as such case shouldn't happen. Uncompleted time-blocks are included.
         */
        public int64 calculate_elapsed (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            unowned GLib.List<Child> link = this.children.first ();
            int64 elapsed = 0;

            while (link != null)
            {
                elapsed = Pomodoro.Interval.add (elapsed, link.data.time_block.calculate_elapsed (timestamp));
                link = link.next;
            }

            return elapsed;
        }

        /**
         * Calculate elapsed time excluding gaps/interruptions.
         *
         * Time between blocks is counted like gaps. It doesn't handle time block overlapping,
         * as such case shouldn't happen.
         */
        public int64 calculate_remaining (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            unowned GLib.List<Child> link = this.children.first ();
            int64 remaining = 0;

            while (link != null) {
                remaining = Pomodoro.Interval.add (remaining, link.data.time_block.calculate_remaining (timestamp));
                link = link.next;
            }

            return remaining;
        }

        // /**
        //  * Calculate progress - elapsed time compared to intended durations.
        //  *
        //  * This is subjective, as going over intended durations
        //  */
        // public float calculate_progress (int64 timestamp = -1)
        // {
        //     if (Pomodoro.Timestamp.is_undefined (this._end_time)) {
        //         return 0.0f;  // Result won't make sense if session has no `end`.
        //     }
        //
        //     unowned GLib.List<Child> link = this.children.first ();
        //     int64 duration = 0;
        //
        //     while (link != null) {
        //         duration = Pomodoro.Interval.add (duration, link.data.intended_duration);
        //         link = link.next;
        //     }
        //
        //     var progress = duration > 0
        //         ? (double) this.calculate_elapsed (timestamp) / (double) duration
        //         : 0.0;
        //
        //     return (float) progress;
        // }

        /**
         * Estimate energy left.
         *
         * Pomodoros deplete energy, while breaks recover it. The starting point is energy=1.0,
         * it depletes to 0.0 just before a long break. A long break fully restores energy. If you keep skipping breaks
         * or extending your pomodoros you may end up with negative value, leading to have a long break sooner.
         *
         * Energy value is relative to given template.
         */
        // TODO: move this to LenientScheduler
        public float calculate_energy (Pomodoro.SessionTemplate session_template,
                                       int64                    timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            var pomodoro_duration    = (double) session_template.pomodoro_duration;
            var short_break_duration = (double) session_template.short_break_duration;
            var long_break_duration  = (double) session_template.long_break_duration;
            var cycles               = (double) session_template.cycles;

            var pomodoro_depletion   = cycles > 1.0 ? - cycles / (cycles - 1.0) : -1.0;
            var pomodoro_slope       = pomodoro_depletion / (pomodoro_duration * cycles);
            var short_break_slope    = - pomodoro_depletion / short_break_duration * (cycles - 1.0);
            var long_break_slope     = 1.0 / long_break_duration;
            var break_slope          = (long_break_slope - short_break_slope) / (long_break_duration - short_break_duration);
            var break_offset         = short_break_slope - break_slope * short_break_duration;

            unowned GLib.List<Child> link = this.children.first ();
            var energy = 1.0;

            while (link != null)
            {
                var time_block = link.data.time_block;
                var elapsed    = time_block.calculate_elapsed (timestamp);

                switch (time_block.state)
                {
                    case Pomodoro.State.POMODORO:
                        energy += pomodoro_slope * elapsed;
                        break;

                    case Pomodoro.State.BREAK:
                        energy += (break_slope * elapsed + break_offset) * elapsed;
                        break;

                    default:
                        assert_not_reached ();
                }

                link = link.next;
            }

            return (float) energy;
        }

        /**
         * Calculate ratio between time elapsed on pomodoros compared to breaks.
         *
         * The intention here is to have a quantitative comparison between pomodoros and breaks.
         * As an example the classic 25-5-15 session has 100 minutes of work and 30 minutes of break,
         * which translates to 3.33 : 1 ratio.
         *
         * Issue with this metric is it will return infinity at the start of session.
         */
        // public float calculate_pomodoro_break_ratio ()
        // {
        // }

        /**
         * Calculate ratio between time elapsed on breaks and total elapsed time.
         *
         * The intention here is to have a percentage how much of the time is spent on breaks.
         */
        public float calculate_break_ratio (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            unowned GLib.List<Child> link = this.children.first ();
            int64 pomodoros_total = 0;
            int64 breaks_total = 0;

            while (link != null)
            {
                var time_block = link.data.time_block;

                switch (time_block.state)
                {
                    case Pomodoro.State.POMODORO:
                        pomodoros_total = Pomodoro.Interval.add (pomodoros_total,
                                                                 time_block.calculate_elapsed (timestamp));
                        break;

                    case Pomodoro.State.BREAK:
                        breaks_total = Pomodoro.Interval.add (breaks_total,
                                                              time_block.calculate_elapsed (timestamp));
                        break;

                    default:
                        assert_not_reached ();
                }

                link = link.next;
            }

            var total = Pomodoro.Interval.add (pomodoros_total, breaks_total);
            var ratio = total > 0
                ? (double) breaks_total / (double) total
                : 0.0;

            return (float) ratio;
        }


        /*
         * Methods for container operations
         */


        private unowned GLib.List<Child>? find_link_by_time_block (Pomodoro.TimeBlock? time_block)
        {
            unowned GLib.List<Child> link = this.children.first ();

            while (link != null)
            {
                if (link.data.time_block == time_block) {
                    return link;
                }

                link = link.next;
            }

            return null;
        }

        /**
         * Remove links following
         */
        private void remove_link (GLib.List<Child>? link)
        {
            if (link == null) {
                return;
            }

            var child = link.data;
            this.children.delete_link (link);

            this.emit_removed (child);
        }

        private void remove_links_after (GLib.List<Child>? link)
        {
            if (link == null) {
                return;
            }

            if (link.next != null) {
                this.remove_links_after (link.next);
                this.remove_link (link.next);
            }
        }

        /**
         * Add the time-block and align it with the last block.
         */
        public void append (Pomodoro.TimeBlock time_block)
                            requires (time_block.session == null)
        {
            var last_time_block = this.get_last_time_block ();

            if (last_time_block != null) {
                time_block.move_to (last_time_block.end_time);
            }

            var child = new Child (time_block);
            this.children.append (child);

            this.emit_added (child);
        }

        /**
         * Add the time-block as first and align it to first time-block.
         */
        public void prepend (Pomodoro.TimeBlock time_block)
                             requires (time_block.session == null)
        {
            var first_time_block = this.get_first_time_block ();

            if (first_time_block != null) {
                var new_start_time = Pomodoro.Timestamp.subtract (first_time_block.start_time,
                                                                  time_block.duration);
                time_block.move_to (new_start_time);
            }

            var child = new Child (time_block);
            this.children.prepend (child);

            this.emit_added (child);
        }

        /**
         * Insert the time-block before given time-block.
         */
        public void insert_before (Pomodoro.TimeBlock time_block,
                                   Pomodoro.TimeBlock sibling)
                                   requires (time_block.session == null)
                                   requires (sibling.session == this)
        {
            unowned GLib.List<Child> sibling_link = this.find_link_by_time_block (sibling);

            // if (sibling_link)
            //     time_block.move_to (sibling.start_time);

            var child = new Child (time_block);
            this.children.insert_before (sibling_link, child);

            this.emit_added (child);
        }

        /**
         * Insert the time-block after given time-block and align it to the sibling.
         */
        public void insert_after (Pomodoro.TimeBlock time_block,
                                  Pomodoro.TimeBlock sibling)
                                  requires (time_block.session == null)
                                  requires (sibling.session == this)
        {
            unowned GLib.List<Child> sibling_link = this.find_link_by_time_block (sibling);

            if (sibling_link.next == null) {
                this.append (time_block);
            }
            else {
                time_block.move_to (sibling.end_time);

                var child = new Child (time_block);
                this.children.insert_before (sibling_link.next, child);

                this.emit_added (child);
            }
        }

        public void remove (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);

            if (link == null) {
                GLib.warning ("Ignoring `Session.remove()`. Time-block does not belong to the session.");
                return;
            }

            var child = link.data;
            this.children.remove_link (link);

            this.emit_removed (child);
        }

        public void remove_before (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);

            if (link == null) {
                GLib.warning ("Ignoring `Session.remove_before()`. Time-block does not belong to the session.");
                return;
            }

            if (link.prev == null) {
                return;
            }

            this.freeze_changed ();

            while (link.prev != null)
            {
                var prev_child = link.prev.data;
                this.children.remove_link (link.prev);
                this.emit_removed (prev_child);
            }

            this.thaw_changed ();
        }

        public void remove_after (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);

            if (link == null) {
                GLib.warning ("Ignoring `Session.remove_after()`. Time-block does not belong to the session.");
                return;
            }

            if (link.next == null) {
                return;
            }

            this.freeze_changed ();

            while (link.next != null)
            {
                var next_child = link.next.data;
                this.children.remove_link (link.next);
                this.emit_removed (next_child);
            }

            this.thaw_changed ();
        }

        public unowned Pomodoro.TimeBlock? get_first_time_block ()
        {
            unowned GLib.List<Child> first_link = this.children.first ();

            return first_link != null ? first_link.data.time_block : null;
        }

        public unowned Pomodoro.TimeBlock? get_last_time_block ()
        {
            unowned GLib.List<Child> last_link = this.children.last ();

            return last_link != null ? last_link.data.time_block : null;
        }

        public unowned Pomodoro.TimeBlock? get_nth_time_block (uint index)
        {
            unowned Child child = this.children.nth_data (index);

            return child != null ? child.time_block : null;
        }

        public unowned Pomodoro.TimeBlock? get_previous_time_block (Pomodoro.TimeBlock? time_block)
        {
            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);

            if (link == null || link.prev == null) {
                return null;
            }

            return link.prev.data.time_block;
        }

        public unowned Pomodoro.TimeBlock? get_next_time_block (Pomodoro.TimeBlock? time_block)
        {
            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);

            if (link == null || link.next == null) {
                return null;
            }

            return link.next.data.time_block;
        }

        public int index (Pomodoro.TimeBlock time_block)
        {
            var index = -1;

            unowned GLib.List<Child> link = this.children.first ();

            while (link != null)
            {
                index++;

                if (link.data.time_block == time_block) {
                    return index;
                }

                link = link.next;
            }

            return index;
        }

        public bool contains (Pomodoro.TimeBlock time_block)
        {
            if (time_block.session != this) {
                return false;
            }

            unowned List<Child> link = this.find_link_by_time_block (time_block);

            return link != null;
        }

        public void @foreach (GLib.Func<unowned Pomodoro.TimeBlock> func)
        {
            unowned GLib.List<Child> link = this.children.first ();

            while (link != null)
            {
                func (link.data.time_block);

                link = link.next;
            }
        }

        // internal void @foreach_meta (GLib.Func<Pomodoro.TimeBlockMeta?> func)
        // {
        //     unowned GLib.List<Child> link = this.children.first ();
        //
        //     while (link != null)
        //     {
        //         func (this.get_child_meta (link.data));
        //
        //         link = link.next;
        //     }
        // }

        public void move_by (int64 offset)
        {
            var logged_warnining = false;

            this.freeze_changed ();

            this.children.@foreach ((child) => {
                if (!logged_warnining && child.status > Pomodoro.TimeBlockStatus.IN_PROGRESS) {
                    GLib.debug ("Moving a time-blocks that have been completed.");
                    logged_warnining = true;
                }

                child.time_block.move_by (offset);
            });

            this.thaw_changed ();
        }

        /**
         * Move all time blocks to a given timestamp, even started / completed.
         *
         * You manually modify time blocks. Consider calling .reschedule() .
         */
        public void move_to (int64 timestamp)
        {
            unowned GLib.List<Child> link = this.children.first ();

            if (link != null) {
                this.move_by (Pomodoro.Timestamp.subtract (timestamp, link.data.time_block.start_time));
            }
        }


        /*
         * Methods for managing time-blocks status
         */

        /**
         * Expose internal data via read-only `TimeBlockMeta` struct.
         */
        private inline Pomodoro.TimeBlockMeta get_child_meta (Child child)
        {
            return TimeBlockMeta () {
                status = child.status,
                cycle = child.cycle,
                intended_duration = child.intended_duration,
                is_long_break = child.is_long_break
            };
        }

        /**
         * Expose internal data via read-only `TimeBlockMeta` struct.
         */
        public Pomodoro.TimeBlockMeta get_time_block_meta (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);

            if (link == null) {
                return Pomodoro.TimeBlockMeta ();
            }

            return this.get_child_meta (link.data);
        }

        public Pomodoro.TimeBlockStatus get_time_block_status (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);

            if (link == null) {
                return -1;
            }

            return link.data.status;
        }

        public void set_time_block_status (Pomodoro.TimeBlock       time_block,
                                           Pomodoro.TimeBlockStatus status)
        {
            unowned GLib.List<Child> link = this.children.first ();
            var changed = false;

            if (!this.contains (time_block)) {
                return;
            }

            while (link != null)
            {
                if (link.data.time_block == time_block) {
                    if (link.data.status != status) {
                        link.data.status = status;
                        changed = true;
                    }
                    break;
                }

                if (link.data.status <= Pomodoro.TimeBlockStatus.IN_PROGRESS) {
                    link.data.status = Pomodoro.TimeBlockStatus.UNCOMPLETED;
                    changed = true;
                }

                link = link.next;
            }

            if (changed) {
                this.emit_changed ();
            }
        }

        private void build_scheduler_context (Pomodoro.Scheduler            scheduler,
                                              int64                         timestamp,
                                              out Pomodoro.SchedulerContext context,
                                              out unowned GLib.List<Child>  first_scheduled_link)
        {
            unowned GLib.List<Child> link = this.children.first ();

            context = Pomodoro.SchedulerContext.initial (timestamp);
            first_scheduled_link = null;

            while (link != null && !context.is_session_completed)
            {
                var time_block = link.data.time_block;
                var time_block_meta = this.get_child_meta (link.data);

                if (time_block_meta.status > Pomodoro.TimeBlockStatus.SCHEDULED) {
                    scheduler.resolve_context (time_block, time_block_meta, ref context);
                }
                else {
                    first_scheduled_link = link;
                    break;
                }

                link = link.next;
            }
        }

        internal void remove_scheduled ()
        {
            unowned GLib.List<Child> link = this.children.first ();

            this.freeze_changed ();

            while (link != null)
            {
                if (link.data.status == Pomodoro.TimeBlockStatus.SCHEDULED) {
                    this.remove_links_after (link);
                    this.remove_link (link);

                    this.update_time_range ();
                    this.update_cycles ();
                    break;
                }

                link = link.next;
            }

            this.thaw_changed ();
        }

        /**
         * Reschedule time-blocks if needed.
         *
         * It will affect time-blocks not marked as completed or uncompleted. May add/remove time-blocks.
         */
        internal void reschedule (Pomodoro.Scheduler scheduler,
                                  int64              timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            Pomodoro.SchedulerContext context;
            Pomodoro.TimeBlock time_block;
            Pomodoro.TimeBlockMeta time_block_meta;
            Child child;
            unowned GLib.List<Child> link;
            var n = 1;

            this.build_scheduler_context (scheduler, timestamp, out context, out link);
            // GLib.debug ("build_scheduler_context() context = %s", context.to_representation ());

            var is_populating = link == null;

            this.freeze_changed ();

            while (true)
            {
                // GLib.debug (
                //     "cycle = %u, state = %s, is_cycle_completed = %s, needs_long_break = %s",
                //     context.cycle,
                //     context.state.to_string (),
                //     context.is_cycle_completed ? "true" : "false",
                //     context.needs_long_break ? "true" : "false"
                // );

                time_block = scheduler.resolve_time_block (context);

                if (time_block == null) {
                    // GLib.debug ("reschedule done");
                    break;
                }

                if (n++ >= Pomodoro.Scheduler.MAX_ITERATIONS) {
                    GLib.error ("`Session.reschedule()` reached iterations limit.");
                    break;
                }

                var existing_child = link != null ? link.data : null;
                if (existing_child != null && existing_child.time_block.state == time_block.state)
                {
                    // Update existing time-block.
                    existing_child.time_block.set_time_range (time_block.start_time, time_block.end_time);
                    existing_child.intended_duration = time_block.duration;

                    child = existing_child;
                    time_block = existing_child.time_block;
                    link = link.next;
                }
                else {
                    // Add new time-block.
                    child = new Child (time_block);
                    child.is_long_break = time_block.state == Pomodoro.State.BREAK && context.needs_long_break;

                    if (existing_child != null) {
                        this.children.insert_before (link, child);
                    }
                    else {
                        this.children.append (child);
                    }

                    this.emit_added (child);
                }

                time_block_meta = this.get_child_meta (child);
                scheduler.resolve_context (time_block, time_block_meta, ref context);
            }

            this.remove_links_after (link);
            this.remove_link (link);

            this.update_time_range ();
            this.update_cycles ();

            this.thaw_changed ();

            if (is_populating) {
                scheduler.populated_session (this);
            }
            else {
                scheduler.rescheduled_session (this);
            }
        }

        /*
         * Signals
         */

        [Signal (run = "last")]
        public signal void added (Pomodoro.TimeBlock time_block)
        {
            this.emit_changed ();
        }

        [Signal (run = "last")]
        public signal void removed (Pomodoro.TimeBlock time_block)
        {
            this.emit_changed ();
        }

        [Signal (run = "first")]
        public signal void changed ()
        {
            assert (this.changed_freeze_count == 0);  // TODO: remove

            this.update_cycles ();
            this.update_time_range ();
        }
    }
}
