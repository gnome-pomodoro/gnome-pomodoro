/*
 * Copyright (c) 2022-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Ft
{
    public delegate void GizmoMeasureFunc (Ft.Gizmo        gizmo,
                                           Gtk.Orientation orientation,
                                           int             for_size,
                                           out int         minimum,
                                           out int         natural,
                                           out int         minimum_baseline,
                                           out int         natural_baseline);

    public delegate void GizmoAllocateFunc (Ft.Gizmo gizmo, int width, int height, int baseline);

    public delegate void GizmoSnapshotFunc (Ft.Gizmo gizmo, Gtk.Snapshot snapshot);

    public delegate bool GizmoContainsFunc (Ft.Gizmo gizmo, double x, double y);

    public delegate bool GizmoFocusFunc (Ft.Gizmo gizmo, Gtk.DirectionType direction);

    public delegate bool GizmoGrabFocusFunc (Ft.Gizmo gizmo);


    /**
     * A widget that is controlled by its parent.
     *
     * It's a carbon copy from Gtk+ code. File gtk/gtk/gtkgizmo.c
     */
    public sealed class Gizmo : Gtk.Widget
    {
        private Ft.GizmoMeasureFunc?   measure_func;
        private Ft.GizmoAllocateFunc?  allocate_func;
        private Ft.GizmoSnapshotFunc?  snapshot_func;
        private Ft.GizmoContainsFunc?  contains_func;
        private Ft.GizmoFocusFunc?     focus_func;
        private Ft.GizmoGrabFocusFunc? grab_focus_func;

        public Gizmo (owned Ft.GizmoMeasureFunc?   measure_func,
                      owned Ft.GizmoAllocateFunc?  allocate_func,
                      owned Ft.GizmoSnapshotFunc?  snapshot_func,
                      owned Ft.GizmoContainsFunc?  contains_func,
                      owned Ft.GizmoFocusFunc?     focus_func,
                      owned Ft.GizmoGrabFocusFunc? grab_focus_func)
        {
            this.measure_func    = (owned) measure_func;
            this.allocate_func   = (owned) allocate_func;
            this.snapshot_func   = (owned) snapshot_func;
            this.contains_func   = (owned) contains_func;
            this.focus_func      = (owned) focus_func;
            this.grab_focus_func = (owned) grab_focus_func;
        }

        public Gizmo.with_role (Gtk.AccessibleRole                 role,
                                owned Ft.GizmoMeasureFunc?   measure_func,
                                owned Ft.GizmoAllocateFunc?  allocate_func,
                                owned Ft.GizmoSnapshotFunc?  snapshot_func,
                                owned Ft.GizmoContainsFunc?  contains_func,
                                owned Ft.GizmoFocusFunc?     focus_func,
                                owned Ft.GizmoGrabFocusFunc? grab_focus_func)
        {
            GLib.Object (
                accessible_role: role
            );

            this.measure_func    = (owned) measure_func;
            this.allocate_func   = (owned) allocate_func;
            this.snapshot_func   = (owned) snapshot_func;
            this.contains_func   = (owned) contains_func;
            this.focus_func      = (owned) focus_func;
            this.grab_focus_func = (owned) grab_focus_func;
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
            if (this.measure_func != null) {
                this.measure_func (this,
                                   orientation,
                                   for_size,
                                   out minimum,
                                   out natural,
                                   out minimum_baseline,
                                   out natural_baseline);
            }
            else {
                minimum = 0;
                natural = for_size;
                minimum_baseline = -1;
                natural_baseline = -1;
            }
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            if (this.allocate_func != null) {
                this.allocate_func (this, width, height, baseline);
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            if (this.snapshot_func != null) {
                this.snapshot_func (this, snapshot);
            }
            else {
                base.snapshot (snapshot);
            }
        }

        public override bool contains (double x,
                                       double y)
        {
            if (this.contains_func != null) {
                return this.contains_func (this, x, y);
            }

            return base.contains (x, y);
        }

        public override bool focus (Gtk.DirectionType direction)
        {
            if (this.focus_func != null) {
                return this.focus_func (this, direction);
            }

            return false;
        }

        public override bool grab_focus ()
        {
            if (this.grab_focus_func != null) {
                return this.grab_focus_func (this);
            }

            return false;
        }

        public override void dispose ()
        {
            this.measure_func    = null;
            this.allocate_func   = null;
            this.snapshot_func   = null;
            this.contains_func   = null;
            this.focus_func      = null;
            this.grab_focus_func = null;

            base.dispose ();
        }
    }
}
