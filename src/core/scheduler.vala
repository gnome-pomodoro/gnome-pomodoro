/*
 * Copyright (c) 2023-2025 gnome-pomodoro contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Pomodoro
{
    /**
     * Structure describing current cycle or energy level within a session.
     *
     * For simplicity, the same structure is shared between all schedulers.
     */
    public struct SchedulerContext
    {
        public int64          timestamp;
        public Pomodoro.State state;
        public bool           is_session_completed;
        public bool           needs_long_break;
        public double         score;

        public SchedulerContext ()
        {
            this.timestamp = Pomodoro.Timestamp.UNDEFINED;
            this.state = Pomodoro.State.STOPPED;
            this.is_session_completed = false;
            this.needs_long_break = false;
            this.score = 0.0;
        }

        public static Pomodoro.SchedulerContext initial (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            return SchedulerContext () {
                timestamp = timestamp,
            };
        }

        /**
         * Make context copy
         *
         * This function is unnecessary. Structs in vala are copied by default. It's kept
         * to bring more clarity to our code.
         */
        public Pomodoro.SchedulerContext copy ()
        {
            return this;
        }

         /**
         * Convert structure to Variant.
         *
         * Used in tests.
         */
        public GLib.Variant to_variant ()
        {
            var builder = new GLib.VariantBuilder (new GLib.VariantType ("a{s*}"));
            builder.add ("{sv}", "timestamp", new GLib.Variant.int64 (this.timestamp));
            builder.add ("{sv}", "state", new GLib.Variant.string (this.state.to_string ()));
            builder.add ("{sv}", "is_session_completed", new GLib.Variant.boolean (this.is_session_completed));
            builder.add ("{sv}", "needs_long_break", new GLib.Variant.boolean (this.needs_long_break));
            builder.add ("{sv}", "score", new GLib.Variant.double (this.score));

            return builder.end ();
        }

        /**
         * Represent context as string.
         *
         * Used in tests.
         */
        public string to_representation ()
        {
            var state_string = this.state.to_string ();

            var representation = new GLib.StringBuilder ("SchedulerContext (\n");
            representation.append (@"    timestamp = $timestamp,\n");
            representation.append (@"    state = $state_string,\n");
            representation.append (@"    is_session_completed = $is_session_completed,\n");
            representation.append (@"    needs_long_break = $needs_long_break,\n");
            representation.append (@"    score = $score,\n");
            representation.append (")");

            return representation.str;
        }
    }


    /**
     * Scheduler helps in determining next time-block in a session.
     *
     * It works in a step-wise fashion. It tries to make a best guess according to `SchedulerContext`.
     *
     * In future we would like to align time-blocks to calendar events and working time.
     */
    public abstract class Scheduler : GLib.Object
    {
        /**
         * A progress threshold that qualifies time-block to be marked as completed.
         *
         * When set to 0.5 it would count two cycles per completed pomodoro. Reasonable values are > 0.667.
         */
        protected const double COMPLETION_THRESHOLD = 0.8;

        /**
         * Max number of time-blocks scheduled in case scheduler enters into an infinite loop.
         */
        private const uint MAX_ITERATIONS = 100;


        [CCode (notify = false)]
        public Pomodoro.SessionTemplate session_template {
            get {
                return this._session_template;
            }
            set {
                if (this._session_template.equals (value)) {
                    return;
                }

                this._session_template = value;

                this.notify_property ("session-template");
            }
        }

        private Pomodoro.SessionTemplate _session_template;


        public int64 calculate_time_block_completion_time (Pomodoro.TimeBlock time_block)
        {
            if (Pomodoro.Timestamp.is_undefined (time_block.start_time)) {
                GLib.debug ("calculate_time_block_completion_time: `start_time` is not set");
                return Pomodoro.Timestamp.UNDEFINED;
            }

            var intended_duration = time_block.get_intended_duration ();

            if (intended_duration == 0) {
                intended_duration = this._session_template.get_duration (time_block.state);
            }

            var remaining_elapsed = (int64) Math.floor (intended_duration * COMPLETION_THRESHOLD);
            var reference_time = time_block.start_time;

            time_block.foreach_gap (
                (gap) => {
                    if (Pomodoro.Timestamp.is_undefined (gap.end_time)) {
                        return;
                    }

                    var tmp = remaining_elapsed - (gap.start_time - reference_time);

                    if (tmp > 0) {
                        remaining_elapsed = tmp;
                        reference_time = gap.end_time;
                    }
                }
            );

            return reference_time + remaining_elapsed;
        }

        public abstract double calculate_time_block_score (Pomodoro.TimeBlock time_block,
                                                           int64              timestamp);

        public abstract double calculate_time_block_weight (Pomodoro.TimeBlock time_block);

        /**
         * Update given state according to given time-block.
         *
         * The context will hold info about current state of the session.
         */
        public abstract void resolve_context (Pomodoro.TimeBlock            time_block,
                                              bool                          is_resuming,
                                              int64                         timestamp,
                                              ref Pomodoro.SchedulerContext context);

        /**
         * Resolve next time-block state according to scheduler state.
         */
        public abstract Pomodoro.State resolve_state (Pomodoro.SchedulerContext context);

        /**
         * Resolve next time-block according to scheduler state.
         */
        public abstract Pomodoro.TimeBlock? resolve_time_block (Pomodoro.SchedulerContext context);

        /**
         * Check whether time-block has been completed at given time.
         */
        public abstract bool is_time_block_completed (Pomodoro.TimeBlock time_block,
                                                      int64              timestamp);

        /**
         * Build a scheduler context from completed/in-progress time-blocks.
         */
        internal void build_scheduler_context (Pomodoro.Session                          session,
                                               bool                                      is_resuming,
                                               int64                                     timestamp,
                                               out Pomodoro.SchedulerContext             context,
                                               out unowned GLib.List<Pomodoro.TimeBlock> first_scheduled_link)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = session.time_blocks.first ();

            context = Pomodoro.SchedulerContext.initial (
                    link != null && link.data.get_status () != Pomodoro.TimeBlockStatus.SCHEDULED
                    ? link.data.start_time
                    : timestamp);
            first_scheduled_link = null;

            while (link != null)
            {
                var time_block = link.data;
                var time_block_status = time_block.get_status ();

                if (time_block_status == Pomodoro.TimeBlockStatus.SCHEDULED) {
                    first_scheduled_link = link;
                    break;
                }

                if (!context.is_session_completed)
                {
                    var time_block_timestamp =
                            time_block_status == Pomodoro.TimeBlockStatus.IN_PROGRESS
                            ? timestamp
                            : time_block.end_time;
                    this.resolve_context (
                            time_block,
                            is_resuming,
                            time_block_timestamp,
                            ref context);
                }

                link = link.next;
            }

            context.timestamp = int64.max (context.timestamp, timestamp);
        }

        /**
         * Adjust time-block start-time and duration.
         */
        public void reschedule_time_block (Pomodoro.TimeBlock time_block,
                                           int64              timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            if (time_block.state == Pomodoro.State.STOPPED) {
                return;
            }

            if (time_block.get_status () == Pomodoro.TimeBlockStatus.COMPLETED ||
                time_block.get_status () == Pomodoro.TimeBlockStatus.UNCOMPLETED)
            {
                return;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            // TODO: adjust session template according to available time

            if (time_block.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED)
            {
                var intended_duration = this._session_template.get_duration (time_block.state);

                time_block.set_intended_duration (intended_duration);
                time_block.set_time_range (timestamp, timestamp + intended_duration);
            }

            time_block.set_completion_time (this.calculate_time_block_completion_time (time_block));
            time_block.set_weight (this.calculate_time_block_weight (time_block));
        }

        public bool reschedule_session (Pomodoro.Session    session,
                                        Pomodoro.TimeBlock? next_time_block,
                                        bool                is_resuming,
                                        int64               timestamp)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            Pomodoro.SchedulerContext context;
            unowned GLib.List<Pomodoro.TimeBlock> link;

            var initial_version = session.version;
            session.freeze_changed ();

            this.ensure_session_meta (session);
            this.build_scheduler_context (session, is_resuming, timestamp, out context, out link);

            // Prepare next time-block
            if (next_time_block != null)
            {
                assert (session.contains (next_time_block));
                assert (next_time_block.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED);

                // Remove time-blocks leading to `next_time_block`
                while (link != null && link.data != next_time_block)
                {
                    unowned var tmp = link.next;
                    session.remove_link (link);
                    link = tmp;
                }

                if (next_time_block.duration > 0) {
                    next_time_block.move_to (timestamp);
                }
                else {
                    this.reschedule_time_block (next_time_block, timestamp);
                }

                this.resolve_context (next_time_block, false, timestamp, ref context);

                link = link.next;
            }

            // Create or update time-blocks.
            var i = 1;

            while (true)
            {
                if (i++ >= Pomodoro.Scheduler.MAX_ITERATIONS) {
                    GLib.error ("`Session.reschedule()` reached iterations limit.");
                    // break;
                }

                var time_block = this.resolve_time_block (context);

                if (time_block == null) {
                    break;
                }

                if (link != null &&
                    link.data.state == time_block.state)
                {
                    // Update existing time-block.
                    assert (link.data.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED);

                    link.data.set_time_range (time_block.start_time, time_block.end_time);
                    link.data.set_meta (time_block.get_meta ());

                    this.resolve_context (link.data, false, timestamp, ref context);

                    link = link.next;
                }
                else {
                    // Add new time-block.
                    if (link != null) {
                        session.time_blocks.insert_before (link, time_block);
                    }
                    else {
                        session.time_blocks.append (time_block);
                    }

                    session.emit_added (time_block);

                    this.resolve_context (time_block, false, timestamp, ref context);
                }
            }

            // Remove time-blocks after a long-break.
            session.remove_links_after (link);
            session.remove_link (link);

            session.thaw_changed ();

            return session.version != initial_version;
        }

        public void ensure_time_block_meta (Pomodoro.TimeBlock time_block)
        {
            if (time_block.get_intended_duration () == 0) {
                time_block.set_intended_duration (
                        this._session_template.get_duration (time_block.state));
            }

            time_block.set_completion_time (
                    this.calculate_time_block_completion_time (time_block));

            time_block.set_weight (this.calculate_time_block_weight (time_block));
        }

        /**
         * Update meta for all time-blocks, not only scheduled. Intended for restoring a session.
         */
        public void ensure_session_meta (Pomodoro.Session session)
        {
            session.@foreach (
                (time_block) => {
                    if (time_block.state != Pomodoro.State.STOPPED) {
                        this.ensure_time_block_meta (time_block);
                    }
                });
        }
    }


    public class SimpleScheduler : Scheduler
    {
        /* Score limit helps session progress bar looking sensible, also serves as a penalty for
         * extending pomodoros too much
         */
        private double MAX_SCORE = 2.0;

        /* Minimum intended-duration to consider scores above 1.0  */
        private int64 SCORE_INTENDED_DURATION_THRESHOLD = 20 * Pomodoro.Interval.MINUTE;

        public SimpleScheduler.with_template (Pomodoro.SessionTemplate session_template)
        {
            GLib.Object (
                session_template: session_template
            );
        }

        private double calculate_time_block_score_internal (Pomodoro.TimeBlock time_block,
                                                            bool               include_uncompleted_gaps,
                                                            int64              timestamp)
                                    requires (Pomodoro.Timestamp.is_defined (time_block.start_time))
                                    requires (time_block.end_time >= time_block.start_time)
        {
            var intended_duration = time_block.get_intended_duration ();
            var score = 0.0;

            if (intended_duration == 0) {
                intended_duration = this.session_template.get_duration (time_block.state);
            }

            if (time_block.state != Pomodoro.State.POMODORO ||
                time_block.get_status () == Pomodoro.TimeBlockStatus.UNCOMPLETED ||
                intended_duration <= 0)
            {
                return score;
            }

            var elapsed = time_block.calculate_elapsed (timestamp);
            var last_gap = time_block.get_last_gap ();

            if (include_uncompleted_gaps &&
                last_gap != null &&
                last_gap.start_time < timestamp &&
                Pomodoro.Timestamp.is_undefined (last_gap.end_time) &&
                time_block.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS)
            {
                elapsed += int64.min (timestamp, time_block.end_time) - last_gap.start_time;
            }

            if (elapsed >= SCORE_INTENDED_DURATION_THRESHOLD) {
                intended_duration = int64.max (intended_duration,
                                               SCORE_INTENDED_DURATION_THRESHOLD);
            }

            if (intended_duration >= SCORE_INTENDED_DURATION_THRESHOLD)
            {
                var base_score = elapsed / intended_duration;
                var partial_score = (
                        (double) (elapsed - base_score * intended_duration) /
                        (COMPLETION_THRESHOLD * (double) intended_duration));

                score = Math.floor (
                    (double) base_score + partial_score
                ).clamp (0.0, MAX_SCORE);
            }
            else {
                score = Math.floor (
                    (double) elapsed / (COMPLETION_THRESHOLD * (double) intended_duration)
                ).clamp (0.0, 1.0);
            }

            assert (score.is_finite ());

            return score;
        }

        public override double calculate_time_block_score (Pomodoro.TimeBlock time_block,
                                                           int64              timestamp)
        {
            return this.calculate_time_block_score_internal (time_block, false, timestamp);
        }

        public override double calculate_time_block_weight (Pomodoro.TimeBlock time_block)
        {
            return this.calculate_time_block_score_internal (time_block, true, time_block.end_time);
        }

        public override void resolve_context (Pomodoro.TimeBlock            time_block,
                                              bool                          is_resuming,
                                              int64                         timestamp,
                                              ref Pomodoro.SchedulerContext context)
        {
            if (time_block.state == Pomodoro.State.STOPPED) {
                return;
            }

            var status = time_block.get_status ();
            var is_long_break = time_block.state == Pomodoro.State.LONG_BREAK ||
                                time_block.state == Pomodoro.State.BREAK;

            if (status == Pomodoro.TimeBlockStatus.IN_PROGRESS)
            {
                var last_gap = time_block.get_last_gap ();
                var is_paused = last_gap != null &&
                                Pomodoro.Timestamp.is_undefined (last_gap.end_time);

                if (!is_resuming && is_paused)
                {
                    status = Pomodoro.TimeBlockStatus.COMPLETED;
                }
                else {
                    status = this.is_time_block_completed (time_block, timestamp)
                            ? Pomodoro.TimeBlockStatus.COMPLETED
                            : Pomodoro.TimeBlockStatus.UNCOMPLETED;
                }

                context.timestamp = timestamp;
            }
            else {
                context.timestamp = time_block.end_time;
            }

            if (status == Pomodoro.TimeBlockStatus.SCHEDULED ||
                status == Pomodoro.TimeBlockStatus.COMPLETED)
            {
                context.score += this.calculate_time_block_weight (time_block);

                if (is_long_break) {
                    context.is_session_completed = true;
                }
            }

            context.state = time_block.state;
            context.needs_long_break = !context.is_session_completed &&
                                        context.score >= this.session_template.cycles;
        }

        public override Pomodoro.State resolve_state (Pomodoro.SchedulerContext context)
        {
            if (context.state != Pomodoro.State.POMODORO) {
                return Pomodoro.State.POMODORO;
            }

            if (this.session_template.has_uniform_breaks ()) {
                return Pomodoro.State.BREAK;
            }

            return context.needs_long_break ? Pomodoro.State.LONG_BREAK : Pomodoro.State.SHORT_BREAK;
        }

        /**
         * Create next time-block.
         *
         * Alternate between a pomodoro and a break, regardless whether previous time-block has been completed.
         */
        public override Pomodoro.TimeBlock? resolve_time_block (Pomodoro.SchedulerContext context)
        {
            if (context.is_session_completed) {
                return null;  // Suggest starting a new session.
            }

            var state = this.resolve_state (context);
            var time_block = new Pomodoro.TimeBlock (state);

            this.reschedule_time_block (time_block, context.timestamp);

            return time_block;
        }

        /**
         * Determine whether time-block should be marked as completed.
         */
        public override bool is_time_block_completed (Pomodoro.TimeBlock time_block,
                                                      int64              timestamp)
        {
            var completion_time = time_block.get_completion_time ();

            if (Pomodoro.Timestamp.is_undefined (completion_time)) {
                completion_time = this.calculate_time_block_completion_time (time_block);
            }

            return timestamp >= completion_time;
        }
    }
}
