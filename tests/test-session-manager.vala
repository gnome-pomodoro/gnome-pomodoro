namespace Tests
{
    // private int count_pomodoros (Pomodoro.Session session)
    // {
    //     var pomodoro_count = 0;
    //     session_manager.current_session.@foreach ((time_block) => {
    //         if (time_block.state == Pomodoro.State.POMODRO)
    //         pomodoro_count += 1;
    //     });
    // }


    private uint8[] list_session_states (Pomodoro.Session session)
    {
        uint8[] states = {};

        session.@foreach ((time_block) => {
            states += (uint8) time_block.state;
        });

        return states;
    }


    public class SessionManagerTest : Tests.TestSuite
    {
        private const uint POMODORO_DURATION = 1500;
        private const uint SHORT_BREAK_DURATION = 300;
        private const uint LONG_BREAK_DURATION = 900;
        private const uint POMODOROS_PER_SESSION = 4;

        private Pomodoro.Timer default_timer;

        public SessionManagerTest ()
        {
            this.add_test ("new", this.test_new);
            this.add_test ("new_with_timer", this.test_new_with_timer);

            // this.add_test ("set_current_session", this.test_set_current_session);
            // this.add_test ("set_current_time_block", this.test_set_current_time_block);

            // this.add_test ("timer_set_state", this.test_timer_set_state);
            // this.add_test ("timer_set_duration", this.test_timer_set_duration);
            this.add_test ("timer_start__initialize_session", this.test_timer_start__initialize_session);
            // this.add_test ("timer_pause", this.test_timer_pause);
            // this.add_test ("timer_reset", this.test_timer_reset);
            // this.add_test ("timer_skip", this.test_timer_reset);
            // this.add_test ("timer_rewind", this.test_timer_reset);
            // this.add_test ("timer_suspended", this.test_timer_suspended);

            // Default timer needs to be referenced somewhere
            this.default_timer = new Pomodoro.Timer ();
            this.default_timer.set_default ();
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze (2000000000 * Pomodoro.Interval.SECOND);

            var settings = Pomodoro.get_settings ();
            settings.set_uint ("pomodoro-duration", POMODORO_DURATION);
            settings.set_uint ("short-break-duration", SHORT_BREAK_DURATION);
            settings.set_uint ("long-break-duration", LONG_BREAK_DURATION);
            settings.set_uint ("pomodoros-per-session", POMODOROS_PER_SESSION);
            // settings.set_boolean ("pause-when-idle", false);
        }

        public override void teardown ()
        {
            var settings = Pomodoro.get_settings ();
            settings.revert ();
        }


        /*
         * Tests for constructors
         */

        public void test_new ()
        {
            var session_manager = new Pomodoro.SessionManager ();

            assert_true (session_manager.timer == this.default_timer);
            assert_true (session_manager.timer.is_default ());
            assert_false (session_manager.timer.is_started ());
            assert_false (session_manager.timer.is_running ());

            assert_null (session_manager.current_session);
            assert_null (session_manager.current_time_block);
        }

        public void test_new_with_timer ()
        {
            var timer = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            assert_true (session_manager.timer == timer);
            assert_false (session_manager.timer.is_default ());
            assert_false (session_manager.timer.is_started ());
            assert_false (session_manager.timer.is_running ());

            assert_null (session_manager.current_session);
            assert_null (session_manager.current_time_block);
        }


        /*
         * Tests for properties
         */

        public void test_set_current_session ()
        {
            var session = new Pomodoro.Session.empty ();

            var session_manager = new Pomodoro.SessionManager ();
        }

        public void test_set_current_time_block ()
        {
            var session    = new Pomodoro.Session.empty ();
            var time_block = session.get_first_time_block ();
            assert_true (time_block.session == session);

            var timer = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var notify_current_time_block_emitted = 0;
            session_manager.notify["current-time-block"].connect (() => {
                notify_current_time_block_emitted++;
            });

            var notify_current_session_emitted = 0;
            session_manager.notify["current-session"].connect (() => {
                notify_current_session_emitted++;
            });

            // Set new time-block. Expect notify signals to be emitted
            session_manager.current_time_block = time_block;
            // assert_cmpvariant (
            //     time_block.to_timer_state ().to_variant (),
            //     timer.state.to_variant ()
            // );
            // assert_true (timer.duration == time_block.state_duration);
            // assert_true (timer.timestamp == time_block.start);
            // assert_true (timer.offset == 0);
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 1);

            // Set current time-block. Expect signals not to be emitted
            notify_current_time_block_emitted = 0;
            notify_current_session_emitted = 0;
            session_manager.current_time_block = session_manager.current_time_block;
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 0);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 0);

            // Set new time-block within same session. Expect notify["current-session"] not to be emitted
            notify_current_time_block_emitted = 0;
            notify_current_session_emitted = 0;
            session_manager.current_time_block = session_manager.current_time_block;
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 0);

            // Set current time-block with new session. Expect notify["current-session"] to be emitted
            notify_current_time_block_emitted = 0;
            notify_current_session_emitted = 0;
            session_manager.current_time_block = session_manager.current_time_block;
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 1);
        }


        /*
         * Tests for methods
         */

        // public void test_initialize_session ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            // TODO
        // }

        // public void test_advance_to ()
        // {
            // TODO
        // }

        // public void test_advance ()
        // {
            // TODO
        // }


        /*
         * Tests for calls performed on timer
         */

        public void test_timer_start__initialize_session ()
        {
            var timer = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            timer.start ();

            assert_nonnull (session_manager.current_session);
            assert_cmpmem (
                list_session_states (session_manager.current_session),
                {
                    Pomodoro.State.POMODORO,
                    Pomodoro.State.SHORT_BREAK,
                    Pomodoro.State.POMODORO,
                    Pomodoro.State.SHORT_BREAK,
                    Pomodoro.State.POMODORO,
                    Pomodoro.State.SHORT_BREAK,
                    Pomodoro.State.POMODORO,
                    Pomodoro.State.LONG_BREAK
                }
            );

            assert_nonnull (session_manager.current_time_block);
            assert_true (session_manager.current_time_block == session_manager.current_session.get_first_time_block ());
            assert_true (session_manager.current_time_block.state == Pomodoro.State.POMODORO);

            // TODO: check enter_time_block signal
            // TODO: check leave_time_block signal

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.duration),
                new GLib.Variant.int64 (POMODORO_DURATION * Pomodoro.Interval.SECOND)
            );
            assert_true (session_manager.timer.is_started ());
            assert_true (session_manager.timer.is_running ());
            assert_true (session_manager.timer.user_data == session_manager.current_time_block);

            // Try to call timer.start() after a while. Expect call to be ignored.
            // var session_manager.current_time_block

            // Pomodoro.Timestamp.tick (Pomodro.Interval.MINUTE);
            // timer.start ();

            // session_manager.current_time_block
        }

        // public void test_timer_stop ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     var session_manager = new Pomodoro.SessionManager.with_timer (timer);

        // }

        // public void test_timer_pause ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     var session_manager = new Pomodoro.SessionManager.with_timer (timer);

        // }

        // public void test_timer_resume ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     var session_manager = new Pomodoro.SessionManager.with_timer (timer);

        // }

        // public void test_timer_rewind ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     var session_manager = new Pomodoro.SessionManager.with_timer (timer);

        // }

        // public void test_timer_skip ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     var session_manager = new Pomodoro.SessionManager.with_timer (timer);

        // }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.SessionManagerTest ()
    );
}
