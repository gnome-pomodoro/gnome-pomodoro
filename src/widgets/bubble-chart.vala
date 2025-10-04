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
        private const int   MIN_BUBBLE_SIZE = 16;
        private const int   MAX_BUBBLE_SIZE = 42;
        private const float BUBBLE_SPACING = 0.2f;
        private const float MIN_BUBBLE_RADIUS = 0.01f;
        private const float MIN_BUBBLE_VALUE = 60.0f;
        private const float BASE_RADIUS = 4.0f;

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

        public uint category {
            get {
                return this._category;
            }
            set {
                if (this._category == value) {
                    return;
                }

                this._category = value;

                this.invalidate_max_value ();
            }
        }

        public bool activate_on_click {
            get; set; default = false;
        }

        public uint levels {
            get {
                return this._levels;
            }
            set {
                if (this._levels == value) {
                    return;
                }

                this._levels = value;

                this.update_level_radii ();
                this.queue_draw_bubbles ();
            }
        }

        [GtkChild]
        private unowned Gtk.Grid layout_grid;
        [GtkChild]
        private unowned Gtk.Box columns_box;
        [GtkChild]
        private unowned Gtk.Box rows_box;
        [GtkChild]
        private unowned Gtk.Grid bubbles_grid;

        private double                    _reference_value = 1.0;
        private uint                      _category = 0U;
        private uint                      _levels = 4U;
        private Category[]                categories;
        private Bucket[,]                 buckets;
        private Pomodoro.Matrix3D?        data;
        private double                    max_value = 0.0;
        private int                       bubble_size;
        private float[]                   level_radii;
        private int                       tooltip_row = -1;
        private int                       tooltip_column = -1;
        private Gtk.Widget?               tooltip_widget;
        private string[]                  rows_labels;
        private string[]                  columns_labels;
        private uint                      update_idle_id = 0;

        static construct
        {
            set_css_name ("chart");
        }

        construct
        {
            this.categories = {};
            this.rows_labels = {};
            this.columns_labels = {};
            this.level_radii = {};
        }

        private inline string format_tooltip_value (uint   category_index,
                                                    double value)
        {
            return category_index < this.categories.length
                    ? this.categories[category_index].unit.format (value)
                    : "%.2f".printf (value);
        }

        private inline double calculate_max_value ()
        {
            var category_data = this.data?.get_matrix (2, (int) this.category);

            return category_data != null
                    ? double.max (category_data.max (), this._reference_value)
                    : this._reference_value;
        }

        private inline float calculate_bubble_radius (double bubble_value)
        {
            var levels = this.level_radii.length;
            float bubble_radius;

            if (this.max_value.is_nan () || this.max_value <= 0.0) {
                return 0.0f;
            }

            if (levels <= 1)
            {
                // Exact value without quantization
                bubble_radius = (1.0f - BUBBLE_SPACING) *
                                (float) this.bubble_size * 0.5f *
                                (float) Math.sqrt (bubble_value / this.max_value);

                if (bubble_radius < MIN_BUBBLE_RADIUS) {
                    bubble_radius = 0.0f;
                }
            }
            else if (bubble_value < MIN_BUBBLE_VALUE) {
                bubble_radius = this.level_radii[0];
            }
            else {
                var level = 1 + ((int) Math.floor (
                        (double) (levels - 1) *
                        (bubble_value / this.max_value))).clamp (0, levels - 2);
                bubble_radius = this.level_radii[level];
            }

            return bubble_radius;
        }

        private void update_level_radii ()
        {
            if (this._levels == 0)
            {
                if (this.level_radii.length > 0) {
                    this.level_radii.resize (0);
                }

                return;
            }

            if (this.bubble_size <= 0) {
                return;
            }

            var levels     = (int) this._levels + 1;  // add base level for empty values
            var min_radius = (double) BASE_RADIUS;
            var max_radius = (1.0 - (double) BUBBLE_SPACING) * (double) this.bubble_size * 0.5;

            if (this.level_radii.length != levels) {
                this.level_radii.resize (levels);
            }

            for (var level = 0; level < levels; level++)
            {
                var t = (double) level / (double)(levels - 1);

                this.level_radii[level] = (float) Math.sqrt (
                        Adw.lerp (min_radius * min_radius, max_radius * max_radius, t));
            }
        }

        private void invalidate_max_value ()
        {
            this.max_value = double.NAN;

            this.queue_allocate ();
        }

        private void ensure_max_value ()
        {
            if (this.max_value.is_nan ()) {
                this.max_value = this.calculate_max_value ();
            }
        }

        private void ensure_categories (uint count)
        {
            var previous_count = this.categories.length;

            if (previous_count >= count) {
                return;
            }

            this.categories.resize ((int) count);

            for (var index = previous_count; index < count; index++)
            {
                this.categories[index] = Category () {
                    label = "",
                    color = this.get_color ()
                };
            }

            // this.queue_update ();
        }

        private bool grow_buckets (uint rows,
                                   uint columns)
        {
            var resized = false;

            if (this.buckets == null) {
                this.buckets = new Bucket[rows, columns];
                resized = true;
            }
            else {
                rows    = uint.max (this.buckets.length[0], rows);
                columns = uint.max (this.buckets.length[1], columns);
            }

            if (this.buckets.length[0] != rows ||
                this.buckets.length[1] != columns)
            {
                var rows_intersection    = int.min ((int) rows, this.buckets.length[0]);
                var columns_intersection = int.min ((int) columns, this.buckets.length[1]);
                var buckets              = new Bucket[rows, columns];

                for (var row = 0; row < rows_intersection; row++)
                {
                    for (var column = 0; column < columns_intersection; column++)
                    {
                        buckets[row, column] = this.buckets[row, column];
                    }
                }

                this.buckets = buckets;
                resized = true;
            }

            return resized;
        }

        private bool grow_data (uint row_count,
                                uint column_count,
                                uint category_count)
        {
            if (this.data == null)
            {
                row_count      = uint.max (row_count, 1U);
                column_count   = uint.max (column_count, 1U);
                category_count = uint.max (category_count, 1U);

                this.data = new Pomodoro.Matrix3D (row_count, column_count, category_count);
                this.queue_update ();
            }
            else {
                row_count      = uint.max (this.data.shape[0], row_count);
                column_count   = uint.max (this.data.shape[1], column_count);
                category_count = uint.max (this.data.shape[2], category_count);
            }

            if (this.data.shape[0] != row_count ||
                this.data.shape[1] != column_count ||
                this.data.shape[2] != category_count)
            {
                this.data.resize (row_count, column_count, category_count);
                this.queue_update ();

                return true;
            }
            else {
                return false;
            }
        }

        private void queue_draw_bubbles ()
        {
            unowned var bubble = this.bubbles_grid.get_first_child ();

            while (bubble != null)
            {
                bubble.queue_draw ();

                bubble = bubble.get_next_sibling ();
            }
        }

        private void queue_resize_bubbles ()
        {
            unowned var bubble = this.bubbles_grid.get_first_child ();

            while (bubble != null)
            {
                bubble.queue_resize ();

                bubble = bubble.get_next_sibling ();
            }
        }

        private void ensure_bubble (uint row,
                                    uint column)
        {
            unowned var existing_bubble = this.bubbles_grid.get_child_at ((int) column, (int) row);

            if (existing_bubble == null)
            {
                var bubble = this.create_bubble (row, column);

                this.bubbles_grid.attach (bubble, (int) column, (int) row);
            }
        }

        public void set_category_label (uint   category_index,
                                        string label)
        {
            this.ensure_categories (category_index + 1);

            this.categories[category_index].label = label;
        }

        public void set_category_color (uint     category_index,
                                        Gdk.RGBA color)
        {
            this.ensure_categories (category_index + 1);

            this.categories[category_index].color = color;

            this.queue_draw ();
        }

        public void set_category_unit (uint          category_index,
                                       Pomodoro.Unit unit)
        {
            this.ensure_categories (category_index + 1);

            this.categories[category_index].unit = unit;
        }

        public double get_category_total (uint category_index)
        {
            return this.data.get_matrix (-1, (int) category_index).sum ();;
        }

        private string get_tooltip_label (uint row,
                                          uint column)
        {
            if (row >= this.buckets.length[0] || column >= this.buckets.length[1]) {
                return "";
            }

            return this.buckets[row, column].tooltip_label;
        }

        public void set_bubble_tooltip_label (uint   row,
                                              uint   column,
                                              string label)
        {
            if (this.grow_buckets (row + 1, column + 1)) {
                this.queue_update ();
            }

            this.buckets[row, column].tooltip_label = label;
        }

        public void set_bubble_inverted (uint row,
                                         uint column,
                                         bool inverted)
        {
            this.ensure_bubble (row, column);

            unowned var bubble = this.bubbles_grid.get_child_at ((int) column, (int) row);

            if (inverted) {
                bubble.add_css_class ("inverted");
            }
            else {
                bubble.remove_css_class ("inverted");
            }

            this.queue_update ();
        }

        private void update_bubbles ()
        {
            var row_count    = uint.max (this.data.shape[0], this.buckets.length[0]);
            var column_count = uint.max (this.data.shape[1], this.buckets.length[1]);

            if (this.data.shape[0] > this.buckets.length[0] ||
                this.data.shape[1] > this.buckets.length[1])
            {
                GLib.warning ("Missing bucket definitions: %dx%d vs %ux%u",
                              this.buckets.length[1], this.buckets.length[0],
                              this.data.shape[1], this.data.shape[0]);
            }

            for (var row = 0U; row < row_count; row++)
            {
                for (var column = 0U; column < column_count; column++)
                {
                    this.ensure_bubble (row, column);
                }
            }
       }

        private void update_rows_labels ()
        {
            var count = this.rows_labels.length;
            var box   = this.rows_box;
            var child = box.get_first_child ();

            for (var index = 0; index < count; index++)
            {
                if (child == null)
                {
                    var label = new Gtk.Label (this.rows_labels[index]);
                    label.xalign = 1.0f;
                    label.yalign = 0.5f;

                    box.append (label);

                    child = (Gtk.Widget) label;
                }
                else {
                    ((Gtk.Label) child).label = this.rows_labels[index];
                }

                child = child.get_next_sibling ();
            }

            while (child != null)
            {
                var next_child = child.get_next_sibling ();
                box.remove (child);
                child = next_child;
            }
        }

        private void update_columns_labels ()
        {
            var count = this.columns_labels.length;
            var box   = this.columns_box;
            var child = box.get_first_child ();

            for (var index = 0; index < count; index++)
            {
                if (child == null)
                {
                    var label = new Gtk.Label (this.columns_labels[index]);
                    label.xalign = 0.5f;
                    label.yalign = 0.5f;

                    box.append (label);

                    child = (Gtk.Widget) label;
                }
                else {
                    ((Gtk.Label) child).label = this.columns_labels[index];
                }

                child = child.get_next_sibling ();
            }

            while (child != null)
            {
                var next_child = child.get_next_sibling ();
                box.remove (child);
                child = next_child;
            }
        }

        private void update ()
        {
            if (this.update_idle_id != 0) {
                this.remove_tick_callback (this.update_idle_id);
                this.update_idle_id = 0;
            }

            this.update_bubbles ();
            this.update_rows_labels ();
            this.update_columns_labels ();
        }

        private void queue_update ()
        {
            if (this.update_idle_id != 0) {
                return;
            }

            this.update_idle_id = this.add_tick_callback (() => {
                this.update_idle_id = 0;
                this.update ();

                return GLib.Source.REMOVE;
            });
        }

        private inline void ensure_rows (uint count)
        {
            if (this.rows_labels.length < count) {
                this.rows_labels.resize ((int) count);
            }
        }

        private inline void ensure_columns (uint count)
        {
            if (this.columns_labels.length < count) {
                this.columns_labels.resize ((int) count);
            }
        }

        public void set_row_label (uint   row,
                                   string label)
        {
            this.ensure_rows (uint.max (
                    row + 1U,
                    this.data != null ? this.data.shape[0] : 0U));

            assert (row < this.rows_labels.length);

            this.rows_labels[row] = label;

            this.queue_update ();
        }

        public void set_column_label (uint   column,
                                      string label)
        {
            this.ensure_columns (uint.max (
                    column + 1U,
                    this.data != null ? this.data.shape[1] : 0U));

            assert (column < this.columns_labels.length);

            this.columns_labels[column] = label;

            this.queue_update ();
        }

        public void fill (double value)
        {
            this.grow_data (uint.max (this.rows_labels.length, this.buckets.length[0]),
                            uint.max (this.columns_labels.length, this.buckets.length[1]),
                            this.categories.length);

            this.data.fill (value);

            this.invalidate_max_value ();
            this.queue_update ();
        }

        public void set_values (uint     row,
                                uint     column,
                                double[] values)
        {
            this.grow_data (row + 1, column + 1, values.length);

            var category_index = 0;

            for (; category_index < values.length; category_index++) {
                this.data.@set ((int) row, (int) column, category_index, values[category_index]);
            }

            for (; category_index < this.data.shape[2]; category_index++) {
                this.data.@set ((int) row, (int) column, category_index, 0.0);
            }

            this.invalidate_max_value ();
        }

        public double get_value (uint row,
                                 uint column,
                                 uint category_index)
        {
            return this.data != null
                    ? this.data.@get ((int) row, (int) column, (int) category_index)
                    : 0.0;
        }

        public void set_value (uint   row,
                               uint   column,
                               uint   category_index,
                               double value)
        {
            this.grow_data (row + 1, column + 1, category_index + 1);

            this.data.@set ((int) row, (int) column, (int) category_index, value);

            this.invalidate_max_value ();
        }

        public inline void add_value (uint   row,
                                      uint   column,
                                      uint   category_index,
                                      double value)
        {
            this.set_value (row,
                            column,
                            category_index,
                            value + this.get_value (row, column, category_index));
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

                var value_label = new Gtk.Label (
                        this.format_tooltip_value (category_index, category_value));
                value_label.halign = Gtk.Align.END;
                grid.attach (value_label, 1, 1 + category_index);
            }

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
            minimum = MIN_BUBBLE_SIZE;
            natural = this.bubble_size;
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        private void snapshot_bubble (Pomodoro.Gizmo gizmo,
                                      Gtk.Snapshot   snapshot)
        {
            var row            = (int) gizmo.get_data<uint> ("row");
            var column         = (int) gizmo.get_data<uint> ("column");
            var category_index = (int) this.category;
            var bubble_value   = this.data.@get (row, column, category_index, 0.0);
            var bubble_radius  = this.calculate_bubble_radius (bubble_value);

            var bubble_origin  = Graphene.Point () {
                x = ((float) gizmo.get_width ()) / 2.0f,
                y = ((float) gizmo.get_height ()) / 2.0f
            };
            var bubble_inverted = gizmo.has_css_class ("inverted");
            var bubble_color    = this.categories[category_index].color;
            var is_empty        = this.level_radii.length > 0
                    ? bubble_radius == this.level_radii[0] : false;

            if (is_empty && bubble_inverted) {
                return;
            }

            if (is_empty || bubble_inverted) {
                bubble_color.alpha = 0.1f;
            }

            var path_builder = new Gsk.PathBuilder ();
            path_builder.add_circle (bubble_origin, bubble_radius);

            if (bubble_inverted)
            {
                bubble_color.alpha *= 0.9f;

                var stroke = new Gsk.Stroke (2.2f);
                snapshot.append_stroke (path_builder.to_path (), stroke, bubble_color);
            }
            else {
                snapshot.append_fill (path_builder.to_path (), Gsk.FillRule.WINDING, bubble_color);
            }
        }

        private bool contains_bubble (Pomodoro.Gizmo gizmo,
                                      double         x,
                                      double         y)
        {
            if (!gizmo.get_mapped ()) {
                return false;
            }

            // Check if cursor fits within bubble boundaries.
            var point = Graphene.Point () {
                x = (float) x,
                y = (float) y
            };
            Graphene.Rect bounds;

            if (!gizmo.compute_bounds (gizmo, out bounds)) {
                return false;
            }

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

            if (this.activate_on_click)
            {
                unowned var weak_bubble = bubble;

                var click_gesture = new Gtk.GestureClick ();
                click_gesture.set_button (Gdk.BUTTON_PRIMARY);
                click_gesture.released.connect ((n_press, x, y) => {
                    BubbleChart.on_clicked_cb (weak_bubble);
                });

                bubble.add_controller (click_gesture);
            }
            else {
                bubble.set_state_flags (Gtk.StateFlags.INSENSITIVE, false);
            }

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
            var self   = BubbleChart.from_widget (widget);
            var row    = widget.get_data<uint> ("row");
            var column = widget.get_data<uint> ("column");

            if (self == null) {
                return false;
            }

            if (self.tooltip_row != row || self.tooltip_column != column) {
                self.tooltip_row    = (int) row;
                self.tooltip_column = (int) column;
                self.tooltip_widget = self.create_tooltip_widget (row, column);
            }

            tooltip.set_custom (self.tooltip_widget);

            return self.tooltip_widget != null;
        }

        private static void on_clicked_cb (Gtk.Widget widget)
        {
            var self   = BubbleChart.from_gizmo ((Pomodoro.Gizmo) widget);
            var row    = widget.get_data<uint> ("row");
            var column = widget.get_data<uint> ("column");

            if (self == null) {
                return;
            }

            var bubble_value = self.data.@get ((int) row, (int) column, (int) self.category);

            if (!bubble_value.is_nan () && bubble_value > 0.0) {
                self.bubble_activated (row, column);
            }
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
            var columns_box_minimum = 0;
            var columns_box_natural = 0;
            var rows_box_minimum = 0;
            var rows_box_natural = 0;

            var rows = int.max (
                    this.data != null ? (int) this.data.shape[0] : 0,
                    this.rows_labels.length);
            var columns = int.max (
                    this.data != null ? (int) this.data.shape[1] : 0,
                    this.columns_labels.length);

            this.columns_box.measure (
                    orientation,
                    for_size,
                    out columns_box_minimum,
                    out columns_box_natural,
                    null,
                    null);
            this.rows_box.measure (
                    orientation,
                    for_size,
                    out rows_box_minimum,
                    out rows_box_natural,
                    null,
                    null);

            if (orientation == Gtk.Orientation.HORIZONTAL)
            {
                minimum = rows_box_minimum + this.layout_grid.column_spacing + int.max (
                        MIN_BUBBLE_SIZE * columns + this.bubbles_grid.column_spacing * (columns - 1),
                        columns_box_minimum);
                natural = rows_box_natural + this.layout_grid.column_spacing + int.max (
                        MIN_BUBBLE_SIZE * columns + this.bubbles_grid.column_spacing * (columns - 1),
                        columns_box_natural);
            }
            else {
                var minimum_bubble_size = MIN_BUBBLE_SIZE;
                var natural_bubble_size = MIN_BUBBLE_SIZE;

                if (for_size > 0 && columns > 0)
                {
                    var total_column_spacing = this.layout_grid.column_spacing +
                                               this.bubbles_grid.column_spacing * (columns - 1);
                    var rows_box_minimum_width = 0;
                    var rows_box_natural_width = 0;

                    this.rows_box.measure (Gtk.Orientation.HORIZONTAL,
                                           -1,
                                           out rows_box_minimum_width,
                                           out rows_box_natural_width,
                                           null,
                                           null);

                    minimum_bubble_size = (
                        (for_size - rows_box_minimum_width - total_column_spacing) / columns
                    ).clamp (MIN_BUBBLE_SIZE, MAX_BUBBLE_SIZE);

                    natural_bubble_size = (
                        (for_size - rows_box_natural_width - total_column_spacing) / columns
                    ).clamp (MIN_BUBBLE_SIZE, MAX_BUBBLE_SIZE);
                }

                minimum = columns_box_minimum + this.layout_grid.row_spacing + int.max (
                        minimum_bubble_size * rows + this.bubbles_grid.row_spacing * (rows - 1),
                        rows_box_minimum);
                natural = columns_box_natural + this.layout_grid.row_spacing + int.max (
                        natural_bubble_size * rows + this.bubbles_grid.row_spacing * (rows - 1),
                        rows_box_natural);
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
            var rows = int.max (
                    this.data != null ? (int) this.data.shape[0] : 0,
                    this.rows_labels.length);
            var columns = int.max (
                    this.data != null ? (int) this.data.shape[1] : 0,
                    this.columns_labels.length);
            var columns_box_height = 0;
            var rows_box_width = 0;

            this.ensure_max_value ();

            this.columns_box.measure (
                    Gtk.Orientation.VERTICAL,
                    -1,
                    null,
                    out columns_box_height,
                    null,
                    null);
            this.rows_box.measure (
                    Gtk.Orientation.HORIZONTAL,
                    height - columns_box_height - this.layout_grid.row_spacing,
                    null,
                    out rows_box_width,
                    null,
                    null);

            var total_column_spacing =
                    this.layout_grid.column_spacing +
                    this.bubbles_grid.column_spacing * (columns - 1);
            var total_row_spacing =
                    this.layout_grid.row_spacing +
                    this.bubbles_grid.row_spacing * (rows - 1);

            var h_bubble_size = columns > 0
                    ? (width - rows_box_width - total_column_spacing) / columns
                    : MIN_BUBBLE_SIZE;
            var v_bubble_size = rows > 0
                    ? (height - columns_box_height - total_row_spacing) / rows
                    : MIN_BUBBLE_SIZE;
            var bubble_size = int.min (h_bubble_size, v_bubble_size).clamp (
                    MIN_BUBBLE_SIZE, MAX_BUBBLE_SIZE);

            if (this.bubble_size != bubble_size)
            {
                this.bubble_size = bubble_size;
                this.update_level_radii ();
                this.queue_resize_bubbles ();
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
            this.rows_labels    = null;
            this.columns_labels = null;
            this.level_radii    = null;
            this.tooltip_widget = null;

            base.dispose ();
        }

        public signal void bubble_activated (uint row, uint column);
    }
}
