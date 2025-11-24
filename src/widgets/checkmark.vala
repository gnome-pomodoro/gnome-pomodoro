namespace Pomodoro
{
    public class Checkmark : Gtk.Widget
    {
        private const uint DEFAULT_PIXEL_SIZE = 32;
        private const uint DEFAULT_DELAY = 500;
        private const uint LINE_WIDTH = 6;

        [CCode (notify = false)]
        public uint pixel_size
        {
            get {
                return this._pixel_size;
            }
            set {
                if (this._pixel_size != value) {
                    this._pixel_size = value;
                    this.notify_property ("pixel-size");
                    this.queue_resize ();
                }
            }
        }

        [CCode (notify = false)]
        public uint delay {
            get {
                return this._delay;
            }
            set {
                if (this._delay != value) {
                    this._delay = value;
                    this.notify_property ("delay");
                    this.animate ();
                }
            }
        }

        private uint                _delay = DEFAULT_DELAY;
        private uint                _pixel_size = DEFAULT_PIXEL_SIZE;
        private uint                _line_width = LINE_WIDTH;
        private Adw.TimedAnimation? first_animation = null;
        private Adw.TimedAnimation? second_animation = null;
        private uint                timeout_id = 0U;
        private bool                animation_done = false;

        static construct
        {
            set_css_name ("checkmark");
        }

        private void on_second_animation_done ()
        {
            this.first_animation  = null;
            this.second_animation = null;
            this.animation_done   = true;
        }

        private void on_first_animation_done ()
        {
            this.second_animation.play ();
        }

        private void animate ()
        {
            if (this.first_animation != null) {
                this.first_animation.pause ();
                this.first_animation = null;
            }

            if (this.second_animation != null) {
                this.second_animation.pause ();
                this.second_animation = null;
            }

            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            var animation_target = new Adw.CallbackAnimationTarget (this.queue_draw);

            this.first_animation = new Adw.TimedAnimation (this,
                                                           0.0,
                                                           1.0,
                                                           200,
                                                           animation_target);
            this.first_animation.set_easing (Adw.Easing.EASE_IN_OUT_CUBIC);
            this.first_animation.done.connect (this.on_first_animation_done);

            this.second_animation = new Adw.TimedAnimation (this,
                                                            0.0,
                                                            1.0,
                                                            300,
                                                            animation_target);
            this.second_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
            this.second_animation.done.connect (this.on_second_animation_done);

            this.timeout_id = GLib.Timeout.add (
                    this._delay,
                    () => {
                        this.timeout_id = 0;

                        if (this.first_animation != null) {
                            this.first_animation.play ();
                        }

                        return GLib.Source.REMOVE;
                    });
            GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.Checkmark.animate");

            this.animation_done = false;
        }

        public override void map ()
        {
            base.map ();

            this.animate ();
        }

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
            minimum = (int) this._pixel_size;
            natural = (int) this._pixel_size;
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            var width  = (float) this.get_width ();
            var height = (float) this.get_height ();
            var origin = Graphene.Point () {
                x = width / 2.0f,
                y = height / 2.0f
            };
            var scale  = (float.min (width, height) - this._line_width) / 2.0f;
            var color  = this.get_color ();

            var x_0 = origin.x - 1.000f * scale;
            var y_0 = origin.y - 0.025f * scale;
            var x_1 = origin.x - 0.250f * scale;
            var y_1 = origin.y + 0.725f * scale;
            var x_2 = origin.x + 1.000f * scale;
            var y_2 = origin.y - 0.525f * scale;

            var progress_1 = this.first_animation != null
                    ? (float) this.first_animation.value
                    : (this.animation_done ? 1.0f : 0.0f);
            var progress_2 = this.second_animation != null
                    ? (float) this.second_animation.value
                    : (this.animation_done ? 1.0f : 0.0f);

            var path_builder = new Gsk.PathBuilder ();
            path_builder.move_to (x_0, y_0);
            path_builder.rel_line_to ((x_1 - x_0) * progress_1,
                                      (y_1 - y_0) * progress_1);
            path_builder.rel_line_to ((x_2 - x_1) * progress_2,
                                      (y_2 - y_1) * progress_2);

            var stroke = new Gsk.Stroke (this._line_width);
            stroke.set_line_cap (Gsk.LineCap.ROUND);
            stroke.set_line_join (Gsk.LineJoin.ROUND);

            snapshot.append_stroke (path_builder.to_path (), stroke, color);
        }

        public override void dispose ()
        {
            if (this.first_animation != null) {
                this.first_animation.pause ();
                this.first_animation = null;
            }

            if (this.second_animation != null) {
                this.second_animation.pause ();
                this.second_animation = null;
            }

            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            base.dispose ();
        }
    }
}
