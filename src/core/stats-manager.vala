/*
 * Copyright (c) 2025 gnome-pomodoro contributors
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
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */

using GLib;


namespace Pomodoro
{
    /**
     * Class responsible for time-tracking and collecting stats
     */
    [SingleInstance]
    public class StatsManager : GLib.Object
    {
        public const int64 MIDNIGHT_OFFSET = 4 * Pomodoro.Interval.HOUR;  // 4 AM

        private struct Segment
        {
            public int64         timestamp;
            public int64         duration;
            public GLib.DateTime datetime;

            public inline bool is_valid ()
            {
                return Pomodoro.Timestamp.is_defined (this.timestamp) &&
                       this.datetime != null &&
                       this.duration > 0;
            }
        }

        public unowned Pomodoro.SessionManager session_manager {
            get {
                return this._session_manager;
            }
            construct {
                this._session_manager = value;
                this._session_manager.time_block_saved.connect (this.on_time_block_saved);
                this._session_manager.gap_saved.connect (this.on_gap_saved);
            }
        }

        private Pomodoro.SessionManager?  _session_manager = null;
        private Pomodoro.TimezoneHistory? timezone_history = null;
        private Pomodoro.Promise?         saving_promise = null;

        construct
        {
            this.timezone_history = new Pomodoro.TimezoneHistory ();
            this.saving_promise = new Pomodoro.Promise ();
        }

        public StatsManager ()
        {
            GLib.Object (
                session_manager: Pomodoro.SessionManager.get_default ()
            );
        }

        private GLib.DateTime? transform_timestamp (int64 timestamp)
        {
            var timezone = this.timezone_history.search (timestamp);

            if (timezone == null) {
                GLib.warning ("Did not find timezone for timestamp %lld", timestamp);
            }

            return Pomodoro.Timestamp.to_datetime (timestamp, timezone);
        }

        private void transform_datetime (GLib.DateTime datetime,
                                         out GLib.Date date,
                                         out int64     offset)
        {
            date = GLib.Date ();
            date.set_dmy ((GLib.DateDay) datetime.get_day_of_month (),
                          (GLib.DateMonth) datetime.get_month (),
                          (GLib.DateYear) datetime.get_year ());

            offset = datetime.get_hour () * Pomodoro.Interval.HOUR +
                     datetime.get_minute () * Pomodoro.Interval.MINUTE +
                     datetime.get_second () * Pomodoro.Interval.SECOND +
                     datetime.get_microsecond ();

            // Adjust for virtual midnight
            if (offset < MIDNIGHT_OFFSET) {
                date.subtract_days (1U);
                offset += 24 * Pomodoro.Interval.HOUR;
            }
        }

        private string? transform_state (Pomodoro.State state)
        {
            switch (state)
            {
                case Pomodoro.State.POMODORO:
                    return "pomodoro";

                case Pomodoro.State.BREAK:
                case Pomodoro.State.SHORT_BREAK:
                case Pomodoro.State.LONG_BREAK:
                    return "break";

                default:
                    return null;
            }
        }

        /**
         * Find timestamps where an entry should be divided: midnights, time-zone changes, etc.
         * `timestamp` is returned as the first split.
         */
        private Segment[] split (int64 timestamp,
                                 int64 duration)
        {
            Segment[] segments = {};

            if (Pomodoro.Timestamp.is_undefined (timestamp) || duration <= 0) {
                return segments;
            }

            this.timezone_history.scan (
                timestamp,
                timestamp + duration,
                (start_time, end_time, timezone) => {
                    var datetime = this.transform_timestamp (start_time);

                    if (datetime == null) {
                        GLib.warning ("Failed to convert timestamp %lld", start_time);
                        return;
                    }

                    segments += Segment () {
                        timestamp = start_time,
                        duration  = 0,
                        datetime  = datetime
                    };

                    var midnight = new GLib.DateTime (
                            timezone,
                            datetime.get_year (),
                            datetime.get_month (),
                            datetime.get_day_of_month (),
                            0,
                            0,
                            0);
                    midnight = midnight.add_seconds (
                            Pomodoro.Timestamp.to_seconds (MIDNIGHT_OFFSET));

                    while (true)
                    {
                        var midnight_timestamp = Pomodoro.Timestamp.from_datetime (midnight);

                        if (midnight_timestamp > end_time) {
                            break;
                        }

                        if (midnight_timestamp < start_time) {
                            midnight = midnight.add_days (1);
                            continue;
                        }

                        segments += Segment () {
                            timestamp = midnight_timestamp,
                            duration  = 0,
                            datetime  = midnight
                        };
                        midnight = midnight.add_days (1);
                    }
                });

            for (var index = 0; index < segments.length - 1; index++) {
                segments[index].duration = segments[index + 1].timestamp -
                                           segments[index].timestamp;
            }

            if (segments.length > 0) {
                segments[segments.length - 1].duration = timestamp + duration -
                                                         segments[segments.length - 1].timestamp;
            }

            return segments;
        }

