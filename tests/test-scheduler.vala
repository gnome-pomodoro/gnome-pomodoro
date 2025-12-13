namespace Tests
{
    private double EPSILON = 0.0001;


    public abstract class BaseSchedulerTest : Tests.TestSuite
    {
        protected Pomodoro.SessionTemplate session_template = Pomodoro.SessionTemplate () {
            pomodoro_duration = 25 * Pomodoro.Interval.MINUTE,
            short_break_duration = 5 * Pomodoro.Interval.MINUTE,
            long_break_duration = 15 * Pomodoro.Interval.MINUTE,
            cycles = 4U
        };

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze_to (2000000000 * Pomodoro.Interval.SECOND);
        }

        public override void teardown ()
        {
            Pomodoro.Timestamp.thaw ();

            var settings = Pomodoro.get_settings ();
            settings.revert ();
        }

        public Pomodoro.Session create_session (Pomodoro.Scheduler scheduler)
        {
            var session = new Pomodoro.Session.from_template (scheduler.session_template);
            session.@foreach (
                (time_block) => {
                    time_block.set_intended_duration (time_block.duration);
                    time_block.set_completion_time (scheduler.calculate_time_block_completion_time (time_block));
                }
            );

            return session;
        }
    }

    public class SimpleSchedulerTest : BaseSchedulerTest
    {
        public SimpleSchedulerTest ()
        {
            this.add_test ("calculate_time_block_completion_time", this.test_calculate_time_block_completion_time);
            this.add_test ("calculate_time_block_completion_time__with_gaps", this.test_calculate_time_block_completion_time__with_gaps);

            this.add_test ("calculate_time_block_score__pomodoro", this.test_calculate_time_block_score__pomodoro);
            this.add_test ("calculate_time_block_score__extended_pomodoro", this.test_calculate_time_block_score__extended_pomodoro);
            this.add_test ("calculate_time_block_score__short_pomodoro", this.test_calculate_time_block_score__short_pomodoro);
            this.add_test ("calculate_time_block_score__short_break", this.test_calculate_time_block_score__short_break);
            this.add_test ("calculate_time_block_score__long_break", this.test_calculate_time_block_score__long_break);
            this.add_test ("calculate_time_block_score__uncompleted_pomodoro", this.test_calculate_time_block_score__uncompleted_pomodoro);
            this.add_test ("calculate_time_block_score__paused_pomodoro", this.test_calculate_time_block_score__paused_pomodoro);

            this.add_test ("calculate_time_block_weight__paused_pomodoro", this.test_calculate_time_block_weight__paused_pomodoro);

            this.add_test ("is_time_block_completed__pomodoro", this.test_is_time_block_completed__pomodoro);
            this.add_test ("is_time_block_completed__short_break", this.test_is_time_block_completed__short_break);
            this.add_test ("is_time_block_completed__long_break", this.test_is_time_block_completed__long_break);

            this.add_test ("resolve_context__update_state", this.test_resolve_context__update_state);
            this.add_test ("resolve_context__update_timestamp", this.test_resolve_context__update_timestamp);
            this.add_test ("resolve_context__completed_pomodoro", this.test_resolve_context__completed_pomodoro);
            this.add_test ("resolve_context__completed_short_break", this.test_resolve_context__completed_short_break);
            this.add_test ("resolve_context__completed_long_break", this.test_resolve_context__completed_long_break);
            this.add_test ("resolve_context__uncompleted_pomodoro", this.test_resolve_context__uncompleted_pomodoro);
            this.add_test ("resolve_context__uncompleted_short_break", this.test_resolve_context__uncompleted_short_break);
            this.add_test ("resolve_context__uncompleted_long_break", this.test_resolve_context__uncompleted_long_break);
            this.add_test ("resolve_context__uncompleted_last_pomodoro", this.test_resolve_context__uncompleted_last_pomodoro);
            this.add_test ("resolve_context__in_progress_pomodoro", this.test_resolve_context__in_progress_pomodoro);
            this.add_test ("resolve_context__in_progress_short_break", this.test_resolve_context__in_progress_short_break);
            this.add_test ("resolve_context__in_progress_long_break", this.test_resolve_context__in_progress_long_break);
            this.add_test ("resolve_context__paused_pomodoro", this.test_resolve_context__paused_pomodoro);
            this.add_test ("resolve_context__paused_short_break", this.test_resolve_context__paused_short_break);
            this.add_test ("resolve_context__needs_long_break", this.test_resolve_context__needs_long_break);

            this.add_test ("resolve_time_block__pomodoro", this.test_resolve_time_block__pomodoro);
            this.add_test ("resolve_time_block__short_break", this.test_resolve_time_block__short_break);
            this.add_test ("resolve_time_block__long_break", this.test_resolve_time_block__long_break);
            this.add_test ("resolve_time_block__completed_session", this.test_resolve_time_block__completed_session);

            this.add_test ("reschedule_session__populate", this.test_reschedule_session__populate);
            this.add_test ("reschedule_session__completed_session", this.test_reschedule_session__completed_session);
            this.add_test ("reschedule_session__uncompleted_pomodoro", this.test_reschedule_session__uncompleted_pomodoro);
            this.add_test ("reschedule_session__uncompleted_short_break", this.test_reschedule_session__uncompleted_short_break);
            this.add_test ("reschedule_session__uncompleted_last_pomodoro", this.test_reschedule_session__uncompleted_last_pomodoro);
            this.add_test ("reschedule_session__uncompleted_long_break", this.test_reschedule_session__uncompleted_long_break);
            this.add_test ("reschedule_session__uncompleted_extra_pomodoro", this.test_reschedule_session__uncompleted_extra_pomodoro);
            this.add_test ("reschedule_session__skip_uncompleted_long_break", this.test_reschedule_session__skip_uncompleted_long_break);
            this.add_test ("reschedule_session__skip_uncompleted_extra_pomodoro", this.test_reschedule_session__skip_uncompleted_extra_pomodoro);
            this.add_test ("reschedule_session__resume_session_1", this.test_reschedule_session__resume_session_1);
            this.add_test ("reschedule_session__resume_session_2", this.test_reschedule_session__resume_session_2);
            this.add_test ("reschedule_session__starting_with_long_break", this.test_reschedule_session__starting_with_long_break);
            this.add_test ("reschedule_session__in_progress_time_block", this.test_reschedule_session__in_progress_time_block);
            this.add_test ("reschedule_session__paused_pomodoro", this.test_reschedule_session__paused_pomodoro);
            this.add_test ("reschedule_session__paused_short_break", this.test_reschedule_session__paused_short_break);
            this.add_test ("reschedule_session__extended_pomodoro_1x", this.test_reschedule_session__extended_pomodoro_1x);
            this.add_test ("reschedule_session__extended_pomodoro_2x", this.test_reschedule_session__extended_pomodoro_2x);

            this.add_test ("ensure_session_meta__scheduled", this.test_ensure_session_meta__scheduled);
            this.add_test ("ensure_session_meta__completed", this.test_ensure_session_meta__completed);
            this.add_test ("ensure_session_meta__uncompleted", this.test_ensure_session_meta__uncompleted);
            this.add_test ("ensure_session_meta__in_progress", this.test_ensure_session_meta__in_progress);
            this.add_test ("ensure_session_meta__with_gaps", this.test_ensure_session_meta__with_gaps);
            this.add_test ("ensure_session_meta__mixed_states", this.test_ensure_session_meta__mixed_states);
        }

        public void test_calculate_time_block_completion_time ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_1.set_time_range (now, now + 30 * Pomodoro.Interval.SECOND);
            time_block_1.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block_1)),
                new GLib.Variant.int64 (now + 20 * Pomodoro.Interval.MINUTE)
            );

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_2.set_time_range (now, now + 20 * Pomodoro.Interval.MINUTE);
            time_block_2.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block_2)),
                new GLib.Variant.int64 (now + 20 * Pomodoro.Interval.MINUTE)
            );

            var time_block_3 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_3.set_time_range (now, now + 50 * Pomodoro.Interval.MINUTE);
            time_block_3.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block_3)),
                new GLib.Variant.int64 (now + 20 * Pomodoro.Interval.MINUTE)
            );

            var time_block_4 = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block_4.set_time_range (now, now + 10 * Pomodoro.Interval.MINUTE);
            time_block_4.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block_4)),
                new GLib.Variant.int64 (now + 4 * Pomodoro.Interval.MINUTE)
            );

            var time_block_5 = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block_5.set_time_range (now, now + 5 * Pomodoro.Interval.SECOND);
            time_block_5.set_intended_duration (5 * Pomodoro.Interval.SECOND);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block_5)),
                new GLib.Variant.int64 (now + 4 * Pomodoro.Interval.SECOND)
            );
        }

        public void test_calculate_time_block_completion_time__with_gaps ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block)),
                new GLib.Variant.int64 (now + 20 * Pomodoro.Interval.MINUTE)
            );

            var gap = new Pomodoro.Gap ();
            gap.set_time_range (now + 5 * Pomodoro.Interval.MINUTE, Pomodoro.Timestamp.UNDEFINED);
            time_block.add_gap (gap);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block)),
                new GLib.Variant.int64 (now + 20 * Pomodoro.Interval.MINUTE)
            );

            gap.set_time_range (now + 5 * Pomodoro.Interval.MINUTE, now + 15 * Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block)),
                new GLib.Variant.int64 (now + 30 * Pomodoro.Interval.MINUTE)
            );

            time_block.set_time_range (now, now + 35 * Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block)),
                new GLib.Variant.int64 (now + 30 * Pomodoro.Interval.MINUTE)
            );
        }

        public void test_calculate_time_block_score__pomodoro ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var score = 0.0;

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (now + 20 * Pomodoro.Interval.MINUTE);

            // At different timestamps
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            score = scheduler.calculate_time_block_score (time_block, now + 19 * Pomodoro.Interval.MINUTE);
            assert_cmpfloat_with_epsilon (score, 0.0, EPSILON);

            score = scheduler.calculate_time_block_score (time_block, now + 20 * Pomodoro.Interval.MINUTE);
            assert_cmpfloat_with_epsilon (score, 1.0, EPSILON);

            score = scheduler.calculate_time_block_score (time_block, now + 99 * Pomodoro.Interval.MINUTE);
            assert_cmpfloat_with_epsilon (score, 1.0, EPSILON);

            // After marking time-block end time
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);

            time_block.set_time_range (now, now + 19 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 0.0, EPSILON);

            time_block.set_time_range (now, now + 20 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 1.0, EPSILON);

            time_block.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 1.0, EPSILON);

            time_block.set_time_range (now, now + (25 + 19) * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 1.0, EPSILON);

            time_block.set_time_range (now, now + (25 + 20) * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 2.0, EPSILON);

            // Uncompleted status should have a priority
            time_block.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 0.0, EPSILON);
        }

        public void test_calculate_time_block_score__extended_pomodoro ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var score = 0.0;

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (now, now + 50 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (now + 20 * Pomodoro.Interval.MINUTE);

            // At different timestamps
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            score = scheduler.calculate_time_block_score (time_block, now + 44 * Pomodoro.Interval.MINUTE);
            assert_cmpfloat_with_epsilon (score, 1.0, EPSILON);

            score = scheduler.calculate_time_block_score (time_block, now + 45 * Pomodoro.Interval.MINUTE);
            assert_cmpfloat_with_epsilon (score, 2.0, EPSILON);

            score = scheduler.calculate_time_block_score (time_block, now + 50 * Pomodoro.Interval.MINUTE);
            assert_cmpfloat_with_epsilon (score, 2.0, EPSILON);

            // After marking time-block end time
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);

            time_block.set_time_range (now, now + 44 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 1.0, EPSILON);

            time_block.set_time_range (now, now + 45 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 2.0, EPSILON);

            time_block.set_time_range (now, now + 50 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 2.0, EPSILON);

            // Uncompleted status should have a priority
            time_block.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 0.0, EPSILON);
        }

        public void test_calculate_time_block_score__short_pomodoro ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var score = 0.0;

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_intended_duration (15 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (now + 20 * Pomodoro.Interval.MINUTE);

            time_block.set_time_range (now, now + 11 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 0.0, EPSILON);

            time_block.set_time_range (now, now + 12 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 1.0, EPSILON);

            time_block.set_time_range (now, now + 30 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 1.0, EPSILON);

            time_block.set_time_range (now, now + 40 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 2.0, EPSILON);
        }

        public void test_calculate_time_block_score__short_break ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var score = 0.0;

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            time_block.set_time_range (now, now + 4 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 0.0, EPSILON);

            time_block.set_time_range (now, now + 5 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 0.0, EPSILON);
        }

        public void test_calculate_time_block_score__long_break ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var score = 0.0;

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.LONG_BREAK);
            time_block.set_intended_duration (15 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            time_block.set_time_range (now, now + 12 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 0.0, EPSILON);

            time_block.set_time_range (now, now + 15 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 0.0, EPSILON);
        }

        public void test_calculate_time_block_score__uncompleted_pomodoro ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (now + 20 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            time_block.duration = 1 * Pomodoro.Interval.MINUTE;
            assert_cmpfloat (
                scheduler.calculate_time_block_score (time_block, time_block.end_time),
                GLib.CompareOperator.EQ,
                0.0
            );

            time_block.duration = 20 * Pomodoro.Interval.MINUTE;
            assert_cmpfloat (
                scheduler.calculate_time_block_score (time_block, time_block.end_time),
                GLib.CompareOperator.EQ,
                0.0
            );

            time_block.duration = 25 * Pomodoro.Interval.MINUTE;
            assert_cmpfloat (
                scheduler.calculate_time_block_score (time_block, time_block.end_time),
                GLib.CompareOperator.EQ,
                0.0
            );
        }

        public void test_calculate_time_block_score__paused_pomodoro ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (now + 20 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            assert_cmpfloat (
                    scheduler.calculate_time_block_score (time_block, time_block.start_time),
                    GLib.CompareOperator.EQ,
                    0.0);

            // Start a pause
            var gap_1 = new Pomodoro.Gap ();
            gap_1.set_time_range (now + 5 * Pomodoro.Interval.MINUTE, Pomodoro.Timestamp.UNDEFINED);
            time_block.add_gap (gap_1);
            assert_cmpfloat (
                    scheduler.calculate_time_block_score (time_block, gap_1.start_time),
                    GLib.CompareOperator.EQ,
                    0.0);
            assert_cmpfloat (
                    scheduler.calculate_time_block_score (time_block, time_block.end_time),
                    GLib.CompareOperator.EQ,
                    0.0);

            // Resume. Check if a long pause confuses the scheduler.
            gap_1.duration = 30 * Pomodoro.Interval.MINUTE;
            time_block.duration += gap_1.duration;
            time_block.set_completion_time (time_block.end_time - 5 * Pomodoro.Interval.MINUTE);
            assert_cmpfloat (
                    scheduler.calculate_time_block_score (time_block, gap_1.end_time),
                    GLib.CompareOperator.EQ,
                    0.0);
            assert_cmpfloat (
                    scheduler.calculate_time_block_score (time_block, time_block.end_time),
                    GLib.CompareOperator.EQ,
                    1.0);
            assert_cmpfloat (
                    scheduler.calculate_time_block_score (time_block, time_block.end_time + Pomodoro.Interval.HOUR),
                    GLib.CompareOperator.EQ,
                    1.0);

            // Pause after `completion_time`
            now = time_block.end_time - Pomodoro.Interval.MINUTE;
            var gap_2 = new Pomodoro.Gap ();
            gap_2.set_time_range (now, Pomodoro.Timestamp.UNDEFINED);
            time_block.add_gap (gap_2);
            assert_cmpfloat (
                    scheduler.calculate_time_block_score (time_block, gap_2.start_time),
                    GLib.CompareOperator.EQ,
                    1.0);
            assert_cmpfloat (
                    scheduler.calculate_time_block_score (time_block, time_block.end_time),
                    GLib.CompareOperator.EQ,
                    1.0);
            assert_cmpfloat (
                    scheduler.calculate_time_block_score (time_block, time_block.end_time + Pomodoro.Interval.HOUR),
                    GLib.CompareOperator.EQ,
                    1.0);

            // Resume. Check if a long pause confuses the scheduler.
            gap_2.duration = 30 * Pomodoro.Interval.MINUTE;
            time_block.duration += gap_2.duration;
            assert_cmpfloat (
                    scheduler.calculate_time_block_score (time_block, gap_2.start_time),
                    GLib.CompareOperator.EQ,
                    1.0);
            assert_cmpfloat (
                    scheduler.calculate_time_block_score (time_block, gap_2.end_time),
                    GLib.CompareOperator.EQ,
                    1.0);
            assert_cmpfloat (
                    scheduler.calculate_time_block_score (time_block, time_block.end_time),
                    GLib.CompareOperator.EQ,
                    1.0);
            assert_cmpfloat (
                    scheduler.calculate_time_block_score (time_block, time_block.end_time + Pomodoro.Interval.HOUR),
                    GLib.CompareOperator.EQ,
                    1.0);
        }

        /**
         * Ignore ongoing gap when calculating weight.
         */
        public void test_calculate_time_block_weight__paused_pomodoro ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_1.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            time_block_1.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            time_block_1.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            assert_cmpfloat_with_epsilon (
                    scheduler.calculate_time_block_weight (time_block_1),
                    1.0,
                    EPSILON);

            var gap_1 = new Pomodoro.Gap ();
            gap_1.set_time_range (now + 5 * Pomodoro.Interval.MINUTE,
                                  Pomodoro.Timestamp.UNDEFINED);
            time_block_1.add_gap (gap_1);
            assert_cmpfloat_with_epsilon (
                    scheduler.calculate_time_block_weight (time_block_1),
                    1.0,
                    EPSILON);

            gap_1.set_time_range (now + 5 * Pomodoro.Interval.MINUTE,
                                  now + 15 * Pomodoro.Interval.MINUTE);
            assert_cmpfloat_with_epsilon (
                    scheduler.calculate_time_block_weight (time_block_1),
                    0.0,
                    EPSILON);

            time_block_1.set_time_range (now, now + 35 * Pomodoro.Interval.MINUTE);
            assert_cmpfloat_with_epsilon (
                    scheduler.calculate_time_block_weight (time_block_1),
                    1.0,
                    EPSILON);

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_2.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            time_block_2.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            time_block_2.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var gap_2 = new Pomodoro.Gap ();
            gap_2.set_time_range (now + 20 * Pomodoro.Interval.MINUTE,
                                  Pomodoro.Timestamp.UNDEFINED);
            time_block_2.add_gap (gap_2);
            assert_cmpfloat_with_epsilon (
                    scheduler.calculate_time_block_weight (time_block_2),
                    1.0,
                    EPSILON);

            var gap_3 = new Pomodoro.Gap ();
            gap_3.set_time_range (now, now + 20 * Pomodoro.Interval.MINUTE);
            time_block_2.add_gap (gap_3);
            assert_cmpfloat_with_epsilon (
                    scheduler.calculate_time_block_weight (time_block_2),
                    0.0,
                    EPSILON);

            time_block_2.set_time_range (
                    time_block_2.start_time,
                    time_block_2.end_time + 50 * Pomodoro.Interval.MINUTE);
            assert_cmpfloat_with_epsilon (
                    scheduler.calculate_time_block_weight (time_block_2),
                    2.0,
                    EPSILON);
        }

        /**
         * Time-block should complete at least 80% of intended duration, and not be shorter than 1 minute.
         */
        public void test_is_time_block_completed__pomodoro ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = this.create_session (scheduler);
            var time_block = session.get_nth_time_block (0);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var timestamp_1 = time_block.start_time + 20 * Pomodoro.Interval.MINUTE - Pomodoro.Interval.SECOND;
            assert_false (scheduler.is_time_block_completed (time_block, timestamp_1));

            var timestamp_2 = time_block.start_time + 20 * Pomodoro.Interval.MINUTE;
            assert_true (scheduler.is_time_block_completed (time_block, timestamp_2));
        }

        public void test_is_time_block_completed__short_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = this.create_session (scheduler);
            var time_block = session.get_nth_time_block (1);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var timestamp_1 = time_block.start_time + 4 * Pomodoro.Interval.MINUTE - Pomodoro.Interval.SECOND;
            assert_false (scheduler.is_time_block_completed (time_block, timestamp_1));

            var timestamp_2 = time_block.start_time + 4 * Pomodoro.Interval.MINUTE;
            assert_true (scheduler.is_time_block_completed (time_block, timestamp_2));
        }

        public void test_is_time_block_completed__long_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = this.create_session (scheduler);
            var time_block = session.get_last_time_block ();
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var timestamp_1 = time_block.start_time + 4 * Pomodoro.Interval.MINUTE - Pomodoro.Interval.SECOND;
            assert_false (scheduler.is_time_block_completed (time_block, timestamp_1));

            var timestamp_2 = time_block.start_time + 12 * Pomodoro.Interval.MINUTE;
            assert_true (scheduler.is_time_block_completed (time_block, timestamp_2));
        }

        /**
         * Expect `Scheduler.resolve_state()` to copy current time-block state into scheduler context.
         */
        public void test_resolve_context__update_state ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            Pomodoro.State[] states = {
                Pomodoro.State.STOPPED,
                Pomodoro.State.POMODORO,
                Pomodoro.State.SHORT_BREAK,
                Pomodoro.State.LONG_BREAK
            };

            foreach (var state in states)
            {
                var context = Pomodoro.SchedulerContext ();
                var time_block = new Pomodoro.TimeBlock (state);
                time_block.set_time_range (20, 30);
                time_block.set_intended_duration (time_block.duration);

                scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
                assert_true (context.state == state);
            }
        }

        public void test_resolve_context__update_timestamp ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            int64[] timestamps = {
                now + Pomodoro.Interval.MINUTE,
                now + 5 * Pomodoro.Interval.MINUTE,
                now + 10 * Pomodoro.Interval.MINUTE
            };

            foreach (var timestamp in timestamps)
            {
                var context = Pomodoro.SchedulerContext ();

                var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
                time_block.set_time_range (timestamp, timestamp + Pomodoro.Interval.MINUTE);

                scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
                assert_cmpvariant (
                    new GLib.Variant.int64 (context.timestamp),
                    new GLib.Variant.int64 (time_block.end_time)
                );
            }
        }

        /**
         * Completing a pomodoro should mark session as completed.
         */
        public void test_resolve_context__completed_pomodoro ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (now, now + 9 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);

            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.STOPPED,
                score = 0.0,
            };
            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.POMODORO,
                score = 1.0,
            };
            scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__completed_short_break ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block.set_time_range (now, now + 5 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);

            var context = Pomodoro.SchedulerContext () {
                timestamp = time_block.start_time,
                state = Pomodoro.State.STOPPED,
                score = 1.0,
            };
            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.SHORT_BREAK,
                score = 1.0,
            };
            scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        /**
         * Completing a long break should mark session as completed.
         */
        public void test_resolve_context__completed_long_break ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.LONG_BREAK);
            time_block.set_time_range (now, now + 15 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);

            var context = Pomodoro.SchedulerContext () {
                timestamp = time_block.start_time,
                state = Pomodoro.State.STOPPED,
                is_session_completed = false,
                needs_long_break = true,
                score = 4.0,
            };
            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.LONG_BREAK,
                is_session_completed = true,
                needs_long_break = false,
                score = 4.0,
            };
            scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__uncompleted_pomodoro ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);
            time_block.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            time_block.set_time_range (now, now + 3 * Pomodoro.Interval.MINUTE);

            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.STOPPED,
                score = 0.0,
            };
            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.POMODORO,
                score = 0.0,
            };
            scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__uncompleted_short_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.STOPPED,
                score = 1.0,
            };
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state     = Pomodoro.State.SHORT_BREAK,
                score     = 1.0,
            };
            scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__uncompleted_long_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.LONG_BREAK);
            time_block.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.STOPPED,
                is_session_completed = false,
                needs_long_break = true,
                score = 4.0,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.LONG_BREAK,
                is_session_completed = false,
                needs_long_break = true,
                score = 4.0,
            };
            scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__uncompleted_last_pomodoro ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.STOPPED,
                is_session_completed = false,
                needs_long_break = false,
                score = 3.0,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
                is_session_completed = false,
                needs_long_break = false,
                score = 3.0,
            };
            scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__in_progress_pomodoro ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (now, now + 9 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (now + 4 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.STOPPED,
                score = 0.0,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.POMODORO,
                score = 1.0,
            };
            scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__in_progress_short_break ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block.set_time_range (now, now + 5 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (now + 4 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.STOPPED,
                score = 1.0,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.SHORT_BREAK,
                score = 1.0,
            };
            scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__in_progress_long_break ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var cycles = (double) this.session_template.cycles;
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.LONG_BREAK);
            time_block.set_time_range (now, now + 15 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (12 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (now + 12 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.STOPPED,
                is_session_completed = false,
                needs_long_break = true,
                score = cycles,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.LONG_BREAK,
                is_session_completed = true,
                needs_long_break = false,
                score = cycles,
            };
            scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__paused_pomodoro ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (now, now + 5 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (now + 4 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var gap = new Pomodoro.Gap.with_start_time (now + 1 * Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap);

            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.STOPPED,
                score = 0.0,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.POMODORO,
                score = 1.0,
            };
            scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__paused_short_break ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block.set_time_range (now, now + 5 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (now + 4 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var gap = new Pomodoro.Gap.with_start_time (now + 1 * Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap);

            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.STOPPED,
                score = 0.0,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.SHORT_BREAK,
                score = 0.0,
            };
            scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__needs_long_break ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var cycles = (double) this.session_template.cycles;
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
            time_block.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            time_block.set_time_range (now, now + 4 * Pomodoro.Interval.MINUTE);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.STOPPED,
                needs_long_break = false,
                score = cycles - 1.0,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.POMODORO,
                needs_long_break = true,
                score = cycles,
            };
            scheduler.resolve_context (time_block, true, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }


        public void test_resolve_time_block__pomodoro ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var context_1 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.STOPPED,
            };
            var time_block_1 = scheduler.resolve_time_block (context_1);
            assert_true (time_block_1.state == Pomodoro.State.POMODORO);

            var context_2 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.SHORT_BREAK,
            };
            var time_block_2 = scheduler.resolve_time_block (context_2);
            assert_true (time_block_2.state == Pomodoro.State.POMODORO);
        }

        public void test_resolve_time_block__short_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
            };

            var time_block = scheduler.resolve_time_block (context);
            assert_true (time_block.state == Pomodoro.State.SHORT_BREAK);
        }

        public void test_resolve_time_block__long_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
                needs_long_break = true,
            };
            var time_block = scheduler.resolve_time_block (context);
            assert_true (time_block.state == Pomodoro.State.LONG_BREAK);
        }

        /**
         * Expect `resolve_time_block()` to return null for a completed session.
         */
        public void test_resolve_time_block__completed_session ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.LONG_BREAK,
                score = (double) this.session_template.cycles,
                is_session_completed = true,
            };
            var time_block = scheduler.resolve_time_block (context);
            assert_null (time_block);
        }


        /**
         * Populate empty session using scheduler.
         */
        public void test_reschedule_session__populate ()
        {
            var timestamp = Pomodoro.Timestamp.advance (0) + Pomodoro.Interval.MINUTE;
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = new Pomodoro.Session ();

            var session_changed_emitted = 0;
            session.changed.connect (() => { session_changed_emitted++; });

            scheduler.reschedule_session (session, null, true, timestamp);

            assert_cmpuint (session.get_cycles ().length (), GLib.CompareOperator.EQ, this.session_template.cycles);
            assert_cmpvariant (
                new GLib.Variant.int64 (session.start_time),
                new GLib.Variant.int64 (timestamp)
            );

            var time_block_1 = session.get_nth_time_block (0);
            assert_true (time_block_1.state == Pomodoro.State.POMODORO);

            var time_block_2 = session.get_nth_time_block (1);
            assert_true (time_block_2.state == Pomodoro.State.SHORT_BREAK);

            var last_time_block = session.get_last_time_block ();
            assert_true (last_time_block.state == Pomodoro.State.LONG_BREAK);

            assert_cmpuint (session_changed_emitted, GLib.CompareOperator.EQ, 1);
        }

        /**
         * Rescheduling a session that has completed long-break shouldn't do anything.
         *
         * No upcoming time-block should force `SessionManager` to start new session.
         */
        public void test_reschedule_session__completed_session ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var session = this.create_session (scheduler);
            session.@foreach (
                (time_block) => {
                    time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
                }
            );
            scheduler.ensure_session_meta (session);

            var session_changed_emitted = 0;
            session.changed.connect (() => { session_changed_emitted++; });

            scheduler.reschedule_session (session, null, true, session.end_time);

            assert_cmpuint (session_changed_emitted, GLib.CompareOperator.EQ, 0);
        }

        public void test_reschedule_session__uncompleted_pomodoro ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);

            var time_block_1 = session.get_nth_time_block (0);
            time_block_1.duration = Pomodoro.Interval.MINUTE;
            time_block_1.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var time_block_2 = session.get_nth_time_block (1);

            scheduler.ensure_session_meta (session);

            var now = time_block_1.end_time;
            scheduler.reschedule_session (session, null, true, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );
        }

        public void test_reschedule_session__uncompleted_short_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);

            var time_block_1 = session.get_nth_time_block (0);  // Pomodoro
            time_block_1.set_status (Pomodoro.TimeBlockStatus.COMPLETED);

            var time_block_2 = session.get_nth_time_block (1);  // Short break
            time_block_2.duration = Pomodoro.Interval.MINUTE;
            time_block_2.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var time_block_3 = session.get_nth_time_block (2);  // Pomodoro

            scheduler.ensure_session_meta (session);

            var now = time_block_2.end_time;
            scheduler.reschedule_session (session, null, true, now);

            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_3.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );
        }

        public void test_reschedule_session__uncompleted_last_pomodoro ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);

            var long_break_1 = session.get_last_time_block ();
            var last_pomodoro = session.get_previous_time_block (long_break_1);

            session.@foreach (
                (time_block) => {
                    if (time_block != last_pomodoro && time_block != long_break_1) {
                        time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
                    }
                }
            );

            last_pomodoro.duration = Pomodoro.Interval.MINUTE;
            last_pomodoro.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            scheduler.ensure_session_meta (session);

            // Rescheule
            var now = last_pomodoro.end_time;

            Pomodoro.Timestamp.freeze_to (now);
            scheduler.reschedule_session (session, null, true, now);

            var extra_short_break = session.get_next_time_block (last_pomodoro);
            assert_nonnull (extra_short_break);
            assert_cmpvariant (
                new GLib.Variant.int64 (extra_short_break.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_true (extra_short_break.state == Pomodoro.State.SHORT_BREAK);
            assert_true (extra_short_break.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED);

            var extra_pomodoro = session.get_next_time_block (extra_short_break);
            assert_nonnull (extra_pomodoro);
            assert_true (extra_pomodoro.state == Pomodoro.State.POMODORO);

            var long_break_2 = session.get_next_time_block (extra_pomodoro);
            assert_nonnull (long_break_2);
            assert_true (long_break_2.state == Pomodoro.State.LONG_BREAK);

            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );

            var last_cycle = session.get_cycles ().last ().data;
            assert_false (last_cycle.is_extra ());
            assert_true (last_cycle.is_visible ());
        }

        public void test_reschedule_session__uncompleted_long_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);

            session.@foreach (
                (time_block) => {
                    if (time_block.state != Pomodoro.State.LONG_BREAK) {
                        time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
                    }
                }
            );

            var long_break = session.get_last_time_block ();
            long_break.duration = Pomodoro.Interval.MINUTE;
            long_break.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            scheduler.ensure_session_meta (session);

            // Rescheule
            var now = long_break.end_time;
            Pomodoro.Timestamp.freeze_to (now);
            scheduler.reschedule_session (session, null, true, now);

            var extra_pomodoro = session.get_next_time_block (long_break);
            assert_nonnull (extra_pomodoro);
            assert_cmpvariant (
                new GLib.Variant.int64 (extra_pomodoro.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_true (extra_pomodoro.state == Pomodoro.State.POMODORO);
            assert_true (extra_pomodoro.get_is_extra ());
            assert_true (extra_pomodoro.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED);

            var extra_long_break = session.get_next_time_block (extra_pomodoro);
            assert_nonnull (extra_long_break);
            assert_cmpvariant (
                new GLib.Variant.int64 (extra_long_break.start_time),
                new GLib.Variant.int64 (extra_pomodoro.end_time)
            );
            assert_true (extra_long_break.state == Pomodoro.State.LONG_BREAK);
            assert_true (extra_long_break.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED);
            assert_false (extra_long_break.get_is_extra ());

            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles + 1U
            );

            var extra_cycle = session.get_cycles ().last ().data;
            assert_true (extra_cycle.is_extra ());
            assert_true (extra_cycle.is_visible ());
        }

        /**
         * Run reschedule after stopping extra pomodoro.
         *
         * Expect extra cycle as as we haven't completed a long-break.
         */
        public void test_reschedule_session__uncompleted_extra_pomodoro ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var session = this.create_session (scheduler);
            session.@foreach (
                (time_block) => {
                    if (time_block.state != Pomodoro.State.LONG_BREAK) {
                        time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
                    }
                }
            );

            var long_break_1 = session.get_last_time_block ();
            long_break_1.end_time = long_break_1.start_time + Pomodoro.Interval.MINUTE;
            long_break_1.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var extra_pomodoro = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            extra_pomodoro.set_time_range (
                    long_break_1.end_time,
                    long_break_1.end_time + 25 * Pomodoro.Interval.MINUTE);
            extra_pomodoro.set_is_extra (true);
            extra_pomodoro.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var long_break_2 = new Pomodoro.TimeBlock (Pomodoro.State.LONG_BREAK);
            long_break_2.set_time_range (
                    extra_pomodoro.end_time,
                    extra_pomodoro.end_time + 15 * Pomodoro.Interval.MINUTE);
            long_break_2.set_status (Pomodoro.TimeBlockStatus.SCHEDULED);

            session.append (extra_pomodoro);
            session.append (long_break_2);
            scheduler.ensure_session_meta (session);

            // Skip long-break
            var now = long_break_1.start_time + Pomodoro.Interval.MINUTE;

            Pomodoro.Timestamp.freeze_to (now);
            scheduler.reschedule_session (session, null, true, now);

            long_break_1.end_time = now;
            long_break_1.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);
        }

        /**
         * Simulate skipping an uncompleted long-break.
         *
         * Expect extra cycle.
         */
        public void test_reschedule_session__skip_uncompleted_long_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);

            session.@foreach (
                (time_block) => {
                    if (time_block.state != Pomodoro.State.LONG_BREAK) {
                        time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
                    }
                }
            );

            var long_break_1 = session.get_last_time_block ();
            long_break_1.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            scheduler.ensure_session_meta (session);

            // Skip long-break
            var now = long_break_1.start_time + Pomodoro.Interval.MINUTE;

            Pomodoro.Timestamp.freeze_to (now);
            scheduler.reschedule_session (session, null, true, now);

            long_break_1.end_time = now;
            long_break_1.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var extra_pomodoro = session.get_next_time_block (long_break_1);
            assert_nonnull (extra_pomodoro);
            assert_true (extra_pomodoro.state == Pomodoro.State.POMODORO);
            assert_true (extra_pomodoro.get_is_extra ());
            assert_cmpvariant (
                new GLib.Variant.int64 (extra_pomodoro.start_time),
                new GLib.Variant.int64 (now)
            );

            var long_break_2 = session.get_next_time_block (extra_pomodoro);
            assert_nonnull (long_break_2);
            assert_true (long_break_2 != long_break_1);
            assert_true (long_break_2.state == Pomodoro.State.LONG_BREAK);

            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles + 1U
            );
        }

        /**
         * Run reschedule after skipping extra pomodoro.
         *
         * We start an extra cycle, but skip it shortly after.
         * Expect the number of visible cycles to be reduced, as we jump to a long-break.
         */
        public void test_reschedule_session__skip_uncompleted_extra_pomodoro ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var session = this.create_session (scheduler);
            session.@foreach (
                (time_block) => {
                    if (time_block.state != Pomodoro.State.LONG_BREAK) {
                        time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
                    }
                }
            );

            var long_break_1 = session.get_last_time_block ();
            long_break_1.end_time = long_break_1.start_time + Pomodoro.Interval.MINUTE;
            long_break_1.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var extra_pomodoro = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            extra_pomodoro.set_time_range (
                    long_break_1.end_time,
                    long_break_1.end_time + 25 * Pomodoro.Interval.MINUTE);
            extra_pomodoro.set_is_extra (true);
            extra_pomodoro.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var long_break_2 = new Pomodoro.TimeBlock (Pomodoro.State.LONG_BREAK);
            long_break_2.set_time_range (
                    extra_pomodoro.end_time,
                    extra_pomodoro.end_time + 15 * Pomodoro.Interval.MINUTE);
            long_break_2.set_status (Pomodoro.TimeBlockStatus.SCHEDULED);

            session.append (extra_pomodoro);
            session.append (long_break_2);
            scheduler.ensure_session_meta (session);

            // Skip extra pomodoro
            var now = extra_pomodoro.start_time + Pomodoro.Interval.MINUTE;

            Pomodoro.Timestamp.freeze_to (now);
            scheduler.reschedule_session (session, long_break_2, true, now);

            extra_pomodoro.end_time = now;
            extra_pomodoro.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            assert_cmpvariant (
                new GLib.Variant.int64 (long_break_2.start_time),
                new GLib.Variant.int64 (now)
            );

            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );
        }

        /**
         * Simulate resuming session after stopping the timer.
         *
         * Simplest case, where we continue after a minute with the next time-block.
         */
        public void test_reschedule_session__resume_session_1 ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);

            var time_block_1 = session.get_nth_time_block (0);
            time_block_1.duration = Pomodoro.Interval.MINUTE;
            time_block_1.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var time_block_2 = session.get_nth_time_block (1);

            // Prepare session before entering time_block_2
            var now = time_block_1.end_time + Pomodoro.Interval.MINUTE;
            scheduler.reschedule_session (session, null, true, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );

            // Enter time_block_2
            time_block_2.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            scheduler.reschedule_session (session, null, true, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );

            // Ensure that `reschedule_session` behaves OK while time_block_2 is in progress
            scheduler.reschedule_session (session, null, true, now + Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );
        }

        /**
         * Simulate resuming session after stopping the timer.
         *
         * Real-world use, where we insert a new pomodoro.
         */
        public void test_reschedule_session__resume_session_2 ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);

            var time_block_1 = session.get_nth_time_block (0);
            time_block_1.duration = Pomodoro.Interval.MINUTE;
            time_block_1.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            // Simulate `initialize_next_time_block`
            var now = time_block_1.end_time + 30 * Pomodoro.Interval.MINUTE;
            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_2.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            session.insert_after (time_block_2, time_block_1);

            scheduler.reschedule_session (session, time_block_2, true, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );
        }

        public void test_reschedule_session__starting_with_long_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);

            var time_block_1 = session.get_first_time_block ();
            time_block_1.duration = Pomodoro.Interval.MINUTE;
            time_block_1.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.LONG_BREAK);
            time_block_2.set_time_range (time_block_1.end_time,
                                         time_block_1.end_time + 15 * Pomodoro.Interval.MINUTE);
            time_block_2.set_status (Pomodoro.TimeBlockStatus.SCHEDULED);
            time_block_2.set_intended_duration (15 * Pomodoro.Interval.MINUTE);
            time_block_2.set_completion_time (time_block_2.end_time);
            session.insert_after (time_block_2, time_block_1);

            Pomodoro.Timestamp.freeze_to (time_block_2.start_time);
            scheduler.reschedule_session (session, time_block_2, true, time_block_2.start_time);

            assert_cmpuint (
                session.count_time_blocks (),
                GLib.CompareOperator.EQ,
                2U
            );
            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                0U
            );
        }

        /**
         * Test rescheduling a session with in-progress time-blocks.
         */
        public void test_reschedule_session__in_progress_time_block ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = this.create_session (scheduler);

            var time_block_1 = session.get_nth_time_block (0);  // Pomodoro
            time_block_1.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
            time_block_1.set_intended_duration (time_block_1.duration);
            time_block_1.set_weight (1.0);

            var time_block_2 = session.get_nth_time_block (1);  // Short break
            time_block_2.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
            time_block_2.set_intended_duration (time_block_2.duration);
            time_block_2.set_weight (0.0);

            var time_block_3 = session.get_nth_time_block (2);  // Pomodoro
            time_block_3.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            time_block_3.set_intended_duration (time_block_3.duration);
            time_block_3.set_weight (1.0);

            // Reschedule session
            var now = time_block_3.end_time - Pomodoro.Interval.MINUTE;
            Pomodoro.Timestamp.freeze_to (now);
            scheduler.reschedule_session (session, null, true, now);

            var pomodoros_count = session.count_time_blocks (
                    time_block => time_block.state == Pomodoro.State.POMODORO);
            assert_cmpuint (pomodoros_count, GLib.CompareOperator.EQ, 4U);

            assert_cmpfloat_with_epsilon (
                time_block_3.get_weight (),
                1.0,
                EPSILON
            );
            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );
        }

        /**
         * Treat in-progress time-blocks as if they're going to be completed according to schedule.
         *
         * Note that we're passing `time_block.end_time` for a timestamp.
         */
        public void test_reschedule_session__paused_pomodoro ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = this.create_session (scheduler);

            var time_block = session.get_nth_time_block (0);  // Pomodoro
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            time_block.set_intended_duration (time_block.duration);
            time_block.set_weight (1.0);

            var gap = new Pomodoro.Gap.with_start_time (
                    time_block.start_time + Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap);

            // Reschedule session
            var timestamp = gap.start_time + 5 * Pomodoro.Interval.MINUTE;
            Pomodoro.Timestamp.freeze_to (timestamp);
            scheduler.reschedule_session (session, null, true, time_block.end_time);
            assert_cmpfloat_with_epsilon (
                time_block.get_weight (),
                1.0,
                EPSILON
            );
            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );
        }

        public void test_reschedule_session__paused_short_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = this.create_session (scheduler);

            var time_block_1 = session.get_nth_time_block (0);  // Pomodoro
            time_block_1.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
            time_block_1.set_intended_duration (time_block_1.duration);
            time_block_1.set_weight (1.0);

            var time_block_2 = session.get_nth_time_block (1);  // Short break
            time_block_2.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            time_block_2.set_intended_duration (time_block_2.duration);
            time_block_2.set_weight (0.0);

            var gap = new Pomodoro.Gap.with_start_time (
                    time_block_2.start_time + Pomodoro.Interval.MINUTE);
            time_block_2.add_gap (gap);

            // Reschedule session
            var timestamp = gap.start_time + 5 * Pomodoro.Interval.MINUTE;
            Pomodoro.Timestamp.freeze_to (timestamp);
            scheduler.reschedule_session (session, null, true, time_block_2.end_time);
            assert_cmpfloat_with_epsilon (
                time_block_2.get_weight (),
                0.0,
                EPSILON
            );
            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );
        }

        /**
         * Test rescheduling a session after a pomodoro has been extended by 1 minute.
         *
         * The extension is small, so the weight should remain 1.0 and visible cycles unchanged.
         */
        public void test_reschedule_session__extended_pomodoro_1x ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = this.create_session (scheduler);

            var time_block = session.get_nth_time_block (0);  // Pomodoro
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            time_block.set_intended_duration (this.session_template.pomodoro_duration);

            var now = time_block.end_time - 10 * Pomodoro.Interval.SECOND;
            time_block.end_time = now + Pomodoro.Interval.MINUTE;
            time_block.set_weight (scheduler.calculate_time_block_weight (time_block));

            Pomodoro.Timestamp.freeze_to (now);
            scheduler.reschedule_session (session, null, true, now);

            assert_cmpfloat (
                time_block.get_weight (),
                GLib.CompareOperator.EQ,
                1.0
            );
            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );
        }

        /**
         * Test rescheduling a session after a pomodoro has been extended, doubling its duration.
         *
         * The pomodoro is extended from 25 to 50 minutes (2x intended duration).
         * This should result in weight = 2.0 and one less visible cycle.
         */
        public void test_reschedule_session__extended_pomodoro_2x ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = this.create_session (scheduler);

            var time_block = session.get_nth_time_block (0);  // Pomodoro
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            time_block.set_intended_duration (this.session_template.pomodoro_duration);

            var now = time_block.end_time - 10 * Pomodoro.Interval.SECOND;
            time_block.end_time = now + time_block.duration;

            time_block.set_weight (scheduler.calculate_time_block_weight (time_block));

            Pomodoro.Timestamp.freeze_to (now);
            scheduler.reschedule_session (session, null, true, now);

            assert_cmpfloat (
                time_block.get_weight (),
                GLib.CompareOperator.EQ,
                2.0
            );
            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles - 1
            );
        }

        /**
         * Test restoring a session with all scheduled time-blocks.
         *
         * Expect meta fields to be updated for all time-blocks.
         */
        public void test_ensure_session_meta__scheduled ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = new Pomodoro.Session.from_template (this.session_template);

            scheduler.ensure_session_meta (session);

            session.@foreach (
                (time_block) => {
                    var meta = time_block.get_meta ();

                    if (time_block.state == Pomodoro.State.POMODORO) {
                        assert_cmpvariant (
                            new GLib.Variant.int64 (meta.intended_duration),
                            new GLib.Variant.int64 (this.session_template.pomodoro_duration)
                        );
                    }
                    else if (time_block.state == Pomodoro.State.SHORT_BREAK) {
                        assert_cmpvariant (
                            new GLib.Variant.int64 (meta.intended_duration),
                            new GLib.Variant.int64 (this.session_template.short_break_duration)
                        );
                    }
                    else if (time_block.state == Pomodoro.State.LONG_BREAK) {
                        assert_cmpvariant (
                            new GLib.Variant.int64 (meta.intended_duration),
                            new GLib.Variant.int64 (this.session_template.long_break_duration)
                        );
                    }

                    assert_true (Pomodoro.Timestamp.is_defined (meta.completion_time));
                    assert_true (meta.completion_time > time_block.start_time);
                    assert_true (meta.completion_time <= time_block.end_time);
                }
            );

            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );
        }

        /**
         * Test restoring session meta with completed time-blocks.
         *
         * Expect meta fields to be updated for completed time-blocks.
         */
        public void test_ensure_session_meta__completed ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = this.create_session (scheduler);

            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);
            time_block_1.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
            time_block_2.set_status (Pomodoro.TimeBlockStatus.COMPLETED);

            scheduler.ensure_session_meta (session);

            var meta_1 = time_block_1.get_meta ();
            assert_true (Pomodoro.Timestamp.is_defined (meta_1.completion_time));
            assert_cmpvariant (
                new GLib.Variant.int64 (meta_1.intended_duration),
                new GLib.Variant.int64 (this.session_template.pomodoro_duration)
            );

            var meta_2 = time_block_2.get_meta ();
            assert_true (Pomodoro.Timestamp.is_defined (meta_2.completion_time));

            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );
        }

        /**
         * Test restoring session meta with uncompleted time-blocks.
         */
        public void test_ensure_session_meta__uncompleted ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = this.create_session (scheduler);

            var time_block = session.get_nth_time_block (0);
            time_block.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            scheduler.ensure_session_meta (session);

            var meta = time_block.get_meta ();
            assert_true (Pomodoro.Timestamp.is_defined (meta.completion_time));
            assert_cmpvariant (
                new GLib.Variant.int64 (meta.intended_duration),
                new GLib.Variant.int64 (this.session_template.pomodoro_duration)
            );
            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles - 1
            );
        }

        /**
         * Test restoring session meta with in-progress time-blocks.
         */
        public void test_ensure_session_meta__in_progress ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = this.create_session (scheduler);

            var time_block = session.get_nth_time_block (0);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            scheduler.ensure_session_meta (session);

            var meta = time_block.get_meta ();
            assert_true (Pomodoro.Timestamp.is_defined (meta.completion_time));
            assert_cmpvariant (
                new GLib.Variant.int64 (meta.intended_duration),
                new GLib.Variant.int64 (this.session_template.pomodoro_duration)
            );
            assert_cmpuint (
                session.count_visible_cycles (),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );
        }

        /**
         * Test restoring session meta with time-blocks that have gaps.
         *
         * Expect completion time to account for gaps.
         */
        public void test_ensure_session_meta__with_gaps ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = new Pomodoro.Session ();

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (now, now + 35 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var gap = new Pomodoro.Gap ();
            gap.set_time_range (now + 5 * Pomodoro.Interval.MINUTE, now + 15 * Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap);

            session.append (time_block);

            scheduler.ensure_session_meta (session);

            var meta = time_block.get_meta ();
            // Completion time should be: start + 20 minutes (80% of 25) + 10 minutes (gap duration)
            assert_cmpvariant (
                new GLib.Variant.int64 (meta.completion_time),
                new GLib.Variant.int64 (now + 30 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpuint (session.count_visible_cycles (), GLib.CompareOperator.EQ, 1U);
        }

        /**
         * Test restoring session meta with mixed time-block states and edge cases.
         *
         * This is a more realistic test with:
         * - Some completed pomodoros with different durations
         * - An uncompleted pomodoro
         * - An in-progress break
         * - Scheduled time-blocks
         * - Time-blocks with gaps
         */
        public void test_ensure_session_meta__mixed_states ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = new Pomodoro.Session ();

            // Completed pomodoro with normal duration
            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_1.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            time_block_1.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
            session.append (time_block_1);

            // Completed short break
            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block_2.set_time_range (time_block_1.end_time, time_block_1.end_time + 5 * Pomodoro.Interval.MINUTE);
            time_block_2.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
            session.append (time_block_2);

            // Uncompleted pomodoro (was interrupted early)
            var time_block_3 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_3.set_time_range (time_block_2.end_time, time_block_2.end_time + 10 * Pomodoro.Interval.MINUTE);
            time_block_3.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);
            session.append (time_block_3);

            // In-progress pomodoro with a gap (pause)
            var time_block_4 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_4.set_time_range (time_block_3.end_time, time_block_3.end_time + 30 * Pomodoro.Interval.MINUTE);
            time_block_4.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            var gap = new Pomodoro.Gap ();
            gap.set_time_range (time_block_4.start_time + 10 * Pomodoro.Interval.MINUTE,
                               time_block_4.start_time + 15 * Pomodoro.Interval.MINUTE);
            time_block_4.add_gap (gap);
            session.append (time_block_4);

            // Scheduled short break
            var time_block_5 = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block_5.set_time_range (time_block_4.end_time, time_block_4.end_time + 5 * Pomodoro.Interval.MINUTE);
            time_block_5.set_status (Pomodoro.TimeBlockStatus.SCHEDULED);
            session.append (time_block_5);

            // Restore session
            scheduler.ensure_session_meta (session);

            // Verify all time-blocks have meta fields properly set
            var meta_1 = time_block_1.get_meta ();
            assert_cmpvariant (
                new GLib.Variant.int64 (meta_1.intended_duration),
                new GLib.Variant.int64 (this.session_template.pomodoro_duration)
            );
            assert_true (Pomodoro.Timestamp.is_defined (meta_1.completion_time));

            var meta_2 = time_block_2.get_meta ();
            assert_cmpvariant (
                new GLib.Variant.int64 (meta_2.intended_duration),
                new GLib.Variant.int64 (this.session_template.short_break_duration)
            );
            assert_true (Pomodoro.Timestamp.is_defined (meta_2.completion_time));

            // Uncompleted pomodoro should still have meta updated
            var meta_3 = time_block_3.get_meta ();
            assert_cmpvariant (
                new GLib.Variant.int64 (meta_3.intended_duration),
                new GLib.Variant.int64 (this.session_template.pomodoro_duration)
            );
            assert_true (Pomodoro.Timestamp.is_defined (meta_3.completion_time));

            // In-progress with gap should have completion time adjusted for gap
            var meta_4 = time_block_4.get_meta ();
            assert_cmpvariant (
                new GLib.Variant.int64 (meta_4.intended_duration),
                new GLib.Variant.int64 (this.session_template.pomodoro_duration)
            );
            assert_true (Pomodoro.Timestamp.is_defined (meta_4.completion_time));
            // Completion should be after the gap ends
            assert_true (meta_4.completion_time > gap.end_time);

            // Scheduled break
            var meta_5 = time_block_5.get_meta ();
            assert_cmpvariant (
                new GLib.Variant.int64 (meta_5.intended_duration),
                new GLib.Variant.int64 (this.session_template.short_break_duration)
            );
            assert_true (Pomodoro.Timestamp.is_defined (meta_5.completion_time));

            // Verify session structure is intact (no time-blocks removed)
            Pomodoro.TimeBlock[] time_blocks = {};
            session.@foreach ((time_block) => {
                time_blocks += time_block;
            });
            assert_cmpuint (time_blocks.length, GLib.CompareOperator.EQ, 5);
            assert_cmpuint (session.count_visible_cycles (), GLib.CompareOperator.EQ, 2U);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.SimpleSchedulerTest ()
    );
}
