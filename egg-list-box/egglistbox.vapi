namespace Egg {
	[CCode (cheader_filename = "egg-list-box.h")]
	public class ListBox : Gtk.Container {
		public delegate bool FilterFunc (Gtk.Widget child);
		public delegate void UpdateSeparatorFunc (ref Gtk.Widget? separator, Gtk.Widget child, Gtk.Widget? before);
		[CCode (has_construct_function = false)]
		public ListBox ();
		public override void add (Gtk.Widget widget);
		public void add_to_scrolled (Gtk.ScrolledWindow scrolled);
		public override bool button_press_event (Gdk.EventButton event);
		public override bool button_release_event (Gdk.EventButton event);
		public void child_changed (Gtk.Widget widget);
		public override GLib.Type child_type ();
		public override void compute_expand_internal (out bool hexpand, out bool vexpand);
		public void drag_highlight_widget (Gtk.Widget widget);
		public override void drag_leave (Gdk.DragContext context, uint time_);
		public override bool drag_motion (Gdk.DragContext context, int x, int y, uint time_);
		public void drag_unhighlight_widget ();
		public override bool draw (Cairo.Context cr);
		public override bool enter_notify_event (Gdk.EventCrossing event);
		public override bool focus (Gtk.DirectionType direction);
		public override void forall_internal (bool include_internals, Gtk.Callback callback);
		public unowned Gtk.Widget? get_child_at_y (int y);
		public override void get_preferred_height (out int minimum_height, out int natural_height);
		public override void get_preferred_height_for_width (int width, out int minimum_height, out int natural_height);
		public override void get_preferred_width (out int minimum_width, out int natural_width);
		public override void get_preferred_width_for_height (int height, out int minimum_width, out int natural_width);
		public override Gtk.SizeRequestMode get_request_mode ();
		public unowned Gtk.Widget? get_selected_child ();
		public override bool leave_notify_event (Gdk.EventCrossing event);
		public override bool motion_notify_event (Gdk.EventMotion event);
		public override void realize ();
		public void refilter ();
		public override void remove (Gtk.Widget widget);
		public void reseparate ();
		public void resort ();
		public void select_child (Gtk.Widget? child);
		public void set_activate_on_single_click (bool single);
		public void set_adjustment (Gtk.Adjustment? adjustment);
		public void set_filter_func (owned Egg.ListBox.FilterFunc? f);
		public void set_selection_mode (Gtk.SelectionMode mode);
		public void set_separator_funcs (owned Egg.ListBox.UpdateSeparatorFunc? update_separator);
		public void set_sort_func (owned GLib.CompareDataFunc<Gtk.Widget>? f);
		public override void show ();
		public override void size_allocate (Gtk.Allocation allocation);
		[Signal (action = true)]
		public virtual signal void activate_cursor_child ();
		public virtual signal void child_activated (Gtk.Widget? child);
		public virtual signal void child_selected (Gtk.Widget? child);
		[Signal (action = true)]
		public virtual signal void move_cursor (Gtk.MovementStep step, int count);
		[Signal (action = true)]
		public virtual signal void toggle_cursor_child ();
	}
}