        /**
         * Convenience method to ensure entries are saved in database.
         *
         * It's intended for testing `StatsManager` alone. If a `SessionManager` is used,
         * the session manager is responsible for saving time-block/gap entries.
         */
        private void try_save_time_block (Pomodoro.TimeBlock time_block)
        {
            if (!Pomodoro.is_test () || time_block.session == null) {
                return;
            }

            if (this._session_manager.current_session != null) {
                return;
            }

            try {
                var session_entry = time_block.session.create_or_update_entry ();
                session_entry?.save_sync ();

                var time_block_entry = time_block.create_or_update_entry ();
                time_block_entry?.save_sync ();
            }
            catch (GLib.Error error) {
                GLib.critical ("Error saving time-block: %s", error.message);
            }

            time_block.foreach_gap (
                (gap) => {
                    var gap_entry = gap.create_or_update_entry ();

                    if (gap_entry != null)
                    {
                        try {
                            gap_entry.save_sync ();
                        }
                        catch (GLib.Error error) {
                            GLib.critical ("Error saving gap: %s", error.message);
                        }
                    }
                });
        }

        private async Gom.ResourceGroup fetch_entries (Gom.Repository repository,
                                                       string         category,
                                                       int64          timestamp,
                                                       int64          source_id) throws GLib.Error
        {
            var category_value = GLib.Value (typeof (string));
            category_value.set_string (category);

            var source_id_value = GLib.Value (typeof (int64));
            source_id_value.set_int64 (source_id);

            var category_filter = new Gom.Filter.eq (
                    typeof (Pomodoro.StatsEntry),
                    "category",
                    category_value);
            var source_id_filter = new Gom.Filter.eq (
                    typeof (Pomodoro.StatsEntry),
                    "source-id",
                    source_id_value);

            var filter = new Gom.Filter.and (category_filter, source_id_filter);

            if (source_id == 0)
            {
                var time_value = GLib.Value (typeof (int64));
                time_value.set_int64 (timestamp);

                var time_filter = new Gom.Filter.eq (
                        typeof (Pomodoro.StatsEntry),
                        "time",
                        time_value);

                filter = new Gom.Filter.and (filter, time_filter);
            }

            return yield repository.find_async (typeof (Pomodoro.StatsEntry), filter);
        }

