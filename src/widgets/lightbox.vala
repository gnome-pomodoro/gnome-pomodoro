namespace Pomodoro
{
    public class MonitorConstrainedLayoutManager : Gtk.LayoutManager
    {
        public Gdk.Monitor? monitor {
            get {
                return this._monitor;
            }
            set {
                this._monitor = value;

                this.layout_changed ();
            }
        }

        private Gdk.Monitor? _monitor = null;

        public MonitorConstrainedLayoutManager (Gdk.Monitor? monitor = null)
        {
            this.monitor = monitor;
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
            if (this._monitor != null)
            {
                var monitor_geometry = this._monitor.get_geometry ();

                minimum = natural = orientation == Gtk.Orientation.HORIZONTAL
                    ? monitor_geometry.width
                    : monitor_geometry.height;
            }
            else {
                minimum = natural = 400;

                // widget.measure (orientation,
                //                 -1,
                //                 out minimum,
                //                 out natural,
                //                 null,
                //                 null);
            }

            minimum_baseline = -1;
            natural_baseline = -1;
        }

        public override void allocate (Gtk.Widget widget,
                                       int        width,
                                       int        height,
                                       int        baseline)
        {
            debug ("### allocate %dx%d", width, height);

            var allocation = Gtk.Allocation () {
                x = 0,
                y = 0,
                width = width,
                height = height
            };

            if (this._monitor != null)
            {
                var monitor_geometry = this._monitor.get_geometry ();
                allocation.x = monitor_geometry.x;
                allocation.y = monitor_geometry.y;
                allocation.width = monitor_geometry.width;
                allocation.height = monitor_geometry.height;

                debug ("### monitor_geometry %dx%d @ (%d, %d)",
                       monitor_geometry.width, monitor_geometry.height,
                       monitor_geometry.x, monitor_geometry.y);
            }

            var child = widget.get_first_child ();

            while (child != null)
            {
                if (!child.should_layout ()) {
                    continue;
                }

                child.allocate_size (allocation, -1);
                child = child.get_next_sibling ();
            }
        }
    }


    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/lightbox.ui")]
    public class Lightbox : Gtk.Window, Gtk.Buildable
    {
        public Gdk.Monitor? monitor {
            get {
                var layout_manager = (Pomodoro.MonitorConstrainedLayoutManager) this.container.layout_manager;

                return layout_manager.monitor;
            }
            set {
                var layout_manager = (Pomodoro.MonitorConstrainedLayoutManager) this.container.layout_manager;

                layout_manager.monitor = value;

                // if (value != null) {
                //     this.fullscreen_on_monitor (value);
                // }
            }
        }

        public Gtk.Widget? contents {
            get {
                return this.container.child;
            }
            set {
                var previous_child = this.container.child;

                if (previous_child != null) {
                    previous_child.remove_css_class ("contents");
                }

                this.container.child = value;

                if (value != null) {
                    value.add_css_class ("contents");
                }
            }
        }

        [GtkChild]
        private unowned Adw.Bin container;

        private bool closing = false;

        static construct
        {
            set_css_name ("lightbox");
            set_auto_startup_notification (false);
        }

        construct
        {
            this.notify["fullscreened"].connect (this.on_notify_fullscreened);

            // Wayland categorizes fullscreen windows and toplevels separately. Indicate from the start that it's an
            // fullscreen window.
            this.fullscreen ();
        }

        [GtkCallback]
        private bool on_key_pressed (Gtk.EventControllerKey event_controller,
                                     uint                   keyval,
                                     uint                   keycode,
                                     Gdk.ModifierType       state)
        {
            switch (keyval)
            {
                case Gdk.Key.Escape:
                    this.close ();
                    return true;
            }

            return false;
        }

        private void on_notify_fullscreened (GLib.Object    object,
                                             GLib.ParamSpec pspec)
        {
            if (!this.fullscreened) {
                GLib.debug ("Closing lightbox. It's no longer fullscreen.");
                this.close ();
            }

            Gdk.FullscreenMode effective_fullscreen_mode;

            if (this.get_effective_fullscreen_mode (out effective_fullscreen_mode)) {
                debug ("### effective_fullscreen_mode = %s", effective_fullscreen_mode.to_string ());
            }
            else {
                debug ("### effective_fullscreen_mode = unknown");
            }
        }

        public bool get_effective_fullscreen_mode (out Gdk.FullscreenMode fullscreen_mode)
        {
            var monitor = this.monitor;
            var monitor_geometry = monitor?.get_geometry ();
            var contents = this.contents;
            var contents_bounds = Graphene.Rect ();

            if (monitor == null || contents == null || !contents.compute_bounds (this, out contents_bounds)) {
                return false;
            }

            if (contents_bounds.origin.x == 0.0f &&
                contents_bounds.origin.y == 0.0f &&
                contents_bounds.size.width == (float) monitor_geometry.width &&
                contents_bounds.size.height == (float) monitor_geometry.height)
            {
                fullscreen_mode = Gdk.FullscreenMode.CURRENT_MONITOR;
            }
            else {
                fullscreen_mode = Gdk.FullscreenMode.ALL_MONITORS;
            }

            return true;
        }

        /**
         * Invoking close on any of lightboxes within group should propagate to main overlay.
         */
        public new void close ()
        {
            if (this.closing) {
                return;
            }

            this.closing = true;

            var group = this.get_group ();

            if (group != null) {
                group.@list_windows ().@foreach (
                    (window) => {
                        var lightbox = (Pomodoro.Lightbox) window;
                        lightbox.close ();
                    });
            }

            base.close ();
        }

        public override void map ()
        {
            var toplevel = (Gdk.Toplevel) this.get_surface ();
            toplevel.fullscreen_mode = Gdk.FullscreenMode.ALL_MONITORS;

            var monitor = this.monitor;

            if (monitor != null) {
                this.fullscreen_on_monitor (monitor);
            }

            base.map ();
        }
    }
}
