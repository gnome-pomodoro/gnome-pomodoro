/*
 * Copyright (c) 2014 gnome-pomodoro contributors
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


public enum Pomodoro.TaskStatus
{
    DEFAULT = 0,
    DONE = 1,
    DISMISSED = 2,
    BLOCKED = 3
}


public enum Pomodoro.Urgency
{
    LOW = 0,
    NORMAL = 1,
    HIGH = 2,
    VERY_HIGH = 3
}


public enum Pomodoro.Importance
{
    LOW = 0,
    NORMAL = 1,
    HIGH = 2,
    VERY_HIGH = 3
}


public class Pomodoro.Project : Object
{
    public string name { get; set; }
}


public class Pomodoro.Task : Object
{
    public string summary { get; set; }
    public string description { get; set; }

//    public uint16 status { get; set; }
    public Importance importance { get; set; default = Importance.NORMAL; }
    public Urgency urgency { get; set; default = Urgency.NORMAL; }

    public uint64 time_spent { get; set; }

    public bool is_done { get; set; }

    public Task? parent { get; set; }
    public Project? project { get; set; }

//    public List<GLib.File> attachments;

//    public uint64 start_date { get; set; }
//    public uint64 end_date { get; set; }

//    public List<Task> get_children () {
//    }

//    public List<Task> get_tasks_blocked () {  // get_preceding_tasks ()
//    }

//    public List<Task> get_tasks_blocking () {  // get_following_tasks ()
//    }

}


// TODO: File/URL attachments
private class Pomodoro.AddTaskDialog : Gtk.Dialog
{
    public Project? project;
    public Task task;

    private Gtk.Grid grid;
    private int grid_rows = 0;

    private enum Column {
        LABEL = 0,
        CONTENT = 1
    }

    construct {
        this.task = new Task ();

        this.destroy_with_parent = true;
        this.modal = true;
        this.use_header_bar = 1;

        this.title = _("New Task");

        var cancel_button = new Gtk.Button.with_mnemonic (_("_Cancel"));

        var done_button = new Gtk.Button.with_mnemonic (_("_Done"));
        done_button.get_style_context ().add_class ("suggested-action");

        cancel_button.clicked.connect (() => {
            this.response (Gtk.ResponseType.CANCEL);
        });

        done_button.clicked.connect (() => {
            this.response (Gtk.ResponseType.OK);
        });

        this.response.connect ((response) => {
            this.destroy ();
        });

        var header_bar = new Gtk.HeaderBar ();
        header_bar.show_close_button = false;
        header_bar.title = this.title;
        header_bar.pack_start (cancel_button);
        header_bar.pack_end (done_button);
        header_bar.show_all ();
        this.set_titlebar (header_bar);

        var entry = new Gtk.Entry ();
        entry.halign = Gtk.Align.FILL;
        entry.hexpand = true;
        entry.width_chars = 30;
        entry.truncate_multiline = true;
        entry.input_purpose = Gtk.InputPurpose.ALPHA;
        entry.input_hints = Gtk.InputHints.SPELLCHECK |
                            Gtk.InputHints.UPPERCASE_SENTENCES |
                            Gtk.InputHints.WORD_COMPLETION;
//        entry.has_default = true; // TODO

        var notes_text_view = new Gtk.TextView ();
        notes_text_view.border_width = 4;
        entry.input_purpose = Gtk.InputPurpose.FREE_FORM;
        entry.input_hints = Gtk.InputHints.SPELLCHECK |
                            Gtk.InputHints.UPPERCASE_SENTENCES;
        notes_text_view.wrap_mode = Gtk.WrapMode.WORD;


        var notes_window = new Gtk.ScrolledWindow (null, null);
        notes_window.halign = Gtk.Align.FILL;
        notes_window.valign = Gtk.Align.FILL;
        notes_window.hexpand = true;
        notes_window.vexpand = true;
        notes_window.shadow_type = Gtk.ShadowType.IN;
        notes_window.min_content_height = 200;
        notes_window.add (notes_text_view);

        var project_select = new Gtk.ComboBoxText();
        project_select.halign = Gtk.Align.START;
        project_select.no_show_all = true;
        project_select.append_text ("Household");
        project_select.append_text ("Pomodoro");

        var tag_flow_box = new Gtk.FlowBox ();
        tag_flow_box.halign = Gtk.Align.FILL;
        tag_flow_box.hexpand = false;
        tag_flow_box.selection_mode = Gtk.SelectionMode.NONE;
        tag_flow_box.column_spacing = 6;
        tag_flow_box.row_spacing = 6;
        tag_flow_box.homogeneous = false;

        tag_flow_box.add (new Gtk.ToggleButton.with_label (_("Urgent")));
        tag_flow_box.add (new Gtk.ToggleButton.with_label (_("Important")));

        foreach (var child in tag_flow_box.get_children ()) {
            child.hexpand = false;
        }

        var due_date_button = new CalendarButton ();
        due_date_button.halign = Gtk.Align.START;

        // var completed/done checkbox

        // var time_spent

        // var parent_task

        // var blocked_by

        // var blocks

        // mark_as_done_button, dismiss_button, delete_button

        this.grid = new Gtk.Grid ();
        this.grid.row_spacing = 10;
        this.grid.column_spacing = 10;
        this.grid.insert_column (Column.LABEL);
        this.grid.insert_column (Column.CONTENT);

        this.grid.set_margin_start (24);
        this.grid.set_margin_end (32);
        this.grid.set_margin_top (24);
        this.grid.set_margin_bottom (24);

        // this.add_field (_("Project"), project_select); // TODO: Pass parent_task/project when creating a dialog
        this.add_field (_("Summary"), entry);
        this.add_field (_("Tags"), tag_flow_box);
        this.add_field (_("Due Date"), due_date_button);
        this.add_field (_("Notes"), notes_window);

        this.grid.show_all ();

        var content_area = this.get_content_area ();
        content_area.pack_start (this.grid, true, true);
    }

    private void add_field (string title, Gtk.Widget widget)
    {
        var label = new Gtk.Label (title);
        label.halign = Gtk.Align.END;
        label.valign = Gtk.Align.CENTER;

        this.grid.attach (label, Column.LABEL, this.grid_rows, 1, 1);
        this.grid.attach (widget, Column.CONTENT, this.grid_rows, 1, 1);
        this.grid_rows += 1;
    }
}


private class Pomodoro.TaskListRow : Gtk.ListBoxRow
{
    public Gtk.Label label;
    public Task task;

    public TaskListRow (Task task)
    {
        this.height_request = 50;

        var row_context = this.get_style_context ();
        row_context.add_class ("task");

        this.task = task;

        this.label = new Gtk.Label (task.summary);
        this.label.set_ellipsize (Pango.EllipsizeMode.END);
        this.label.set_alignment (0.0f, 0.5f);
        this.label.wrap = true;
        this.label.wrap_mode = Pango.WrapMode.WORD;

        var label_context = this.label.get_style_context ();
        label_context.add_class ("summary");

        var check_button = new Gtk.CheckButton ();
        check_button.set_margin_left (15); /* TODO: Use css */
        check_button.set_margin_right (3); /* TODO: Use css */

        task.bind_property ("is-done",
                            check_button,
                            "active",
                            GLib.BindingFlags.BIDIRECTIONAL | GLib.BindingFlags.SYNC_CREATE);

        task.notify.connect(() => {
            this.on_task_changed ();
        });

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
        hbox.set_halign (Gtk.Align.START);
        hbox.pack_start (check_button, false, true);
        hbox.pack_start (label, true, false);

        hbox.show_all ();

        this.add (hbox);

        this.on_task_changed ();
    }

    private void on_task_changed ()
    {
        var attribs = new Pango.AttrList ();

        if (this.task.is_done) {
            var strikethrough = Pango.attr_strikethrough_new (true);
            attribs.insert ((owned) strikethrough);
        }

        label.set_attributes (attribs);
    }
}