        private async void track_internal (string          category,
                                           int64           source_id,
                                           owned Segment[] segments) throws GLib.Error
        {
            if (segments.length == 0) {
                return;
            }

            var repository = Pomodoro.Database.get_repository ();

            var entries = yield this.fetch_entries (repository,
                                                    category,
                                                    segments[0].timestamp,
                                                    source_id);
            var entry_index = 0;

            var to_save = (Gom.ResourceGroup) GLib.Object.@new (
                    typeof (Gom.ResourceGroup),
                    repository: repository,
                    resource_type: typeof (Pomodoro.StatsEntry),
                    is_writable: true);
            var to_save_count = 0;
            var to_delete = (Gom.ResourceGroup) GLib.Object.@new (
                    typeof (Gom.ResourceGroup),
                    repository: repository,
                    resource_type: typeof (Pomodoro.StatsEntry),
                    is_writable: true);
            var to_delete_count = 0;

            if (entries.count > 0) {
                yield entries.fetch_async (0U, entries.count);
            }

            foreach (var segment in segments)
            {
                Pomodoro.StatsEntry entry;
                GLib.Date           date;
                int64               offset;

                if (!segment.is_valid ()) {
                    continue;
                }

                if (entry_index < entries.count)
                {
                    entry = (Pomodoro.StatsEntry?) entries.get_index (entry_index);
                    entry_index++;

                    if (entry.time == segment.timestamp &&
                        entry.duration == segment.duration)
                    {
                        continue;
                    }

                    entry.set_data<bool> ("updated", true);
                }
                else {
                    entry = new Pomodoro.StatsEntry ();
                    entry.repository = repository;
                }

                this.transform_datetime (segment.datetime, out date, out offset);

                entry.category = category;
                entry.time = segment.timestamp;
                entry.date = Pomodoro.Database.serialize_date (date);
                entry.offset = offset;
                entry.duration = segment.duration;
                entry.source_id = source_id;

                to_save.append (entry);
                to_save_count++;
            }

            to_save.write_sync ();
            // yield to_save.write_async ();  // XXX: should use async

            while (entry_index < entries.count) {
                // to_delete.append (entries.get_index (entry_index));
                to_delete_count++;
                entry_index++;
            }

            if (to_delete != null) {
                yield to_delete.delete_async ();
            }

            // FIXME
            // for (var index = 0; index < to_save_count; index++) {
            //     unowned var tmp = (Pomodoro.StatsEntry?) to_save.get_index (index);
            //     this.entry_saved (tmp);
            // }

            // FIXME
            // for (var index = 0; index < to_delete_count; index++) {
            //     unowned var tmp = (Pomodoro.StatsEntry?) to_delete.get_index (index);
            //     this.entry_deleted (tmp);
            // }
        }

        public void track (string category,
                           int64  timestamp,
                           int64  duration,
                           int64  source_id = 0)
        {
            if (Pomodoro.Timestamp.is_undefined (timestamp) || duration <= 0) {
                return;
            }

            var segments = this.split (timestamp, duration);

            this.saving_promise.hold ();

            this.track_internal.begin (
                category,
                source_id,
                segments,
                (obj, res) => {
                    try {
                        this.track_internal.end (res);
                    }
                    catch (GLib.Error error) {
                        GLib.warning ("Error while tracking: %s", error.message);
                    }

                    this.saving_promise.release ();
                });
        }

        /**
         * Finds the intersection of two arrays of segments.
         * Returns a new array containing segments that represent overlapping time periods.
         * Assume that both arrays are sorted.
         */
        private Segment[] intersect_segments (owned Segment[] a,
                                              owned Segment[] b)
        {
            Segment[] result = {};

            var b_index  = 0;
            var b_length = b.length;

            // For each segment in array `a`, find intersections with array `b`
            foreach (var segment_a in a)
            {
                var a_start = segment_a.timestamp;
                var a_end   = a_start + segment_a.duration;

                // Skip segments in `b` that end before the current segment in `a` starts
                while (b_index < b_length &&
                       b[b_index].timestamp + b[b_index].duration <= a_start)
                {
                    b_index++;
                }

                // If we've gone through all segments in `b`, we're done
                if (b_index >= b_length) {
                    break;
                }

                // Check for intersections with segments in `b`
                for (var tmp_index = b_index; tmp_index < b_length; tmp_index++)
                {
                    var segment_b = b[tmp_index];
                    var b_start   = segment_b.timestamp;
                    var b_end     = b_start + segment_b.duration;

                    if (b_start >= a_end) {
                        break;
                    }

                    if (a_start < b_end && a_end > b_start)
                    {
                        var intersection_start = int64.max (a_start, b_start);
                        var intersection_end   = int64.min (a_end, b_end);

                        result += Segment () {
                            timestamp = intersection_start,
                            duration  = intersection_end - intersection_start,
                            datetime  = intersection_start == a_start
                                        ? segment_a.datetime : segment_b.datetime
                        };
                    }
                }
            }

            return result;
        }

