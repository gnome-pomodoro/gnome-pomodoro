namespace Pomodoro
{
    /**
     * A lightweight equivalent of `TimezoneEntry`
     */
    [Compact]
    private class TimezoneMarker
    {
        public int64         timestamp;
        public GLib.TimeZone timezone;

        public TimezoneMarker (int64         timestamp,
                               GLib.TimeZone timezone)
        {
            this.timestamp = timestamp;
            this.timezone  = timezone;
        }

        ~TimezoneMarker ()
        {
            this.timezone = null;
        }
    }


    public delegate void TimezoneScanFunc (int64         start_time,
                                           int64         end_time,
                                           GLib.TimeZone timezone);


    /**
     * We use UTC timestamp throughout the app and store local timezone separately
     * as a way to convert it to local time when needed.
     *
     * Internally, data is stored from most recent to oldest entries. Be aware that
     * `GLib.TimeZone` timestamps are in seconds while ours are in microseconds.
     */
    [SingleInstance]
    public class TimezoneHistory : GLib.Object
    {
        private const uint FETCH_LIMIT = 50;

        private GLib.Array<Pomodoro.TimezoneMarker> data;  // TODO: consider a linked list
        private int64 fetched_timestamp = Pomodoro.Timestamp.UNDEFINED;
        private bool fetched_all = false;

        construct
        {
            this.data = new GLib.Array<Pomodoro.TimezoneMarker> ();
        }

        private inline Pomodoro.TimezoneMarker create_marker (int64         timestamp,
                                                              GLib.TimeZone timezone)
        {
            return new Pomodoro.TimezoneMarker (timestamp, timezone);
        }

        /**
         * Try to fill in `data`.
         *
         * Returns the number of fetched entries.
         */
        private uint fetch ()
        {
            Gom.Filter? filter = null;

            if (this.fetched_all) {
                return 0U;
            }

            if (Pomodoro.Timestamp.is_defined (this.fetched_timestamp)) {
                filter = new Gom.Filter.lt (typeof (Pomodoro.TimezoneEntry),
                                            "time",
                                            this.fetched_timestamp);
            }

            var sorting = (Gom.Sorting) GLib.Object.@new (typeof (Gom.Sorting));
            sorting.add (typeof (Pomodoro.TimezoneEntry), "time", Gom.SortingMode.DESCENDING);

            var repository = Pomodoro.Database.get_repository ();

            try {
                var results = repository.find_sorted_sync (typeof (Pomodoro.TimezoneEntry),
                                                           filter,
                                                           sorting);
                var results_count = results.count;
                var fetch_count = uint.min (results_count, FETCH_LIMIT);

                results.fetch_sync (0, fetch_count);

                for (var index = 0; index < fetch_count; index++)
                {
                    var entry = (Pomodoro.TimezoneEntry) results.get_index (index);

                    this.data.append_val (this.create_marker (
                            entry.time,
                            new GLib.TimeZone.identifier (entry.identifier)));
                    this.fetched_timestamp = entry.time;
                }

                if (results_count < FETCH_LIMIT) {
                    this.fetched_all = true;
                }

                return fetch_count;
            }
            catch (GLib.Error error) {
                GLib.warning ("Failed to fetch timezones: %s", error.message);
            }

            return 0U;
        }

        private bool replace_in_database (int64         timestamp,
                                          GLib.TimeZone timezone)
        {
            var timestamp_value = GLib.Value (typeof (int64));
            timestamp_value.set_int64 (timestamp);

            var repository = Pomodoro.Database.get_repository ();
            var filter = new Gom.Filter.eq (
                    typeof (Pomodoro.TimezoneEntry),
                    "time",
                    timestamp_value);

            try {
                var entry = (Pomodoro.TimezoneEntry?) repository.find_one_sync (
                        typeof (Pomodoro.TimezoneEntry),
                        filter);
                if (entry == null) {
                    return false;
                }

                entry.identifier = timezone.get_identifier ();
                entry.save_sync ();
            }
            catch (GLib.Error error) {
                return false;
            }

            return true;
        }

        public void insert (int64         timestamp,
                            GLib.TimeZone timezone)
                            requires (Pomodoro.Timestamp.is_defined (timestamp))
        {
            unowned Pomodoro.TimezoneMarker? existing_marker;
            uint index;

            this.search_internal (timestamp, out existing_marker, out index);

            if (existing_marker != null)
            {
                if (existing_marker.timezone.get_identifier () == timezone.get_identifier ()) {
                    return;  // avoid inserting duplicates
                }

                if (existing_marker.timestamp == timestamp) {
                    this.data.remove_index (index);  // replacing existing marker
                }

                this.data.insert_val (index, this.create_marker (timestamp, timezone));
            }
            else {
                this.data.append_val (this.create_marker (timestamp, timezone));
            }

            var entry = new Pomodoro.TimezoneEntry ();
            entry.repository = Pomodoro.Database.get_repository ();
            entry.time = timestamp;
            entry.identifier = timezone.get_identifier ();

            try {
                entry.save_sync ();

                this.changed ();
            }
            catch (GLib.Error error) {
                if (!this.replace_in_database (timestamp, timezone)) {
                    GLib.warning ("Failed to save timezone %s at %s: %s",
                                  timezone.get_identifier (),
                                  timestamp.to_string (),
                                  error.message);
                }
            }
        }

        private inline void search_internal (int64                                timestamp,
                                             out unowned Pomodoro.TimezoneMarker? marker,
                                             out uint                             index)
        {
            marker = null;
            index = 0U;

            var _index = index;

            do {
                while (_index < this.data.length)
                {
                    unowned var _marker = this.data.index (_index);

                    if (timestamp >= _marker.timestamp) {
                        marker = _marker;
                        index = _index;
                        return;
                    }

                    _index++;
                }
            }
            while (this.fetch () > 0);
        }

        public unowned GLib.TimeZone? search (int64 timestamp)
        {
            unowned Pomodoro.TimezoneMarker? marker;

            this.search_internal (timestamp, out marker, null);

            return marker?.timezone;
        }

        public unowned GLib.TimeZone? search_by_date (GLib.Date date,
                                                      int64     offset = 0)
        {
            unowned Pomodoro.TimezoneMarker? marker = null;
            unowned Pomodoro.TimezoneMarker? last_valid_marker = null;
            uint index;

            var estimated_datetime = new GLib.DateTime.utc (
                    date.get_year (),
                    date.get_month (),
                    date.get_day (),
                    0, 0, 0);
            estimated_datetime.add_days (-2);
            var estimated_timestamp = estimated_datetime.to_unix ();

            this.search_internal (estimated_timestamp, out marker, out index);

            if (marker == null && this.data.length > 0) {
                index  = this.data.length - 1;
                marker = this.data.index (index);
            }

            while (marker != null)
            {
                var datetime = new GLib.DateTime (
                        marker.timezone,
                        date.get_year (),
                        date.get_month (),
                        date.get_day (),
                        0, 0, 0);
                if (offset != 0) {
                    datetime = datetime.add_seconds (Pomodoro.Interval.to_seconds (offset));
                }

                if (marker.timestamp > datetime.to_unix ()) {
                    break;
                }

                last_valid_marker = marker;
                index++;
                marker = index < this.data.length
                        ? this.data.index (index)
                        : null;
            }

            return last_valid_marker?.timezone;
        }

        /**
         * Try to find fist occurrence of an timezone offset change.
         * It only considers one such occurrence for a given time range. For our purposes
         * it's good enough - we need it to be reliable up to a day, preferably up to a month.
         */
        private inline void split_timezone (int64                     start_time,
                                            int64                     end_time,
                                            GLib.TimeZone             timezone,
                                            Pomodoro.TimezoneScanFunc func)
        {
            var start_interval_id = timezone.find_interval (
                    GLib.TimeType.UNIVERSAL,
                    start_time / Pomodoro.Interval.SECOND);
            var end_interval_id = timezone.find_interval (
                    GLib.TimeType.UNIVERSAL,
                    end_time / Pomodoro.Interval.SECOND);
            var start_offset = timezone.get_offset (start_interval_id);
            var end_offset = timezone.get_offset (end_interval_id);

            if (start_offset != end_offset)
            {
                // Use binary search for finding the transition time.
                var range_start_time = start_time / Pomodoro.Interval.SECOND;
                var range_end_time = end_time / Pomodoro.Interval.SECOND;
                var range_mid_time = range_start_time;
                var range_mid_offset = start_offset;

                while (range_start_time < range_end_time)
                {
                    range_mid_time = range_start_time + (range_end_time - range_start_time) / 2;
                    range_mid_offset = timezone.get_offset (
                            timezone.find_interval (GLib.TimeType.UNIVERSAL, range_mid_time));

                    if (range_mid_offset != start_offset) {
                        range_end_time = range_mid_time;
                    } else {
                        range_start_time = range_mid_time + 1;
                    }
                }

                // Round 59:59 to a full minutes to make it consistent with our time-blocks API.
                // `range_end - range_start` in should return correct range duration.
                if (range_mid_time % 1800 == 1799) {
                    range_mid_time += 1;
                }

                var split_time = range_mid_time * Pomodoro.Interval.SECOND;

                if (start_time < split_time) {
                    func (start_time, split_time, timezone);
                }

                if (split_time < end_time) {
                    func (split_time, end_time, timezone);
                }
            }
            else {
                func (start_time, end_time, timezone);
            }
        }

        public void scan (int64                     start_time,
                          int64                     end_time,
                          Pomodoro.TimezoneScanFunc func)
        {
            if (start_time > end_time) {
                return;
            }

            unowned Pomodoro.TimezoneMarker? marker;
            unowned Pomodoro.TimezoneMarker? next_marker;
            uint index;

            this.search_internal (start_time, out marker, out index);

            if (marker == null && !Pomodoro.is_test ())  // XXX: avoid `is_test`; specify a fallback-timezone
            {
                func (start_time,
                      marker != null ? marker.timestamp : end_time,
                      new GLib.TimeZone.local ());
                return;
            }

            while (marker != null && marker.timestamp < end_time)
            {
                next_marker = index >= 1
                        ? this.data.index (index - 1U)
                        : null;

                this.split_timezone (
                        int64.max (marker.timestamp, start_time),
                        next_marker != null
                                ? int64.min (next_marker.timestamp, end_time)
                                : end_time,
                        marker.timezone,
                        func);

                if (next_marker != null) {
                    marker = next_marker;
                    index--;
                }
                else {
                    break;
                }
            }
        }

        public void clear_cache ()
        {
            this.data = new GLib.Array<Pomodoro.TimezoneMarker> ();
            this.fetched_timestamp = Pomodoro.Timestamp.UNDEFINED;
            this.fetched_all = false;
        }

        public signal void changed ();

        public override void dispose ()
        {
            this.data = null;

            base.dispose ();
        }
    }
}
