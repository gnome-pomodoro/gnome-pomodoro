namespace Tests
{
    private class MockNotificationBackend : GLib.Object, Pomodoro.NotificationBackend
    {
        public string[] log;

        construct
        {
            this.log = {};
        }

        public void withdraw_notification (string id)
        {
            this.log += @"withdraw:$(id)";
        }

        public void send_notification (string?           id,
                                       GLib.Notification notification)
        {
            var hash = notification.get_data<string> ("hash");

            this.log += @"send:$(id):$(hash)";
        }

        public void clear ()
        {
            this.log = {};
        }

        public override void dispose ()
        {
            this.log = null;

            base.dispose ();
        }
    }


    public class NotificationManagerTest : Tests.MainLoopTestSuite
    {
        private Pomodoro.Timer timer;
        private Pomodoro.SessionManager session_manager;
        private Pomodoro.NotificationManager notification_manager;

        public NotificationManagerTest ()
        {
            this.add_test ("time_block_started", this.test_time_block_started);
            this.add_test ("time_block_running", this.test_time_block_running);
            this.add_test ("time_block_about_to_end", this.test_time_block_about_to_end);
            this.add_test ("time_block_ended", this.test_time_block_ended);
            this.add_test ("confirm_advancement__break", this.test_confirm_advancement__break);
            this.add_test ("confirm_advancement__pomodoro", this.test_confirm_advancement__pomodoro);
            this.add_test ("withdraw_notifications__pause", this.test_withdraw_notifications__pause);
            this.add_test ("withdraw_notifications__stop", this.test_withdraw_notifications__stop);
            this.add_test ("request_screen_overlay", this.test_request_screen_overlay);
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze_to (2000000000 * Pomodoro.Interval.SECOND);
            Pomodoro.Timestamp.set_auto_advance (Pomodoro.Interval.MICROSECOND);

            this.timer = new Pomodoro.Timer ();
            Pomodoro.Timer.set_default (this.timer);

            this.session_manager = new Pomodoro.SessionManager.with_timer (this.timer);
            Pomodoro.SessionManager.set_default (this.session_manager);

            this.notification_manager = new Pomodoro.NotificationManager.with_backend (
                    new MockNotificationBackend ());
            assert (!this.notification_manager.get_data<bool> ("teardown"));

            var settings = Pomodoro.get_settings ();
            settings.set_uint ("pomodoro-duration", 1500);
            settings.set_uint ("short-break-duration", 300);
            settings.set_uint ("long-break-duration", 900);
            settings.set_uint ("cycles", 4);
            settings.set_boolean ("announce-about-to-end", false);
            settings.set_boolean ("confirm-starting-break", false);
            settings.set_boolean ("confirm-starting-pomodoro", false);
            settings.set_boolean ("screen-overlay", false);

            this.session_manager.ensure_session ();
        }

        public override void teardown ()
        {
            this.notification_manager.set_data<bool> ("teardown", true);
            this.notification_manager.destroy ();

            this.notification_manager = null;
            this.session_manager = null;
            this.timer = null;

            Pomodoro.SessionManager.set_default (null);
            Pomodoro.Timer.set_default (null);

            base.teardown ();
        }

        private MockNotificationBackend get_mock_backend ()
        {
            return this.notification_manager.backend as MockNotificationBackend;
        }

        public void test_time_block_started ()
        {
            var backend = this.get_mock_backend ();
            backend.clear ();

            this.timer.start ();
            assert_cmpstrv (backend.log, {
                "send:timer:pomodoro:time-block-started"
            });
        }

        public void test_time_block_running ()
        {
            this.timer.start ();

            // Pause and resume to trigger notify_time_block_running
            Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);

            var backend = this.get_mock_backend ();
            backend.clear ();

            this.timer.pause ();
            assert_cmpstrv (backend.log, {
                "withdraw:timer"
            });

            backend.clear ();
            this.timer.resume ();
            assert_cmpstrv (backend.log, {
                "send:timer:pomodoro:time-block-running:-1"
            });
        }

        public void test_time_block_about_to_end ()
        {
            var settings = Pomodoro.get_settings ();
            settings.set_boolean ("announce-about-to-end", true);

            this.timer.start ();

            var backend = this.get_mock_backend ();
            backend.clear ();

            var time_block = this.session_manager.current_time_block;

            // Advance time to just BEFORE about-to-end threshold
            var timestamp_1 = time_block.end_time - 16 * Pomodoro.Interval.SECOND;
            Pomodoro.Timestamp.freeze_to (timestamp_1);
            this.timer.tick (timestamp_1);
            assert_cmpint (backend.log.length, GLib.CompareOperator.EQ, 0);

            // Advance time into the threshold
            var timestamp_2 = time_block.end_time - 10 * Pomodoro.Interval.SECOND;
            Pomodoro.Timestamp.freeze_to (timestamp_2);
            this.timer.tick (timestamp_2);
            assert_cmpstrv (backend.log, {
                @"send:timer:pomodoro:time-block-about-to-end:$(timestamp_2)"
            });

            // Another tick should NOT trigger another notification
            backend.clear ();
            var timestamp_3 = time_block.end_time - 9 * Pomodoro.Interval.SECOND;
            Pomodoro.Timestamp.freeze_to (timestamp_3);
            this.timer.tick (timestamp_3);
            assert_cmpstrv (backend.log, {});
        }

        public void test_time_block_ended ()
        {
            var settings = Pomodoro.get_settings ();
            settings.set_boolean ("confirm-starting-pomodoro", false);

            this.session_manager.advance_to_state (Pomodoro.State.SHORT_BREAK);

            var backend = this.get_mock_backend ();
            backend.clear ();

            var now = this.session_manager.current_time_block.end_time;
            Pomodoro.Timestamp.freeze_to (now);
            this.timer.finish (now);
            assert_cmpstrv (backend.log, {
                "send:timer:short-break:time-block-ended"
            });
        }

        public void test_confirm_advancement__break ()
        {
            var settings = Pomodoro.get_settings ();
            settings.set_boolean ("confirm-starting-break", true);

            this.session_manager.advance_to_state (Pomodoro.State.POMODORO);

            var backend = this.get_mock_backend ();
            backend.clear ();

            var confirm_advancement_emitted = 0;

            this.session_manager.confirm_advancement.connect (
                (current_time_block, next_time_block) => {
                    confirm_advancement_emitted++;
                });

            var now = this.session_manager.current_time_block.end_time;
            Pomodoro.Timestamp.freeze_to (now);
            this.timer.finish (now);
            assert_cmpint (
                confirm_advancement_emitted,
                GLib.CompareOperator.EQ,
                1
            );
            assert_cmpstrv (backend.log, {
                "send:timer:pomodoro:confirm-advancement"
            });
        }

        public void test_confirm_advancement__pomodoro ()
        {
            var settings = Pomodoro.get_settings ();
            settings.set_boolean ("confirm-starting-pomodoro", true);

            this.session_manager.advance_to_state (Pomodoro.State.SHORT_BREAK);

            var backend = this.get_mock_backend ();
            backend.clear ();

            var confirm_advancement_emitted = 0;

            this.session_manager.confirm_advancement.connect (
                (current_time_block, next_time_block) => {
                    confirm_advancement_emitted++;
                });

            var now = this.session_manager.current_time_block.end_time;
            Pomodoro.Timestamp.freeze_to (now);
            this.timer.finish (now);
            assert_cmpint (
                confirm_advancement_emitted,
                GLib.CompareOperator.EQ,
                1
            );
            assert_cmpstrv (backend.log, {
                "send:timer:short-break:confirm-advancement"
            });
        }

        public void test_withdraw_notifications__pause ()
        {
            this.session_manager.advance_to_state (Pomodoro.State.POMODORO);

            var backend = this.get_mock_backend ();
            backend.clear ();

            this.timer.pause ();
            assert_cmpstrv (backend.log, {
                "withdraw:timer"
            });
        }

        public void test_withdraw_notifications__stop ()
        {
            this.session_manager.advance_to_state (Pomodoro.State.POMODORO);

            var backend = this.get_mock_backend ();
            backend.clear ();

            this.timer.reset ();
            assert_cmpstrv (backend.log, {
                "withdraw:timer"
            });
        }

        public void test_request_screen_overlay ()
        {
            var settings = Pomodoro.get_settings ();
            settings.set_boolean ("screen-overlay", true);

            var backend = this.get_mock_backend ();

            var open_requested = false;

            this.notification_manager.request_screen_overlay_open.connect (() => {
                open_requested = true;
            });

            this.session_manager.advance_to_state (Pomodoro.State.POMODORO);
            backend.clear ();

            this.session_manager.advance_to_state (Pomodoro.State.SHORT_BREAK);
            assert_true (open_requested);
            assert_cmpstrv (backend.log, {});

            // Simulate overlay opened
            this.notification_manager.screen_overlay_opened ();
            assert_cmpstrv (backend.log, {
                "withdraw:timer"
            });

            // Simulate overlay closed
            var tick_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            this.timer.tick (tick_time);
            backend.clear ();
            this.notification_manager.screen_overlay_closed ();
            assert_cmpstrv (backend.log, {
                @"send:timer:short-break:time-block-running:$(tick_time)"
            });
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.NotificationManagerTest ()
    );
}
