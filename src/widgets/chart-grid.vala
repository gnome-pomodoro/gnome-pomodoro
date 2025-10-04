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

namespace Pomodoro
{
    public class ChartGrid : Gtk.Widget
    {
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

        public int x_origin {
            get {
                return this._x_origin;
            }
            set {
                this._x_origin = value;
            }
        }

        public int y_origin {
            get {
                return this._y_origin;
            }
            set {
                this._y_origin = value;
            }
        }

        public float line_width {
            get {
                return this._line_width;
            }
            set {
                this._line_width = value;

                this.queue_draw ();
            }
        }

        public bool horizontal {
            get {
                return this._horizontal;
            }
            set {
                this._horizontal = value;

                this.queue_draw ();
            }
        }

        public bool vertical {
            get {
                return this._vertical;
            }
            set {
                this._vertical = value;

                this.queue_draw ();
            }
        }

        private unowned Pomodoro.ChartAxis? _x_axis = null;
        private unowned Pomodoro.ChartAxis? _y_axis = null;
        private int                         _x_origin = 0;
        private int                         _y_origin = 0;
        private float                       _line_width = 1.0f;
        private bool                        _horizontal = true;
        private bool                        _vertical = true;

        static construct
        {
            set_css_name ("chartgrid");
        }

        public ChartGrid (Pomodoro.ChartAxis? x_axis,
                          Pomodoro.ChartAxis? y_axis)
        {
            this._x_axis = x_axis;
            this._y_axis = y_axis;

            if (this._x_axis != null) {
                this._x_axis.configured.connect (() => this.queue_draw ());
            }

            if (this._y_axis != null) {
                this._y_axis.configured.connect (() => this.queue_draw ());
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            var style_context = this.get_style_context ();
            var width         = (float) this.get_width ();
            var height        = (float) this.get_height ();
            var stroke        = new Gsk.Stroke (this._line_width);
            var path_builder  = new Gsk.PathBuilder ();

            // offset rounds line positions to full pixels
            var line_offset   = ((this._line_width - 1.0f) % 2.0f - 1.0f).abs () * 0.5f;

            Gdk.RGBA color;
            style_context.lookup_color ("unfocused_borders", out color);

            color.alpha *= 0.5f;

            if (this.horizontal && this._y_axis != null)
            {
                var y_scale = -this._y_axis.scale;

                foreach (var tick_value in this._y_axis.get_ticks ())
                {
                    var line_y = Math.roundf (tick_value * y_scale + (float) this._y_origin) +
                                 line_offset;

                    path_builder.move_to (0.0f, line_y);
                    path_builder.line_to (width, line_y);
                }
            }

            if (this.vertical && this._x_axis != null)
            {
                var x_scale = this._x_axis.scale;

                foreach (var tick_value in this._x_axis.get_ticks ())
                {
                    var line_x = Math.roundf (tick_value * x_scale + (float) this._x_origin) +
                                 line_offset;

                    path_builder.move_to (line_x, 0.0f);
                    path_builder.line_to (line_x, height);
                }
            }

            snapshot.append_stroke (path_builder.to_path (), stroke, color);
        }

        public override void dispose ()
        {
            this._x_axis = null;
            this._y_axis = null;

            base.dispose ();
        }
    }
}
