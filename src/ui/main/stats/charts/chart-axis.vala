/*
 * Copyright (c) 2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Ft
{
    [CCode (scope = "weak")]
    public delegate string FormatValueFunc (double value);


    public class ChartAxis : Gtk.Widget
    {
        private const double EPSILON = 0.00001;
        private const uint   MAX_TICKS = 24;

        // How much we allow to go beyond value range to display a tick
        private const float EXTENT = 0.2f;

        public Gtk.Orientation orientation {
            get {
                return this._orientation;
            }
            construct {
                this._orientation = value;
            }
        }

        public float value_from {
            get {
                return this._value_from;
            }
        }

        public float value_to {
            get {
                return this._value_to;
            }
        }

        public float value_spacing {
            get {
                return this._value_spacing;
            }
        }

        public float scale {
            get {
                return this._scale;
            }
            set {
                if (this._scale != value) {
                    this._scale = value;
                }
            }
        }

        public int text_offset {
            get {
                return this._text_offset;
            }
            set {
                if (this._text_offset != value) {
                    this._text_offset = value;
                }
            }
        }

        public bool continous {
            get {
                return this._continous;
            }
            set {
                this._continous = value;

                this.queue_resize ();
            }
        }

        public int origin {
            get {
                return this._origin;
            }
            set {
                this._origin = value;

                this.queue_resize ();
            }
        }

        internal int label_width;
        internal int label_height;

        private Gtk.Orientation     _orientation = Gtk.Orientation.HORIZONTAL;
        private float               _value_from = 0.0f;
        private float               _value_to = 1.0f;
        private float               _value_spacing = 1.0f;
        private float               _scale = 1.0f;
        private int                 _text_offset = 0;
        private bool                _continous = true;
        private int                 _origin = 0;
        private float[]             ticks = null;
        private Pango.Layout[]      layouts = null;
        private Ft.FormatValueFunc? format_value_func = null;

        static construct
        {
            set_css_name ("chartaxis");
        }

        construct
        {
            this.layouts = {};
        }

        public ChartAxis (Gtk.Orientation           orientation,
                          owned Ft.FormatValueFunc? format_value_func = null)
        {
            GLib.Object (
                orientation: orientation,
                focusable: false
            );

            this.format_value_func = (owned) format_value_func;
        }

        private static float[] create_ticks (float value_from,
                                             float value_to,
                                             float value_spacing)
                                             requires (value_spacing.abs () > EPSILON)
        {
            var tick_from   = (int) Math.floorf (value_from / value_spacing);
            var tick_to     = int.max ((int) Math.ceilf (value_to / value_spacing), tick_from + 1);

            var tick_count  = tick_to > tick_from ? tick_to - tick_from + 1 : 0;
            var tick_values = new float[tick_count];

            for (var index = 0; index < tick_values.length; index++) {
                tick_values[index] = (float)(tick_from + index) * value_spacing;
            }

            value_from = tick_values[0];
            value_to   = tick_values[tick_values.length - 1];

            return tick_values;
        }

        private inline Pango.Alignment get_text_alignment ()
        {
            switch (this._orientation)
            {
                case Gtk.Orientation.HORIZONTAL:
                    return Pango.Alignment.CENTER;

                case Gtk.Orientation.VERTICAL:
                    return Pango.Alignment.RIGHT;

                default:
                    assert_not_reached ();
            }
        }

        private inline string format_value (float value)
        {
            return this.format_value_func != null
                    ? this.format_value_func ((double) value)
                    : value.to_string ();
        }

        /**
         * Determine optimal ticks to display on an axis
         */
        private void calculate_ticks (float       value_from,
                                      float       value_to,
                                      float       value_spacing,
                                      int         available_size,
                                      out float[] ticks,
                                      out int     label_width,
                                      out int     label_height)
        {
            // Define possible tick values
            float[] tick_values;

            if (this._continous)
            {
                var value_from_extended = value_from - (value_to - value_from) * EXTENT;
                var value_to_extended = value_to + (value_to - value_from) * EXTENT;

                if (value_from >= 0.0f && value_from_extended < 0.0f) {
                    value_from_extended = value_from;
                }

                if (value_to <= 0.0f && value_to_extended > 0.0f) {
                    value_to_extended = value_to;
                }

                tick_values = create_ticks (value_from_extended, value_to_extended, value_spacing);
            }
            else {
                tick_values = create_ticks (value_from, value_to, value_spacing);
            }

            // Find index of the origin point
            var origin_value = 0.0f;
            var origin_index = (int) Math.roundf ((origin_value - tick_values[0]) / value_spacing);

            // Prepare a Pango layout to estimate label size
            var context = this.create_pango_context ();
            var layout = new Pango.Layout (context);
            layout.set_width (-1);

            var label_sizes = new int[tick_values.length, 2];

            for (var tick_index = 0; tick_index < tick_values.length; tick_index++)
            {
                label_sizes[tick_index, 0] = -1;
                label_sizes[tick_index, 1] = -1;
            }

            // Determine optimal stride and offset
            var min_stride = int.max (tick_values.length / (int) MAX_TICKS, 1);
            var max_stride = int.max (tick_values.length / 2, 1);
            var best_stride = 0;
            var best_offset = 0;
            var best_tick_count = 0;
            var best_label_width = 0;
            var best_label_height = 0;
            var best_score = 0.0f;

            for (var candidate_stride = max_stride;
                 candidate_stride >= min_stride;
                 candidate_stride--)
            {
                // Calculate optimal offset and tick_count
                var tick_index_from = origin_index - candidate_stride * (int) Math.roundf (
                        (value_from - origin_value) / (value_spacing * (float) candidate_stride));
                var tick_index_to = origin_index + candidate_stride * (int) Math.roundf (
                        (value_to - origin_value) / (value_spacing * (float) candidate_stride));

                if (tick_index_from < 0) {
                    tick_index_from = 0;
                }

                if (tick_index_to > tick_values.length - 1) {
                    tick_index_to = tick_values.length - 1;
                }

                if (tick_index_to == tick_index_from)
                {
                    if (tick_index_to + candidate_stride >= tick_values.length - 1) {
                        tick_index_to += candidate_stride;
                    }
                    else if (tick_index_from - candidate_stride >= 0) {
                        tick_index_from -= candidate_stride;
                    }
                }

                var candidate_offset = tick_index_from;
                var candidate_tick_count = (tick_index_to - tick_index_from) / candidate_stride + 1;

                if (candidate_tick_count < 2) {
                    continue;
                }

                // Estimate label size for the candidate stride and offset
                var candidate_label_width = 0;
                var candidate_label_height = 0;

                for (var tick_index = tick_index_from;
                     tick_index <= tick_index_to;
                     tick_index += candidate_stride)
                {
                    if (label_sizes[tick_index, 0] < 0 || label_sizes[tick_index, 1] < 0)
                    {
                        var tick_label = this.format_value (tick_values[tick_index]);

                        layout.set_text (tick_label, tick_label.length);
                        layout.get_pixel_size (out label_sizes[tick_index, 0],
                                               out label_sizes[tick_index, 1]);
                    }

                    candidate_label_width  = int.max (label_sizes[tick_index, 0],
                                                      candidate_label_width);
                    candidate_label_height = int.max (label_sizes[tick_index, 1],
                                                      candidate_label_height);
                }

                // Check if the number of ticks can fit the `available_size`
                var candidate_label_size = this._orientation == Gtk.Orientation.HORIZONTAL
                        ? candidate_label_width
                        : candidate_label_height;
                var candidate_spacing = this._orientation == Gtk.Orientation.HORIZONTAL
                        ? candidate_label_size
                        : candidate_label_size * 2;
                var candidate_size =
                        (candidate_label_size + candidate_spacing) * (candidate_tick_count - 1) +
                        candidate_label_size;

                if (candidate_size > available_size)
                {
                    if (best_stride == 0) {
                        continue;
                    }
                    else {
                        // Reducing stride further is unlikely to get better candidates
                        break;
                    }
                }

                // Select a candidate that spans the most and has the most ticks.
                var candidate_score = (float) candidate_tick_count * (float) candidate_size;

                if (candidate_score >= best_score)
                {
                    best_stride       = candidate_stride;
                    best_offset       = candidate_offset;
                    best_tick_count   = candidate_tick_count;
                    best_label_width  = candidate_label_width;
                    best_label_height = candidate_label_height;
                    best_score        = candidate_score;
                }
            }

            if (best_tick_count >= 2)
            {
                ticks        = new float[best_tick_count];
                label_width  = best_label_width;
                label_height = best_label_height;

                for (var tick_index = 0; tick_index < ticks.length; tick_index++) {
                    ticks[tick_index] += tick_values[tick_index * best_stride + best_offset];
                }
            }
            else {
                // Not a likely scenario
                GLib.warning ("Could not determine axis ticks for range %f to %f and spacing %f",
                              value_from, value_to, value_spacing);

                ticks        = new float[2];
                label_width  = 0;
                label_height = 0;

                ticks[0] = Math.roundf ((value_from - origin_value) / value_spacing) *
                           value_spacing + origin_value;
                ticks[1] = ticks[0] + value_spacing;

                for (var tick_index = 0; tick_index < ticks.length; tick_index++)
                {
                    var tick_label = this.format_value (ticks[tick_index]);
                    var tmp_label_width = 0;
                    var tmp_label_height = 0;

                    layout.set_text (tick_label, tick_label.length);
                    layout.get_pixel_size (out tmp_label_width, out tmp_label_height);

                    label_width  = int.max (label_width, tmp_label_width);
                    label_height = int.max (label_height, tmp_label_height);
                }
            }
        }

        public void set_format_value_func (owned Ft.FormatValueFunc? func)
        {
            this.format_value_func = (owned) func;

            this.queue_resize ();
        }

        /**
         * Determine displayed value range calculate ticks.
         */
        public void configure (float value_from,
                               float value_to,
                               float value_spacing,
                               int   available_size)
        {
            this.calculate_ticks (value_from,
                                  value_to,
                                  value_spacing,
                                  available_size,
                                  out this.ticks,
                                  out this.label_width,
                                  out this.label_height);

            this._value_from = float.min (this.ticks[0], value_from);
            this._value_to = float.max (this.ticks[this.ticks.length - 1], value_to);

            this.configured ();

            this.queue_resize ();
        }

        public float[] get_ticks ()
        {
            return this.ticks;
        }

        public Ft.ChartAxis detach ()
        {
            var clone = (Ft.ChartAxis) GLib.Object.@new (
                    typeof (Ft.ChartAxis),
                    orientation: this._orientation);

            var initial_ref_count  = this.ref_count;
            weak Ft.ChartAxis self = this;
            GLib.WeakRef weak_clone = GLib.WeakRef (clone);
            ulong configured_id = 0,
                  destroy_id = 0,
                  clone_destroy_id = 0;

            clone.set_format_value_func (
                (value) => {
                    return self.format_value_func != null
                            ? self.format_value_func (value)
                            : value.to_string ();
                });
            this.bind_property ("scale",
                                clone,
                                "scale",
                                GLib.BindingFlags.SYNC_CREATE);
            this.bind_property ("text-offset",
                                clone,
                                "text-offset",
                                GLib.BindingFlags.SYNC_CREATE);
            this.bind_property ("origin",
                                clone,
                                "origin",
                                GLib.BindingFlags.SYNC_CREATE);

            configured_id = this.configured.connect (
                () => {
                    var _clone = (Ft.ChartAxis) weak_clone.get ();

                    if (_clone != null)
                    {
                        _clone._value_to = self._value_to;
                        _clone.label_width = self.label_width;
                        _clone.label_height = self.label_height;
                        _clone.ticks = self.ticks;
                    }
                });
            destroy_id = this.destroy.connect (
                () => {
                    var _clone = (Ft.ChartAxis) weak_clone.get ();

                    if (_clone != null) {
                        _clone.set_format_value_func (null);
                    }

                    if (_clone != null && clone_destroy_id != 0) {
                        _clone.disconnect (clone_destroy_id);
                        clone_destroy_id = 0;
                    }

                    if (configured_id != 0) {
                        self.disconnect (configured_id);
                        configured_id = 0;
                    }

                    if (destroy_id != 0) {
                        self.disconnect (destroy_id);
                        destroy_id = 0;
                    }
                });
            clone_destroy_id = clone.destroy.connect (
                () => {
                    var _clone = (Ft.ChartAxis) weak_clone.get ();

                    if (_clone != null) {
                        _clone.set_format_value_func (null);
                    }

                    if (_clone != null && clone_destroy_id != 0) {
                        _clone.disconnect (clone_destroy_id);
                        clone_destroy_id = 0;
                    }

                    if (configured_id != 0) {
                        self.disconnect (configured_id);
                        configured_id = 0;
                    }

                    if (destroy_id != 0) {
                        self.disconnect (destroy_id);
                        destroy_id = 0;
                    }
                });

            this.visible = false;

            assert (this.ref_count == initial_ref_count);

            return clone;
        }

        public inline bool is_detached ()
        {
            return !this.visible;
        }


        /*
         * Widget
         */

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        public override void measure (Gtk.Orientation orientation,
                                      int             for_size,
                                      out int         minimum,
                                      out int         natural,
                                      out int         minimum_baseline,
                                      out int         natural_baseline)
        {
            var label_size = orientation == Gtk.Orientation.HORIZONTAL
                    ? this.label_width : this.label_height;

            natural = this._orientation == orientation
                    ? label_size / 2 + this.origin
                    : label_size + this.text_offset;
            minimum = natural;
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            var context = this.create_pango_context ();
            var text_alignment = this.get_text_alignment ();

            this.layouts = new Pango.Layout[this.ticks.length];

            for (var tick_index = 0; tick_index < this.ticks.length; tick_index++)
            {
                var tick_value = this.ticks[tick_index];
                var tick_label = this.format_value (tick_value);

                var layout = new Pango.Layout (context);
                layout.set_width (this.label_width * Pango.SCALE);
                layout.set_alignment (text_alignment);
                layout.set_ellipsize (Pango.EllipsizeMode.NONE);
                layout.set_wrap (Pango.WrapMode.WORD);
                layout.set_text (tick_label, tick_label.length);

                this.layouts[tick_index] = layout;
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            var tick_count = int.min (this.ticks.length, this.layouts.length);

            if (this.ticks.length != this.layouts.length) {
                GLib.warning ("Number of layouts (%d) does not match the number of ticks (%d)",
                              this.layouts.length,
                              this.ticks.length);
            }

            var color = this.get_color ();
            var scale = this._orientation == Gtk.Orientation.HORIZONTAL
                    ? this._scale
                    : -this._scale;

            for (var tick_index = 0; tick_index < tick_count; tick_index++)
            {
                var tick_value      = this.ticks[tick_index];
                unowned var layout  = this.layouts[tick_index];
                var layout_position = (float) this._origin + tick_value * scale;
                var layout_offset   = (float) this._text_offset;
                var layout_width    = (float) this.label_width;
                var layout_height   = (float) this.label_height;
                Graphene.Point layout_origin;

                switch (this._orientation)
                {
                    case Gtk.Orientation.HORIZONTAL:
                        layout_origin = Graphene.Point () {
                            x = layout_position - layout_width / 2.0f,
                            y = layout_offset
                        };
                        break;

                    case Gtk.Orientation.VERTICAL:
                        layout_origin = Graphene.Point () {
                            x = (float) this.get_width () - layout_offset - layout_width,
                            y = layout_position - layout_height / 2.0f
                        };
                        break;

                    default:
                        assert_not_reached ();
                }

                // `append_layout` places the layout with bottom-left corner as its origin
                snapshot.save ();
                snapshot.translate (layout_origin);
                snapshot.append_layout (layout, color);
                snapshot.restore ();
            }
        }

        public signal void configured ();

        public override void dispose ()
        {
            this.ticks = null;
            this.layouts = null;
            this.format_value_func = null;

            base.dispose ();
        }
    }
}
