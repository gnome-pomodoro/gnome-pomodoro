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
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/bubble-chart.ui")]
    public class BubbleChart : Gtk.Widget
    {
        private const int    MIN_BUBBLE_SIZE = 16;
        private const int    MAX_BUBBLE_SIZE = 40;
        private const float  MIN_BUBBLE_RADIUS = 1.0f;
        private const int    SPACING = 3;
        private const double EPSILON = 0.00001;

        /**
         * Value that should be visible on the chart.
         */
        public double reference_value {
            get {
                return this._reference_value;
            }
            set {
                if (this._reference_value == value) {
                    return;
                }

                this._reference_value = value;

                this.invalidate_max_value ();
            }
        }

        public bool stacked {
            get {
                return this._stacked;
            }
            set {
                if (this._stacked == value) {
                    return;
                }

                this._stacked = value;

                this.invalidate_max_value ();
            }
        }

        [GtkChild]
        private unowned Gtk.Grid layout_grid;
        [GtkChild]
        private unowned Gtk.Box x_axis;
        [GtkChild]
        private unowned Gtk.Box y_axis;
        [GtkChild]
        private unowned Gtk.Grid bubbles_grid;

        private double                    _reference_value = 1.0;
        private bool                      _stacked = true;
        private Category[]                categories;
        private Bucket[,]                 buckets;
        private Pomodoro.Matrix3D?        data;
        private uint                      rows = 0;
        private uint                      columns = 0;
        private Pomodoro.FormatValueFunc? format_value_func;
        private double                    max_value = 0.0;
        private int                       bubble_radius;
        private int                       tooltip_row = -1;
        private int                       tooltip_column = -1;
        private Gtk.Widget?               tooltip_widget;

        static construct
        {
            set_css_name ("chart");
        }

        construct
        {
            this.categories = {};
        }

        private string format_value (double value)
        {
            return this.format_value_func != null
                    ? this.format_value_func (value)
                    : "%.2f".printf (value);
        }

        public void set_format_value_func (owned Pomodoro.FormatValueFunc? func)
        {
            this.format_value_func = (owned) func;

            this.queue_allocate ();
        }

        private double calculate_max_value ()
        {
            var max_value = double.NAN;

            if (this._stacked && this.data.shape[2] > 0U)
            {
                var categories_data = this.data.unstack ();
                var values = categories_data[0].copy ();
                var category_index = 1;

                for (; category_index < categories_data.length; category_index++) {
                    if (!values.add (categories_data[category_index])) {
                        GLib.debug ("BubbleChart: Unable to calculate max_value");
                    }
                }

                max_value = values.max ();
            }
            else {
                max_value = this.data.max ();
            }

            return double.max (max_value, this._reference_value);
        }

        private void invalidate_max_value ()
        {
            this.max_value = double.NAN;

            this.queue_allocate ();
        }

        private void ensure_buckets ()
        {
            var rows = this.rows;
            var columns = this.columns;

            if (this.buckets == null) {
                this.buckets = new Bucket[rows, columns];
            }

            if (this.buckets.length[0] != rows ||
                this.buckets.length[1] != columns)
            {
                var intersect_0 = uint.min (rows, this.buckets.length[0]);
                var intersect_1 = uint.min (columns, this.buckets.length[1]);
                var buckets     = new Bucket[rows, columns];

                for (var i = 0; i < intersect_0; i++)
                {
                    for (var j = 0; j < intersect_1; j++) {
                        buckets[i, j] = this.buckets[i, j];
                    }
                }

                this.buckets = buckets;
            }
        }

        private void ensure_data ()
        {
            var rows = this.rows;
            var columns = this.columns;
            var category_count = this.categories.length;

            if (this.data == null) {
                this.data = new Pomodoro.Matrix3D (rows, columns, category_count);
            }

            if (this.data.shape[0] != rows ||
                this.data.shape[1] != columns ||
                this.data.shape[2] != category_count)
            {
                this.data.resize (rows, columns, category_count);
            }
        }

        private void ensure_bubble (uint row,
                                    uint column)
        {
            if (this.bubbles_grid.get_child_at ((int) column, (int) row) != null) {
                return;
            }

            this.bubbles_grid.attach (this.create_bubble (row, column), (int) column, (int) row);
        }

        public uint add_column (string label)
        {
            var tick_label = new Gtk.Label (label);
            tick_label.halign = Gtk.Align.CENTER;

            this.x_axis.append (tick_label);
            this.columns++;

            return this.columns - 1U;
        }

        public uint add_row (string label)
        {
            var tick_label = new Gtk.Label (label);
            tick_label.halign = Gtk.Align.END;

            this.y_axis.append (tick_label);
            this.rows++;

            return (uint) this.rows - 1U;
        }

        public unowned Gtk.Label? get_row_label (uint index)
        {
            unowned var label = this.y_axis.get_first_child ();

            while (label != null)
            {
                if (index == 0U) {
                    return (Gtk.Label) label;
                }

                label = label.get_next_sibling ();
                index--;
            }

            return null;
        }

        public uint add_category (string label)
        {
            var category_index = this.categories.length;

            this.categories += Category() {
                label = label,
                color = this.get_color ()
            };

            this.queue_allocate ();

            return category_index;
        }

        public void set_category_label (uint   category_index,
                                        string label)
        {
            if (category_index >= this.categories.length) {
                GLib.warning ("Can't set label for category #%u", category_index);
                return;
            }

            this.categories[category_index].label = label;
        }

        public void set_category_color (uint     category_index,
                                        Gdk.RGBA color)
        {
            if (category_index >= this.categories.length) {
                GLib.warning ("Can't set color for category #%u", category_index);
                return;
            }

            this.categories[category_index].color = color;

            this.queue_draw ();
        }

        public double get_category_total (uint category_index)
        {
            var total = this.data.get_matrix (-1, (int) category_index).sum ();

            if (this._stacked)
            {
                for (var index = 0; index < category_index; index++) {
                    total += this.data.get_matrix (-1, index).sum ();
                }
            }

            return total;
        }

        private string get_tooltip_label (uint row,
                                          uint column)
        {
            if (row >= this.buckets.length[0] || column >= this.buckets.length[1]) {
                return "";
            }

            return this.buckets[row, column].tooltip_label;
        }

        public void set_tooltip_label (uint   row,
                                       uint   column,
                                       string label)
        {
            this.ensure_buckets ();

            if (row >= this.buckets.length[0] || column >= this.buckets.length[1]) {
                GLib.warning ("Can't set tooltip label for bucket %u, %u", column, row);
                return;
            }

            this.buckets[row, column].tooltip_label = label;
        }

        public void set_values (uint     row,
                                uint     column,
                                double[] values)
        {
            this.ensure_data ();

            var category_index = 0;
            var is_empty = true;

            for (; category_index < values.length; category_index++)
            {
                this.data.@set ((int) row, (int) column, category_index, values[category_index]);

                if (values[category_index] > EPSILON) {
                    is_empty = false;
                }
            }

            for (; category_index < this.data.shape[2]; category_index++) {
                this.data.@set ((int) row, (int) column, category_index, 0.0);
            }

            if (!is_empty) {
                this.ensure_bubble (row, column);
            }

            this.invalidate_max_value ();
        }

        public void set_value (uint   row,
                               uint   column,
                               uint   category_index,
                               double value)
        {
            this.ensure_data ();

            if (value > EPSILON) {
                this.ensure_bubble (row, column);
            }

            this.data.@set ((int) row, (int) column, (int) category_index, value);

            this.invalidate_max_value ();
        }

        private Gtk.Widget? create_tooltip_widget (uint row,
                                                   uint column)
        {
            var category_count = this.categories.length;

            var grid = new Gtk.Grid ();
            grid.column_spacing = 10;
            grid.row_spacing = 5;
            grid.row_homogeneous = true;
            grid.add_css_class ("tooltip-contents");

            var header_label = new Gtk.Label (this.get_tooltip_label (row, column));
            header_label.add_css_class ("tooltip-header");
            grid.attach (header_label, 0, 0, 2, 1);

            for (var category_index = category_count - 1; category_index >= 0; category_index--)
            {
                var category = this.categories[category_index];
                var category_value = this.data.@get ((int) row, (int) column, (int) category_index);

                var category_label = new Gtk.Label (@"$(category.label):");
                category_label.halign = Gtk.Align.START;
                grid.attach (category_label, 0, 1 + category_index);

                var value_label = new Gtk.Label (this.format_value (category_value));
                value_label.halign = Gtk.Align.END;
                grid.attach (value_label, 1, 1 + category_index);
            }

            // TODO: interruptions

            return grid;
        }

        private void measure_bubble (Pomodoro.Gizmo  gizmo,
                                     Gtk.Orientation orientation,
                                     int             for_size,
                                     out int         minimum,
                                     out int         natural,
                                     out int         minimum_baseline,
                                     out int         natural_baseline)
        {
            var diameter = this.bubble_radius * 2;

            minimum = int.max (diameter, MIN_BUBBLE_SIZE);
            natural = diameter.clamp (minimum, MAX_BUBBLE_SIZE);
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        private void snapshot_bubble (Pomodoro.Gizmo gizmo,
                                      Gtk.Snapshot   snapshot)
        {
            var row            = (int) gizmo.get_data<uint> ("row");
            var column         = (int) gizmo.get_data<uint> ("column");
            var category_count = (int) this.data.shape[2];
            var origin_x       = ((float) gizmo.get_width ()) / 2.0f;
            var origin_y       = ((float) gizmo.get_height ()) / 2.0f;
            var base_value     = 0.0;

            if (this._stacked)
            {
                for (var category_index = 0; category_index < category_count; category_index++)
                {
                    base_value += this.data.@get (row, column, category_index);
                }
            }

            for (var category_index = category_count - 1; category_index >= 0; category_index--)
            {
                var bubble_value  = this.data[row, column, category_index];
                var bubble_color  = this.categories[category_index].color;
                var bubble_radius = (float) this.bubble_radius *
                                    (float) Math.sqrt (bubble_value / this.max_value);

                if (!this._stacked) {
                    base_value = bubble_value;
                }

                if (bubble_value < EPSILON && category_index != 0) {
                    base_value -= bubble_value;
                    continue;
                }

                if (bubble_radius > MIN_BUBBLE_RADIUS)
                {
                    var bounds = Graphene.Rect ();
                    bounds.init (origin_x - bubble_radius,
                                 origin_y - bubble_radius,
                                 2.0f * bubble_radius,
                                 2.0f * bubble_radius);

                    var outline = Gsk.RoundedRect ();
                    outline.init_from_rect (bounds, bubble_radius);

                    snapshot.push_rounded_clip (outline);
                    snapshot.append_color (bubble_color, bounds);
                    snapshot.pop ();
                }

                base_value -= bubble_value;
            }
        }

        private bool contains_bubble (Pomodoro.Gizmo gizmo,
                                      double         x,
                                      double         y)
        {
            if (!gizmo.get_mapped ()) {
                return false;
            }

            // Check if cursor fits within bar boundaries.
            var point = Graphene.Point () {
                x = (float) x,
                y = (float) y
            };
            Graphene.Rect bounds;

            gizmo.compute_bounds (gizmo, out bounds);

            return bounds.contains_point (point);
        }

        private Gtk.Widget? create_bubble (uint row,
                                           uint column)
        {
            var bubble = new Pomodoro.Gizmo (BubbleChart.measure_bubble_cb,
                                             null,
                                             BubbleChart.snapshot_bubble_cb,
                                             BubbleChart.contains_bubble_cb,
                                             null,
                                             null);
            bubble.focusable = false;
            bubble.has_tooltip = true;
            bubble.add_css_class ("bubble");
            bubble.set_data<uint> ("row", row);
            bubble.set_data<uint> ("column", column);

            bubble.query_tooltip.connect (BubbleChart.on_query_tooltip_cb);

            return (Gtk.Widget) bubble;
        }

        private static Pomodoro.BubbleChart? from_gizmo (Pomodoro.Gizmo gizmo)
        {
            Gtk.Widget? widget = gizmo;

            while (widget != null)
            {
                var chart = widget as Pomodoro.BubbleChart;

                if (chart != null) {
                    return chart;
                }

                widget = widget.get_parent ();
            }

            return null;
        }

        private static Pomodoro.BubbleChart? from_widget (Gtk.Widget widget)
        {
            Gtk.Widget? current = widget;

            while (current != null)
            {
                var chart = current as Pomodoro.BubbleChart;

                if (chart != null) {
                    return chart;
                }

                current = current.get_parent ();
            }

            return null;
        }

        private static void measure_bubble_cb (Pomodoro.Gizmo  gizmo,
                                               Gtk.Orientation orientation,
                                               int             for_size,
                                               out int         minimum,
                                               out int         natural,
                                               out int         minimum_baseline,
                                               out int         natural_baseline)
        {
            var self = BubbleChart.from_gizmo (gizmo);

            if (self != null) {
                self.measure_bubble (gizmo, orientation, for_size, out minimum, out natural, out minimum_baseline, out natural_baseline);
            }
            else {
                minimum = 0;
                natural = 0;
                minimum_baseline = -1;
                natural_baseline = -1;
            }
        }

        private static void snapshot_bubble_cb (Pomodoro.Gizmo gizmo,
                                                Gtk.Snapshot   snapshot)
        {
            var self = BubbleChart.from_gizmo (gizmo);

            if (self != null) {
                self.snapshot_bubble (gizmo, snapshot);
            }
        }

        private static bool contains_bubble_cb (Pomodoro.Gizmo gizmo,
                                                double         x,
                                                double         y)
        {
            var self = BubbleChart.from_gizmo (gizmo);

            return self != null ? self.contains_bubble (gizmo, x, y) : false;
        }

        private static bool on_query_tooltip_cb (Gtk.Widget  widget,
                                                 int         x,
                                                 int         y,
                                                 bool        keyboard_tooltip,
                                                 Gtk.Tooltip tooltip)
        {
            var self = BubbleChart.from_widget (widget);

            if (self == null) {
                return false;
            }

            var row = widget.get_data<uint> ("row");
            var column = widget.get_data<uint> ("column");

            if (self.tooltip_row != row || self.tooltip_column != column) {
                self.tooltip_row    = (int) row;
                self.tooltip_column = (int) column;
                self.tooltip_widget = self.create_tooltip_widget (row, column);
            }

            tooltip.set_custom (self.tooltip_widget);

            return self.tooltip_widget != null;
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
            var x_axis_minimum = 0;
            var x_axis_natural = 0;
            var y_axis_minimum = 0;
            var y_axis_natural = 0;

            this.x_axis.measure (orientation,
                                 for_size,
                                 out x_axis_minimum,
                                 out x_axis_natural,
                                 null,
                                 null);
            this.y_axis.measure (orientation,
                                 for_size,
                                 out y_axis_minimum,
                                 out y_axis_natural,
                                 null,
                                 null);

            if (orientation == Gtk.Orientation.HORIZONTAL)
            {
                minimum = int.max (
                        x_axis_minimum + y_axis_minimum + layout_grid.column_spacing,
                        (MIN_BUBBLE_SIZE + SPACING) * (int) this.columns + y_axis_minimum + layout_grid.column_spacing);
                natural = int.min (
                        x_axis_natural + y_axis_natural + layout_grid.column_spacing,
                        (MAX_BUBBLE_SIZE + SPACING) * (int) this.columns + y_axis_minimum + layout_grid.column_spacing);
            }
            else {
                minimum = int.max (
                        x_axis_minimum + y_axis_minimum + layout_grid.row_spacing,
                        (MIN_BUBBLE_SIZE + SPACING) * (int) this.rows + x_axis_minimum + layout_grid.row_spacing);

                if (for_size > 0)
                {
                    var y_axis_width = 0;

                    this.y_axis.measure (Gtk.Orientation.HORIZONTAL,
                                         -1,
                                         null,
                                         out y_axis_width,
                                         null,
                                         null);

                    var bubble_width = (for_size - y_axis_width - this.layout_grid.column_spacing) / (int) this.columns;
                    var bubble_radius = (bubble_width - SPACING).clamp (MIN_BUBBLE_SIZE, MAX_BUBBLE_SIZE) / 2;

                    natural = (bubble_radius * 2 + SPACING) * (int) this.rows + x_axis_minimum + (int) layout_grid.row_spacing;
                }
                else {
                    natural = int.min (
                        x_axis_natural + y_axis_natural + (int) layout_grid.row_spacing,
                        (MAX_BUBBLE_SIZE + SPACING) * (int) this.rows + x_axis_minimum + (int) layout_grid.row_spacing);
                }
            }

            if (natural < minimum) {
                natural = minimum;
            }

            minimum_baseline = -1;
            natural_baseline = -1;
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            int y_axis_width;
            int x_axis_height;

            if (this.max_value.is_nan ()) {
                this.max_value = this.calculate_max_value ();
            }

            this.x_axis.measure (Gtk.Orientation.VERTICAL,
                                 -1,
                                 null,
                                 out x_axis_height,
                                 null,
                                 null);
            this.y_axis.measure (Gtk.Orientation.HORIZONTAL,
                                 -1,
                                 null,
                                 out y_axis_width,
                                 null,
                                 null);

            var bubble_width = this.columns > 0U
                    ? (width - x_axis_height) / (int) this.columns
                    : 0;
            var bubble_radius = (bubble_width.clamp (MIN_BUBBLE_SIZE, MAX_BUBBLE_SIZE) - SPACING) / 2;

            if (this.bubble_radius != bubble_radius)
            {
                this.bubble_radius = bubble_radius;

                unowned var bubble = this.bubbles_grid.get_first_child ();

                while (bubble != null)
                {
                    bubble.queue_resize ();

                    bubble = bubble.get_next_sibling ();
                }
            }

            var allocation = Gtk.Allocation () {
                width  = width,
                height = height
            };
            this.layout_grid.allocate_size (allocation, -1);
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            this.snapshot_child (this.layout_grid, snapshot);
        }

        public override void dispose ()
        {
            this.data           = null;
            this.categories     = null;
            this.buckets        = null;
            this.tooltip_widget = null;

            base.dispose ();
        }
    }
}