        public void track_time_block (Pomodoro.TimeBlock time_block)
        {
            this.try_save_time_block (time_block);

            unowned var time_block_entry = time_block.entry;
            var         category         = this.transform_state (time_block.state);
            var         timestamp        = time_block.start_time;
            Segment[]   segments           = {};

            if (category == null ||
                time_block.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED)
            {
                // Assume that we never edit a time-block back to SCHEDULED status,
                // otherwise we would need to delete stats entries if they exist.
                return;
            }

            if (time_block_entry == null) {
                GLib.warning ("Skipping tracking %s. Missing source entry.",
                              time_block.state.to_string ());
                return;
            }

            time_block.foreach_gap (
                (gap) => {
                    segments += Segment () {
                        timestamp = timestamp,
                        duration  = gap.start_time - timestamp,
                        datetime  = this.transform_timestamp (timestamp)
                    };
                    timestamp    = gap.end_time;
                });

            if (Pomodoro.Timestamp.is_defined (time_block.end_time) &&
                time_block.get_status () != Pomodoro.TimeBlockStatus.IN_PROGRESS)
            {
                segments += Segment () {
                    timestamp = timestamp,
                    duration  = time_block.end_time - timestamp,
                    datetime  = this.transform_timestamp (timestamp)
                };
            }

            segments = this.intersect_segments (
                    segments,
                    this.split (time_block.start_time, time_block.duration));

            this.saving_promise.hold ();

            this.track_internal.begin (
                category,
                time_block_entry.id,
                segments,
                (obj, res) => {
                    try {
                        this.track_internal.end (res);
                    }
                    catch (GLib.Error error) {
                        GLib.warning ("Error while tracking: %s", error.message);
                    }

                    this.saving_promise.release ();
                });
        }

        public void track_gap (Pomodoro.Gap gap)
        {
            this.try_save_time_block (gap.time_block);

            unowned var gap_entry = gap.entry;

            if (gap_entry == null) {
                GLib.warning ("Skipping tracking gap. Missing source entry.");
                return;
            }

            if (Pomodoro.Timestamp.is_undefined (gap.end_time)) {
                return;
            }

            if (gap.time_block == null ||
                gap.time_block.state != Pomodoro.State.POMODORO ||
                gap.start_time == gap.time_block.start_time ||
                gap.end_time == gap.time_block.end_time)
            {
                return;
            }

            this.track ("interruption",
                        gap.start_time,
                        gap.duration,
                        gap_entry.id);
        }

        public async void flush ()
        {
            yield this.saving_promise.wait ();
        }

        public GLib.DateTime get_midnight (GLib.Date date)
        {
            var timezone = this.timezone_history.search_by_date (
                    date,
                    Pomodoro.StatsManager.MIDNIGHT_OFFSET);

            if (timezone == null) {
                timezone = new GLib.TimeZone.local ();
            }

            var midnight_hour = (int) (Pomodoro.StatsManager.MIDNIGHT_OFFSET / Pomodoro.Interval.HOUR);
            var midnight = new GLib.DateTime (
                    timezone,
                    date.get_year (),
                    date.get_month (),
                    date.get_day (),
                    midnight_hour,
                    0,
                    0);

            return midnight;
        }

        private void on_time_block_saved (Pomodoro.TimeBlock      time_block,
                                          Pomodoro.TimeBlockEntry time_block_entry)
        {
            this.track_time_block (time_block);
        }

        private void on_gap_saved (Pomodoro.Gap      gap,
                                   Pomodoro.GapEntry gap_entry)
        {
            this.track_time_block (gap.time_block);
            this.track_gap (gap);
        }

        public signal void entry_saved (Pomodoro.StatsEntry entry);

        public signal void entry_deleted (Pomodoro.StatsEntry entry);

        public override void dispose ()
        {
            if (this._session_manager != null)
            {
                this._session_manager.time_block_saved.disconnect (this.on_time_block_saved);
                this._session_manager.gap_saved.disconnect (this.on_gap_saved);
                this._session_manager = null;
            }

            this.timezone_history = null;
            this.saving_promise = null;

            base.dispose ();
        }
    }
}