private class Pomodoro.TaskListPane : Gtk.Box
{
    public Gtk.SearchBar search_bar;

    private Gtk.ListBox list_box;
    private unowned GLib.ActionGroup? action_group;

//    private GLib.List<Task> selection;

    /* TODO: Move to Utils? */
    private void list_box_separator_func (Gtk.ListBoxRow  row,
                                          Gtk.ListBoxRow? before)
    {
        if (before != null)
        {
            var current = row.get_header ();

            if (current == null)
            {
                current = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
                current.show ();
                row.set_header (current);
            }
        }
    }

    public TaskListPane () {
        this.orientation = Gtk.Orientation.VERTICAL;
        this.spacing = 0;
    }

    construct
    {
        this.setup_search_bar ();

        this.list_box = new Gtk.ListBox ();
        this.list_box.set_selection_mode (Gtk.SelectionMode.NONE);
        this.list_box.set_activate_on_single_click (true);
        this.list_box.set_header_func (this.list_box_separator_func);
        this.list_box.can_focus = false;
        this.list_box.show ();

        this.list_box.insert (this.create_row_for_task ("Save the world"), -1);
        this.list_box.insert (this.create_row_for_task ("Buy milk"), -1);
        this.list_box.insert (this.create_row_for_task ("Walk the dog"), -1);

        this.list_box.insert (this.create_row_for_task ("Save the world"), -1);
        this.list_box.insert (this.create_row_for_task ("Buy milk"), -1);
        this.list_box.insert (this.create_row_for_task ("Walk the dog"), -1);

        this.list_box.insert (this.create_row_for_task ("Save the world"), -1);
        this.list_box.insert (this.create_row_for_task ("Buy milk"), -1);
        this.list_box.insert (this.create_row_for_task ("Walk the dog"), -1);

        this.list_box.insert (this.create_row_for_task ("Save the world"), -1);
        this.list_box.insert (this.create_row_for_task ("Buy milk"), -1);
        this.list_box.insert (this.create_row_for_task ("Walk the dog"), -1);

        this.list_box.row_activated.connect (this.on_row_activated);

		this.list_box.selected_rows_changed.connect
		                               (this.on_selected_rows_changed);

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.set_policy (Gtk.PolicyType.NEVER,
                                    Gtk.PolicyType.AUTOMATIC);
        scrolled_window.add (this.list_box);
        scrolled_window.show ();

        this.pack_start (this.search_bar, false, true);
        this.pack_start (scrolled_window, true, true);

        this.setup_actions ();
    }

