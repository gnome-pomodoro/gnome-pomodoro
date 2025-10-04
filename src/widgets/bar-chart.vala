namespace Pomodoro
{
    /**
     * Widget for displaying a bar chart or a histogram.
     */
    public class BarChart : Pomodoro.Chart
    {
        private const int    MIN_BAR_WIDTH = 16;
        private const int    MAX_BAR_WIDTH = 30;
        private const float  BAR_SPACING = 0.25f;
        private const int    MIN_BAR_SPACING = 2;
        private const float  ASPECT_RATIO = 1.66f;
        private const float  BAR_HIT_ZONE_PADDING = 10.0f;
        private const double EPSILON = 0.00001;

        public bool stacked {
            get {
                return this._stacked;
            }
            set {
                if (this._stacked == value) {
                    return;
                }

                this._stacked = value;

                this.queue_allocate ();
            }
        }

        public bool show_empty_bars {
            get {
                return this._show_empty_bars;
            }
            set {
                if (this._show_empty_bars == value) {
                    return;
                }

                this._show_empty_bars = value;

                this.queue_draw ();
            }
        }

        public bool activate_on_click {
            get; set; default = false;
        }

        public float reference_value {
            get {
                return this.contents.y_value_to;
            }
            set {
                this.contents.y_value_to = value;
            }
        }

        private bool             _stacked = true;
        private bool             _show_empty_bars = false;
        private double           transform_slope = 1.0;
        private double           transform_intercept = 0.0;
        private Bucket[]         buckets;
        private Category[]       categories;
        private Pomodoro.Matrix? data;
        private int              bar_width;
        private int              bar_height;
        private int              bar_radius;
        private int              tooltip_bar_index = -1;
        private Gtk.Widget?      tooltip_widget;

        construct
        {
            this.buckets    = {};
            this.categories = {};

            this.contents.grid.vertical = false;
            this.contents.x_axis.continous = false;
            this.contents.y_value_from = 0.0f;
            this.contents.y_value_to = float.NAN;
        }


        /*
         * Data
         */

        private double calculate_bucket_sum (uint bucket_index)
        {
            if (this.data == null) {
                return 0.0;
            }

            var values = this.data.get_vector (0, (int) bucket_index);

            for (var category_index = 0; category_index < this.categories.length; category_index++)
            {
                if (!this.categories[category_index].visible) {
                    values.@set (category_index, 0.0);
                }
            }

            return values != null ? values.sum () : 0.0;
        }

        private double calculate_bucket_max (uint bucket_index)
        {
            if (this.data == null) {
                return 0.0;
            }

            var values = this.data.get_vector (0, (int) bucket_index);

            for (var category_index = 0; category_index < this.categories.length; category_index++)
            {
                if (!this.categories[category_index].visible) {
                    values.@set (category_index, 0.0);
                }
            }

            return values != null ? values.max () : 0.0;
        }

        private inline double calculate_bucket_total_value (uint bucket_index)
        {
            return this._stacked
                    ? this.calculate_bucket_sum (bucket_index)
                    : this.calculate_bucket_max (bucket_index);
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
                    label   = "",
                    color   = this.get_color (),
                    visible = true
                };
            }

            this.queue_update ();
        }

        private void ensure_buckets (uint count)
        {
            var previous_count = this.buckets.length;

            if (previous_count >= count) {
                return;
            }

            this.buckets.resize ((int) count);

            for (var index = previous_count; index < count; index++)
            {
                this.buckets[index] = Bucket () {
                    label = ""
                };
            }

            this.queue_update ();
        }

        private inline void ensure_data ()
        {
            if (this.data == null)
            {
                var bucket_count = this.buckets.length;
                var category_count = this.categories.length;

                this.data = new Pomodoro.Matrix (bucket_count, category_count);
            }
        }

        private inline void grow_data (uint bucket_count,
                                       uint category_count)
                                       requires (bucket_count < 1000)
        {
            this.ensure_data ();

            bucket_count   = uint.max (this.data.shape[0], bucket_count);
            category_count = uint.max (this.data.shape[1], category_count);

            if (this.data.shape[0] != bucket_count ||
                this.data.shape[1] != category_count)
            {
                this.data.resize (bucket_count, category_count);
            }
        }

        private bool is_bucket_empty (uint bucket_index)
        {
            var category_count = int.min ((int) this.data.shape[1], this.categories.length);
            var total_abs_value = 0.0;

            for (var category_index = 0; category_index < category_count; category_index++)
            {
                var category_value = this.data.@get ((int) bucket_index, category_index);

                if (category_value.is_finite ()) {
                    total_abs_value += category_value.abs ();
                }
            }

            return total_abs_value.abs () <= EPSILON;

            // XXX: use Use CanvasLayoutChild.range.size.height ?
        }

        public uint get_bars_count ()
        {
            return this.buckets.length;
        }

        public uint get_categories_count ()
        {
            return this.categories.length;
        }

        public double get_category_total (uint category_index)
        {
            var total = this.data.get_vector (-1, (int) category_index).sum ();

            if (this._stacked)
            {
                for (var index = 0; index < category_index; index++) {
                    total += this.data.get_vector (-1, index).sum ();
                }
            }

            return total;
        }

        public void remove_all_bars ()
        {
            this.buckets = null;
        }

        public void set_bar_label (uint   bar_index,
                                   string label,
                                   string tooltip_label = "")
        {
            if (tooltip_label == "") {
                tooltip_label = label;
            }

            this.ensure_buckets (bar_index + 1);

            this.buckets[bar_index].label = label;
            this.buckets[bar_index].tooltip_label = tooltip_label;

            // this.queue_allocate ();
            // this.contents.x_axis.queue_allocate ();
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

        public void set_category_unit (uint         category_index,
                                      Pomodoro.Unit unit)
        {
            this.ensure_categories (category_index + 1);

            this.categories[category_index].unit = unit;
        }

        public void set_category_visible (uint category_index,
                                          bool visible)
        {
            this.ensure_categories (category_index + 1);

            this.categories[category_index].visible = visible;

            this.queue_draw ();
        }

        public void fill (double value)
        {
            this.grow_data ((uint) this.buckets.length,
                            (uint) this.categories.length);

            this.data.fill (value);

            this.queue_update ();
        }

        public void set_values (uint     bar_index,
                                double[] values)
        {
            this.grow_data (bar_index + 1, values.length);

            if (values.length > this.data.shape[1]) {
                GLib.warning ("BarChart.set_values received a vector with length %d when there are only %u categories",
                              values.length, this.data.shape[1]);
            }

            var category_index = 0;

            for (; category_index < values.length; category_index++) {
                this.data.@set ((int) bar_index, category_index, values[category_index]);
            }

            for (; category_index < this.data.shape[1]; category_index++) {
                this.data.@set ((int) bar_index, category_index, 0.0);
            }

            // XXX: update only changed bars
            this.queue_update ();
        }

        public double get_value (uint bar_index,
                                 uint category_index)
        {
            return this.data != null
                    ? this.data.@get ((int) bar_index, (int) category_index)
                    : 0.0;
        }

        public void set_value (uint   bar_index,
                               uint   category_index,
                               double value)
        {
            assert (value.is_finite ());  // TODO: remove

            this.grow_data (bar_index + 1, category_index + 1);

            this.data.@set ((int) bar_index, (int) category_index, value);

            if (category_index < this.categories.length &&
                this.categories[category_index].visible)
            {
                // TODO: update only changed bars
                this.queue_update ();
            }
        }

        public inline void add_value (uint   bar_index,
                                      uint   category_index,
                                      double value)
        {
            this.set_value (bar_index,
                            category_index,
                            value + this.get_value (bar_index, category_index));
        }


        /*
         * Bars
         */

        private bool on_query_tooltip (Gtk.Widget  widget,
                                       int         x,
                                       int         y,
                                       bool        keyboard_tooltip,
                                       Gtk.Tooltip tooltip)
        {
            var bar_index = widget.get_data<uint> ("index");

            if (this.tooltip_bar_index != bar_index) {
                this.tooltip_bar_index = (int) bar_index;
                this.tooltip_widget = this.create_tooltip_widget (bar_index);
            }

            tooltip.set_custom (this.tooltip_widget);

            return this.tooltip_widget != null;
        }

        private Gtk.Widget? create_tooltip_widget (uint bar_index)
        {
            var bucket = this.buckets[bar_index];
            var category_count = this.categories.length;

            var grid = new Gtk.Grid ();
            grid.column_spacing = 10;
            grid.row_spacing = 5;
            grid.row_homogeneous = true;
            grid.add_css_class ("tooltip-contents");

            var header_label = new Gtk.Label (bucket.tooltip_label);
            header_label.add_css_class ("tooltip-header");
            grid.attach (header_label, 0, 0, 2, 1);

            for (var category_index = category_count - 1; category_index >= 0; category_index--)
            {
                var category = this.categories[category_index];
                var category_value = this.data.@get ((int) bar_index, category_index);

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

        private Gtk.Widget create_bar ()
        {
            var bar = new Pomodoro.Gizmo (Pomodoro.BarChart.measure_bar_cb,
                                          null,
                                          Pomodoro.BarChart.snapshot_bar_cb,
                                          Pomodoro.BarChart.contains_bar_cb,
                                          null,
                                          null);
            bar.focusable = false;
            bar.has_tooltip = true;
            bar.add_css_class ("bar");
            bar.query_tooltip.connect (Pomodoro.BarChart.on_query_tooltip_cb);

            if (this.activate_on_click)
            {
                unowned var weak_bar = bar;

                var click_gesture = new Gtk.GestureClick ();
                click_gesture.set_button (Gdk.BUTTON_PRIMARY);
                click_gesture.released.connect ((n_press, x, y) => {
                    BarChart.on_clicked_cb (weak_bar);
                });

                bar.add_controller (click_gesture);
            }
            else {
                bar.set_state_flags (Gtk.StateFlags.INSENSITIVE, false);
            }

            return bar;
        }

        private static Pomodoro.BarChart? from_gizmo (Pomodoro.Gizmo gizmo)
        {
            Gtk.Widget? widget = gizmo;

            while (widget != null)
            {
                var chart = widget as Pomodoro.BarChart;

                if (chart != null) {
                    return chart;
                }

                widget = widget.get_parent ();
            }

            return null;
        }

        private static Pomodoro.BarChart? from_widget (Gtk.Widget widget)
        {
            Gtk.Widget? current = widget;

            while (current != null)
            {
                var chart = current as Pomodoro.BarChart;

                if (chart != null) {
                    return chart;
                }

                current = current.get_parent ();
            }

            return null;
        }

        private static void measure_bar_cb (Pomodoro.Gizmo  gizmo,
                                            Gtk.Orientation orientation,
                                            int             for_size,
                                            out int         minimum,
                                            out int         natural,
                                            out int         minimum_baseline,
                                            out int         natural_baseline)
        {
            var self = BarChart.from_gizmo (gizmo);

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

        private static void snapshot_bar_cb (Pomodoro.Gizmo gizmo,
                                             Gtk.Snapshot   snapshot)
        {
            var self = BarChart.from_gizmo (gizmo);

            if (self != null) {
                self.snapshot_bar (gizmo, snapshot);
            }
        }

        private static bool contains_bar_cb (Pomodoro.Gizmo gizmo,
                                             double         x,
                                             double         y)
        {
            var self = BarChart.from_gizmo (gizmo);

            return self != null ? self.contains_bar (gizmo, x, y) : false;
        }

        private static bool on_query_tooltip_cb (Gtk.Widget  widget,
                                                 int         x,
                                                 int         y,
                                                 bool        keyboard_tooltip,
                                                 Gtk.Tooltip tooltip)
        {
            var self = BarChart.from_widget (widget);

            return self != null
                    ? self.on_query_tooltip (widget, x, y, keyboard_tooltip, tooltip)
                    : false;
        }

        private static void on_clicked_cb (Gtk.Widget widget)
        {
            var self      = BarChart.from_gizmo ((Pomodoro.Gizmo) widget);
            var bar_index = widget.get_data<uint> ("index");

            if (self != null) {
                self.bar_activated (bar_index);
            }
        }

        private inline void update_bar (Gtk.Widget bar,
                                        uint       bar_index)
        {
            bar.set_data<uint> ("index", bar_index);

            var layout_child = this.contents.canvas.get_layout_child (bar);

            if (layout_child != null)
            {
                var total_value = this.calculate_bucket_total_value (bar_index);
                var bar_x = (double) bar_index * this.transform_slope + this.transform_intercept;

                layout_child.x = (float) bar_x;
                layout_child.y = 0.0f;
                layout_child.set_range ((float) bar_x, (float) bar_x, 0.0f, (float) total_value);
            }
        }

        private void measure_bar (Pomodoro.Gizmo  gizmo,
                                  Gtk.Orientation orientation,
                                  int             for_size,
                                  out int         minimum,
                                  out int         natural,
                                  out int         minimum_baseline,
                                  out int         natural_baseline)
        {
            minimum = orientation == Gtk.Orientation.HORIZONTAL ? this.bar_width : this.bar_height;
            natural = minimum;
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        private void snapshot_bar (Pomodoro.Gizmo gizmo,
                                   Gtk.Snapshot   snapshot)
        {
            var bar_index = gizmo.get_data<uint> ("index");

            if (bar_index >= this.data.shape[0]) {
                GLib.warning ("Unable to snapshot bar %u: No data", bar_index);
                return;
            }

            if (!this.show_empty_bars && this.is_bucket_empty (bar_index)) {
                return;
            }

            var category_count = int.min ((int) this.data.shape[1], this.categories.length);
            var base_value     = 0.0;
            var bar_width      = (float) this.bar_width;
            var bar_height     = (float) this.bar_height;
            var y_scale        = (double) this.contents.canvas.y_scale;
            var is_shown       = false;

            if (this._stacked)
            {
                for (var category_index = 0; category_index < category_count; category_index++)
                {
                    var category_value = this.data.@get ((int) bar_index, category_index);

                    if (category_value.is_finite ()) {
                        base_value += category_value;
                    }
                }
            }

            for (var category_index = category_count - 1; category_index >= 0; category_index--)
            {
                var category_value = this.data.@get ((int) bar_index, category_index);
                var category_color = this.categories[category_index].color;

                if (!category_value.is_finite ()) {
                    continue;
                }

                if (!this._stacked) {
                    base_value = category_value;
                }

                if (category_value * y_scale <= 0.0 &&
                    (category_index != 0 || is_shown))
                {
                    base_value -= category_value;
                    continue;
                }

                var bounds = Graphene.Rect ();
                bounds.init (0.0f,
                             bar_height - bar_width - (float)(base_value * y_scale),
                             bar_width,
                             (float)(category_value * y_scale) + bar_width);

                var outline = Gsk.RoundedRect ();
                outline.init_from_rect (bounds, bar_width / 2.0f);

                snapshot.push_rounded_clip (outline);
                snapshot.append_color (category_color, bounds);
                snapshot.pop ();

                base_value -= category_value;
                is_shown = true;
            }
        }

        private bool contains_bar (Pomodoro.Gizmo gizmo,
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

            if (!gizmo.compute_bounds (gizmo, out bounds) ||
                !bounds.contains_point (point))
            {
                return false;
            }

            // Check if cursor fits within value bars and the ornaments (bar radius)
            var bar_index = gizmo.get_data<uint> ("index");

            if (!this.show_empty_bars && this.is_bucket_empty (bar_index)) {
                return false;
            }

            var total_value = (float) this.calculate_bucket_total_value (bar_index);

            point.y += this.bar_radius + BAR_HIT_ZONE_PADDING;
            point = this.contents.canvas.transform_point (point);

            return point.y <= total_value;
        }

        private inline void foreach_bar (GLib.Func<unowned Gtk.Widget> func)
        {
            var child = this.contents.canvas.get_first_child ();

            while (child != null)
            {
                var next_child = child.get_next_sibling ();

                func (child);

                child = next_child;
            }
        }


        /*
         * Chart
         */

        /**
         * Charts `width` depends more on content and can be scrolled horizontally.
         * `height` is determined by the `Chart` using aspect-ratio.
         */
        public override Gtk.SizeRequestMode get_contents_request_mode (Pomodoro.Canvas canvas)
        {
            return Gtk.SizeRequestMode.WIDTH_FOR_HEIGHT;
        }

        public override void update_canvas (Pomodoro.Canvas canvas)
        {
            var bars_count = this.get_bars_count ();
            var bar_index = 0U;

            // Update existing bars and remove unnecessary ones
            this.foreach_bar (
                (bar) => {
                    if (bar_index < bars_count) {
                        this.update_bar (bar, bar_index);
                        bar_index++;
                    }
                    else {
                        canvas.remove_child (bar);
                    }
                });

            // Create missing bars
            while (bar_index < bars_count)
            {
                var bar = this.create_bar ();
                canvas.add_child (bar);

                this.update_bar (bar, bar_index);

                bar_index++;
            }

            // HACK: Sync x-axis synced with scale
            this.x_spacing = (float) this.transform_slope;
        }

        public override void measure_canvas (Pomodoro.Canvas canvas,
                                             Gtk.Orientation orientation,
                                             int             for_size,
                                             out int         minimum,
                                             out int         natural)
        {
            if (orientation == Gtk.Orientation.HORIZONTAL)
            {
                var bars_count = (int) this.buckets.length;

                var label_width = this.contents.x_axis.label_width;
                var min_margins = int.max (label_width - MIN_BAR_WIDTH, 0);
                var max_margins = int.max (label_width - MAX_BAR_WIDTH, 0);

                // Estimate content size
                var max_bar_spacing = int.max (
                        (int) Math.floorf ((float) MAX_BAR_WIDTH * BAR_SPACING),
                        MIN_BAR_SPACING);
                var min_width = (MIN_BAR_WIDTH + MIN_BAR_SPACING) * bars_count -
                        MIN_BAR_SPACING + min_margins;
                var max_width = (MAX_BAR_WIDTH + max_bar_spacing) * bars_count -
                        max_bar_spacing + max_margins;
                var nat_width = (int) Math.roundf (ASPECT_RATIO * (float) max_width);

                // Calculate optimal bar size and spacing
                var segment_width = bars_count != 0 ? nat_width / bars_count : 0;
                var bar_spacing = int.max ((int) Math.floorf (BAR_SPACING * (float) segment_width),
                                           MIN_BAR_SPACING);
                var bar_width = int.min (segment_width - bar_spacing, MAX_BAR_WIDTH);

                minimum = min_width;
                natural = bars_count * (bar_width + bar_spacing) - bar_spacing;
            }
            else {
                minimum = this.height_request;
                natural = minimum;
            }
        }

        public override void measure_working_area (Pomodoro.Canvas   canvas,
                                                   int               available_width,
                                                   int               available_height,
                                                   out Gdk.Rectangle working_area)
        {
            // Calculate optimal bar size and spacing
            var bars_count = (int) this.get_bars_count ();
            var segment_width = bars_count != 0 ? available_width / bars_count : 0;
            var bar_spacing = int.max ((int) Math.floorf (BAR_SPACING * (float) segment_width),
                                       MIN_BAR_SPACING);
            var bar_width  = int.min (segment_width - bar_spacing, MAX_BAR_WIDTH);
            var bar_height = available_height;
            var bar_radius = bar_width / 2;

            working_area = Gdk.Rectangle () {
                x      = bar_width / 2,
                y      = bar_width - bar_radius,
                width  = segment_width * (bars_count - 1),
                height = bar_height - 2 * bar_radius
            };

            // Store measurements for bar allocation / snapshot
            this.bar_width  = bar_width;
            this.bar_height = bar_height;
            this.bar_radius = bar_radius;

            this.foreach_bar (
                (bar) => {
                    var layout_child = canvas.get_layout_child (bar);

                    if (layout_child != null) {
                        layout_child.x_origin = this.bar_radius;
                        layout_child.y_origin = this.bar_height - this.bar_radius;
                    }
                });
        }


        /*
         * Axes
         */

        /**
         * Modify bars `x` position to concrete values rather than bar indices. Used for zooming.
         */
        public void set_transform (double slope,
                                   double intercept)
        {
            this.transform_slope  = slope;
            this.transform_intercept = intercept;
        }

        public override string format_x_value (double value)
        {
            var bar_index = (int) Math.round ((value - this.transform_intercept) /
                                              this.transform_slope);

            return bar_index >= 0 && bar_index < this.buckets.length
                    ? this.buckets[bar_index].label
                    : "∅";  // for debugging
        }

        private string format_tooltip_value (uint   category_index,
                                             double value)
        {
            return category_index < this.categories.length
                    ? this.categories[category_index].unit.format (value)
                    : "%.2f".printf (value);
        }


        /*
         * Widget
         */

        public override void dispose ()
        {
            if (this.tooltip_widget != null) {
                this.tooltip_widget.unparent ();
                this.tooltip_widget = null;
            }

            this.data           = null;
            this.categories     = null;
            this.buckets        = null;
            this.tooltip_widget = null;

            base.dispose ();
        }

        public signal void bar_activated (uint bar_index);
    }
}
