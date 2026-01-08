/*
 * Copyright (c) 2022-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Pomodoro
{
    public class SizeStackPage : GLib.Object
    {
        public Gtk.Widget child { get; construct; }
        public string     name { get; set; }
        public bool       resizable { get; set; default = true; }

        internal unowned Gtk.Widget? last_focus = null;
        internal int                 last_width = -1;
        internal int                 last_height = -1;

        public SizeStackPage (Gtk.Widget child)
        {
            GLib.Object (
                child: child
            );
        }

        public override void dispose ()
        {
            this.last_focus = null;

            base.dispose ();
        }
    }


    /**
     * Container for transitioning between widgets of varying sizes.
     *
     * The purpose is to swap widgets of varying complexity or just different variants.
     * It's tailored for interpolating window size - origin of the transition is at top left corner.
     */
    public class SizeStack : Gtk.Widget, Gtk.Buildable
    {
        public unowned Gtk.Widget? visible_child {
            get {
                return this.current_page?.child;
            }
            set {
                unowned var page = this.find_page_by_child (value);

                if (page == null) {
                    GLib.warning ("Given child of type '%s' not found in PomodoroSizeStack",
                                  value.get_type ().name ());
                    return;
                }

                this.select_page (page, true);
            }
        }

        public string visible_child_name {
            get {
                return this.current_page != null
                        ? this.current_page.name
                        : "";
            }
            set {
                unowned var page = this.find_page_by_name (value);

                if (page == null) {
                    GLib.warning ("Page with name '%s' not found in PomodoroSizeStack", value);
                    return;
                }

                this.select_page (page, true);
            }
        }

        // The animation duration, in milliseconds.
        public uint transition_duration { get; set; default = 500; }

        private GLib.List<Pomodoro.SizeStackPage> pages = null;
        private Adw.TimedAnimation?               transition_animation = null;
        private unowned Pomodoro.SizeStackPage?   current_page = null;
        private unowned Pomodoro.SizeStackPage?   previous_page = null;
        private bool                              size_request_set = false;

        private unowned Pomodoro.SizeStackPage? find_page_by_child (Gtk.Widget child)
        {
            unowned var link = this.pages.first ();

            while (link != null)
            {
                if (link.data.child == child) {
                    return link.data;
                }

                link = link.next;
            }

            return null;
        }

        private unowned Pomodoro.SizeStackPage? find_page_by_name (string name)
        {
            unowned var link = this.pages.first ();

            while (link != null)
            {
                if (link.data.name == name) {
                    return link.data;
                }

                link = link.next;
            }

            return null;
        }

        private float get_transition_progress ()
        {
            return this.transition_animation != null
                    ? (float) this.transition_animation.value
                    : 1.0f;
        }

        private void stop_resizing_window ()
        {
            var window = this.get_root () as Gtk.Window;
            var resizable = this.current_page != null
                    ? this.current_page.resizable
                    : true;

            if (window == null) {
                return;
            }

            window.halign = Gtk.Align.FILL;
            window.valign = Gtk.Align.FILL;

            if (window.resizable != resizable)
            {
                window.resizable = resizable;

                /*
                // HACK: Workaround for not being able to resize window after the transition.
                // When changing `resizable`, GTK calls gdk_toplevel_present() which can cause
                // the compositor to restore a previously remembered window size.
                // Keep size request set for a short time to prevent GTK from changing size
                var width = window.get_width ();
                var height = window.get_height ();
                window.set_size_request (width, height);

                window.resizable = resizable;

                var timeout_id = GLib.Timeout.add (100, () => {
                    window.set_size_request (-1, -1);

                    return GLib.Source.REMOVE;
                });
                GLib.Source.set_name_by_id (timeout_id,
                                            "Pomodoro.SizeStack.on_transition_animation_done");
                */
            }
            else {
                // HACK: There's a glitch with recent GTK+ / Mutter on Wayland, that window size
                // shrinks to minimum size when initiating a resize. The workaround enforces a
                // minimum size which we lift once user starts resizing the window. It's not great,
                // because the user can't shrink window down at first.
                var width = window.get_width ();
                var height = window.get_height ();
                window.set_size_request (width, height);

                this.add_tick_callback (
                    () => {
                        this.size_request_set = true;

                        return GLib.Source.REMOVE;
                    });
            }
        }

        private void start_resizing_window ()
        {
            var window = this.get_root () as Gtk.Window;

            if (window == null) {
                return;
            }

            window.halign = Gtk.Align.START;
            window.valign = Gtk.Align.START;
            window.set_size_request (-1, -1);
            window.resizable = true;
        }

        /**
         * In GTK4, Window insists on preserving its remembered size. We need to invalidate it.
         * See `gtk_window_compute_default_size`.
         */
        private inline void invalidate_window_default_size ()
        {
            var window = this.get_root () as Gtk.Window;

            window?.set_default_size (-1, -1);
        }

        /**
         * Call it after setting `visible_child` and `last_visible_child`.
         */
        private void start_transition (uint transition_duration)
                                       requires (this.current_page != null && this.previous_page != null)
        {
            if (this.transition_animation != null) {
                this.transition_animation.pause ();
                this.transition_animation = null;
            }

            this.start_resizing_window ();

            var animation_target = new Adw.CallbackAnimationTarget (
                (value) => {
                    this.queue_resize ();

                    this.invalidate_window_default_size ();
                });

            var animation = new Adw.TimedAnimation (this,
                                                    0.0,
                                                    1.0,
                                                    transition_duration,
                                                    animation_target);
            animation.easing = Adw.Easing.EASE_IN_OUT_CUBIC;
            animation.done.connect (
                () => {
                    this.transition_animation = null;

                    if (this.previous_page != null) {
                        this.previous_page.child.set_child_visible (false);
                        this.previous_page = null;
                    }

                    this.stop_resizing_window ();

                    this.queue_resize ();
                });

            this.transition_animation = animation;
            this.transition_animation.play ();
        }

        private void select_page (Pomodoro.SizeStackPage page,
                                  bool                   transition = true)
        {
            if (page == this.current_page || this.in_destruction ()) {
                return;
            }

            // Store last focus/size for the current_page
            var contains_focus = false;
            var current_child = this.current_page?.child;

            if (current_child != null && this.transition_animation == null)
            {
                var focus = this.root?.get_focus ();
                var minimum_size = Gtk.Requisition ();
                var natural_size = Gtk.Requisition ();
                var last_width = -1;
                var last_height = -1;
                unowned Gtk.Widget? last_focus = null;

                if (focus != null && focus.is_ancestor (current_child)) {
                    contains_focus = true;
                    last_focus = focus;
                }
                else {
                    last_focus = null;
                }

                last_width  = current_child.get_width ();
                last_height = current_child.get_height ();

                if (last_width <= 0 ||
                    last_height <= 0)
                {
                    current_child.get_preferred_size (out minimum_size, out natural_size);

                    last_width  = natural_size.width;
                    last_height = natural_size.height;
                }

                this.current_page.last_focus  = last_focus;
                this.current_page.last_width  = last_width;
                this.current_page.last_height = last_height;
            }

            // Select page
            if (this.previous_page != null && this.previous_page != page) {
                this.previous_page.child.set_child_visible (false);
                this.previous_page = null;
            }

            this.previous_page = this.current_page;
            this.current_page = page;

            page.child.set_child_visible (true);

            if (contains_focus)
            {
                if (page.last_focus != null) {
                    page.last_focus.grab_focus ();
                }
                else {
                    page.child.child_focus (Gtk.DirectionType.TAB_FORWARD);
                }
            }

            if (this.current_page != null &&
                this.previous_page != null)
            {
                this.start_transition (transition ? this.transition_duration : 0);
            }
            else {
                this.queue_resize ();
            }

            this.notify_property ("visible-child");
            this.notify_property ("visible-child-name");
        }

        private void remove_page (Pomodoro.SizeStackPage page)
        {
            if (this.pages.index (page) < 0) {
                return;
            }

            page.child.unparent ();

            if (this.current_page == page) {
                this.current_page = null;
            }

            if (this.previous_page == page) {
                this.previous_page = null;
            }

            this.pages.remove (page);
        }

        private void add_page (Pomodoro.SizeStackPage page)
        {
            if (this.pages.index (page) >= 0) {
                return;
            }

            var child = page.child;
            child.set_child_visible (false);
            child.set_parent (this);

            this.pages.append (page);

            if (this.current_page == null) {
                this.select_page (page, false);
            }
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

            this.invalidate_window_default_size ();
        }

        public override void compute_expand_internal (out bool hexpand,
                                                      out bool vexpand)
        {
            unowned var child = this.get_first_child ();

            hexpand = false;
            vexpand = false;

            while (child != null)
            {
                hexpand |= child.hexpand_set && child.hexpand;
                vexpand |= child.vexpand_set && child.vexpand;

                child = child.get_next_sibling ();
            }
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
            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;

            if (this.current_page == null) {
                return;
            }

            var last_size = orientation == Gtk.Orientation.HORIZONTAL
                    ? this.current_page.last_width
                    : this.current_page.last_height;
            var minimum_for_size = 0;

            if (last_size <= 0 || this.transition_animation == null)
            {
                current_page.child.measure (get_opposite_orientation (orientation),
                                            -1,
                                            out minimum_for_size,
                                            null,
                                            null,
                                            null);
                current_page.child.measure (orientation,
                                            minimum_for_size,
                                            out minimum,
                                            out natural,
                                            null,
                                            null);
            }
            else {
                minimum = 0;
                natural = last_size;
            }

            if (this.previous_page != null)
            {
                var previous_size = orientation == Gtk.Orientation.HORIZONTAL
                        ? this.previous_page.last_width
                        : this.previous_page.last_height;
                var t = this.get_transition_progress ();

                natural = (int) GLib.Math.roundf (
                        Pomodoro.lerpf ((float) previous_size, (float) natural, t));
            }

            if (natural < minimum) {
                natural = minimum;
            }
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            unowned var current_child  = this.current_page?.child;
            unowned var previous_child = this.previous_page?.child;

            if (this.size_request_set)
            {
                this.size_request_set = false;

                // Lift minimum window size constraint at first opportunity.
                var window = this.get_root () as Gtk.Window;
                window?.set_size_request (-1, -1);
            }

            if (previous_child != null)
            {
                var previous_child_allocation = Gtk.Allocation () {
                    x      = 0,
                    y      = 0,
                    width  = int.max (this.previous_page.last_width, width),
                    height = int.max (this.previous_page.last_height, height)
                };

                // Do not transition width if there's a big discrepancy
                if (this.current_page.last_width > 2 * this.previous_page.last_width) {
                    previous_child_allocation.width = this.previous_page.last_width;
                }

                previous_child.allocate_size (previous_child_allocation, baseline);
            }

            if (current_child != null)
            {
                var current_child_allocation = Gtk.Allocation () {
                    x      = 0,
                    y      = 0,
                    width  = width,
                    height = height
                };

                if (this.transition_animation != null) {
                    current_child_allocation.width = int.max (this.current_page.last_width, width);
                    current_child_allocation.height = int.max (this.current_page.last_height, height);
                }
                else {
                    this.current_page.last_width = width;
                    this.current_page.last_height = height;
                }

                current_child.allocate_size (current_child_allocation, baseline);
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            unowned var current_child = this.current_page?.child;
            unowned var previous_child = this.previous_page?.child;

            if (current_child == null || !current_child.visible) {
                return;
            }

            if (this.transition_animation != null &&
                previous_child != null &&
                previous_child.visible)
            {
                var progress = (double) Math.powf ((float) this.get_transition_progress (), 1.5f);

                snapshot.push_cross_fade (progress);
                this.snapshot_child (previous_child, snapshot);
                snapshot.pop ();

                this.snapshot_child (current_child, snapshot);
                snapshot.pop ();
            }
            else {
                this.snapshot_child (current_child, snapshot);
            }
        }

        public override void dispose ()
        {
            unowned var link = this.pages.first ();

            while (link != null)
            {
                this.remove_page (link.data);

                link = this.pages.first ();
            }

            this.pages = null;
            this.transition_animation = null;
            this.current_page = null;
            this.previous_page = null;

            base.dispose ();
        }
    }
}