    public GLib.List<unowned Task> get_selection ()
    {
        var selection = new GLib.List<unowned Task> ();

		foreach (var row in this.list_box.get_selected_rows ()) {
		    selection.prepend ((row as TaskListRow).task);
		}

        return selection;
    }

    public void select_all ()
    {
        this.list_box.select_all ();
    }

    public void unselect_all ()
    {
        this.list_box.unselect_all ();
    }


    private void action_select_all (SimpleAction action,
                                    Variant?     parameter)
    {
        this.select_all ();
    }

    private void action_select_none (SimpleAction action,
                                     Variant?     parameter)
    {
        this.unselect_all ();
    }

    private void action_find (SimpleAction action,
                              Variant?     parameter)
    {
        var is_enabled = this.search_bar.search_mode_enabled;

        this.search_bar.search_mode_enabled = !is_enabled;
    }

    private void setup_search_bar ()
    {
        var entry = new Gtk.SearchEntry ();
        entry.set_placeholder_text (_("Type to search..."));
        entry.set_width_chars (30);
        entry.valign = Gtk.Align.FILL;
        entry.shadow_type = Gtk.ShadowType.NONE;

        // var prev_button = new Gtk.Button.from_icon_name ("go-up-symbolic",
        //                                                  Gtk.IconSize.MENU);
        // var next_button = new Gtk.Button.from_icon_name ("go-down-symbolic",
        //                                                  Gtk.IconSize.MENU);
        // var options_button = new Gtk.Button.from_icon_name ("go-down-symbolic",
        //                                                     Gtk.IconSize.MENU);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        // hbox.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        hbox.pack_start (entry, true, false);
        // hbox.pack_start (prev_button, false, false);
        // hbox.pack_start (next_button, false, false);
        // hbox.pack_start (options_button, false, false);

        var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.VERTICAL);
        size_group.add_widget (entry);
        // size_group.add_widget (prev_button);
        // size_group.add_widget (next_button);
        // size_group.add_widget (options_button);

        this.search_bar = new Gtk.SearchBar ();
        this.search_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
        this.search_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_TOOLBAR);
        this.search_bar.add (hbox);
        this.search_bar.connect_entry (entry);
        this.search_bar.show_all ();
    }

    private void setup_actions ()
    {
        this.realize.connect (() => {
            var window = this.get_toplevel ();

            return_if_fail (window != null);

            var action_group = window as ActionMap;
            // var action_group = new GLib.SimpleActionGroup ();

            var select_all_action = new GLib.SimpleAction ("select-all", null);
            select_all_action.activate.connect (this.action_select_all);

            var select_none_action = new GLib.SimpleAction ("select-none", null);
            select_none_action.activate.connect (this.action_select_none);

            var find_action = new GLib.SimpleAction ("find", null);
            find_action.activate.connect (this.action_find);

            action_group.add_action (select_all_action);
            action_group.add_action (select_none_action);
            action_group.add_action (find_action);

            this.action_group = action_group as GLib.ActionGroup;
        });
    }

    private void on_row_activated (Gtk.ListBoxRow row)
    {
        var tmp_row = row as TaskListRow;

        GLib.message ("\"%s\" activated", tmp_row.task.summary);

        if (this.list_box.selection_mode != Gtk.SelectionMode.MULTIPLE)
        {
            this.list_box.set_selection_mode (Gtk.SelectionMode.MULTIPLE);
            this.list_box.select_row (row);
        }
    }

    private void on_selected_rows_changed ()
    {
	    this.selection_changed ();
    }

    protected Gtk.ListBoxRow create_row_for_task (string text)
    {
        var task = new Task ();
        task.summary = text;

        var row = new TaskListRow (task);
        row.show ();

        return row;
    }

    public signal void selection_changed ();
}


