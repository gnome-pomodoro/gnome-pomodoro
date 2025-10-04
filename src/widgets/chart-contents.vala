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
     * Extra wrapper around canvas for displaying axes and grid over charts content.
     */
    // TODO: implement viewport/scrollable interface
    public sealed class ChartContents : Gtk.Widget
    {
        private const int AXIS_TEXT_OFFSET = 8;

        public Pomodoro.Canvas canvas {
            get {
                return this._canvas;
            }
        }

        public Pomodoro.ChartAxis x_axis {
            get {
                return this._x_axis;
            }
        }

        public Pomodoro.ChartAxis y_axis {
            get {
                return this._y_axis;
            }
        }

        public Pomodoro.ChartGrid grid {
            get {
                return this._grid;
            }
        }

        public int x_origin {
            get {
                return this._x_origin;
            }
        }

        public int y_origin {
            get {
                return this._y_origin;
            }
        }

        public float y_value_from {
            get {
                return this._y_value_from;
            }
            set {
                if (this._y_value_from == value) {
                    return;
                }

                this._y_value_from = value;

                this.queue_resize ();
            }
        }

        public float y_value_to {
            get {
                return this._y_value_to;
            }
            set {
                if (this._y_value_to == value) {
                    return;
                }

                this._y_value_to = value;

                this.queue_resize ();
            }
        }


        private Pomodoro.Canvas?     _canvas = null;
        private Pomodoro.ChartAxis?  _x_axis = null;
        private Pomodoro.ChartAxis?  _y_axis = null;
        private Pomodoro.ChartGrid?  _grid = null;
        private int                  _x_origin = 0;
        private int                  _y_origin = 0;
        private float                _y_value_from = float.NAN;
        private float                _y_value_to = float.NAN;
        private weak Pomodoro.Chart? chart = null;
        private bool                 is_empty = true;

        construct
        {
            this.accessible_role = Gtk.AccessibleRole.IMG;
            this.add_css_class ("contents");

            this._canvas = new Pomodoro.Canvas ();

            this._x_axis = new Pomodoro.ChartAxis (Gtk.Orientation.HORIZONTAL);
            this._x_axis.text_offset = AXIS_TEXT_OFFSET;

            this._y_axis = new Pomodoro.ChartAxis (Gtk.Orientation.VERTICAL);
            this._y_axis.text_offset = AXIS_TEXT_OFFSET;

            this._grid = new Pomodoro.ChartGrid (this.x_axis, this._y_axis);

            this._grid.insert_before (this, null);
            this._x_axis.insert_before (this, null);
            this._y_axis.insert_before (this, null);
            this._canvas.insert_before (this, null);
        }

        private unowned Pomodoro.Chart? get_chart ()
        {
            if (this.chart != null) {
                return this.chart;
            }

            var widget = this.parent;

            while (widget != null)
            {
                if (widget is Pomodoro.Chart)
                {
                    this.chart = (Pomodoro.Chart) widget;

                    return this.chart;
                }

                widget = widget.parent;
            }

            return null;
        }

        /**
         * Key function for calculating contents layout.
         *
         * Updates children if needed. It's the place where we compute scale.
         */
        internal void configure_axes (int chart_width,
                                      int chart_height)
        {
            var chart = this.get_chart ();

            if (chart == null) {
                return;
            }

            chart.update_canvas (this._canvas);

            // Check value ranges and prepare axes ticks
            float x_value_from, x_value_to, y_value_from, y_value_to;

            this._canvas.calculate_range (out x_value_from,
                                          out x_value_to,
                                          out y_value_from,
                                          out y_value_to);

            if (this._y_value_from.is_finite ()) {
                y_value_from = float.min (y_value_from, this._y_value_from);
            }

            if (this._y_value_to.is_finite ()) {
                y_value_to = float.max (y_value_to, this._y_value_to);
            }

            this._x_axis.configure (x_value_from,
                                    x_value_to,
                                    chart.x_spacing,
                                    chart_width);
            this._y_axis.configure (y_value_from,
                                    y_value_to,
                                    chart.y_spacing,
                                    chart_height);

            this.queue_resize ();
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            var chart = this.get_chart ();

            return chart != null
                    ? chart.get_contents_request_mode (this._canvas)
                    : Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        public override void measure (Gtk.Orientation orientation,
                                      int             for_size,
                                      out int         minimum,
                                      out int         natural,
                                      out int         minimum_baseline,
                                      out int         natural_baseline)
        {
            var chart = this.get_chart ();

            if (chart != null)
            {
                chart.measure_canvas (this._canvas,
                                      orientation,
                                      for_size,
                                      out minimum,
                                      out natural);

                if (minimum > natural) {
                    minimum = natural;
                }

                if (this._y_axis.visible)
                {
                    if (orientation == Gtk.Orientation.HORIZONTAL) {
                        // XXX: it's not precise - we ignore x-axis `label_width`
                        minimum += this._y_axis.text_offset;
                        natural += this._y_axis.text_offset;
                    }
                }

                if (this._x_axis.visible)
                {
                    if (orientation == Gtk.Orientation.VERTICAL) {
                        minimum += this._x_axis.label_height + this._x_axis.text_offset;
                        natural += this._x_axis.label_height + this._x_axis.text_offset;
                    }
                }
            }
            else {
                minimum = 0;
                natural = 0;
            }

            minimum_baseline = -1;
            natural_baseline = -1;
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            // By now axes should be configured.

            var canvas_width  = width;
            var canvas_height = height;

            canvas_height -= this._x_axis.visible
                    ? this._x_axis.label_height + this._x_axis.text_offset
                    : 0;
            canvas_width -= this._y_axis.visible
                    ? this._y_axis.label_width + this._y_axis.text_offset
                    : this._y_axis.text_offset;

            // Measure working area
            Gdk.Rectangle canvas_working_area;

            chart.measure_working_area (this._canvas,
                                        canvas_width,
                                        canvas_height,
                                        out canvas_working_area);
            normalize_rectangle (ref canvas_working_area);

            this.is_empty = canvas_working_area.width == 0 || canvas_working_area.height == 0;

            if (this.is_empty) {
                return;
            }

            // Calculate scale
            var x_scale = (float) (
                    (double) canvas_working_area.width /
                    (double) (this._x_axis.value_to - this._x_axis.value_from));
            var y_scale = (float) (
                    (double) canvas_working_area.height /
                    (double) (this._y_axis.value_to - this._y_axis.value_from));

            this._canvas.set_scale (x_scale, y_scale);
            this._x_axis.scale = x_scale;
            this._y_axis.scale = y_scale;

            // Calculate layout
            // If an axis is not visible its position will be negative
            var canvas_x_offset = this._x_axis.label_width / 2 - canvas_working_area.x;

            var y_axis_allocation = Gtk.Allocation () {
                x      = this._y_axis.visible ? 0 : -this._y_axis.label_width,
                y      = 0,
                width  = this._y_axis.label_width + this._y_axis.text_offset,
                height = height
            };

            var x_axis_allocation = Gtk.Allocation () {
                x      = y_axis_allocation.x + y_axis_allocation.width +
                         int.max (0 - canvas_x_offset, 0),
                height = this._x_axis.label_height + this._x_axis.text_offset
            };
            x_axis_allocation.y = height - (this._x_axis.visible ? x_axis_allocation.height : 0);
            x_axis_allocation.width = width - x_axis_allocation.x;

            var grid_allocation = Gtk.Allocation () {
                x      = y_axis_allocation.x + y_axis_allocation.width - this._y_axis.text_offset,
                y      = 0,
                height = height - x_axis_allocation.y
            };
            grid_allocation.width = width - grid_allocation.x;

            var canvas_allocation = Gtk.Allocation () {
                x      = y_axis_allocation.x + y_axis_allocation.width +
                         int.max (canvas_x_offset, 0),
                y      = 0,
                width  = canvas_width,
                height = canvas_height
            };

            // Sync origin
            this._canvas.update_origin ();

            this._x_origin = canvas_allocation.x + this._canvas.x_origin;
            this._y_origin = canvas_allocation.y + this._canvas.y_origin;

            this._x_axis.origin = this._x_origin - x_axis_allocation.x;
            this._y_axis.origin = this._y_origin - y_axis_allocation.y;
            this._grid.x_origin = this._x_origin - grid_allocation.x;
            this._grid.y_origin = this._y_origin - grid_allocation.y;

            // Allocate children
            this._canvas.allocate_size (canvas_allocation, -1);

            if (this._x_axis.visible) {
                this._x_axis.allocate_size (x_axis_allocation, -1);
            }

            if (this._y_axis.visible) {
                this._y_axis.allocate_size (y_axis_allocation, -1);
            }

            if (this._grid.visible) {
                this._grid.allocate_size (grid_allocation, -1);
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            if (this.is_empty) {
                return;
            }

            for (var child = this.get_first_child ();
                 child != null;
                 child = child.get_next_sibling ())
            {
                if (child.visible) {
                    this.snapshot_child (child, snapshot);
                }
            }
        }

        public override void unrealize ()
        {
            base.unrealize ();

            this.chart = null;
        }

        public override void dispose ()
        {
            this.chart = null;

            if (this._grid != null) {
                this._grid.unparent ();
                this._grid = null;
            }

            if (this._x_axis != null) {
                this._x_axis.unparent ();
                this._x_axis = null;
            }

            if (this._y_axis != null) {
                this._y_axis.unparent ();
                this._y_axis = null;
            }

            if (this._canvas != null) {
                this._canvas.unparent ();
                this._canvas = null;
            }

            base.dispose ();
        }
    }
}
