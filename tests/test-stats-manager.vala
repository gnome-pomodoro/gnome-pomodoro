namespace Tests
{
    public class StatsManagerTest : Tests.TestSuite
    {
        private Pomodoro.StatsManager?    stats_manager;
        private Pomodoro.TimezoneHistory? timezone_history;
        private Gom.Repository?           repository;
        private GLib.TimeZone?            new_york_timezone;
        private GLib.TimeZone?            london_timezone;
        private GLib.TimeZone?            los_angeles_timezone;
        private GLib.MainLoop?            main_loop;
        private uint                      timeout_id = 0;

        private weak Pomodoro.StatsManager? previous_stats_manager;

        public StatsManagerTest ()
        {
            this.add_test ("track", this.test_track);
            this.add_test ("track__update", this.test_track__update);

            this.add_test ("track_time_block__pomodoro",
                           this.test_track_time_block__pomodoro);
            this.add_test ("track_time_block__break",
                           this.test_track_time_block__break);
            this.add_test ("track_time_block__skip_unfinished",
                           this.test_track_time_block__skip_unfinished);
            this.add_test ("track_time_block__update",
                           this.test_track_time_block__update);

            this.add_test ("track_gap",
                           this.test_track_gap);
            this.add_test ("track_gap__skip_unfinished",
                           this.test_track_gap__skip_unfinished);
            this.add_test ("track_gap__skip_non_pomodoro",
                           this.test_track_gap__skip_non_pomodoro);
            this.add_test ("track_gap__skip_start",
                           this.test_track_gap__skip_start);
            this.add_test ("track_gap__skip_end",
                           this.test_track_gap__skip_end);
            this.add_test ("gap__update",
                           this.test_gap__update);

            this.add_test ("midnight_split__before_true_midnight",
                           this.test_midnight_split__before_true_midnight);
            this.add_test ("midnight_split__after_true_midnight",
                           this.test_midnight_split__after_true_midnight);
            this.add_test ("midnight_split__multiple_days",
                           this.test_midnight_split__multiple_days);
            this.add_test ("timezone_change__forward",
                           this.test_timezone_change__forward);
            this.add_test ("timezone_change__backward",
                           this.test_timezone_change__backward);
            this.add_test ("dst_change__forward",
                           this.test_dst_change__forward);
            this.add_test ("dst_change__backward",
                           this.test_dst_change__backward);
        }

        public override void setup ()
        {
            // Sat January 01 2000 08:00:00 UTC
            Pomodoro.Timestamp.freeze_to (Pomodoro.Timestamp.from_seconds_uint (946713600));

            var settings = Pomodoro.get_settings ();
            settings.set_uint ("pomodoro-duration", 1500);
            settings.set_uint ("short-break-duration", 300);
            settings.set_uint ("long-break-duration", 900);
            settings.set_uint ("cycles", 4);
            settings.set_boolean ("confirm-starting-break", false);
            settings.set_boolean ("confirm-starting-pomodoro", false);

            Pomodoro.Database.open ();

            debug ("@@@ A");

            try {
                this.new_york_timezone = new GLib.TimeZone.identifier ("America/New_York");  // 3 AM
                this.london_timezone = new GLib.TimeZone.identifier ("Europe/London");  // 8 AM
                this.los_angeles_timezone = new GLib.TimeZone.identifier ("America/Los_Angeles");  // 0 AM
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }

            debug ("@@@ B");

            this.main_loop = new GLib.MainLoop ();

            this.timezone_history = new Pomodoro.TimezoneHistory ();
            this.timezone_history.insert (Pomodoro.Timestamp.peek (), this.new_york_timezone);

            debug ("@@@ C");

            this.stats_manager = new Pomodoro.StatsManager ();
            assert (this.stats_manager != this.previous_stats_manager);

            debug ("@@@ D");

            this.repository = Pomodoro.Database.get_repository ();

            debug ("@@@ E");
        }

        public override void teardown ()
        {
            this.timezone_history.clear_cache ();

            this.previous_stats_manager = this.stats_manager;
            this.stats_manager = null;
            this.timezone_history = null;
            this.repository = null;
            this.main_loop = null;

            Pomodoro.SessionManager.set_default (null);
            Pomodoro.Timer.set_default (null);
            Pomodoro.Database.close ();

            var settings = Pomodoro.get_settings ();
            settings.revert ();
        }

        private bool run_main_loop (uint timeout = 1000)
                                    requires (this.timeout_id == 0)
        {
            var success = true;

            this.timeout_id = GLib.Timeout.add (timeout, () => {
                this.timeout_id = 0;
                this.main_loop.quit ();

                success = false;

                return GLib.Source.REMOVE;
            });

            this.main_loop.run ();

            return success;
        }

        private void quit_main_loop ()
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            this.main_loop.quit ();
        }

        private void run_flush ()
        {
            this.stats_manager.flush.begin (
                (obj, res) => {
                    this.stats_manager.flush.end (res);

                    this.quit_main_loop ();
                });

            assert_true (this.run_main_loop ());
        }

        public void test_track ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 7, 0, 0));

            this.stats_manager.track ("test", timestamp, Pomodoro.Interval.MINUTE);

            this.run_flush ();

            try {
                Gom.ResourceGroup results;

                results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1U);

                var stats_entry = (Pomodoro.StatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.StatsEntry), null);
                assert_cmpstr (
                        stats_entry.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry.offset),
                        new GLib.Variant.int64 (7 * Pomodoro.Interval.HOUR));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry.duration),
                        new GLib.Variant.int64 (Pomodoro.Interval.MINUTE));

                // Expect aggregated entries to be up to date
                results = this.repository.find_sync (typeof (Pomodoro.AggregatedStatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1U);

                var aggregated_entry = (Pomodoro.AggregatedStatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.AggregatedStatsEntry), null);
                assert_cmpstr (
                        aggregated_entry.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        aggregated_entry.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (aggregated_entry.duration),
                        new GLib.Variant.int64 (Pomodoro.Interval.MINUTE));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_track__update ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 12, 0, 0));

            this.stats_manager.track (  // entry to keep
                    "test",
                    timestamp - 1,
                    Pomodoro.Interval.MINUTE);
            this.stats_manager.track (
                    "test",
                    timestamp,
                    5 * Pomodoro.Interval.MINUTE);
            this.run_flush ();

            this.stats_manager.track (
                    "test",
                    timestamp,
                    6 * Pomodoro.Interval.MINUTE);
            this.run_flush ();

            try {
                var results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2);

                var time_value = GLib.Value (typeof (int64));
                time_value.set_int64 (timestamp);

                var time_filter = new Gom.Filter.eq (
                        typeof (Pomodoro.StatsEntry),
                        "time",
                        time_value);

                var stats_entry = (Pomodoro.StatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.StatsEntry), time_filter);
                assert_cmpstr (
                        stats_entry.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry.duration),
                        new GLib.Variant.int64 (6 * Pomodoro.Interval.MINUTE));

                var aggregated_entry = (Pomodoro.AggregatedStatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.AggregatedStatsEntry), null);
                assert_cmpstr (
                        aggregated_entry.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpvariant (
                        new GLib.Variant.int64 (aggregated_entry.duration),
                        new GLib.Variant.int64 ((1 + 6) * Pomodoro.Interval.MINUTE));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_track_time_block__pomodoro ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 7, 0, 0));

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (timestamp, timestamp + 5 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);

            var gap = new Pomodoro.Gap ();
            gap.set_time_range (timestamp + 1 * Pomodoro.Interval.MINUTE,
                                timestamp + 3 * Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            this.stats_manager.track_time_block (time_block);

            this.run_flush ();

            // Expect two entries for each continuous segment of pomodoro separated by a gap
            try {
                Gom.ResourceGroup results;

                var sorting = (Gom.Sorting) GLib.Object.@new (typeof (Gom.Sorting));
                sorting.add (typeof (Pomodoro.StatsEntry), "time", Gom.SortingMode.ASCENDING);

                results = this.repository.find_sorted_sync (typeof (Pomodoro.StatsEntry),
                                                            null,
                                                            sorting);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2U);

                results.fetch_sync (0U, results.count);

                var stats_entry_1 = (Pomodoro.StatsEntry?) results.get_index (0U);
                assert_cmpstr (
                        stats_entry_1.category,
                        GLib.CompareOperator.EQ,
                        "pomodoro");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.time),
                        new GLib.Variant.int64 (time_block.start_time));
                assert_cmpstr (
                        stats_entry_1.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.offset),
                        new GLib.Variant.int64 (7 * Pomodoro.Interval.HOUR));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.duration),
                        new GLib.Variant.int64 (1 * Pomodoro.Interval.MINUTE));

                var stats_entry_2 = (Pomodoro.StatsEntry?) results.get_index (1U);
                assert_cmpstr (
                        stats_entry_2.category,
                        GLib.CompareOperator.EQ,
                        "pomodoro");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.time),
                        new GLib.Variant.int64 (gap.end_time));
                assert_cmpstr (
                        stats_entry_2.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.offset),
                        new GLib.Variant.int64 (7 * Pomodoro.Interval.HOUR +
                                                3 * Pomodoro.Interval.MINUTE));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.duration),
                        new GLib.Variant.int64 (2 * Pomodoro.Interval.MINUTE));

                // Expect aggregated entries to be up to date
                results = this.repository.find_sync (typeof (Pomodoro.AggregatedStatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1U);

                var aggregated_entry = (Pomodoro.AggregatedStatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.AggregatedStatsEntry), null);
                assert_cmpstr (
                        aggregated_entry.category,
                        GLib.CompareOperator.EQ,
                        "pomodoro");
                assert_cmpstr (
                        aggregated_entry.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (aggregated_entry.duration),
                        new GLib.Variant.int64 (3 * Pomodoro.Interval.MINUTE));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Expect various brake types to be treated as just "break".
         */
        public void test_track_time_block__break ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 7, 0, 0));

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block.set_time_range (timestamp, timestamp + 5 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);

            var gap = new Pomodoro.Gap ();
            gap.set_time_range (timestamp + 1 * Pomodoro.Interval.MINUTE,
                                timestamp + 3 * Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            this.stats_manager.track_time_block (time_block);

            this.run_flush ();

            // Expect two entries for each continuous segment of break separated by a gap
            try {
                Gom.ResourceGroup results;

                var sorting = (Gom.Sorting) GLib.Object.@new (typeof (Gom.Sorting));
                sorting.add (typeof (Pomodoro.StatsEntry), "time", Gom.SortingMode.ASCENDING);

                results = this.repository.find_sorted_sync (typeof (Pomodoro.StatsEntry),
                                                            null,
                                                            sorting);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2U);

                results.fetch_sync (0U, results.count);

                var stats_entry_1 = (Pomodoro.StatsEntry?) results.get_index (0U);
                assert_cmpstr (
                        stats_entry_1.category,
                        GLib.CompareOperator.EQ,
                        "break");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.time),
                        new GLib.Variant.int64 (time_block.start_time));
                assert_cmpstr (
                        stats_entry_1.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.offset),
                        new GLib.Variant.int64 (7 * Pomodoro.Interval.HOUR));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.duration),
                        new GLib.Variant.int64 (1 * Pomodoro.Interval.MINUTE));

                var stats_entry_2 = (Pomodoro.StatsEntry?) results.get_index (1U);
                assert_cmpstr (
                        stats_entry_2.category,
                        GLib.CompareOperator.EQ,
                        "break");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.time),
                        new GLib.Variant.int64 (gap.end_time));
                assert_cmpstr (
                        stats_entry_2.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.offset),
                        new GLib.Variant.int64 (7 * Pomodoro.Interval.HOUR +
                                                3 * Pomodoro.Interval.MINUTE));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.duration),
                        new GLib.Variant.int64 (2 * Pomodoro.Interval.MINUTE));

                // Expect aggregated entries to be up to date
                results = this.repository.find_sync (typeof (Pomodoro.AggregatedStatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1U);

                var aggregated_entry = (Pomodoro.AggregatedStatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.AggregatedStatsEntry), null);
                assert_cmpstr (
                        aggregated_entry.category,
                        GLib.CompareOperator.EQ,
                        "break");
                assert_cmpstr (
                        aggregated_entry.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (aggregated_entry.duration),
                        new GLib.Variant.int64 (3 * Pomodoro.Interval.MINUTE));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Only track interruptions that have been finished.
         */
        public void test_track_time_block__skip_unfinished ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 7, 0, 0));

            var time_block = new Pomodoro.TimeBlock.with_start_time (timestamp,
                                                                     Pomodoro.State.POMODORO);
            time_block.end_time = Pomodoro.Timestamp.UNDEFINED;

            var session = new Pomodoro.Session ();
            session.append (time_block);

            this.stats_manager.track_time_block (time_block);

            try {
                var results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 0U);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_track_time_block__update ()
        {
            Pomodoro.StatsEntry? original_stats_entry = null;

            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 7, 0, 0));

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (timestamp, timestamp + 5 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            this.stats_manager.track_time_block (time_block);
            this.run_flush ();

            try {
                original_stats_entry = (Pomodoro.StatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.StatsEntry), null);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }

            // Edit pomodoro
            time_block.set_time_range (timestamp, timestamp + 9 * Pomodoro.Interval.MINUTE);

            var gap = new Pomodoro.Gap ();
            gap.set_time_range (timestamp + 4 * Pomodoro.Interval.MINUTE,
                                timestamp + 6 * Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap);

            this.stats_manager.track_time_block (time_block);
            this.run_flush ();

            try {
                Gom.ResourceGroup results;

                results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2U);

                results.fetch_sync (0U, results.count);

                var stats_entry_1 = (Pomodoro.StatsEntry?) results.get_index (0U);
                assert_cmpstr (
                        stats_entry_1.category,
                        GLib.CompareOperator.EQ,
                        "pomodoro");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.source_id),
                        new GLib.Variant.int64 (original_stats_entry.source_id));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.id),
                        new GLib.Variant.int64 (original_stats_entry.id));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.duration),
                        new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.offset),
                        new GLib.Variant.int64 (7 * Pomodoro.Interval.HOUR));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.time),
                        new GLib.Variant.int64 (time_block.start_time));

                var stats_entry_2 = (Pomodoro.StatsEntry?) results.get_index (1U);
                assert_cmpstr (
                        stats_entry_2.category,
                        GLib.CompareOperator.EQ,
                        "pomodoro");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.source_id),
                        new GLib.Variant.int64 (original_stats_entry.source_id));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.duration),
                        new GLib.Variant.int64 (3 * Pomodoro.Interval.MINUTE));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.offset),
                        new GLib.Variant.int64 (7 * Pomodoro.Interval.HOUR +
                                                6 * Pomodoro.Interval.MINUTE));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.time),
                        new GLib.Variant.int64 (gap.end_time));

                results = this.repository.find_sync (typeof (Pomodoro.AggregatedStatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1U);

                var aggregated_entry = (Pomodoro.AggregatedStatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.AggregatedStatsEntry), null);
                assert_cmpstr (
                        aggregated_entry.category,
                        GLib.CompareOperator.EQ,
                        "pomodoro");
                assert_cmpvariant (
                        new GLib.Variant.int64 (aggregated_entry.duration),
                        new GLib.Variant.int64 (7 * Pomodoro.Interval.MINUTE));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_track_gap ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 7, 0, 0));

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (timestamp, timestamp + 30 * Pomodoro.Interval.MINUTE);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            var gap = new Pomodoro.Gap ();
            gap.set_time_range (time_block.start_time + 4 * Pomodoro.Interval.MINUTE,
                                time_block.start_time + 5 * Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap);

            this.stats_manager.track_gap (gap);

            this.run_flush ();

            try {
                Gom.ResourceGroup results;

                results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1U);

                var stats_entry = (Pomodoro.StatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.StatsEntry), null);
                assert_cmpstr (
                        stats_entry.category,
                        GLib.CompareOperator.EQ,
                        "interruption");
                assert_cmpstr (
                        stats_entry.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry.offset),
                        new GLib.Variant.int64 (7 * Pomodoro.Interval.HOUR +
                                                4 * Pomodoro.Interval.MINUTE));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry.duration),
                        new GLib.Variant.int64 (Pomodoro.Interval.MINUTE));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Only track interruptions that have been finished.
         */
        public void test_track_gap__skip_unfinished ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 7, 0, 0));

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (timestamp, timestamp + 30 * Pomodoro.Interval.MINUTE);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            var gap = new Pomodoro.Gap.with_start_time (time_block.start_time + 4 * Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap);

            this.stats_manager.track_gap (gap);

            this.run_flush ();

            try {
                var results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 0U);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Only track interruptions for work / pomodoro.
         */
        public void test_track_gap__skip_non_pomodoro ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 7, 0, 0));

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
            time_block.set_time_range (timestamp, timestamp + 30 * Pomodoro.Interval.MINUTE);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            var gap = new Pomodoro.Gap ();
            gap.set_time_range (time_block.start_time + 4 * Pomodoro.Interval.MINUTE,
                                time_block.start_time + 5 * Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap);

            this.stats_manager.track_gap (gap);

            this.run_flush ();

            try {
                var results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 0U);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Don't count gaps at the start of a time-block as interruption.
         */
        public void test_track_gap__skip_start ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 7, 0, 0));

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (timestamp, timestamp + 30 * Pomodoro.Interval.MINUTE);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            var gap = new Pomodoro.Gap ();
            gap.set_time_range (time_block.start_time,
                                time_block.start_time + Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap);

            this.stats_manager.track_gap (gap);

            this.run_flush ();

            try {
                var results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 0U);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Don't count gaps at the end of a time-block as interruption.
         */
        public void test_track_gap__skip_end ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 7, 0, 0));

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (timestamp, timestamp + 30 * Pomodoro.Interval.MINUTE);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            var gap = new Pomodoro.Gap ();
            gap.set_time_range (time_block.end_time - Pomodoro.Interval.MINUTE,
                                time_block.end_time);
            time_block.add_gap (gap);

            this.stats_manager.track_gap (gap);

            this.run_flush ();

            try {
                var results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 0U);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_gap__update ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 12, 0, 0));

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (timestamp, timestamp + 30 * Pomodoro.Interval.MINUTE);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            var gap = new Pomodoro.Gap ();
            gap.set_time_range (time_block.start_time + 4 * Pomodoro.Interval.MINUTE,
                                time_block.start_time + 5 * Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap);

            this.stats_manager.track_gap (gap);
            this.run_flush ();

            gap.set_time_range (time_block.start_time + 4 * Pomodoro.Interval.MINUTE,
                                time_block.start_time + 6 * Pomodoro.Interval.MINUTE);
            this.stats_manager.track_gap (gap);
            this.run_flush ();

            try {
                var results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                var stats_entry = (Pomodoro.StatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.StatsEntry), null);
                assert_cmpstr (
                        stats_entry.category,
                        GLib.CompareOperator.EQ,
                        "interruption");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry.duration),
                        new GLib.Variant.int64 (2 * Pomodoro.Interval.MINUTE));

                var aggregated_entry = (Pomodoro.AggregatedStatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.AggregatedStatsEntry), null);
                assert_cmpstr (
                        aggregated_entry.category,
                        GLib.CompareOperator.EQ,
                        "interruption");
                assert_cmpvariant (
                        new GLib.Variant.int64 (aggregated_entry.duration),
                        new GLib.Variant.int64 (2 * Pomodoro.Interval.MINUTE));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Scenario for 23:00 - 04:30
         * Expect that time before 4 AM will be attributed to the previous day.
         */
        public void test_midnight_split__before_true_midnight ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 23, 0, 0));

            this.stats_manager.track (
                    "test",
                    timestamp,
                    5 * Pomodoro.Interval.HOUR + 30 * Pomodoro.Interval.MINUTE);

            this.run_flush ();

            try {
                Gom.ResourceGroup results;

                results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2U);

                results.fetch_sync (0U, results.count);

                var stats_entry_1 = (Pomodoro.StatsEntry?) results.get_index (0U);
                assert_cmpstr (
                        stats_entry_1.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_1.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.offset),
                        new GLib.Variant.int64 (23 * Pomodoro.Interval.HOUR));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.duration),
                        new GLib.Variant.int64 (5 * Pomodoro.Interval.HOUR));

                var stats_entry_2 = (Pomodoro.StatsEntry?) results.get_index (1U);
                assert_cmpstr (
                        stats_entry_2.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_2.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-02");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.offset),
                        new GLib.Variant.int64 (Pomodoro.StatsManager.MIDNIGHT_OFFSET));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.duration),
                        new GLib.Variant.int64 (30 * Pomodoro.Interval.MINUTE));

                // Expect an aggregated entry for each day
                results = this.repository.find_sync (
                        typeof (Pomodoro.AggregatedStatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2U);

                results.fetch_sync (0U, results.count);

                var agg_stats_entry_1 = (Pomodoro.AggregatedStatsEntry?) results.get_index (0U);
                assert_cmpstr (
                        agg_stats_entry_1.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        agg_stats_entry_1.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (agg_stats_entry_1.duration),
                        new GLib.Variant.int64 (5 * Pomodoro.Interval.HOUR));

                var agg_stats_entry_2 = (Pomodoro.AggregatedStatsEntry?) results.get_index (1U);
                assert_cmpstr (
                        agg_stats_entry_2.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        agg_stats_entry_2.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-02");
                assert_cmpvariant (
                        new GLib.Variant.int64 (agg_stats_entry_2.duration),
                        new GLib.Variant.int64 (30 * Pomodoro.Interval.MINUTE));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Scenario for 03:00 - 04:30
         * Expect that time before 4 AM will be attributed to the previous day.
         */
        public void test_midnight_split__after_true_midnight ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 3, 0, 0));

            this.stats_manager.track (
                    "test",
                    timestamp,
                    90 * Pomodoro.Interval.MINUTE);

            this.run_flush ();

            try {
                Gom.ResourceGroup results;

                results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2U);

                results.fetch_sync (0U, results.count);

                var stats_entry_1 = (Pomodoro.StatsEntry?) results.get_index (0U);
                assert_cmpstr (
                        stats_entry_1.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_1.date,
                        GLib.CompareOperator.EQ,
                        "1999-12-31");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.offset),
                        new GLib.Variant.int64 ((24 + 3) * Pomodoro.Interval.HOUR));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.duration),
                        new GLib.Variant.int64 (Pomodoro.Interval.HOUR));

                var stats_entry_2 = (Pomodoro.StatsEntry?) results.get_index (1U);
                assert_cmpstr (
                        stats_entry_2.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_2.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.offset),
                        new GLib.Variant.int64 (Pomodoro.StatsManager.MIDNIGHT_OFFSET));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.duration),
                        new GLib.Variant.int64 (30 * Pomodoro.Interval.MINUTE));

                // Expect an aggregated entry for each day
                results = this.repository.find_sync (typeof (Pomodoro.AggregatedStatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2U);

                results.fetch_sync (0U, results.count);

                var agg_stats_entry_1 = (Pomodoro.AggregatedStatsEntry?) results.get_index (0U);
                assert_cmpstr (
                        agg_stats_entry_1.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        agg_stats_entry_1.date,
                        GLib.CompareOperator.EQ,
                        "1999-12-31");
                assert_cmpvariant (
                        new GLib.Variant.int64 (agg_stats_entry_1.duration),
                        new GLib.Variant.int64 (Pomodoro.Interval.HOUR));

                var agg_stats_entry_2 = (Pomodoro.AggregatedStatsEntry?) results.get_index (1U);
                assert_cmpstr (
                        agg_stats_entry_2.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        agg_stats_entry_2.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (agg_stats_entry_2.duration),
                        new GLib.Variant.int64 (30 * Pomodoro.Interval.MINUTE));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Scenario for Monday 09:00 - Friday 17:00
         */
        public void test_midnight_split__multiple_days ()
        {
            var start_time = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 3, 9, 0, 0));
            var end_time = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 7, 17, 0, 0));

            this.stats_manager.track ("test", start_time, end_time - start_time);

            this.run_flush ();

            try {
                Gom.ResourceGroup results;

                results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 5U);

                results.fetch_sync (0U, results.count);

                var stats_entry_1 = (Pomodoro.StatsEntry?) results.get_index (0U);
                assert_cmpstr (
                        stats_entry_1.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_1.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-03");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.offset),
                        new GLib.Variant.int64 (9 * Pomodoro.Interval.HOUR));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.duration),
                        new GLib.Variant.int64 ((24 - 9) * Pomodoro.Interval.HOUR + Pomodoro.StatsManager.MIDNIGHT_OFFSET));

                var stats_entry_2 = (Pomodoro.StatsEntry?) results.get_index (1U);
                assert_cmpstr (
                        stats_entry_2.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_2.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-04");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.offset),
                        new GLib.Variant.int64 (Pomodoro.StatsManager.MIDNIGHT_OFFSET));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.duration),
                        new GLib.Variant.int64 (24 * Pomodoro.Interval.HOUR));

                var stats_entry_5 = (Pomodoro.StatsEntry?) results.get_index (4U);
                assert_cmpstr (
                        stats_entry_5.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_5.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-07");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_5.offset),
                        new GLib.Variant.int64 (Pomodoro.StatsManager.MIDNIGHT_OFFSET));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_5.duration),
                        new GLib.Variant.int64 (17 * Pomodoro.Interval.HOUR - Pomodoro.StatsManager.MIDNIGHT_OFFSET));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Jump from America/New_York 12:01 to Europe/London 17:01
         */
        public void test_timezone_change__forward ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 12, 0, 0));

            this.timezone_history.insert (timestamp + Pomodoro.Interval.MINUTE,
                                          this.london_timezone);

            this.stats_manager.track (
                    "test",
                    timestamp,
                    5 * Pomodoro.Interval.MINUTE);

            this.run_flush ();

            try {
                Gom.ResourceGroup results;

                results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2U);

                results.fetch_sync (0U, results.count);

                var stats_entry_1 = (Pomodoro.StatsEntry?) results.get_index (0U);
                assert_cmpstr (
                        stats_entry_1.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_1.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.offset),
                        new GLib.Variant.int64 (12 * Pomodoro.Interval.HOUR));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.duration),
                        new GLib.Variant.int64 (Pomodoro.Interval.MINUTE));

                var stats_entry_2 = (Pomodoro.StatsEntry?) results.get_index (1U);
                assert_cmpstr (
                        stats_entry_2.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_2.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.offset),
                        new GLib.Variant.int64 ((12 + 5) * Pomodoro.Interval.HOUR +
                                                Pomodoro.Interval.MINUTE));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.duration),
                        new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Jump from America/New_York 12:01 to America/Los_Angeles 09:01
         */
        public void test_timezone_change__backward ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 12, 0, 0));

            this.timezone_history.insert (timestamp + Pomodoro.Interval.MINUTE,
                                          this.los_angeles_timezone);

            this.stats_manager.track (
                    "test",
                    timestamp,
                    5 * Pomodoro.Interval.MINUTE);

            this.run_flush ();

            try {
                Gom.ResourceGroup results;

                results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2U);

                results.fetch_sync (0U, results.count);

                var stats_entry_1 = (Pomodoro.StatsEntry?) results.get_index (0U);
                assert_cmpstr (
                        stats_entry_1.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_1.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.offset),
                        new GLib.Variant.int64 (12 * Pomodoro.Interval.HOUR));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.duration),
                        new GLib.Variant.int64 (Pomodoro.Interval.MINUTE));

                var stats_entry_2 = (Pomodoro.StatsEntry?) results.get_index (1U);
                assert_cmpstr (
                        stats_entry_2.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_2.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.offset),
                        new GLib.Variant.int64 ((12 - 3) * Pomodoro.Interval.HOUR +
                                                Pomodoro.Interval.MINUTE));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.duration),
                        new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Detect DST switch from 2:00 AM EST to 3:00 AM EDT
         */
        public void test_dst_change__forward ()
        {
            var dst_switch_time = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 4, 2, 2, 0, 0));

            this.stats_manager.track (
                    "test",
                    dst_switch_time - Pomodoro.Interval.MINUTE,
                    5 * Pomodoro.Interval.MINUTE);

            this.run_flush ();

            try {
                Gom.ResourceGroup results;

                results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2U);

                results.fetch_sync (0U, results.count);

                var stats_entry_1 = (Pomodoro.StatsEntry?) results.get_index (0U);
                assert_cmpstr (
                        stats_entry_1.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_1.date,
                        GLib.CompareOperator.EQ,
                        "2000-04-01");  // adjusted to virtual midnight
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.offset),
                        new GLib.Variant.int64 ((24 + 2) * Pomodoro.Interval.HOUR - Pomodoro.Interval.MINUTE));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.duration),
                        new GLib.Variant.int64 (Pomodoro.Interval.MINUTE));

                var stats_entry_2 = (Pomodoro.StatsEntry?) results.get_index (1U);
                assert_cmpstr (
                        stats_entry_2.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_2.date,
                        GLib.CompareOperator.EQ,
                        "2000-04-01");  // adjusted to virtual midnight
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.offset),
                        new GLib.Variant.int64 ((24 + 3) * Pomodoro.Interval.HOUR));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.duration),
                        new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Detect DST switch from 2:00 AM EDT to 1:00 AM EST
         */
        public void test_dst_change__backward ()
        {
            var dst_switch_time = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2001, 10, 28, 0, 59, 59)) +
                    Pomodoro.Interval.HOUR + Pomodoro.Interval.SECOND;

            var current_timezone = this.timezone_history.search (dst_switch_time);
            assert_cmpstr (current_timezone.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");

            this.stats_manager.track (
                    "test",
                    dst_switch_time - Pomodoro.Interval.MINUTE,
                    5 * Pomodoro.Interval.MINUTE);

            this.run_flush ();

            try {
                Gom.ResourceGroup results;

                results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2U);

                results.fetch_sync (0U, results.count);

                var stats_entry_1 = (Pomodoro.StatsEntry?) results.get_index (0U);
                assert_cmpstr (
                        stats_entry_1.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_1.date,
                        GLib.CompareOperator.EQ,
                        "2001-10-27");  // adjusted to virtual midnight
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.offset),
                        new GLib.Variant.int64 ((24 + 2) * Pomodoro.Interval.HOUR - Pomodoro.Interval.MINUTE));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_1.duration),
                        new GLib.Variant.int64 (Pomodoro.Interval.MINUTE));

                var stats_entry_2 = (Pomodoro.StatsEntry?) results.get_index (1U);
                assert_cmpstr (
                        stats_entry_2.category,
                        GLib.CompareOperator.EQ,
                        "test");
                assert_cmpstr (
                        stats_entry_2.date,
                        GLib.CompareOperator.EQ,
                        "2001-10-27");  // adjusted to virtual midnight
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.offset),
                        new GLib.Variant.int64 ((24 + 1) * Pomodoro.Interval.HOUR));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry_2.duration),
                        new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }
    }


    public class StatsManagerSessionManagerTest : Tests.TestSuite
    {
        private Pomodoro.Timer?           timer;
        private Pomodoro.SessionManager?  session_manager;
        private Pomodoro.StatsManager?    stats_manager;
        private Pomodoro.TimezoneHistory? timezone_history;
        private Gom.Repository?           repository;
        private GLib.TimeZone?            new_york_timezone;
        private GLib.MainLoop?            main_loop;
        private uint                      timeout_id = 0;

        private weak Pomodoro.StatsManager? previous_stats_manager;

        public StatsManagerSessionManagerTest ()
        {
            this.add_test ("save__pomodoro", this.test_save__pomodoro);
            this.add_test ("save__break", this.test_save__break);
            this.add_test ("save__interruption", this.test_save__interruption);
            this.add_test ("save__many", this.test_save__many);
        }

        public override void setup ()
        {
            // Sat Jan 01 2000 08:00:00 UTC+0000
            Pomodoro.Timestamp.freeze_to (Pomodoro.Timestamp.from_seconds_uint (946713600));
            Pomodoro.Timestamp.set_auto_advance (Pomodoro.Interval.MICROSECOND);

            var settings = Pomodoro.get_settings ();
            settings.set_uint ("pomodoro-duration", 1500);
            settings.set_uint ("short-break-duration", 300);
            settings.set_uint ("long-break-duration", 900);
            settings.set_uint ("cycles", 4);
            settings.set_boolean ("confirm-starting-break", false);
            settings.set_boolean ("confirm-starting-pomodoro", false);

            Pomodoro.Database.open ();

            try {
                this.new_york_timezone = new GLib.TimeZone.identifier ("America/New_York");  // 3 AM
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }

            this.main_loop = new GLib.MainLoop ();

            this.timezone_history = new Pomodoro.TimezoneHistory ();
            this.timezone_history.insert (Pomodoro.Timestamp.peek (), this.new_york_timezone);

            this.timer = new Pomodoro.Timer ();
            Pomodoro.Timer.set_default (this.timer);

            this.session_manager = new Pomodoro.SessionManager.with_timer (this.timer);
            Pomodoro.SessionManager.set_default (this.session_manager);

            this.stats_manager = new Pomodoro.StatsManager ();
            assert (this.stats_manager != this.previous_stats_manager);

            this.repository = Pomodoro.Database.get_repository ();
        }

        public override void teardown ()
        {
            this.timezone_history.clear_cache ();

            this.previous_stats_manager = this.stats_manager;
            this.stats_manager = null;
            this.timezone_history = null;
            this.session_manager = null;
            this.repository = null;
            this.main_loop = null;

            Pomodoro.SessionManager.set_default (null);
            Pomodoro.Timer.set_default (null);
            Pomodoro.Database.close ();

            var settings = Pomodoro.get_settings ();
            settings.revert ();
        }

        private bool run_main_loop (uint timeout = 1000)
                                    requires (this.timeout_id == 0)
        {
            var success = true;

            this.timeout_id = GLib.Timeout.add (timeout, () => {
                this.timeout_id = 0;
                this.main_loop.quit ();

                success = false;

                return GLib.Source.REMOVE;
            });

            this.main_loop.run ();

            return success;
        }

        private void quit_main_loop ()
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            this.main_loop.quit ();
        }

        private void run_save ()
        {
            this.session_manager.save.begin (
                (obj, res) => {
                    assert_true (this.session_manager.save.end (res));

                    this.quit_main_loop ();
                });
            assert_true (this.run_main_loop ());

            this.stats_manager.flush.begin (
                (obj, res) => {
                    this.stats_manager.flush.end (res);

                    this.quit_main_loop ();
                });
            assert_true (this.run_main_loop ());
        }

        private uint count (string date,
                            string category) throws GLib.Error
        {
            try {
                var date_value = GLib.Value (typeof (string));
                date_value.set_string (date);

                var category_value = GLib.Value (typeof (string));
                category_value.set_string (category);

                var date_filter = new Gom.Filter.eq (
                        typeof (Pomodoro.StatsEntry),
                        "date",
                        date_value);
                var category_filter = new Gom.Filter.eq (
                        typeof (Pomodoro.StatsEntry),
                        "category",
                        category_value);
                var filter = new Gom.Filter.and (date_filter, category_filter);

                var results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), filter);

                return results.count;
            }
            catch (GLib.Error error) {
                throw error;
            }
        }

        private int64 sum (string date,
                           string category) throws GLib.Error
        {
            try {
                var date_value = GLib.Value (typeof (string));
                date_value.set_string (date);

                var category_value = GLib.Value (typeof (string));
                category_value.set_string (category);

                var date_filter = new Gom.Filter.eq (
                        typeof (Pomodoro.AggregatedStatsEntry),
                        "date",
                        date_value);
                var category_filter = new Gom.Filter.eq (
                        typeof (Pomodoro.AggregatedStatsEntry),
                        "category",
                        category_value);
                var filter = new Gom.Filter.and (date_filter, category_filter);

                var result = (Pomodoro.AggregatedStatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.AggregatedStatsEntry), filter);

                return result.duration;
            }
            catch (GLib.Error error) {
                throw error;
            }
        }

        public void test_save__pomodoro ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 12, 0, 0));

            Pomodoro.Timestamp.freeze_to (timestamp);

            this.session_manager.advance_to_state (Pomodoro.State.POMODORO);
            this.session_manager.advance (this.session_manager.current_time_block.end_time);

            var time_block = this.session_manager.current_session.get_first_time_block ();
            var time_block_saved_emitted = 0U;

            this.session_manager.time_block_saved.connect (
                () => {
                    time_block_saved_emitted++;
                });

            this.run_save ();
            assert_cmpuint (time_block_saved_emitted, GLib.CompareOperator.EQ, 2U);

            try {
                var results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                var stats_entry = (Pomodoro.StatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.StatsEntry), null);
                assert_cmpstr (
                        stats_entry.category,
                        GLib.CompareOperator.EQ,
                        "pomodoro");
                assert_cmpstr (
                        stats_entry.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry.duration),
                        new GLib.Variant.int64 (time_block.duration));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry.offset),
                        new GLib.Variant.int64 (12 * Pomodoro.Interval.HOUR));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_save__break ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 12, 0, 0));

            Pomodoro.Timestamp.freeze_to (timestamp);

            this.session_manager.advance_to_state (Pomodoro.State.SHORT_BREAK);
            this.session_manager.advance (this.session_manager.current_time_block.end_time);

            var time_block = this.session_manager.current_session.get_first_time_block ();
            var time_block_saved_emitted = 0U;

            this.session_manager.time_block_saved.connect (
                (time_block, time_block_entry) => {
                    time_block_saved_emitted++;
                });

            this.run_save ();
            assert_cmpuint (time_block_saved_emitted, GLib.CompareOperator.EQ, 2U);

            try {
                var results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1U);

                var stats_entry = (Pomodoro.StatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.StatsEntry), null);
                assert_cmpstr (
                        stats_entry.category,
                        GLib.CompareOperator.EQ,
                        "break");
                assert_cmpstr (
                        stats_entry.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry.duration),
                        new GLib.Variant.int64 (time_block.duration));
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry.offset),
                        new GLib.Variant.int64 (12 * Pomodoro.Interval.HOUR));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_save__interruption ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 12, 0, 0));

            var time_block_saved_emitted = 0U;
            var gap_saved_emitted = 0U;

            this.session_manager.time_block_saved.connect (
                (time_block, time_block_entry) => {
                    time_block_saved_emitted++;
                });
            this.session_manager.gap_saved.connect (
                (gap, gap_entry) => {
                    gap_saved_emitted++;
                });

            Pomodoro.Timestamp.freeze_to (timestamp);
            this.timer.start (Pomodoro.Timestamp.peek ());

            Pomodoro.Timestamp.freeze_to (timestamp + 5 * Pomodoro.Interval.MINUTE);
            this.timer.pause (Pomodoro.Timestamp.peek ());

            Pomodoro.Timestamp.freeze_to (timestamp + 6 * Pomodoro.Interval.MINUTE);
            this.timer.resume (Pomodoro.Timestamp.peek ());

            this.run_save ();
            assert_cmpuint (time_block_saved_emitted, GLib.CompareOperator.EQ, 1U);
            assert_cmpuint (gap_saved_emitted, GLib.CompareOperator.EQ, 1U);

            var time_block = this.session_manager.current_time_block;
            var gap = time_block.get_last_gap ();

            try {
                // In this case, gap stats entry is saved before the time-block stats entry
                // as it's still in progress.
                var results = this.repository.find_sync (typeof (Pomodoro.StatsEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1U);

                var stats_entry = (Pomodoro.StatsEntry?) this.repository.find_one_sync (
                        typeof (Pomodoro.StatsEntry), null);
                assert_cmpstr (
                        stats_entry.category,
                        GLib.CompareOperator.EQ,
                        "interruption");
                assert_cmpstr (
                        stats_entry.date,
                        GLib.CompareOperator.EQ,
                        "2000-01-01");
                assert_cmpvariant (
                        new GLib.Variant.int64 (stats_entry.duration),
                        new GLib.Variant.int64 (gap.duration));
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_save__many ()
        {
            var timestamp = Pomodoro.Timestamp.from_datetime (
                    new GLib.DateTime (this.new_york_timezone, 2000, 1, 1, 12, 0, 0));

            var time_block_saved_emitted = 0U;
            var gap_saved_emitted = 0U;
            var cycle = 0;

            this.session_manager.time_block_saved.connect (
                (time_block, time_block_entry) => {
                    time_block_saved_emitted++;
                });
            this.session_manager.gap_saved.connect (
                (gap, gap_entry) => {
                    gap_saved_emitted++;
                });

            Pomodoro.Timestamp.freeze_to (timestamp);
            this.session_manager.ensure_session ();
            this.session_manager.current_session.@foreach (
                (time_block) => {
                    time_block.set_status (cycle <= 1
                                           ? Pomodoro.TimeBlockStatus.COMPLETED
                                           : Pomodoro.TimeBlockStatus.SCHEDULED);

                    var gap_1 = new Pomodoro.Gap ();
                    gap_1.set_time_range (time_block.start_time + 1 * Pomodoro.Interval.MINUTE,
                                          time_block.start_time + 2 * Pomodoro.Interval.MINUTE);
                    time_block.add_gap (gap_1);

                    var gap_2 = new Pomodoro.Gap ();
                    gap_2.set_time_range (time_block.start_time + 3 * Pomodoro.Interval.MINUTE,
                                          time_block.start_time + 4 * Pomodoro.Interval.MINUTE);
                    time_block.add_gap (gap_2);

                    if (time_block.state.is_break ()) {
                        cycle++;
                    }
                }
            );

            this.run_save ();
            assert_cmpuint (time_block_saved_emitted, GLib.CompareOperator.EQ, 4U);

            try {
                assert_cmpuint (this.count ("2000-01-01", "pomodoro"),
                                GLib.CompareOperator.EQ,
                                2U);
                assert_cmpuint (this.count ("2000-01-01", "break"),
                                GLib.CompareOperator.EQ,
                                2U);
                assert_cmpuint (this.count ("2000-01-01", "interruption"),
                                GLib.CompareOperator.EQ,
                                4U);

                assert_cmpvariant (
                    new GLib.Variant.int64 (this.sum ("2000-01-01", "pomodoro")),
                    new GLib.Variant.int64 (23 * Pomodoro.Interval.MINUTE * 2)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (this.sum ("2000-01-01", "break")),
                    new GLib.Variant.int64 (3 * Pomodoro.Interval.MINUTE * 2)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (this.sum ("2000-01-01", "interruption")),
                    new GLib.Variant.int64 (2 * Pomodoro.Interval.MINUTE * 2)
                );
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.StatsManagerTest ()
        // new Tests.StatsManagerSessionManagerTest ()
    );
}
