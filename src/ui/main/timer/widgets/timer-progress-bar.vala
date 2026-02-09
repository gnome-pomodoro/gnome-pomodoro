/*
 * Copyright (c) 2021-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Ft
{
    public enum TimerProgressShape
    {
        BAR,
        RING
    }


    public sealed class TimerProgressBar : Gtk.Widget
    {
        private const float  MIN_LINE_WIDTH = 6.0f;
        private const float  MAX_LINE_WIDTH = 8.0f;
        private const int    MIN_WIDTH = 100;
        private const uint   TIMEOUT_RESOLUTION = 2U;
        private const uint   MIN_TIMEOUT_INTERVAL = 25;  // 40Hz
        private const uint   FADE_IN_DURATION = 500;
        private const uint   FADE_OUT_DURATION = 500;

        public Ft.Timer timer {
            get {
                return this._timer;
            }
            construct {
                this._timer = value != null
                        ? value
                        : Ft.Timer.get_default ();
            }
        }

        [CCode (notify = false)]
        public Ft.TimerProgressShape shape {
            get {
                return this._shape;
            }
            construct {
                Ft.Gizmo through;
                Ft.Gizmo highlight;

                this._shape = value;

                switch (this._shape)
                {
                    case Ft.TimerProgressShape.BAR:
                        through = new Ft.Gizmo (
                                TimerProgressBar.measure_bar_cb,
                                null,
                                TimerProgressBar.snapshot_bar_through_cb,
                                null,
                                null,
                                null);
                        highlight = new Ft.Gizmo (
                                TimerProgressBar.measure_bar_cb,
                                null,
                                TimerProgressBar.snapshot_bar_highlight_cb,
                                null,
                                null,
                                null);
                        break;

                    case Ft.TimerProgressShape.RING:
                        through = new Ft.Gizmo (
                                TimerProgressBar.measure_ring_cb,
                                null,
                                TimerProgressBar.snapshot_ring_through_cb,
                                null,
                                null,
                                null);
                        highlight = new Ft.Gizmo (
                                TimerProgressBar.measure_ring_cb,
                                null,
                                TimerProgressBar.snapshot_ring_highlight_cb,
                                null,
                                null,
                                null);
                        break;

                    default:
                        assert_not_reached ();
                }

                through.focusable = false;
                through.add_css_class ("through");
                through.set_parent (this);

                highlight.focusable = false;
                highlight.add_css_class ("highlight");
                highlight.set_parent (this);

                this.through = through;
                this.highlight = highlight;

                this.queue_resize ();
            }
        }

        [CCode (notify = false)]
        public float line_width {
            get {
                return this._line_width;
            }
            set {
                if (this._line_width != value) {
                    this._line_width = value;
                    this.line_width_set = true;
                    this.notify_property ("line-width");
                    this.queue_allocate ();
                }
            }
        }

        [CCode (notify = false)]
        public bool line_width_set {
            get {
                return this._line_width_set;
            }
            set {
                if (this._line_width_set != value) {
                    this._line_width_set = value;
                    this.notify_property ("line-width-set");
                    this.queue_allocate ();
                }
            }
        }

        public float display_value {
            get {
                return (float) this._display_value;
            }
        }

        private Ft.TimerProgressShape   _shape = Ft.TimerProgressShape.BAR;
        private Ft.Timer                _timer;
        private float                   _line_width = MIN_LINE_WIDTH;
        private bool                    _line_width_set = false;
        private double                  _display_value = 0.0;
        private double                  display_value_from = 0.0;
        private double                  display_value_to = 0.0;
        private int64                   last_display_time = Ft.Timestamp.UNDEFINED;
        private Adw.TimedAnimation?     value_animation = null;
        private Adw.TimedAnimation?     opacity_animation = null;
        private unowned Ft.Gizmo        through = null;
        private unowned Ft.Gizmo        highlight = null;
        private ulong                   tick_id = 0U;
        private uint                    tick_callback_id = 0U;
        private uint                    timeout_id = 0U;
        private uint                    timeout_interval = 0U;
        private uint                    timeout_inhibit_count = 0U;
        private float                   radius;
        private float                   line_cap_radius;
        private float                   line_cap_angle;

        static construct
        {
            set_css_name ("timerprogressbar");
        }

        private inline int64 get_current_time ()
        {
            return this._timer.is_running ()
                    ? this._timer.get_current_time (this.get_frame_clock ().get_frame_time ())
                    : this._timer.get_last_state_changed_time ();
        }

        /**
         * Stop the timeout callbacks. Prioritise animations over the timeout. It's redundant to
         * run both.
         */
        private void inhibit_timeout ()
        {
            this.timeout_inhibit_count++;

            this.stop_timeout ();
        }

        private void uninhibit_timeout ()
        {
            if (this.timeout_inhibit_count > 0)
            {
                this.timeout_inhibit_count--;

                if (this.timeout_inhibit_count == 0 && this._timer.is_running ()) {
                    this.start_timeout ();
                }
            }
        }

        private void start_timeout ()
        {
            if (this.timeout_inhibit_count > 0) {
                return;
            }

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
                                            "Ft.TimerProgressBar.queue_draw");
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

        private void on_timer_state_changed (Ft.TimerState current_state,
                                             Ft.TimerState previous_state)
        {
            var timestamp = this._timer.get_last_state_changed_time ();
            var is_ring = this._shape == Ft.TimerProgressShape.RING;

            if (!current_state.is_finished () && previous_state.is_finished () && is_ring) {
                this.fade_in ();
            }
            else if (current_state.user_data != null && previous_state.user_data == null) {
                this.fade_in ();
            }
            else if (!current_state.is_started () && previous_state.is_started ()) {
                this.fade_out ();
            }

            if (this.opacity_animation == null &&
                (timestamp - this.last_display_time) < 5 * Ft.Interval.SECOND)
            {
                var value_from = this._display_value;
                var value_to = this._timer.calculate_progress (timestamp);

                this.animate_value (value_from, value_to);
            }

            if (current_state.is_running ()) {
                this.start_timeout ();
            }
            else {
                this.stop_timeout ();
            }

            this.highlight.queue_draw ();
        }

        private void on_opacity_animation_done ()
        {
            this.opacity_animation = null;
            this.uninhibit_timeout ();
        }

        private void on_value_animation_done ()
        {
            this.value_animation = null;
            this.uninhibit_timeout ();
        }

        private float calculate_line_width (int size)
        {
            // HACK: sizing is hard-coded for the TimerView; perhaps it's not the best place
            var size_float = (float) Math.roundf ((float) size);
            var min_size   = 300.0f;
            var max_size   = 450.0f;
            var t          = ((size_float - min_size) / (max_size - min_size)).clamp (0.0f, 1.0f);

            return Math.roundf (lerpf (MIN_LINE_WIDTH, MAX_LINE_WIDTH, t));
        }

        private uint calculate_timeout_interval ()
        {
            int64 distance;

            switch (this._shape)
            {
                case Ft.TimerProgressShape.BAR:
                    distance = (int64) this.get_width ();
                    break;

                case Ft.TimerProgressShape.RING:
                    distance = (int64) Math.ceil (2.0 * Math.PI * (double) this.radius);
                    break;

                default:
                    assert_not_reached ();
            }

            distance *= TIMEOUT_RESOLUTION;

            return distance > 0
                    ? Ft.Timestamp.to_milliseconds_uint (this._timer.duration / distance)
                    : 0;
        }

        private uint calculate_animation_duration (double value_from,
                                                   double value_to)
        {
            switch (this._shape)
            {
                case Ft.TimerProgressShape.BAR:
                    return (uint)(Math.sqrt ((value_to - value_from).abs ()) * 500.0);

                case Ft.TimerProgressShape.RING:
                    return (uint)(Math.sqrt ((value_to - value_from).abs ()) * 1000.0);

                default:
                    assert_not_reached ();
            }
        }

        private void fade_in ()
        {
            var opacity_from = this.opacity_animation != null
                    ? this.opacity_animation.value
                    : 0.0;
            var opacity_to = 1.0;

            if (this.opacity_animation != null) {
                this.opacity_animation.pause ();
                this.opacity_animation = null;
                this.uninhibit_timeout ();
            }

            if (this.get_mapped ())
            {
                this.inhibit_timeout ();

                var animation_target = new Adw.CallbackAnimationTarget (this.highlight.queue_draw);

                this.opacity_animation = new Adw.TimedAnimation (this.highlight,
                                                                 opacity_from,
                                                                 opacity_to,
                                                                 FADE_IN_DURATION,
                                                                 animation_target);
                this.opacity_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
                this.opacity_animation.done.connect (this.on_opacity_animation_done);
                this.opacity_animation.play ();
            }
        }

        private void fade_out ()
        {
            var opacity_from = this.opacity_animation != null
                    ? this.opacity_animation.value
                    : 1.0;
            var opacity_to = 0.0;

            if (this.opacity_animation != null) {
                this.opacity_animation.pause ();
                this.opacity_animation = null;
                this.uninhibit_timeout ();
            }

            if (this.get_mapped ())
            {
                this.inhibit_timeout ();

                var animation_target = new Adw.CallbackAnimationTarget (this.highlight.queue_draw);

                this.opacity_animation = new Adw.TimedAnimation (this.highlight,
                                                                 opacity_from,
                                                                 opacity_to,
                                                                 FADE_OUT_DURATION,
                                                                 animation_target);
                this.opacity_animation.set_easing (Adw.Easing.EASE_IN_OUT_CUBIC);
                this.opacity_animation.done.connect (this.on_opacity_animation_done);
                this.opacity_animation.play ();
            }
        }

        private void animate_value (double value_from,
                                    double value_to)
                                    requires (value_from.is_finite ())
                                    requires (value_to.is_finite ())
        {
            if ((value_from - value_to).abs () < 0.01) {
                return;
            }

            if (this.value_animation != null) {
                this.value_animation.pause ();
                this.value_animation = null;
                this.uninhibit_timeout ();
            }

            if (this.get_mapped ())
            {
                this.inhibit_timeout ();

                var animation_duration = this.calculate_animation_duration (value_from, value_to);
                var animation_target = new Adw.CallbackAnimationTarget (this.highlight.queue_draw);

                this.value_animation = new Adw.TimedAnimation (this.highlight,
                                                               0.0,
                                                               1.0,
                                                               animation_duration,
                                                               animation_target);
                this.value_animation.set_easing (this._timer.is_paused ()
                                                 ? Adw.Easing.EASE_IN_OUT_CUBIC
                                                 : Adw.Easing.EASE_OUT_QUAD);
                this.value_animation.done.connect (this.on_value_animation_done);
                this.value_animation.play ();

                this.display_value_from = value_from;
                this.display_value_to = value_to;
            }
        }


        /*
         * Bar shape
         */

        private static void measure_bar_cb (Ft.Gizmo        gizmo,
                                            Gtk.Orientation orientation,
                                            int             for_size,
                                            out int         minimum,
                                            out int         natural,
                                            out int         minimum_baseline,
                                            out int         natural_baseline)
        {
            unowned var self = (Ft.TimerProgressBar) gizmo.parent;

            if (self != null) {
                self.measure_bar (gizmo,
                                  orientation,
                                  for_size,
                                  out minimum,
                                  out natural,
                                  out minimum_baseline,
                                  out natural_baseline);
            }
            else {
                minimum = 0;
                natural = 0;
                minimum_baseline = -1;
                natural_baseline = -1;
            }
        }

        private static void snapshot_bar_through_cb (Ft.Gizmo     gizmo,
                                                     Gtk.Snapshot snapshot)
        {
            unowned var self = (Ft.TimerProgressBar) gizmo.parent;

            if (self != null) {
                self.snapshot_bar_through (gizmo, snapshot);
            }
        }

        private static void snapshot_bar_highlight_cb (Ft.Gizmo     gizmo,
                                                       Gtk.Snapshot snapshot)
        {
            unowned var self = (Ft.TimerProgressBar) gizmo.parent;

            if (self != null) {
                self.snapshot_bar_highlight (gizmo, snapshot);
            }
        }

        private void measure_bar (Ft.Gizmo        gizmo,
                                  Gtk.Orientation orientation,
                                  int             for_size,
                                  out int         minimum,
                                  out int         natural,
                                  out int         minimum_baseline,
                                  out int         natural_baseline)
        {
            if (orientation == Gtk.Orientation.VERTICAL)
            {
                minimum = (int) Math.ceilf (this._line_width);
                natural = minimum;
            }
            else {
                minimum = MIN_WIDTH;
                natural = minimum;
            }

            minimum_baseline = -1;
            natural_baseline = -1;
        }

        private void snapshot_bar_through (Ft.Gizmo     gizmo,
                                           Gtk.Snapshot snapshot)
        {
            var width  = (float) gizmo.get_width ();
            var height = (float) gizmo.get_height ();
            var color  = gizmo.get_color ();

            var through_width   = width;
            var through_height  = this._line_width;
            var through_x       = 0.0f;
            var through_y       = (height - through_height) / 2.0f;
            var through_bounds  = Graphene.Rect ();
            var through_outline = Gsk.RoundedRect ();

            through_bounds.init (through_x,
                                 through_y,
                                 through_width,
                                 through_height);
            through_outline.init_from_rect (through_bounds, through_height / 2.0f);

            snapshot.push_rounded_clip (through_outline);
            snapshot.append_color (color, through_bounds);
            snapshot.pop ();
        }

        private void snapshot_bar_highlight (Ft.Gizmo     gizmo,
                                             Gtk.Snapshot snapshot)
        {
            double display_value;

            var opacity = this.opacity_animation != null
                    ? this.opacity_animation.value
                    : 1.0;
            var timestamp = this.get_current_time ();

            if (this.opacity_animation == null ||
                this.opacity_animation.value_to > 0.0)
            {
                display_value = this._timer.user_data != null
                        ? this._timer.calculate_progress (this.get_current_time ())
                        : 0.0;
            }
            else {
                display_value = this._display_value;
            }

            if (this.value_animation != null) {
                display_value = lerp (this.display_value_from,
                                      display_value,
                                      this.value_animation.value);
            }

            if (display_value <= 0.0 || opacity == 0.0)
            {
                this._display_value = 0.0;
                this.last_display_time = timestamp;

                return;  // Nothing to draw
            }

            var width           = (float) gizmo.get_width ();
            var height          = (float) gizmo.get_height ();
            var color           = gizmo.get_color ();
            var clip_applied    = false;
            var opacity_applied = false;

            if (opacity < 1.0) {
                snapshot.push_opacity (this.opacity_animation.value);
                opacity_applied = true;
            }

            var highlight_width   = width * float.min ((float) display_value, 1.0f);
            var highlight_height  = this._line_width;
            var highlight_x       = 0.0f;
            var highlight_y       = (height - highlight_height) / 2.0f;
            var highlight_bounds  = Graphene.Rect ();
            var highlight_outline = Gsk.RoundedRect ();

            if (this.get_direction () == Gtk.TextDirection.RTL) {
                highlight_x = width - highlight_x - highlight_width;
            }

            if (highlight_width < highlight_height)
            {
                var clip_bounds  = Graphene.Rect ();
                var clip_outline = Gsk.RoundedRect ();
                clip_bounds.init (0.0f,
                                  highlight_y,
                                  width,
                                  highlight_height);
                clip_outline.init_from_rect (clip_bounds, highlight_height / 2.0f);
                snapshot.push_rounded_clip (clip_outline);

                highlight_x    -= highlight_height - highlight_width;
                highlight_width = highlight_height;
                clip_applied    = true;
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

            if (opacity_applied) {
                snapshot.pop ();
            }

            this._display_value = display_value;
            this.last_display_time = timestamp;
        }


        /*
         * Ring shape
         */

        private static void measure_ring_cb (Ft.Gizmo        gizmo,
                                             Gtk.Orientation orientation,
                                             int             for_size,
                                             out int         minimum,
                                             out int         natural,
                                             out int         minimum_baseline,
                                             out int         natural_baseline)
        {
            unowned var self = (Ft.TimerProgressBar) gizmo.parent;

            if (self != null) {
                self.measure_ring (gizmo,
                                    orientation,
                                    for_size,
                                    out minimum,
                                    out natural,
                                    out minimum_baseline,
                                    out natural_baseline);
            }
            else {
                minimum = 0;
                natural = 0;
                minimum_baseline = -1;
                natural_baseline = -1;
            }
        }

        private static void snapshot_ring_through_cb (Ft.Gizmo     gizmo,
                                                      Gtk.Snapshot snapshot)
        {
            unowned var self = (Ft.TimerProgressBar) gizmo.parent;

            if (self != null) {
                self.snapshot_ring_through (gizmo, snapshot);
            }
        }

        private static void snapshot_ring_highlight_cb (Ft.Gizmo     gizmo,
                                                        Gtk.Snapshot snapshot)
        {
            unowned var self = (Ft.TimerProgressBar) gizmo.parent;

            if (self != null) {
                self.snapshot_ring_highlight (gizmo, snapshot);
            }
        }

        private void measure_ring (Ft.Gizmo        gizmo,
                                   Gtk.Orientation orientation,
                                   int             for_size,
                                   out int         minimum,
                                   out int         natural,
                                   out int         minimum_baseline,
                                   out int         natural_baseline)
        {
            minimum = int.max (for_size, MIN_WIDTH);
            natural = minimum;
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        private void snapshot_ring_through (Ft.Gizmo     gizmo,
                                            Gtk.Snapshot snapshot)
        {
            var color = gizmo.get_color ();
            var origin = Graphene.Point () {
                x = (float) gizmo.get_width () / 2.0f,
                y = (float) gizmo.get_height () / 2.0f
            };

            var path_builder = new Gsk.PathBuilder ();
            path_builder.add_circle (origin, this.radius);

            var stroke = new Gsk.Stroke (this._line_width);
            snapshot.append_stroke (path_builder.to_path (), stroke, color);
        }

        private void snapshot_ring_highlight (Ft.Gizmo     gizmo,
                                              Gtk.Snapshot snapshot)
        {
            double display_value;

            var opacity = this.opacity_animation != null
                    ? this.opacity_animation.value
                    : 1.0;
            var timestamp = this.get_current_time ();

            if (this.opacity_animation == null ||
                this.opacity_animation.value_to > 0.0)
            {
                display_value = this._timer.user_data != null && !this._timer.is_finished ()
                        ? this._timer.calculate_progress (timestamp)
                        : 1.0;
            }
            else {
                display_value = this._display_value;
            }

            if (this.value_animation != null) {
                display_value = lerp (this.display_value_from,
                                      display_value,
                                      this.value_animation.value);
            }

            if (display_value >= 1.0 || opacity == 0.0)
            {
                this._display_value = 1.0;
                this.last_display_time = timestamp;

                return;  // Nothing to draw
            }

            var color = gizmo.get_color ();
            var origin = Graphene.Point () {
                x = (float) gizmo.get_width () / 2.0f,
                y = (float) gizmo.get_height () / 2.0f
            };
            var path_builder = new Gsk.PathBuilder ();
            var clip_applied = false;
            var opacity_applied = false;

            if (opacity < 1.0) {
                snapshot.push_opacity (opacity);
                opacity_applied = true;
            }

            // Draw a circular arc representing remaining time. The arc starts at the top
            // of the circle (-90°) and sweeps counter-clockwise as time progresses.
            // For edge cases (sweep > 360° or < 0°), we apply clipping and adjust the starting
            // point to handle line cap rendering correctly. `svg_arc_to ()` requires an arc
            // endpoint, so we do some trigonometry.
            if (display_value < 0.001) {
                path_builder.add_circle (origin, this.radius);
            }
            else if (display_value < 0.999)
            {
                var sweep_angle = (2.0 * Math.PI + this.line_cap_angle) * (1.0 - display_value) -
                                  this.line_cap_angle;

                if (sweep_angle > 2.0 * Math.PI) {
                    path_builder.move_to (origin.x + this.radius, origin.y);
                    clip_applied = true;
                }
                else if (sweep_angle < 0.0) {
                    path_builder.move_to (origin.x - this.radius, origin.y);
                    clip_applied = true;
                }
                else {
                    path_builder.move_to (origin.x, origin.y - this.radius);
                }

                if (clip_applied)
                {
                    var clip_bounds  = Graphene.Rect ();
                    var clip_outline = Gsk.RoundedRect ();
                    clip_bounds.init (origin.x - this._line_width / 2.0f,
                                      origin.y - this.radius - this._line_width / 2.0f,
                                      this._line_width,
                                      this._line_width);
                    clip_outline.init_from_rect (clip_bounds, this._line_width / 2.0f);
                    snapshot.push_rounded_clip (clip_outline);
                }

                float sin_angle, cos_angle;
                Math.sincosf ((float)(-Math.PI_2 + sweep_angle), out sin_angle, out cos_angle);

                path_builder.svg_arc_to (this.radius,
                                         this.radius,
                                         0.0f,
                                         sweep_angle > Math.PI,
                                         true,
                                         origin.x + this.radius * cos_angle,
                                         origin.y + this.radius * sin_angle);
            }

            var stroke = new Gsk.Stroke (this._line_width);
            stroke.set_line_cap (Gsk.LineCap.ROUND);

            snapshot.append_stroke (path_builder.to_path (), stroke, color);

            if (clip_applied) {
                snapshot.pop ();
            }

            if (opacity_applied) {
                snapshot.pop ();
            }

            this._display_value = display_value;
            this.last_display_time = timestamp;
        }


        /*
         * Widget
         */

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
            var minimum_for_size = 0;

            this.through.measure (get_opposite_orientation (orientation),
                                  -1,
                                  out minimum_for_size,
                                  null,
                                  null,
                                  null);
            this.through.measure (orientation,
                                  int.max (minimum_for_size, for_size),
                                  out minimum,
                                  out natural,
                                  null,
                                  null);

            minimum_baseline = -1;
            natural_baseline = -1;
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            float line_width;

            if (!this._line_width_set)
            {
                switch (this._shape)
                {
                    case Ft.TimerProgressShape.BAR:
                        line_width = this.calculate_line_width (width);
                        break;

                    case Ft.TimerProgressShape.RING:
                        var size = int.min (width, height);
                        line_width = this.calculate_line_width (size);

                        this.radius = ((float) size - line_width) / 2.0f;
                        this.line_cap_radius = line_width / 2.0f;
                        this.line_cap_angle = Math.atan2f (2.0f * this.line_cap_radius,
                                                           this.radius);
                        break;

                    default:
                        assert_not_reached ();
                }
            }
            else {
                line_width = this._line_width;
            }

            if (this._line_width != line_width) {
                this._line_width = line_width;
                this.notify_property ("line-width");
            }

            this.through.allocate (width, height, baseline, null);
            this.highlight.allocate (width, height, baseline, null);
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            this.snapshot_child (this.through, snapshot);
            this.snapshot_child (this.highlight, snapshot);
        }

        public override void map ()
        {
            base.map ();

            this._timer.state_changed.connect (this.on_timer_state_changed);
            this.timeout_inhibit_count = 0;

            if (this._timer.is_running ()) {
                this.start_timeout ();
            }
        }

        public override void unmap ()
        {
            this.stop_timeout ();

            this._timer.state_changed.disconnect (this.on_timer_state_changed);

            if (this.value_animation != null) {
                this.value_animation.pause ();
                this.value_animation = null;
            }

            if (this.opacity_animation != null) {
                this.opacity_animation.pause ();
                this.opacity_animation = null;
            }

            base.unmap ();
        }

        public override void dispose ()
        {
            this.stop_timeout ();

            if (this.value_animation != null) {
                this.value_animation.pause ();
                this.value_animation = null;
            }

            if (this.opacity_animation != null) {
                this.opacity_animation.pause ();
                this.opacity_animation = null;
            }

            this.through.unparent ();
            this.highlight.unparent ();

            this.through = null;
            this.highlight = null;
            this._timer = null;

            base.dispose ();
        }
    }
}
