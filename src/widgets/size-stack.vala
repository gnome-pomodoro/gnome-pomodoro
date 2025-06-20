namespace Pomodoro
{
    private inline Gtk.Orientation get_opposite_orientation (Gtk.Orientation orientation)
    {
        return orientation == Gtk.Orientation.HORIZONTAL
            ? Gtk.Orientation.VERTICAL
            : Gtk.Orientation.HORIZONTAL;
    }


    public class SizeStackPage : GLib.Object
    {
        public Gtk.Widget child { get; construct; }
        public string     name { get; set; }
        public bool       resizable { get; set; default = true; }

        public SizeStackPage (Gtk.Widget child)
        {
            GLib.Object (
                child: child
            );
        }
    }


    /**
     * Container for transitioning between widgets of varying sizes.
     *
     * The purpose is to swap widgets of varying complexity or just different variants. It's tailored for interpolating
     * window size - origin of the transition is at top left corner.
     */
    public class SizeStack : Gtk.Widget, Gtk.Buildable
    {
        private class ChildInfo
        {
            public Pomodoro.SizeStackPage page;
            public weak Gtk.Widget?       last_focus = null;
            public int                    last_width = -1;
            public int                    last_height = -1;
            public ulong                  notify_visible_id = 0;
            public ulong                  unmap_id = 0;

            public ChildInfo (Pomodoro.SizeStackPage page)
            {
                this.page = page;
            }
        }


        public unowned Gtk.Widget? visible_child {
            get {
                return this._visible_child != null
                    ? this._visible_child.page.child
                    : null;
            }
            set {
                var child_info = this.find_child_info_for_widget (value);

                if (child_info == null) {
                    GLib.warning ("Given child of type '%s' not found in PomodoroSizeStack", value.get_type ().name ());
                    return;
                }

                if (child_info.page.child.visible) {
                    this.set_visible_child_internal (child_info, this.transition_duration);
                }
            }
        }

        public string visible_child_name {
            get {
                return this._visible_child != null
                    ? this._visible_child.page.name
                    : null;
            }
            set {
                var child_info = this.find_child_info_for_name (value);

                if (child_info == null) {
                    GLib.warning ("Child with name '%s' not found in PomodoroSizeStack", value);
                    return;
                }

                if (child_info.page.child.visible) {
                    this.set_visible_child_internal (child_info, this.transition_duration);
                }
            }
        }

        // In GTK4 window is unwilling to shrink its size, needs extra nudge.
        public bool interpolate_window_size { get; set; default = false; }

        // The animation duration, in milliseconds.
        public uint transition_duration { get; set; default = 500; }

        private GLib.List<ChildInfo> children;
        private Adw.Animation?       transition_animation;
        private unowned ChildInfo?   _visible_child;
        private unowned ChildInfo?   last_visible_child;


        private unowned ChildInfo? find_child_info_for_widget (Gtk.Widget child)
        {
            unowned GLib.List<ChildInfo> link;
            unowned ChildInfo            child_info;

            for (link = this.children; link != null; link = link.next)
            {
                child_info = link.data;

                if (child_info.page.child == child) {
                    return child_info;
                }
            }

            return null;
        }

        private unowned ChildInfo? find_child_info_for_name (string name)
        {
            unowned GLib.List<ChildInfo> link;
            unowned ChildInfo            child_info;

            for (link = this.children; link != null; link = link.next)
            {
                child_info = link.data;

                if (child_info.page.name == name) {
                    return child_info;
                }
            }

            return null;
        }

        private double get_transition_progress ()
        {
            if (this.transition_animation != null) {
                return this.transition_animation.value;
            }

            if (this._visible_child != null && this.last_visible_child == null) {
                return 1.0;
            }

            return 0.0;
        }

        private void update_window_resizable ()
        {
            var window = this.get_root () as Gtk.Window;

            if (window == null) {
                return;
            }

            if (this.interpolate_window_size &&
                this.transition_animation == null &&
                this._visible_child != null)
            {
                window.resizable = this._visible_child.page.resizable;
            }
        }

        /**
         * In GTK4, Window insists on preserving its remembered size. We need to invalidate it.
         * See `gtk_window_compute_default_size`.
         */
        private void update_window_default_size ()
                                                 requires (this.interpolate_window_size)
        {
            var window = this.get_root () as Gtk.Window;

            if (window != null) {
                window.set_default_size (-1, -1);
            }
        }

        private void on_transition_animation_done ()
        {
            var window = this.get_root () as Gtk.Window;

            if (this.last_visible_child != null) {
                this.last_visible_child.page.child.set_child_visible (false);
                this.last_visible_child = null;
            }

            if (this.interpolate_window_size && window != null)
            {
                window.halign = Gtk.Align.FILL;
                window.valign = Gtk.Align.FILL;

                // HACK: Workaround not being able to resize window after the transition.
                this.add_tick_callback (() => {
                    window.resizable = !this._visible_child.page.resizable;
                    window.resizable = this._visible_child.page.resizable;

                    return GLib.Source.REMOVE;
                });
            }
        }

        /**
         * Call it after setting `visible_child` and `last_visible_child`.
         */
        private void start_transition (uint transition_duration)
        {
            var window = this.get_root () as Gtk.Window;

            if (this.transition_animation != null) {
                this.transition_animation.pause ();
                this.transition_animation = null;
            }

            if (this.interpolate_window_size && window != null) {
                window.halign = Gtk.Align.START;
                window.valign = Gtk.Align.START;
                window.set_size_request (-1, -1);
            }

            if (this._visible_child == null || this.last_visible_child == null || transition_duration == 0) {
                this.on_transition_animation_done ();
                return;
            }

            if (this._visible_child.page.resizable) {
                window.resizable = true;
            }

            var animation_target = new Adw.CallbackAnimationTarget ((value) => {
                if (this.interpolate_window_size) {
                    this.update_window_default_size ();
                }

                this.queue_resize ();
            });

            var animation = new Adw.TimedAnimation (this, 0.0, 1.0, transition_duration, animation_target);
            animation.easing = Adw.Easing.EASE_IN_OUT_CUBIC;
            animation.done.connect (() => {
                if (this.transition_animation == animation)
                {
                    this.transition_animation.pause ();
                    this.transition_animation = null;

                    this.on_transition_animation_done ();
                }
            });
            animation.play ();

            this.transition_animation = animation;
        }

        private void set_visible_child_internal (ChildInfo? child_info,
                                                 uint       transition_duration)
        {
            unowned GLib.List<ChildInfo> link;
            var contains_focus = false;

            // If we are being destroyed, do not bother with transitions
            // and notifications.
            if (this.in_destruction ()) {
                return;
            }

            if (child_info == null)
            {
                for (link = this.children; link != null; link = link.next)
                {
                    if (link.data.page.child.visible) {
                        child_info = link.data;
                    }
                }
            }

            if (child_info == this._visible_child) {
                return;
            }

            // Store focus for the current child.
            if (this.root != null &&
                this._visible_child != null &&
                this._visible_child.page.child != null)
            {
                var focus = this.root.get_focus ();

                if (focus != null && focus.is_ancestor (this._visible_child.page.child))
                {
                    contains_focus = true;

                    this._visible_child.last_focus = focus;
                }
                else {
                    this._visible_child.last_focus = null;
                }
            }

            if (this.last_visible_child != null) {
                this.last_visible_child.page.child.set_child_visible (false);
                this.last_visible_child = null;
            }

            if (this._visible_child != null) {
                this._visible_child.last_width = this._visible_child.page.child.get_width ();
                this._visible_child.last_height = this._visible_child.page.child.get_height ();
                this.last_visible_child = this._visible_child;
            }

            if (child_info.last_width <= 0 || child_info.last_height <= 0 || !child_info.page.resizable)
            {
                var minimum_size = Gtk.Requisition ();
                var natural_size = Gtk.Requisition ();

                // TODO: try retrieving from settings
                child_info.page.child.get_preferred_size (out minimum_size, out natural_size);

                child_info.last_width = natural_size.width;
                child_info.last_height = natural_size.height;
            }

            this._visible_child = child_info;

            if (child_info != null &&
                child_info.page.child != null)
            {
                child_info.page.child.set_child_visible (true);

                if (contains_focus)
                {
                    if (child_info.last_focus != null) {
                        // FIXME? Restoring focus to Gtk.ModelButton doesnt seem to work
                        // child_info.last_focus.grab_focus ();
                        child_info.page.child.child_focus (Gtk.DirectionType.TAB_FORWARD);
                    }
                    else {
                        child_info.page.child.child_focus (Gtk.DirectionType.TAB_FORWARD);
                    }
                }
            }

            this.start_transition (transition_duration);

            if (this.interpolate_window_size) {
                this.update_window_resizable ();
                this.update_window_default_size ();
            }

            this.queue_resize ();

            this.notify_property ("visible-child");
            this.notify_property ("visible-child-name");
        }

        private void on_child_notify_visible (GLib.Object    object,
                                              GLib.ParamSpec pspec)
        {
            var child_info = this.find_child_info_for_widget ((Gtk.Widget) object);
            var visible    = child_info.page.child.visible;

            if (this._visible_child == null && visible) {
                this.set_visible_child_internal (child_info, this.transition_duration);
            }
            else if (this._visible_child == child_info && !visible) {
                this.set_visible_child_internal (null, this.transition_duration);
            }

            if (this.last_visible_child == child_info)
            {
                this.last_visible_child.page.child.set_child_visible (false);
                this.last_visible_child = null;
            }

            this.start_transition (0);
        }

        private void on_child_unmap (Gtk.Widget widget)
        {
            if (this.transition_animation != null) {
                this.transition_animation.skip ();
                this.transition_animation = null;
            }
        }

        private void add_child_internal (ChildInfo child_info)
        {
            var child = child_info.page.child;

            this.children.append (child_info);

            child.set_child_visible (false);
            child.set_parent (this);

            child_info.notify_visible_id = child.notify["visible"].connect (this.on_child_notify_visible);
            child_info.unmap_id = child.unmap.connect (this.on_child_unmap);

            if (this._visible_child == null && child.visible) {
                this.set_visible_child_internal (child_info, this.transition_duration);
            }

            if (this._visible_child == child_info) {
                this.queue_resize ();
            }
        }

        private void remove_child_internal (ChildInfo child_info,
                                            bool      in_dispose)
        {
            var child       = child_info.page.child;
            var was_visible = false;

            child.disconnect (child_info.notify_visible_id);
            child.disconnect (child_info.unmap_id);
            child.unparent ();

            if (this._visible_child == child_info) {
                this._visible_child = null;
                was_visible = child.visible;
            }

            if (this.last_visible_child == child_info) {
                this.last_visible_child = null;
            }

            this.children.remove (child_info);

            if (!in_dispose && was_visible)
            {
                this.queue_resize ();
            }
        }

        private void add_page (Pomodoro.SizeStackPage page)
        {
            var child_info = new ChildInfo (page);

            this.add_child_internal (child_info);
        }

        public new void add_child (Gtk.Builder builder,
                                   GLib.Object object,
                                   string?     type)
        {
            if (object is Pomodoro.SizeStackPage) {
                this.add_page ((Pomodoro.SizeStackPage) object);
            }
            else if (object is Gtk.Widget) {
                this.add_page (new Pomodoro.SizeStackPage ((Gtk.Widget) object));
            }
            else {
                base.add_child (builder, object, type);
            }
        }

        public override void realize ()
        {
            base.realize ();

            this.update_window_resizable ();
        }

        public override void compute_expand_internal (out bool hexpand,
                                                      out bool vexpand)
        {
            unowned GLib.List<ChildInfo> link;

            hexpand = false;
            vexpand = false;

            for (link = this.children; link != null; link = link.next)
            {
                if (link.data.page != null)
                {
                    hexpand |= link.data.page.child.hexpand_set && link.data.page.child.hexpand;
                    vexpand |= link.data.page.child.vexpand_set && link.data.page.child.vexpand;
                }
            }
        }

        public override void css_changed (Gtk.CssStyleChange change)
        {
            // TODO: invalidate last size

            base.css_changed (change);
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
            var visible_child        = this._visible_child;
            var visible_child_widget = visible_child != null ? visible_child.page.child : null;
            var last_visible_child   = this.last_visible_child;
            var transition_progress  = this.get_transition_progress ();

            var window = this.get_root () as Gtk.Window;
            var interpolating_window_size = this.interpolate_window_size &&
                                            window != null &&
                                            window.default_width < 0 &&
                                            window.default_height < 0;

            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;

            if (visible_child != null)
            {
                var size = orientation == Gtk.Orientation.HORIZONTAL
                    ? visible_child.last_width
                    : visible_child.last_height;
                var minimum_for_size = 0;

                if (size >= 0 && (this.transition_animation != null || interpolating_window_size))
                {
                    minimum = size;
                    natural = size;
                }
                else {
                    visible_child_widget.measure (get_opposite_orientation (orientation),
                                                  -1,
                                                  out minimum_for_size,
                                                  null,
                                                  null,
                                                  null);
                    visible_child_widget.measure (orientation,
                                                  int.max (minimum_for_size, for_size),
                                                  out minimum,
                                                  out natural,
                                                  null,
                                                  null);
                }
            }

            if (last_visible_child != null)
            {
                var last_size = orientation == Gtk.Orientation.HORIZONTAL
                    ? last_visible_child.last_width
                    : last_visible_child.last_height;

                minimum = (int) GLib.Math.round (
                    Adw.lerp ((double) last_size, (double) minimum, transition_progress));

                natural = (int) GLib.Math.round (
                    Adw.lerp ((double) last_size, (double) natural, transition_progress));
            }

            if (natural < minimum) {
                natural = minimum;
            }
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            var visible_child             = this._visible_child;
            var visible_child_widget      = visible_child != null ? visible_child.page.child : null;
            var last_visible_child        = this.last_visible_child;
            var last_visible_child_widget = last_visible_child != null ? last_visible_child.page.child : null;

            if (last_visible_child != null &&
                last_visible_child_widget != null &&
                last_visible_child_widget.visible)
            {
                var last_visible_child_allocation = Gtk.Allocation () {
                    x = 0,
                    y = 0,
                    width = int.max (last_visible_child.last_width, width),
                    height = int.max (last_visible_child.last_height, height)
                };
                last_visible_child_widget.allocate_size (last_visible_child_allocation, baseline);
            }

            if (visible_child != null &&
                visible_child_widget != null &&
                visible_child_widget.visible)
            {
                var visible_child_allocation = Gtk.Allocation () {
                    x = 0,
                    y = 0,
                    width = width,
                    height = height
                };

                if (this.transition_animation != null) {
                    visible_child_allocation.width = int.max (visible_child.last_width, width);
                    visible_child_allocation.height = int.max (visible_child.last_height, height);
                }

                visible_child_widget.allocate_size (visible_child_allocation, baseline);
            }
        }

        private void snapshot_crossfade (Gtk.Snapshot snapshot)
        {
            var visible_child             = this._visible_child;
            var visible_child_widget      = visible_child != null ? visible_child.page.child : null;
            var last_visible_child        = this.last_visible_child;
            var last_visible_child_widget = last_visible_child != null ? last_visible_child.page.child : null;
            var transition_progress       = this.get_transition_progress ();
            var opacity                   = Math.pow (transition_progress, 1.5);

            snapshot.save ();

            if (last_visible_child != null &&
                last_visible_child_widget != null &&
                last_visible_child_widget.visible)
            {
                snapshot.push_opacity (1.0 - opacity);
                this.snapshot_child (last_visible_child_widget, snapshot);
                snapshot.pop ();
            }

            if (visible_child != null &&
                visible_child_widget != null &&
                visible_child_widget.visible)
            {
                snapshot.push_opacity (opacity);
                this.snapshot_child (visible_child_widget, snapshot);
                snapshot.pop ();
            }

            snapshot.restore ();
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            var visible_child             = this._visible_child;
            var visible_child_widget      = visible_child != null ? visible_child.page.child : null;
            var last_visible_child        = this.last_visible_child;
            var last_visible_child_widget = last_visible_child != null ? last_visible_child.page.child : null;
            var bounds                    = Graphene.Rect ();

            bounds.init (0, 0, this.get_width (), this.get_height ());

            if (last_visible_child_widget != null &&
                last_visible_child_widget.visible)
            {
                snapshot.push_clip (bounds);
                this.snapshot_crossfade (snapshot);
                snapshot.pop ();
                return;
            }

            if (visible_child_widget != null &&
                visible_child_widget.visible)
            {
                snapshot.push_clip (bounds);
                this.snapshot_child (visible_child_widget, snapshot);
                snapshot.pop ();
            }
        }

        public override void dispose ()
        {
            unowned Gtk.Widget? child;

            while ((child = this.get_first_child ()) != null)
            {
                var child_info = this.find_child_info_for_widget (child);

                if (child_info != null) {
                    this.remove_child_internal (child_info, true);
                }
            }

            base.dispose ();
        }
    }
}
