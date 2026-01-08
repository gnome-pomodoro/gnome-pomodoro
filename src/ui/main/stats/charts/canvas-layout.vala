/*
 * Copyright (c) 2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Pomodoro
{
    /**
     * A `Gtk.LayoutChild` for `Pomodoro.Canvas` widgets, storing per-child layout properties
     */
    public sealed class CanvasLayoutChild : Gtk.LayoutChild
    {
        /**
         * Absolute position in the value space.
         */
        public float x { get; set; default = 0.0f; }

        /**
         * Absolute position in the value space.
         */
        public float y { get; set; default = 0.0f; }

        /**
         * Offset from the widget's top-left corner in pixels.
         */
        public int x_origin { get; set; default = 0; }

        /**
         * Offset from the widget's top-left corner in pixels.
         */
        public int y_origin { get; set; default = 0; }

        internal Graphene.Rect range;
        internal Gdk.Rectangle absolute_bounds;

        /**
         * Calculate widget's bounds. The bounds position is in relative units from its origin.
         */
        public Gdk.Rectangle calculate_bounds ()
        {
            var bounds = Gdk.Rectangle () {
                x      = -this.x_origin,
                y      = -this.y_origin,
                width  = 0,
                height = 0
            };
            var widget = this.get_child_widget ();

            if (widget != null) {
                widget.measure (Gtk.Orientation.HORIZONTAL,
                                -1,
                                null,
                                out bounds.width,
                                null,
                                null);
                widget.measure (Gtk.Orientation.VERTICAL,
                                -1,
                                null,
                                out bounds.height,
                                null,
                                null);
            }

            return bounds;
        }

        public void set_range (float x_from,
                               float x_to,
                               float y_from,
                               float y_to)
        {
            this.range = Graphene.Rect ();
            this.range.init (x_from, y_from, x_to - x_from, y_to - y_from);
        }
    }


    public sealed class CanvasLayout : Gtk.LayoutManager
    {
        private const double EPSILON = 0.00001;

        /**
         * Calculate child's bounds in `Canvas` coordinates.
         */
        private inline Gdk.Rectangle calculate_child_bounds (Pomodoro.CanvasLayoutChild child,
                                                             float                      x_scale,
                                                             float                      y_scale)
        {
            child.absolute_bounds    = child.calculate_bounds ();  // cache result
            child.absolute_bounds.x += (int) Math.roundf (x_scale * child.x);
            child.absolute_bounds.y -= (int) Math.roundf (y_scale * child.y);

            return child.absolute_bounds;
        }

        /**
         * Calculate bounds for all children in `Canvas` coordinates.
         */
        private Gdk.Rectangle calculate_bounds (Gtk.Widget widget)
        {
            var canvas         = (Pomodoro.Canvas) widget;
            var x_scale        = canvas.x_scale;
            var y_scale        = canvas.y_scale;
            var bounds         = Gdk.Rectangle ();
            var is_first_child = true;

            for (var child_widget = widget.get_first_child ();
                 child_widget != null;
                 child_widget = child_widget.get_next_sibling ())
            {
                var layout_child = (Pomodoro.CanvasLayoutChild) this.get_layout_child (child_widget);

                if (layout_child == null) {
                    continue;
                }

                var child_bounds = this.calculate_child_bounds (layout_child, x_scale, y_scale);

                if (is_first_child) {
                    bounds = child_bounds;
                    is_first_child = false;
                }
                else {
                    bounds.union (child_bounds, out bounds);
                }
            }

            return bounds;
        }

        private inline int calculate_width (Gtk.Widget widget)
        {
            // XXX: use cached bounds if possible
            return int.max (this.calculate_bounds (widget).width,
                            widget.width_request);
        }

        private inline int calculate_height (Gtk.Widget widget)
        {
            // XXX: use cached bounds if possible
            return int.max (this.calculate_bounds (widget).height,
                            widget.height_request);
        }

        /**
         * Calculate value bounds aka value range
         */
        public Graphene.Rect calculate_range (Gtk.Widget widget)
        {
            var range          = Graphene.Rect ();
            var is_first_child = true;

            for (var child_widget = widget.get_first_child ();
                 child_widget != null;
                 child_widget = child_widget.get_next_sibling ())
            {
                var layout_child = (Pomodoro.CanvasLayoutChild) this.get_layout_child (child_widget);

                if (layout_child == null) {
                    continue;
                }

                if (is_first_child) {
                    range = layout_child.range;
                    is_first_child = false;
                }
                else {
                    range = range.union (layout_child.range);
                }
            }

            return range;
        }

        /**
         * Calculate and canvas origin point
         *
         * The origin point is absolute (centre of coordinate system).
         */
        public bool calculate_origin (Gtk.Widget widget,
                                      out int    x_origin,
                                      out int    y_origin)
        {
            var canvas = widget as Pomodoro.Canvas;

            if (canvas != null)
            {
                // XXX: cache bounds if possible
                var bounds   = this.calculate_bounds (widget);
                var x_offset = int.max (widget.width_request - bounds.width, 0);
                var y_offset = int.max (widget.height_request - bounds.height, 0);

                x_origin = -bounds.x + x_offset;
                y_origin = -bounds.y + y_offset;

                return true;
            }
            else {
                x_origin = 0;
                y_origin = 0;

                return false;
            }
        }


        /*
         * LayoutManger
         */

        public override Gtk.LayoutChild create_layout_child (Gtk.Widget widget,
                                                             Gtk.Widget for_child)
        {
            return (Gtk.LayoutChild) GLib.Object.@new (typeof (Pomodoro.CanvasLayoutChild),
                                                       "layout-manager", this,
                                                       "child-widget", for_child);
        }

        public override Gtk.SizeRequestMode get_request_mode (Gtk.Widget widget)
        {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        public override void measure (Gtk.Widget      widget,
                                      Gtk.Orientation orientation,
                                      int             for_size,
                                      out int         minimum,
                                      out int         natural,
                                      out int         minimum_baseline,
                                      out int         natural_baseline)
        {
            natural = orientation == Gtk.Orientation.HORIZONTAL
                    ? this.calculate_width (widget)
                    : this.calculate_height (widget);
            minimum = natural;
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        /**
         * Place items for given size.
         *
         * We likely execute it having `origin` point computed earlier.
         */
        public override void allocate (Gtk.Widget widget,
                                       int        width,
                                       int        height,
                                       int        baseline)
        {
            var canvas = (Pomodoro.Canvas) widget;

            canvas.update_origin ();

            var x_origin = canvas.x_origin;
            var y_origin = canvas.y_origin;

            // Translate widgets to top-left corner and allocate
            for (var child_widget = widget.get_first_child ();
                 child_widget != null;
                 child_widget = child_widget.get_next_sibling ())
             {
                var layout_child = (Pomodoro.CanvasLayoutChild?) this.get_layout_child (child_widget);

                if (layout_child == null) {
                    continue;
                }

                var child_allocation = (Gtk.Allocation) layout_child.absolute_bounds;
                child_allocation.x += x_origin;
                child_allocation.y += y_origin;

                child_widget.allocate_size (child_allocation, -1);
            }
        }
    }
}
