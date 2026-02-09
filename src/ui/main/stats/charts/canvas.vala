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
    /**
     * A container for placing widgets at given coordinates in a user-defined value space.
     * Value space is defined by `x-scale` and `y-scale`. `Canvas` will stretch to accommodate all
     * children. Then it's expected that parent widget will position the canvas, using `transform`
     * for alignment.
     *
     * There is no sub-pixel accuracy here. Items positions are rounded to nearest pixels.
     *
     * Unlike in GTK+, the y-coordinates increase when going up (like in typical charts).
     * Items are positioned from bottom-left corner.
     * Worth a read: https://docs.gtk.org/gtk4/coordinates.html
     */
    public sealed class Canvas : Gtk.Widget
    {
        private const double EPSILON = 0.00001;

        public float x_scale {
            get {
                return this._x_scale;
            }
            set {
                if (this._x_scale == value) {
                    return;
                }

                this._x_scale = value;

                this.invalidate_transform ();
                this.queue_resize ();
                this.queue_resize_children ();
            }
        }

        public float y_scale {
            get {
                return this._y_scale;
            }
            set {
                if (this._y_scale == value) {
                    return;
                }

                this._y_scale = value;

                this.invalidate_transform ();
                this.queue_resize ();
                this.queue_resize_children ();
            }
        }

        /**
         * Offset between top-left corner and an origin point.
         */
        [CCode (notify = false)]
        public int x_origin {
            get {
                return this._x_origin;
            }
        }

        /**
         * Offset between top-left corner and an origin point.
         */
        [CCode (notify = false)]
        public int y_origin {
            get {
                return this._y_origin;
            }
        }

        private float          _x_scale = 1.0f;
        private float          _y_scale = 1.0f;
        private int            _x_origin = 0;
        private int            _y_origin = 0;
        private Gsk.Transform? transform = null;
        private Gsk.Transform? transform_inv = null;

        static construct
        {
            set_css_name ("canvas");
            set_layout_manager_type (typeof (Ft.CanvasLayout));
        }

        private void invalidate_transform ()
        {
            this.transform = null;
            this.transform_inv = null;
        }

        private void queue_resize_children ()
        {
            for (var child = this.get_first_child ();
                 child != null;
                 child = child.get_next_sibling ())
            {
                child.queue_resize ();
            }
        }

        /**
         * Set-up the value space. We only need `x-scale` and `y-scale`.
         */
        public void set_scale (float x_scale,
                               float y_scale)
                               requires (x_scale.is_finite ())
                               requires (y_scale.is_finite ())
        {
            var x_scale_changed = x_scale != this._x_scale;
            var y_scale_changed = y_scale != this._y_scale;

            this._x_scale = x_scale;
            this._y_scale = y_scale;

            if (x_scale_changed) {
                this.notify_property ("x-scale");
            }

            if (y_scale_changed) {
                this.notify_property ("y-scale");
            }

            if (x_scale_changed || y_scale_changed) {
                this.invalidate_transform ();
                this.queue_resize ();
                this.queue_resize_children ();
            }
        }

        private void set_origin (int x_origin,
                                 int y_origin)
        {
            var x_origin_changed = x_origin != this._x_origin;
            var y_origin_changed = y_origin != this._y_origin;

            this._x_origin = x_origin;
            this._y_origin = y_origin;

            if (x_origin_changed) {
                this.notify_property ("x-origin");
            }

            if (y_origin_changed) {
                this.notify_property ("y-origin");
            }

            if (x_origin_changed || y_origin_changed) {
                this.invalidate_transform ();
            }
        }

        internal void update_origin ()
        {
            var layout = (Ft.CanvasLayout) this.layout_manager;
            int x_origin, y_origin;

            if (layout.calculate_origin (this, out x_origin, out y_origin)) {
                this.set_origin (x_origin, y_origin);
            }
        }

        private void update_transform ()
        {
            if (this._x_scale.abs () > EPSILON && this._y_scale.abs () > EPSILON)
            {
                var transform = new Gsk.Transform ();
                transform = transform.scale (1.0f / this._x_scale, -1.0f / this._y_scale);
                transform = transform.translate (
                    Graphene.Point () {
                        x = (float)(-this._x_origin),
                        y = (float)(-this._y_origin)
                    });
                this.transform = transform;
                this.transform_inv = transform.invert ();
            }
            else {
                this.transform = null;
                this.transform_inv = null;
            }
        }

        /**
         * Transform point from widget coordinates to value coordinates
         */
        public Graphene.Point transform_point (Graphene.Point point)
        {
            if (this.transform == null) {
                this.update_transform ();
            }

            return this.transform != null
                    ? this.transform.transform_point (point)
                    : point;
        }

        /**
         * Transform point from value coordinates to widget coordinates
         */
        public Graphene.Point transform_point_inv (Graphene.Point point)
        {
            if (this.transform_inv == null) {
                this.update_transform ();
            }

            return this.transform_inv != null
                    ? this.transform_inv.transform_point (point)
                    : point;
        }

        public void calculate_range (out float x_from,
                                     out float x_to,
                                     out float y_from,
                                     out float y_to)
        {
            var layout = (Ft.CanvasLayout) this.layout_manager;
            var range = layout.calculate_range (this);

            x_from = range.origin.x;
            x_to   = range.origin.x + range.size.width;
            y_from = range.origin.y;
            y_to   = range.origin.y + range.size.height;
        }


        /*
         * Children
         */

        /**
         * Get the layout child for a widget (for advanced usage)
         */
        internal inline unowned Ft.CanvasLayoutChild? get_layout_child (Gtk.Widget child)
        {
            return (Ft.CanvasLayoutChild?) this.layout_manager?.get_layout_child (child);
        }

        /**
         * Add a widget to the canvas at the given position
         */
        public void add_child (Gtk.Widget child,
                               float      x = 0.0f,
                               float      y = 0.0f)
        {
            child.set_parent (this);

            var layout_child = this.get_layout_child (child);
            layout_child.x = x;
            layout_child.y = y;

            this.queue_resize ();
        }

        /**
         * Remove a widget from the canvas
         */
        public void remove_child (Gtk.Widget child)
        {
            child.unparent ();

            this.queue_resize ();
        }

        /**
         * Set the position of a widget in the canvas
         */
        public void set_child_position (Gtk.Widget child,
                                        float      x,
                                        float      y)
        {
            var layout_child = this.get_layout_child (child);

            if (layout_child != null) {
                layout_child.x = x;
                layout_child.y = y;
            }

            this.queue_resize ();
        }

        /**
         * Get the position of a widget in the canvas
         */
        public void get_child_position (Gtk.Widget child,
                                        out float  x,
                                        out float  y)
        {
            var layout_child = this.get_layout_child (child);

            if (layout_child != null) {
                x = layout_child.x;
                y = layout_child.y;
            }
            else {
                x = 0.0f;
                y = 0.0f;
            }

            // this.queue_resize ();
        }

        /**
         * Set the origin offset of a widget
         */
        public void set_child_origin (Gtk.Widget child,
                                      int        x_origin,
                                      int        y_origin)
        {
            var layout_child = this.get_layout_child (child);

            if (layout_child != null) {
                layout_child.x_origin = x_origin;
                layout_child.y_origin = y_origin;
            }

            // this.queue_resize ();
        }

        /**
         * Set value range of a widget
         */
        public void set_child_range (Gtk.Widget child,
                                     float      x_from,
                                     float      x_to,
                                     float      y_from,
                                     float      y_to)
        {
            var layout_child = this.get_layout_child (child);

            if (layout_child != null) {
                layout_child.range = Graphene.Rect ();
                layout_child.range.init (x_from, y_from, x_to - x_from, y_to - y_from);
            }

            // this.queue_resize ();
        }

        public override void dispose ()
        {
            Gtk.Widget? child;

            while ((child = this.get_first_child ()) != null) {
                child.unparent ();
            }

            this.transform = null;
            this.transform_inv = null;

            base.dispose ();
        }
    }
}
