/*
 * Copyright (c) 2025 gnome-pomodoro contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Pomodoro
{
    public enum Unit
    {
        AMOUNT,
        PERCENT,
        INTERVAL;

        public string format (double value)
        {
            if (value.is_nan ()) {
                return "–";
            }

            switch (this)
            {
                case AMOUNT:
                    var value_rounded = (long) Math.round (value * 10.0);
                    var number        = value_rounded / 10;
                    var decimal       = value_rounded.abs () % 10;

                    return decimal == 0 ? number.to_string () : @"$(number).$(decimal)";

                case PERCENT:
                    var value_rounded = (int) Math.round (100.0 * value);

                    return @"$(value_rounded)%";

                case INTERVAL:
                    // round +/- 10s
                    var value_rounded = 20.0 * Math.round (value / 20.0);

                    return Pomodoro.Interval.format_short (
                            Pomodoro.Interval.from_seconds (value_rounded));

                default:
                    assert_not_reached ();
            }
        }
    }


    private struct Category
    {
        public string        label;
        public Gdk.RGBA      color;
        public Pomodoro.Unit unit;
        public bool          visible;
    }


    private struct Bucket
    {
        public string label;
        public string tooltip_label;
    }


    /**
     * Base class for drawing a 2D charts with X and Y axes.
     *
     * The content is scrollable horizontally.
     */
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/chart.ui")]
    public abstract class Chart : Gtk.Widget, Gtk.Buildable
    {
        private const int MIN_WIDTH = 300;
        private const int MIN_HEIGHT = 150;
        private const double EPSILON = 0.00001;

        /**
         * Interval between ticks on x axis
         */
        public float x_spacing {
            get {
                return this._x_spacing;
            }
            set {
                if (this._x_spacing == value) {
                    return;
                }

                this._x_spacing = value;

                this.queue_allocate ();
            }
        }

        /**
         * Interval between ticks on y axis
         */
        public float y_spacing {
            get {
                return this._y_spacing;
            }
            set {
                if (this._y_spacing == value) {
                    return;
                }

                this._y_spacing = value;

                this.queue_allocate ();
            }
        }

        public float aspect_ratio {
            get {
                return this._aspect_ratio;
            }
            set {
                this._aspect_ratio = value;

                this.queue_resize ();
            }
        }

        [GtkChild]
        protected unowned Pomodoro.ChartContents contents;
        [GtkChild]
        private unowned Gtk.ScrolledWindow scrolled_window;

        private Pomodoro.ChartAxis? y_axis = null;
        private float               _x_spacing = 1.0f;
        private float               _y_spacing = 1.0f;
        private float               _aspect_ratio = 1.0f;
        private double              drag_start_x;
        private bool                zooming = false;
        private double              zoom_x_value;
        private double              zoom_y_value;
        private double              zoom_x;
        private double              zoom_y;
        private FormatValueFunc?    format_value_func = null;

        static construct
        {
            set_css_name ("chart");
        }

        construct
        {
            unowned var self = this;

            this.contents.x_axis.set_format_value_func (
                (value) => {
                    return self.format_x_value (value);
                });
            this.contents.y_axis.set_format_value_func (
                (value) => {
                    return self.format_y_value (value);
                });

            this.y_axis = this.contents.y_axis.detach ();
            this.y_axis.insert_before (this, null);

            // HACK: counteract delegates/self increasing `this.ref_count`
            this.@unref ();
        }

        public void set_format_value_func (owned Pomodoro.FormatValueFunc? func)
        {
            this.format_value_func = (owned) func;

            this.queue_allocate ();
        }

        public virtual string format_x_value (double value)
        {
            return this.format_value_func != null
                    ? this.format_value_func (value)
                    : "%.2f".printf (value);
        }

        public virtual string format_y_value (double value)
        {
            return this.format_value_func != null
                    ? this.format_value_func (value)
                    : "%.2f".printf (value);
        }

        [GtkCallback]
        private void on_drag_begin (double start_x,
                                    double start_y)
        {
            this.drag_start_x = this.scrolled_window.hadjustment.value;
        }

        [GtkCallback]
        private void on_pan (Gtk.GesturePan   gesture,
                             Gtk.PanDirection direction,
                             double           offset)
        {
            if (direction == Gtk.PanDirection.LEFT) {
                offset = -offset;
            }

            this.scrolled_window.hadjustment.value = this.drag_start_x - offset;
        }

        private bool get_pointer_position (out double x,
                                           out double y)
        {
            double px, py;
            double nx, ny;
            Graphene.Point point;

            var native = this.get_native ();
            var surface = native?.get_surface ();
            var pointer = surface?.get_display ().get_default_seat ()?.get_pointer ();

            if (pointer == null)
            {
                x = double.NAN;
                y = double.NAN;

                return false;
            }

            surface.get_device_position (pointer, out px, out py, null);
            native.get_surface_transform (out nx, out ny);

            var surface_point = Graphene.Point ();
            surface_point.init ((float)(px - nx), (float)(py - ny));

            if (native.compute_point (this, surface_point, out point))
            {
                x = (double) point.x;
                y = (double) point.y;

                return true;
            }
            else {
                x = double.NAN;
                y = double.NAN;

                return false;
            }
        }

        [GtkCallback]
        private bool on_scroll (Gtk.EventControllerScroll controller,
                                double                    dx,
                                double                    dy)
        {
            var event = controller.get_current_event ();
            double x, y;

            if (event == null) {
                return false;
            }

            if ((event.get_modifier_state () & Gdk.ModifierType.CONTROL_MASK) == 0) {
                return false;
            }

            if (!this.get_pointer_position (out x, out y)) {
                return false;
            }

            var point = Graphene.Point ();
            point.init ((float) x, (float) y);

            var contents_point = Graphene.Point ();

            if (!this.compute_point (this.contents, point, out contents_point)) {
                return false;
            }

            contents_point = this.contents.canvas.transform_point (contents_point);

            if (dy < 0.0) {
                this.zoom_begin (contents_point.x, contents_point.y, x, y);
                this.zoom_in ();
            }
            else if (dy > 0.0) {
                this.zoom_begin (contents_point.x, contents_point.y, x, y);
                this.zoom_out ();
            }

            return true;
        }

        public abstract Gtk.SizeRequestMode get_contents_request_mode (Pomodoro.Canvas canvas);

        /**
         * Create and position canvas items in the value space.
         */
        public abstract void update_canvas (Pomodoro.Canvas canvas);

        public abstract void measure_canvas (Pomodoro.Canvas canvas,
                                             Gtk.Orientation orientation,
                                             int             for_size,
                                             out int         minimum,
                                             out int         natural);

        /**
         * A method for calculating items size before allocation. It's expected that you update
         * items origin point for the widgets.
         *
         * At this point canvas scale is not calculated yet, nor we know items final positions
         * at the pixel-level.
         *
         * If size exceeds `available_width`, the content will be scrolled horizontally. The
         * `working_area` represents area available for drawing values.
         */
        public abstract void measure_working_area (Pomodoro.Canvas   canvas,
                                                   int               available_width,
                                                   int               available_height,
                                                   out Gdk.Rectangle working_area);

        protected void queue_update ()
        {
            this.queue_resize ();
        }

        protected virtual void zoom_begin (double x_value,
                                           double y_value,
                                           double x,
                                           double y)
        {
            this.zoom_x_value = x_value;
            this.zoom_y_value = y_value;
            this.zoom_x       = x;
            this.zoom_y       = y;
            this.zooming      = true;
        }

        protected virtual void zoom_end (double x_value,
                                         double y_value,
                                         double x,
                                         double y)
        {
            // Convert point from value coordinates to chart coordinates
            var contents_point = Graphene.Point ();
            contents_point.init ((float) x_value, (float) y_value);
            contents_point = this.contents.canvas.transform_point_inv (contents_point);

            var point = Graphene.Point ();

            if (this.contents.compute_point (this, contents_point, out point))
            {
                // Adjust scroll, so that anchor point is preserved
                var hadjustment = this.scrolled_window.hadjustment;
                hadjustment.value = (hadjustment.value + point.x - x).clamp (
                        hadjustment.lower, hadjustment.upper);
                // TODO: vadjustment
            }

            this.zooming = false;
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
            this.scrolled_window.measure (orientation,
                                          for_size,
                                          out minimum,
                                          out natural,
                                          null,
                                          null);

            if (orientation == Gtk.Orientation.HORIZONTAL) {
                minimum = int.max (MIN_WIDTH, minimum);
                natural = int.max (minimum, this.width_request);
            }
            else {
                minimum = int.max (MIN_HEIGHT, minimum);
                natural = int.max (minimum, this.height_request);

                // Grow the hight to met the requested aspect ratio
                if (for_size > 0 && this.aspect_ratio > 0.0f) {
                    natural = int.max (
                            (int) Math.roundf ((float) for_size / this.aspect_ratio),
                            minimum);
                }
            }

            minimum_baseline = -1;
            natural_baseline = -1;
        }

        /**
         * Calculate chart layout
         *
         * Base class allocates axes, handles content sizing. Content may be scrolled horizontally
         * if there is not enough space.
         */
        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            this.update_canvas (this.contents.canvas);

            this.contents.configure_axes (width, height);

            var y_axis_width = this.y_axis != null ? this.y_axis.label_width : 0;
            var scrolled_window_allocation = Gtk.Allocation () {
                x      = y_axis_width,
                y      = 0,
                width  = width - y_axis_width,
                height = height
            };
            this.scrolled_window.allocate_size (scrolled_window_allocation, -1);

            if (this.y_axis != null)
            {
                var y_axis_allocation = Gtk.Allocation () {
                    x = 0,
                    y = this.contents.y_origin - this.y_axis.origin
                };
                this.y_axis.measure (Gtk.Orientation.HORIZONTAL,
                                     -1,
                                     null,
                                     out y_axis_allocation.width,
                                     null,
                                     null);
                this.y_axis.measure (Gtk.Orientation.VERTICAL,
                                     -1,
                                     null,
                                     out y_axis_allocation.height,
                                     null,
                                     null);
                this.y_axis.allocate_size (y_axis_allocation, -1);
            }

            if (this.zooming) {
                this.zoom_end (this.zoom_x_value, this.zoom_y_value, this.zoom_x, this.zoom_y);
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            this.snapshot_child (this.scrolled_window, snapshot);

            if (this.y_axis != null) {
                this.snapshot_child (this.y_axis, snapshot);
            }
        }

        public signal void zoom_in ();

        public signal void zoom_out ();

        public override void dispose ()
        {
            if (this.y_axis != null) {
                this.y_axis.unparent ();
                this.y_axis = null;
            }

            this.@ref ();
            this.contents.x_axis.set_format_value_func (null);
            this.contents.y_axis.set_format_value_func (null);

            this.scrolled_window.child = null;
            this.format_value_func = null;

            // HACK: Without this `GtkScrolledWindow` does not get disposed properly
            this.dispose_template (typeof (Pomodoro.Chart));

            base.dispose ();
        }
    }
}
