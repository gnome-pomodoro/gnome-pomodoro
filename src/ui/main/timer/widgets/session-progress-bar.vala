/*
 * Copyright (c) 2021-2025 gnome-pomodoro contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Pomodoro
{
    public sealed class SessionProgressBar : Gtk.Widget
    {
        private const float DEFAULT_LINE_WIDTH = 6.0f;
        private const float SEGMENT_SPACING = 0.17f;
        private const int   MIN_WIDTH = 100;
        private const uint  TIMEOUT_RESOLUTION = 3U;
        private const uint  MIN_TIMEOUT_INTERVAL = 25;  // 40Hz
        private const uint  FADE_IN_DURATION = 500;
        private const uint  FADE_OUT_DURATION = 500;
        private const uint  VALUE_ANIMATION_DURATION = 500;
        private const uint  SCALE_ANIMATION_DURATION = 700;


        sealed class Segment : Gtk.Widget
        {
            public Pomodoro.Timer timer {
                get {
                    return this._timer;
                }
                construct {
                    this._timer = value;
                }
            }

            public Pomodoro.Cycle cycle {
                get {
                    return this._cycle;
                }
                set {
                    if (this._cycle == value) {
                        return;
                    }

                    if (this.cycle_changed_id != 0) {
                        this._cycle.disconnect (this.cycle_changed_id);
                        this.cycle_changed_id = 0;
                    }

                    this._cycle = value;

                    if (this._cycle != null) {
                        this.cycle_changed_id = this._cycle.changed.connect (this.on_cycle_changed);
                    }

                    this.on_cycle_changed ();
                    this.queue_draw_all ();
                }
            }

            public float span_start {
                get {
                    return this._span_start;
                }
            }

            public float span_end {
                get {
                    return this._span_end;
                }
            }

            public float weight {
                get {
                    return this._weight;
                }
            }

            [CCode (notify = false)]
            public float line_width
            {
                get {
                    return this._line_width;
                }
                set {
                    if (this._line_width != value) {
                        this._line_width = value;
                        this.notify_property ("line-width");
                        this.queue_draw_all ();
                    }
                }
            }

            public float display_value {
                get {
                    return this._display_value;
                }
            }

            private Pomodoro.Cycle?        _cycle = null;
            private Pomodoro.Timer?        _timer = null;
            private float                  _line_width;
            private float                  _span_start = 0.0f;
            private float                  _span_end = 0.0f;
            private float                  _weight = 0.0f;
            private float                  _display_value = 0.0f;
            private ulong                  cycle_changed_id = 0U;
            private ulong                  tick_id = 0U;
            private uint                   tick_callback_id = 0U;
            private uint                   timeout_id = 0U;
            private uint                   timeout_interval = 0U;
            private unowned Pomodoro.Gizmo through = null;
            private unowned Pomodoro.Gizmo highlight = null;
            private Graphene.Rect          bounds;
            private Gsk.RoundedRect        outline;
            private float                  value_animation_progress = 1.0f;

            internal float                 display_value_from = 0.0f;
            internal float                 display_value_to = 0.0f;

            construct
            {
                var through = new Pomodoro.Gizmo (Segment.measure_child_cb,
                                                  null,
                                                  Segment.snapshot_through_cb,
                                                  null,
                                                  null,
                                                  null);
                through.focusable = false;
                through.add_css_class ("through");
                through.set_parent (this);

                var highlight = new Pomodoro.Gizmo (Segment.measure_child_cb,
                                                    null,
                                                    Segment.snapshot_highlight_cb,
                                                    null,
                                                    null,
                                                    null);
                highlight.focusable = false;
                highlight.add_css_class ("highlight");
                highlight.insert_after (this, through);

                this.highlight = highlight;
                this.through = through;
            }

            public Segment (Pomodoro.Cycle cycle)
            {
                GLib.Object (
                    timer: Pomodoro.Timer.get_default (),
                    cycle: cycle
                );
            }

            private inline int64 get_current_time ()
            {
                return this._timer.is_running ()
                        ? this._timer.get_current_time (this.get_frame_clock ().get_frame_time ())
                        : this._timer.get_last_state_changed_time ();
            }

            internal void prepare_value_animation (float display_value_from,
                                                   float display_value_to)
            {
                this.display_value_from = display_value_from;
                this.display_value_to = display_value_to;
                this.value_animation_progress = this._display_value == display_value_to
                        ? 1.0f
                        : 0.0f;
            }

            internal void finish_value_animation ()
            {
                if (this.value_animation_progress != 1.0f) {
                    this.value_animation_progress = 1.0f;
                    this.highlight.queue_draw ();
                }
            }

            internal void set_value_animation_progress (float progress)
            {
                if (this.value_animation_progress != progress) {
                    this.value_animation_progress = progress;
                    this.highlight.queue_draw ();
                }
            }

            private inline void queue_draw_all ()
            {
                this.queue_draw ();
                this.through.queue_draw ();
                this.highlight.queue_draw ();
            }

            private static void measure_child_cb (Pomodoro.Gizmo  gizmo,
                                                  Gtk.Orientation orientation,
                                                  int             for_size,
                                                  out int         minimum,
                                                  out int         natural,
                                                  out int         minimum_baseline,
                                                  out int         natural_baseline)
            {
                // `SessionProgressBar` dictates the size. Gizmos fill available space.
                minimum          = 0;
                natural          = 0;
                minimum_baseline = -1;
                natural_baseline = -1;
            }

            private static void snapshot_through_cb (Pomodoro.Gizmo gizmo,
                                                     Gtk.Snapshot   snapshot)
            {
                var self = (Segment) gizmo.parent;

                if (self != null) {
                    self.snapshot_through (gizmo, snapshot);
                }
            }

            private static void snapshot_highlight_cb (Pomodoro.Gizmo gizmo,
                                                       Gtk.Snapshot   snapshot)
            {
                var self = (Segment) gizmo.parent;

                if (self != null) {
                    self.snapshot_highlight (gizmo, snapshot);
                }
            }

            private void snapshot_through (Pomodoro.Gizmo gizmo,
                                           Gtk.Snapshot   snapshot)
            {
                snapshot.push_rounded_clip (this.outline);
                snapshot.append_color (gizmo.get_color (), this.bounds);
                snapshot.pop ();
            }

            private void snapshot_highlight (Pomodoro.Gizmo gizmo,
                                             Gtk.Snapshot   snapshot)
            {
                var timestamp = this.get_current_time ();
                var display_value = this._cycle != null
                        ? (float) this._cycle.calculate_progress (timestamp)
                        : 0.0f;
                var color = gizmo.get_color ();

                if (this.value_animation_progress < 1.0f) {
                    display_value = lerpf (this.display_value_from,
                                           display_value,
                                           this.value_animation_progress);
                }

                if (display_value > 0.0f && display_value < 1.0f)
                {
                    var width  = (float) this.get_width ();
                    var height = (float) this.get_height ();

                    var highlight_width   = (this._span_end - this._span_start) * display_value * width;
                    var highlight_height  = this._line_width;
                    var highlight_x       = this._span_start * width;
                    var highlight_y       = (height - highlight_height) / 2.0f;
                    var highlight_bounds  = Graphene.Rect ();
                    var highlight_outline = Gsk.RoundedRect ();
                    var clip_applied      = false;

                    if (highlight_width < highlight_height)
                    {
                        highlight_x -= highlight_height - highlight_width;
                        highlight_width = highlight_height;

                        snapshot.push_rounded_clip (this.outline);
                        clip_applied = true;
                    }

                    if (this.get_direction () == Gtk.TextDirection.RTL) {
                        highlight_x = width - highlight_x - highlight_width;
                    }

                    highlight_bounds.init (highlight_x,
                                           highlight_y,
                                           highlight_width,
                                           highlight_height);
                    highlight_outline.init_from_rect (highlight_bounds, highlight_height / 2.0f);

                    snapshot.push_rounded_clip (highlight_outline);
                    snapshot.append_color (color, highlight_bounds);
                    snapshot.pop ();

                    if (clip_applied) {
                        snapshot.pop ();
                    }
                }
                else if (display_value == 1.0f)
                {
                    snapshot.push_rounded_clip (this.outline);
                    snapshot.append_color (color, this.bounds);
                    snapshot.pop ();
                }

                this._display_value = display_value;
            }

            public void set_span_range (float span_start,
                                        float span_end)
            {
                var changed = false;

                if (span_end < span_start) {
                    var tmp = span_start;
                    span_start = span_end;
                    span_end = tmp;
                }

                if (this._span_start != span_start) {
                    this._span_start = span_start;
                    changed = true;
                }

                if (this._span_end != span_end) {
                    this._span_end = span_end;
                    changed = true;
                }

                if (changed) {
                    this.queue_draw_all ();
                }
            }

            private uint calculate_timeout_interval ()
                                                     requires (this._cycle != null)
            {
                var timestamp = this.get_current_time ();
                var distance  = (float) (this._span_end - this._span_start) * (float) this.get_width ();
                var duration  = (float) this._cycle.calculate_progress_duration (timestamp);

                distance *= (float) TIMEOUT_RESOLUTION;

                return distance > 0.0
                        ? Pomodoro.Timestamp.to_milliseconds_uint ((int64) Math.roundf (duration / distance))
                        : 0;
            }

            private void start_timeout ()
                                        requires (this._cycle != null)
                                        requires (this.get_mapped ())
            {
                var timeout_interval = this.calculate_timeout_interval ();

                if (timeout_interval < MIN_TIMEOUT_INTERVAL) {
                    timeout_interval = 0U;
                }

                if (this.timeout_interval != timeout_interval) {
                    this.timeout_interval = timeout_interval;
                    this.stop_timeout ();
                }

                if (this.tick_id == 0 && timeout_interval > 0 && timeout_interval > 500) {
                    this.tick_id = this._timer.tick.connect (
                        (timestamp) => {
                            this.highlight.queue_draw ();
                        });
                }
                else if (this.timeout_id == 0 && timeout_interval > 0)
                {
                    this.timeout_id = GLib.Timeout.add (
                        timeout_interval,
                        () => {
                            this.highlight.queue_draw ();

                            return GLib.Source.CONTINUE;
                        });
                    GLib.Source.set_name_by_id (this.timeout_id,
                                                "Pomodoro.SessionProgressBar.Segment.queue_draw");
                }
                else if (this.tick_callback_id == 0 && timeout_interval == 0)
                {
                    this.tick_callback_id = this.add_tick_callback (
                        () => {
                            this.highlight.queue_draw ();

                            return GLib.Source.CONTINUE;
                        });
                }
            }

            private void stop_timeout ()
            {
                if (this.tick_id != 0) {
                    this._timer.disconnect (this.tick_id);
                    this.tick_id = 0;
                }

                if (this.timeout_id != 0) {
                    GLib.Source.remove (this.timeout_id);
                    this.timeout_id = 0;
                }

                if (this.tick_callback_id != 0) {
                    this.remove_tick_callback (this.tick_callback_id);
                    this.tick_callback_id = 0;
                }
            }

            internal bool has_timeout ()
            {
                return this.tick_id != 0 ||
                       this.timeout_id != 0 ||
                       this.tick_callback_id != 0;
            }

            internal void update_timeout ()
            {
                this.stop_timeout ();

                if (!this.get_mapped () || this._cycle == null) {
                    return;
                }

                var current_time_block = this._timer.user_data as Pomodoro.TimeBlock;
                if (current_time_block != null && !this._cycle.contains (current_time_block)) {
                    return;
                }

                if (this._timer.is_running ()) {
                    this.start_timeout ();
                }
            }

            public void update ()
            {
                this.update_timeout ();
            }

            private void on_cycle_changed ()
            {
                var weight = this._cycle != null
                        ? (float) this._cycle.get_weight ()
                        : 0.0f;

                if (weight <= 0.0f) {
                    return;  // retain last weight
                }

                if (this._weight != weight) {
                    // TODO: animate weight
                    this._weight = weight;
                }

                this.update ();
            }

            public override void map ()
            {
                base.map ();

                this.update_timeout ();
            }

            public override void unmap ()
            {
                this.stop_timeout ();

                base.unmap ();
            }

            public override Gtk.SizeRequestMode get_request_mode ()
            {
                return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
            }

            public override void measure (Gtk.Orientation orientation,
                                          int             for_size,
                                          out int         minimum,
                                          out int         natural,
                                          out int         minimum_baseline,
                                          out int         natural_baseline)
            {
                minimum = orientation == Gtk.Orientation.HORIZONTAL
                        ? MIN_WIDTH
                        : (int) Math.ceilf (this._line_width);
                natural = minimum;
                minimum_baseline = -1;
                natural_baseline = -1;
            }

            public override void size_allocate (int width,
                                                int height,
                                                int baseline)
            {
                this.through.allocate (width, height, baseline, null);
                this.highlight.allocate (width, height, baseline, null);
            }

            public override void snapshot (Gtk.Snapshot snapshot)
            {
                var width          = (float) this.get_width ();
                var height         = (float) this.get_height ();
                var segment_x      = float.max (this._span_start, 0.0f) * width;
                var segment_y      = (height - this._line_width) / 2.0f;
                var segment_width  = float.min (this._span_end, 1.0f) * width - segment_x;
                var segment_height = this._line_width;

                if (segment_width <= 0.0f) {
                    return;
                }

                if (this.get_direction () == Gtk.TextDirection.RTL) {
                    segment_x = width - segment_x - segment_width;
                }

                this.bounds = Graphene.Rect ();
                this.bounds.init (segment_x, segment_y, segment_width, segment_height);

                this.outline = Gsk.RoundedRect ();
                this.outline.init_from_rect (bounds, 0.5f * segment_height);

                this.snapshot_child (this.through, snapshot);
                this.snapshot_child (this.highlight, snapshot);
            }

            public override void dispose ()
            {
                this.stop_timeout ();

                this.through.unparent ();
                this.highlight.unparent ();

                this.through = null;
                this.highlight = null;
                this._timer = null;
                this._cycle = null;

                base.dispose ();
            }
        }


        public Pomodoro.Timer timer {
            get {
                return this._timer;
            }
            construct {
                this._timer = value != null
                        ? value
                        : Pomodoro.Timer.get_default ();
            }
        }

        public Pomodoro.SessionManager session_manager {
            get {
                return this._session_manager;
            }
            construct {
                this._session_manager = value != null
                        ? value
                        : Pomodoro.SessionManager.get_default ();
            }
        }

        [CCode (notify = false)]
        public Pomodoro.Session session {
            get {
                return this._session;
            }
            set {
                if (this._session == value) {
                    return;
                }

                if (this._session != null) {
                    this._session.changed.disconnect (this.on_session_changed);
                }

                this._session = value;
                this.update ();

                if (this._session != null) {
                    this._session.changed.connect (this.on_session_changed);
                }

                this.notify_property ("session");
            }
        }

        [CCode (notify = false)]
        public float line_width
        {
            get {
                return this._line_width;
            }
            set {
                if (this._line_width == value) {
                    return;
                }

                this._line_width = value;

                this.notify_property ("line-width");
                this.queue_resize ();
            }
        }

        public bool reveal
        {
            get {
                return this._reveal;
            }
        }

        private Pomodoro.Timer?          _timer = null;
        private Pomodoro.SessionManager? _session_manager = null;
        private Pomodoro.Session?        _session = null;
        private float                    _line_width = DEFAULT_LINE_WIDTH;
        private bool                     _reveal = true;
        private bool                     revealing = false;
        private unowned Segment?         current_segment = null;
        private float                    scale = float.NAN;
        private Adw.TimedAnimation?      scale_animation = null;
        private Adw.TimedAnimation?      opacity_animation = null;
        private Adw.TimedAnimation?      value_animation = null;
        private int64                    long_break_time = Pomodoro.Timestamp.UNDEFINED;
        private uint                     tick_callback_id = 0;

        static construct
        {
            set_css_name ("sessionprogressbar");
        }

        construct
        {
            this.has_tooltip = true;
        }

        private void remove_segments ()
        {
            unowned Gtk.Widget? child;

            while ((child = this.get_first_child ()) != null)
            {
                child.unparent ();
            }

            this.current_segment = null;
            this.scale = float.NAN;
        }

        /**
         * Remove segments that are not in the view.
         */
        private void remove_invisible_segments ()
                                                requires (this.scale_animation == null)
        {
            unowned var segment = (Segment?) this.get_first_child ();

            while (segment != null)
            {
                unowned var next_segment = (Segment?) segment.get_next_sibling ();

                if (segment.span_start >= 1.0f && segment.cycle == null) {
                    segment.unparent ();
                }

                segment = next_segment;
            }
        }

        private inline void snapshot_segments (Gtk.Snapshot snapshot)
        {
            unowned var child = this.get_first_child ();

            while (child != null)
            {
                this.snapshot_child (child, snapshot);

                child = child.get_next_sibling ();
            }
        }

        private float calculate_scale (double total_weight,
                                       uint   cycles_count)
        {
            var norm = total_weight + (cycles_count - 1) * (double) SEGMENT_SPACING;

            return norm > 0.0
                    ? (float)(1.0 / norm)
                    : 0.0f;
        }

        private float get_current_scale ()
        {
            return this.scale_animation != null
                    ? (float) this.scale_animation.value
                    : this.scale;
        }

        private float get_target_scale ()
        {
            unowned var segment = (Segment?) this.get_first_child ();
            var cycles_count = 0;
            var total_weight = 0.0;

            while (segment != null)
            {
                unowned var cycle = segment.cycle;

                if (cycle != null) {
                    total_weight += cycle.get_weight ();
                    cycles_count++;
                }

                segment = (Segment?) segment.get_next_sibling ();
            }

            return this.calculate_scale (total_weight, cycles_count);
        }

        private unowned Segment? get_current_segment ()
        {
            unowned var segment = (Segment?) this.get_last_child ();

            while (segment != null)
            {
                if (segment.display_value > 0.0f) {
                    break;
                }

                segment = (Segment?) segment.get_prev_sibling ();
            }

            return segment;
        }

        private float get_current_position ()
        {
            unowned var segment = (Segment?) this.get_first_child ();
            var position = 0.0f;

            while (segment != null)
            {
                var display_value = segment.display_value;

                if (display_value < 1.0f) {
                    position = lerpf (segment.span_start, segment.span_end, display_value);
                    break;
                }

                position = segment.span_end;
                segment = (Segment?) segment.get_next_sibling ();
            }

            return position;
        }

        private float get_target_position ()
        {
            unowned var segment = (Segment?) this.get_first_child ();
            var position = 0.0f;

            var timestamp = this._timer.is_running ()
                    ? this._timer.get_current_time ()
                    : this._timer.get_last_state_changed_time ();

            while (segment != null)
            {
                var segment_progress = segment.cycle != null
                        ? (float) segment.cycle.calculate_progress (timestamp)
                        : 0.0f;

                if (segment_progress <= 0.0f) {
                    break;
                }

                if (segment_progress < 1.0f) {
                    position = lerpf (segment.span_start, segment.span_end, segment_progress);
                    break;
                }

                position = segment.span_end;
                segment = (Segment?) segment.get_next_sibling ();
            }

            return position;
        }

        private void update_segments_span ()
        {
            var scale = this.scale_animation != null
                    ? (float) this.scale_animation.value
                    : this.scale;
            var position = 0.0f;
            var spacing = (float)(SEGMENT_SPACING * scale);

            unowned var segment = (Segment?) this.get_first_child ();

            while (segment != null)
            {
                segment.set_span_range (position, position + segment.weight * scale);

                position = segment.span_end + spacing;
                segment  = (Segment?) segment.get_next_sibling ();
            }

            this.queue_draw ();
        }

        /**
         * Synchronise segments according to cycles.
         */
        private void update_segments ()
        {
            if (this._session == null) {
                this._session_manager.ensure_session ();
                this._session = this._session_manager.current_session;
                this.notify_property ("session");
            }

            var cycles = this._session.get_cycles ();
            var cycles_count = 0U;

            unowned GLib.List<unowned Pomodoro.Cycle> link = cycles.first ();
            unowned var segment = (Segment?) this.get_first_child ();
            unowned var current_cycle = this._session_manager.get_current_cycle ();
            unowned Segment? current_segment = null;

            while (link != null)
            {
                var cycle = link.data;

                if (link.data.is_visible ())
                {
                    if (segment != null) {
                        segment.cycle = cycle;
                    }
                    else {
                        var new_segment = new Segment (cycle);
                        this.bind_property ("line-width",
                                            new_segment,
                                            "line-width",
                                            GLib.BindingFlags.SYNC_CREATE);
                        new_segment.insert_before (this, null);
                        segment = new_segment;
                    }

                    if (cycle == current_cycle) {
                        current_segment = segment;
                    }

                    cycles_count++;
                    segment = (Segment?) segment.get_next_sibling ();
                }

                link = link.next;
            }

            this.current_segment = current_segment;

            // Update segments without associated cycles.
            while (segment != null)
            {
                segment.cycle = null;

                segment = (Segment?) segment.get_next_sibling ();
            }

            // Update segments span and opacity.
            var scale_from    = this.get_current_scale ();
            var scale_to      = this.get_target_scale ();
            var position_from = this.get_current_position ();
            var position_to   = this.get_target_position ();

            if (cycles_count > 1U) {
                this.fade_in ();
            }
            else {
                this.fade_out ();
            }

            if (this._reveal) {
                // this.animate_weights ();  TODO
                this.animate_scale (scale_from, scale_to);
                this.animate_value (position_from, position_to);
            }

            if (this.scale_animation == null) {
                this.remove_invisible_segments ();
            }
        }

        /**
         * Find when there will be a long break for the tooltip.
         */
        private void update_long_break_time ()
        {
            var long_break_time = Pomodoro.Timestamp.UNDEFINED;

            this._session?.@foreach (
                (time_block) => {
                    if (time_block.state == Pomodoro.State.LONG_BREAK &&
                        time_block.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED &&
                        Pomodoro.Timestamp.is_undefined (long_break_time))
                    {
                        long_break_time = time_block.start_time;
                    }
                }
            );

            this.long_break_time = long_break_time;
        }

        private void update ()
        {
            if (this.tick_callback_id != 0) {
                this.remove_tick_callback (this.tick_callback_id);
                this.tick_callback_id = 0;
            }

            this.update_long_break_time ();
            this.update_segments ();
        }

        private void queue_update ()
        {
            if (this._reveal && !this.get_mapped ()) {
                return;
            }

            if (this.tick_callback_id != 0) {
                return;
            }

            this.tick_callback_id = this.add_tick_callback (
                () => {
                    this.tick_callback_id = 0;
                    this.update ();

                    return GLib.Source.REMOVE;
                });
        }


        /*
         * Scale animation
         */

        private void on_scale_animation_done ()
        {
            this.scale_animation = null;

            this.update_segments_span ();
            this.remove_invisible_segments ();
        }

        private void animate_scale (float scale_from,
                                    float scale_to)
        {
            if (scale_to == scale_from) {
                return;
            }

            this.scale = scale_to;

            if (this.scale_animation != null) {
                this.scale_animation.pause ();
                this.scale_animation = null;
            }

            if (this.get_mapped () && !scale_from.is_nan () && !scale_to.is_nan ())
            {
                var animation_target = new Adw.CallbackAnimationTarget (this.update_segments_span);

                this.scale_animation = new Adw.TimedAnimation (this,
                                                               (double) scale_from,
                                                               (double) scale_to,
                                                               SCALE_ANIMATION_DURATION,
                                                               animation_target);
                this.scale_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
                this.scale_animation.done.connect (this.on_scale_animation_done);
                this.scale_animation.play ();
            }
            else if (!scale_to.is_nan ()) {
                this.on_scale_animation_done ();
            }
        }


        /*
         * Value animation
         */

        private void prepare_value_animation (float position_from,
                                              float position_to)
        {
            unowned var segment = (Segment?) this.get_first_child ();

            while (segment != null)
            {
                if (segment.span_start < segment.span_end)
                {
                    var display_value_from = (
                            (position_from - segment.span_start) /
                            (segment.span_end - segment.span_start)).clamp (0.0f, 1.0f);
                    var display_value_to = (
                            (position_to - segment.span_start) /
                            (segment.span_end - segment.span_start)).clamp (0.0f, 1.0f);

                    segment.prepare_value_animation (
                            float.max (display_value_from, segment.display_value),
                            display_value_to);
                }

                segment = (Segment?) segment.get_next_sibling ();
            }
        }

        private void finish_value_animation ()
        {
            unowned var segment = (Segment?) this.get_first_child ();

            while (segment != null)
            {
                segment.finish_value_animation ();

                segment = (Segment?) segment.get_next_sibling ();
            }
        }

        private void on_value_animation_done ()
        {
            this.value_animation = null;

            this.finish_value_animation ();
        }

        private void animate_value (float position_from,
                                    float position_to)
                                    requires (position_from.is_finite ())
                                    requires (position_to.is_finite ())
        {
            if (!this.get_mapped () || (position_to - position_from).abs () < 0.01f) {
                return;
            }

            if (this.value_animation != null) {
                this.value_animation.pause ();
                this.value_animation = null;
            }

            var segment = this.get_current_segment ();
            var scale = this.get_current_scale ();
            var is_forward = position_from < position_to;

            if (segment == null) {
                GLib.debug ("Unable to animate value from %.3f to %.3f",
                            position_from,
                            position_to);
                return;
            }

            var animation_duration = (uint)(
                    Math.sqrt ((double)(position_to - position_from).abs () / (double) scale) *
                    (double) VALUE_ANIMATION_DURATION);

            var animation_target = new Adw.CallbackAnimationTarget (
                (position) => {
                    while (segment != null)
                    {
                        if (!is_forward && position < segment.span_start) {
                            segment.set_value_animation_progress (1.0f);
                            segment = (Segment?) segment.get_prev_sibling ();
                            continue;
                        }

                        if (is_forward && position > segment.span_end) {
                            segment.set_value_animation_progress (1.0f);
                            segment = (Segment?) segment.get_next_sibling ();
                            continue;
                        }

                        if (segment.display_value_from == segment.display_value_to) {
                            segment.set_value_animation_progress (1.0f);
                            break;
                        }

                        var segment_position_from = lerpf (
                                segment.span_start,
                                segment.span_end,
                                segment.display_value_from);
                        var segment_position_to = lerpf (
                                segment.span_start,
                                segment.span_end,
                                segment.display_value_to);

                        var progress = ((float) position - segment_position_from) /
                                        (segment_position_to - segment_position_from);

                        segment.set_value_animation_progress (progress.clamp (0.0f, 1.0f));
                        break;
                    }
                });

            this.prepare_value_animation (position_from, position_to);

            this.value_animation = new Adw.TimedAnimation (this,
                                                           (double) position_from,
                                                           (double) position_to,
                                                           animation_duration,
                                                           animation_target);
            this.value_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
            this.value_animation.done.connect (this.on_value_animation_done);
            this.value_animation.play ();
        }


        /*
         * Opacity animation (fade-in / fade-out)
         */

        private void on_opacity_animation_done ()
        {
            this.opacity_animation = null;
            this.revealing = false;
        }

        private void fade_in_internal ()
        {
            var opacity_from = this.opacity_animation != null
                    ? this.opacity_animation.value
                    : 0.0;
            var opacity_to = 1.0;

            if (!this._reveal) {
                return;
            }

            if (this.opacity_animation != null) {
                this.opacity_animation.pause ();
                this.opacity_animation = null;
            }

            var animation_target = new Adw.CallbackAnimationTarget (this.queue_draw);

            this.opacity_animation = new Adw.TimedAnimation (this,
                                                             opacity_from,
                                                             opacity_to,
                                                             FADE_IN_DURATION,
                                                             animation_target);
            this.opacity_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
            this.opacity_animation.done.connect (this.on_opacity_animation_done);
            this.opacity_animation.play ();
        }

        private void fade_in ()
        {
            if (this._reveal) {
                return;
            }

            this._reveal = true;
            this.revealing = true;
            this.notify_property ("reveal");

            if (this.get_mapped ()) {
                this.fade_in_internal ();
            }
        }

        private void fade_out ()
        {
            if (!this._reveal) {
                return;
            }

            var opacity_from = this.opacity_animation != null
                    ? this.opacity_animation.value
                    : 1.0;
            var opacity_to = 0.0;

            this._reveal = false;
            this.revealing = false;
            this.notify_property ("reveal");

            if (this.opacity_animation != null) {
                this.opacity_animation.pause ();
                this.opacity_animation = null;
            }

            if (this.get_mapped ())
            {
                var animation_target = new Adw.CallbackAnimationTarget (this.queue_draw);

                this.opacity_animation = new Adw.TimedAnimation (this,
                                                                 opacity_from,
                                                                 opacity_to,
                                                                 FADE_OUT_DURATION,
                                                                 animation_target);
                this.opacity_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
                this.opacity_animation.done.connect (this.on_opacity_animation_done);
                this.opacity_animation.play ();
            }
            else {
                this.on_opacity_animation_done ();
            }
        }


        /*
         * Timer / session change handlers
         */

        private void on_session_changed (Pomodoro.Session session)
        {
            this.queue_update ();
        }

        /**
         * Timer state may change after rescheduling / updating segments,
         * so only prod current segment if there's no timeout.
         */
        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            unowned Segment? segment = (Segment?) this.get_first_child ();
            unowned var current_time_block = (Pomodoro.TimeBlock?) current_state.user_data;

            if (current_time_block == null) {
                return;
            }

            while (segment != null)
            {
                if (segment.cycle?.contains (current_time_block) && !segment.has_timeout ()) {
                    segment.update_timeout ();
                    break;
                }

                segment = (Segment?) segment.get_next_sibling ();
            }
        }


        /*
         * Widget
         */

        public override void map ()
        {
            this.update ();

            this._timer.state_changed.connect (this.on_timer_state_changed);

            base.map ();

            if (this.revealing) {
                this.fade_in_internal ();
            }
        }

        public override void unmap ()
        {
            base.unmap ();

            if (this.scale_animation != null) {
                this.scale_animation.pause ();
                this.scale_animation = null;
            }

            if (this.opacity_animation != null) {
                this.opacity_animation.pause ();
                this.opacity_animation = null;
            }

            if (this.tick_callback_id != 0) {
                this.remove_tick_callback (this.tick_callback_id);
                this.tick_callback_id = 0;
            }

            this._timer.state_changed.disconnect (this.on_timer_state_changed);

            this.remove_segments ();
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        public override void measure (Gtk.Orientation orientation,
                                      int             for_size,
                                      out int         minimum,
                                      out int         natural,
                                      out int         minimum_baseline,
                                      out int         natural_baseline)
        {
            var line_width = (int) Math.ceilf (this._line_width);

            if (orientation == Gtk.Orientation.HORIZONTAL) {
                minimum = int.max (line_width, MIN_WIDTH);
                natural = int.max (minimum, for_size);
            }
            else {
                minimum = line_width;
                natural = minimum;
            }

            minimum_baseline = -1;
            natural_baseline = -1;
        }

        /**
         * All children have same allocation. This way animations can be a little smoother.
         */
        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            var allocation = Gtk.Allocation () {
                x      = 0,
                y      = 0,
                width  = width,
                height = height
            };
            unowned var child = this.get_first_child ();

            while (child != null)
            {
                child.allocate_size (allocation, baseline);

                child = child.get_next_sibling ();
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            var width        = (float) this.get_width ();
            var height       = (float) this.get_height ();
            var fade_applied = false;

            if (this.scale_animation != null)
            {
                var scale         = this.scale_animation.value;
                var norm          = 1.0 / this.scale_animation.value;
                var norm_from     = 1.0 / this.scale_animation.value_from;
                var norm_to       = 1.0 / this.scale_animation.value_to;
                var fade_x        = width * (float)(double.min (norm_from, norm_to) * scale);
                var fade_progress = (norm - norm_from) / (norm_to - norm_from);
                var fade_opacity  = norm_from >= norm_to
                        ? (float) fade_progress
                        : (float)(1.0 - fade_progress);

                if (fade_x < width)
                {
                    var fade_bounds = Graphene.Rect ();
                    fade_bounds.init (fade_x,
                                      0.0f,
                                      width - fade_x,
                                      height);

                    snapshot.push_mask (Gsk.MaskMode.INVERTED_ALPHA);
                    snapshot.append_linear_gradient (
                            fade_bounds,
                            { width, 0.0f },
                            { fade_x, 0.0f },
                            {
                                { 0.0f, { 0.0f, 0.0f, 0.0f, fade_opacity }},
                                { 1.0f, { 0.0f, 0.0f, 0.0f, 0.0f }},
                            });
                    snapshot.pop ();

                    fade_applied = true;
                }
            }

            if (this.opacity_animation != null) {
                snapshot.push_opacity (this.opacity_animation.value);
                this.snapshot_segments (snapshot);
                snapshot.pop ();
            }
            else if (this._reveal) {
                this.snapshot_segments (snapshot);
            }

            if (fade_applied) {
                snapshot.pop ();
            }
        }

        public override bool query_tooltip (int         x,
                                            int         y,
                                            bool        keyboard_tooltip,
                                            Gtk.Tooltip tooltip)
        {
            var timestamp = int64.max (this._timer.get_last_state_changed_time (),
                                       this._timer.get_last_tick_time ());
            var remaining = this._timer.is_running () &&
                            Pomodoro.Timestamp.is_defined (this.long_break_time)
                    ? Pomodoro.Timestamp.subtract (this.long_break_time, timestamp)
                    : 0;

            if (remaining > 0)
            {
                var seconds = Pomodoro.Timestamp.to_seconds (remaining);
                var seconds_uint = (uint) Pomodoro.round_seconds (seconds);

                tooltip.set_markup (_("Long break due in <b>%s</b>").printf (
                        Pomodoro.format_time (seconds_uint)));

                // TODO: connect to the timer tick to update the tooltip

                return true;
            }
            else {
                return base.query_tooltip (x, y, keyboard_tooltip, tooltip);
            }
        }

        public override void dispose ()
        {
            if (this.scale_animation != null) {
                this.scale_animation.pause ();
                this.scale_animation = null;
            }

            if (this.opacity_animation != null) {
                this.opacity_animation.pause ();
                this.opacity_animation = null;
            }

            if (this.value_animation != null) {
                this.value_animation.pause ();
                this.value_animation = null;
            }

            if (this.tick_callback_id != 0) {
                this.remove_tick_callback (this.tick_callback_id);
                this.tick_callback_id = 0;
            }

            if (this._session != null) {
                this._session.changed.disconnect (this.on_session_changed);
            }

            this.remove_segments ();

            this._timer.state_changed.disconnect (this.on_timer_state_changed);

            this._session_manager = null;
            this._timer = null;
            this._session = null;
            this.current_segment = null;

            base.dispose ();
        }
    }
}