public class Pomodoro.MainWindow : Gtk.ApplicationWindow
{
    private GLib.Settings settings;

    private Gtk.Box vbox;
    private Gtk.Stack header_bar_stack;
    private Gtk.Stack stack;

    private TaskListPane task_list_pane;


    public MainWindow ()
    {
        this.title = _("Tasks");

        var geometry = Gdk.Geometry ();
        geometry.min_width = 300;
        geometry.min_height = 300;

        var geometry_hints = Gdk.WindowHints.MIN_SIZE;

        this.set_geometry_hints (this,
                                 geometry,
                                 geometry_hints);

        this.set_default_size (450, 600);

        this.set_destroy_with_parent (false);

        this.set_type_hint (Gdk.WindowTypeHint.NORMAL);

        this.settings = Pomodoro.get_settings ().get_child ("preferences");

        this.setup ();
    }

    private void setup ()
    {
        var context = this.get_style_context ();
        context.add_class ("main-window");

        this.stack = new Gtk.Stack ();
        this.stack.homogeneous = true;
        this.stack.transition_duration = 150;
        this.stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        this.stack.show ();

        this.add (this.stack);

        this.setup_task_list ();
        this.setup_header_bar ();

        this.key_press_event.connect (this.on_key_press_event);
    }

    private Gtk.HeaderBar create_task_list_header_bar ()
    {
        var project_button = new Gtk.MenuButton ();
        project_button.relief = Gtk.ReliefStyle.NONE;
        project_button.valign = Gtk.Align.CENTER;
        // project_button.menu_model = project_menu;
        // project_button.get_style_context ().add_class ("project-menu");

        var project_button_label = new Gtk.Label (_("All Tasks"));
        project_button_label.get_style_context ().add_class ("title");

        var project_button_arrow = new Gtk.Arrow (Gtk.ArrowType.DOWN,
                                              Gtk.ShadowType.NONE);

        var project_button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        project_button_box.pack_start (project_button_label, true, false);
        project_button_box.pack_start (project_button_arrow, false, false);
        project_button.add (project_button_box);

        var new_task_button = new Gtk.Button.with_mnemonic (_("_New"));
        new_task_button.clicked.connect (() => {
            var dialog = new AddTaskDialog ();  // TODO: Set current project
            dialog.set_transient_for (this.get_toplevel () as Gtk.Window);
            dialog.present ();
        });

        var find_image = new Gtk.Image.from_icon_name ("edit-find-symbolic",
                                                       Gtk.IconSize.MENU);
        var find_button = new Gtk.ToggleButton ();
        find_button.set_image (find_image);
        find_button.bind_property ("active",
                                   this.task_list_pane.search_bar,
                                   "search-mode-enabled",
                                   GLib.BindingFlags.BIDIRECTIONAL);

        var header_bar = new Gtk.HeaderBar ();
        header_bar.show_close_button = true;
        header_bar.set_custom_title (project_button);
        header_bar.pack_start (new_task_button);
        header_bar.pack_end (find_button);

        //var bookmark_icon = GLib.Icon.new_for_string (
        //        "resource:///org/gnome/pomodoro/" + Resources.BOOKMARK + ".svg");
        //var urgency_status = new Gtk.Image.from_gicon (bookmark_icon,
        //                                               Gtk.IconSize.MENU);

        //var filter_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
        //filter_box.pack_start (urgency_status, false, false);

        //var filter_label = new Gtk.Label (_("Today"));
        //filter_box.pack_start (filter_label, true, false);

        //var filter_button = new Gtk.Button ();
        //filter_button.set_relief (Gtk.ReliefStyle.NONE);
        //filter_button.add (filter_box);

        //var urgency_filter_menu = new GLib.Menu ();
        //urgency_filter_menu.append (_("Urgent"), "action-name");
        //urgency_filter_menu.append (_("Important"), "action-name");

        //var time_filter_menu = new GLib.Menu ();
        //time_filter_menu.append (_("All"), "action-name");
        //time_filter_menu.append (_("Today"), "action-name");

        //var filter_menu = new GLib.Menu ();
        //filter_menu.append_section (null, urgency_filter_menu);
        //filter_menu.append_section (null, time_filter_menu );

        //var urgency_popover = new Gtk.Popover.from_model (filter_button,
        //                                                  filter_menu);
        //urgency_popover.set_modal (true);
        //urgency_popover.set_position (Gtk.PositionType.TOP);

        //filter_button.clicked.connect(() => {
        //    urgency_popover.show();
        //});

        //filter_button.show_all();
        //this.header_bar.pack_start (filter_button);

        header_bar.show_all ();
        return header_bar;
    }

    private Gtk.Label selection_menubutton_label;

    private Gtk.HeaderBar create_task_list_selection_header_bar ()
    {
        var header_bar = new Gtk.HeaderBar ();
        header_bar.show_close_button = false;
        header_bar.get_style_context ().add_class ("selection-mode");

        var menubutton = new Gtk.MenuButton ();
        menubutton.valign = Gtk.Align.CENTER;
        menubutton.get_style_context ().add_class ("selection-menu");

        try {
            var builder = new Gtk.Builder ();
            builder.add_from_resource ("/org/gnome/pomodoro/menu.ui");

            var selection_menu = builder.get_object ("selection-menu") as GLib.MenuModel;
            menubutton.menu_model = selection_menu;
        }
        catch (GLib.Error error) {
            GLib.warning (error.message);
        }

        var menubutton_label = new Gtk.Label (_("Click on items to select them"));

        var menubutton_arrow = new Gtk.Arrow (Gtk.ArrowType.DOWN,
                                              Gtk.ShadowType.NONE);
        var menubutton_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        menubutton_box.pack_start (menubutton_label, true, false);
        menubutton_box.pack_start (menubutton_arrow, false, false);
        menubutton.add (menubutton_box);

        this.selection_menubutton_label = menubutton_label;

        var search_button = new Gtk.ToggleButton ();
        var search_image = new Gtk.Image.from_icon_name ("edit-find-symbolic",
                                                         Gtk.IconSize.MENU);
        search_button.set_image (search_image);
        search_button.show_all();
        search_button.bind_property ("active",
                                     this.task_list_pane.search_bar,
                                     "search-mode-enabled",
                                     GLib.BindingFlags.BIDIRECTIONAL);

        var cancel_button = new Gtk.Button.with_mnemonic (_("_Cancel"));
        cancel_button.clicked.connect (() => {
            this.task_list_pane.unselect_all ();
            this.header_bar_stack.set_visible_child_name ("task-list");
        });

        header_bar.set_custom_title (menubutton);
        header_bar.pack_end (cancel_button);
        header_bar.pack_end (search_button);

        header_bar.show_all ();
        return header_bar;
    }

    private Gtk.HeaderBar create_task_details_header_bar ()
    {
        var header_bar = new Gtk.HeaderBar ();
        header_bar.show_close_button = true;

        header_bar.title = "<Project name>";

        header_bar.show_all ();
        return header_bar;
    }

    private void setup_header_bar ()
    {
        this.header_bar_stack = new Gtk.Stack ();
        this.header_bar_stack.add_named (
                              this.create_task_list_header_bar (),
                              "task-list");
        this.header_bar_stack.add_named (
                              this.create_task_list_selection_header_bar (),
                              "task-list-selection");
        this.header_bar_stack.add_named (
                              this.create_task_details_header_bar (),
                              "task-details");
        this.header_bar_stack.show ();

        this.header_bar_stack.set_visible_child_name ("task-list");

        this.set_titlebar (this.header_bar_stack);
    }

    private void setup_task_list ()
    {
        this.task_list_pane = new TaskListPane ();
        this.task_list_pane.show ();

        this.task_list_pane.selection_changed.connect (() => {
            var items = this.task_list_pane.get_selection ();
            var n_items = items.length ();

            if (n_items > 0) {
                this.header_bar_stack.set_visible_child_name ("task-list-selection");
            }
            else {
                this.header_bar_stack.set_visible_child_name ("task-list");
            }

            string label;
            if (n_items == 0) {
                label = _("Click on items to select them");
            } else {
                label = ngettext ("%d selected",
                                  "%d selected",
                                  n_items).printf (n_items);
            }

            this.selection_menubutton_label.label = label;
        });

        this.stack.add_named (this.task_list_pane, "task-list");
    }

    private bool on_key_press_event (Gdk.EventKey event)
    {
        return this.task_list_pane.search_bar.handle_event (event); //Gtk.get_current_event ());
    }
}
