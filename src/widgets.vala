/*
 * Copyright (c) 2013 gnome-pomodoro contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */


public class Pomodoro.Toolbar : Gtk.Toolbar
{
    construct {
        this.show_arrow = false;

        var context =  this.get_style_context ();

        context.add_class (Gtk.STYLE_CLASS_MENUBAR);
        context.add_class ("header-bar");
    }

    public override bool draw (Cairo.Context cr)
    {
        var context = this.get_style_context ();
        var width = this.get_allocated_width ();
        var height = this.get_allocated_height ();

        context.render_background (cr, 0.0, 0.0, width, height);
        context.render_frame (cr, 0.0, 0.0, width, height);

        return base.draw (cr);
    }
}


public class Pomodoro.ModeButton : Gtk.Box
{
    private int _selected = -1;

    public int selected {
        get {
            return this._selected;
        }
        set {
            var children = this.get_children ();
            var index = 0;

            if (value < 0 || value >= children.length ()) {
                return;
            }

            foreach (var child in children)
            {
                if (child is Gtk.ToggleButton)
                {
                    var item = child as Item;

                    item.can_toggle = true;
                    item.active = (index == value);

                    if (item.active)
                        item.can_toggle = false;
                }

                index++;
            }

            if (value != this._selected) {
                this._selected = value;
                this.changed ();
            }
        }
    }

    public ModeButton (Gtk.Orientation orientation)
    {
        GLib.Object (
            orientation: orientation,
            homogeneous: true,
            spacing: 0
        );

        this.halign = Gtk.Align.CENTER;
        this.can_focus = false;

        var style_context = this.get_style_context ();
        style_context.add_class (Gtk.STYLE_CLASS_LINKED);
    }

    public new void add (Gtk.Widget child)
    {
        var style_context = child.get_style_context ();
        style_context.add_class (Gtk.STYLE_CLASS_RAISED);

        var button = child as Gtk.ToggleButton;

        button.set_alignment (0.5f, 0.5f);
        button.can_focus = true;
        button.add_events (Gdk.EventMask.SCROLL_MASK);

        button.toggled.connect (this.on_child_toggled);

        this.pack_start (button, true, true, 0);

        if (this.selected < 0) {
            this.selected = 0;
        }
    }

    private void on_child_toggled (Gtk.Widget child)
    {
        var button = child as Gtk.ToggleButton;

        if (button.active) {
            this.selected = this.get_children ().index (child);
        }
    }

    public unowned Gtk.Widget add_label (string text)
    {
        var item = new Item.with_label (text);
        item.set_focus_on_click (false);
        item.show ();

        this.add (item);

        return item as Gtk.Widget;
    }

    public override bool scroll_event (Gdk.EventScroll event)
    {
        switch (event.direction)
        {
            case Gdk.ScrollDirection.RIGHT:
            case Gdk.ScrollDirection.DOWN:
                this.selected += 1;
                break;

            case Gdk.ScrollDirection.LEFT:
            case Gdk.ScrollDirection.UP:
                this.selected -= 1;
                break;
        }

        return false;
    }

    public signal void changed ();


    class Item : Gtk.ToggleButton
    {
        public bool can_toggle { get; set; default=true; }

        private Pango.Layout layout_bold;

        public Item.with_label (string label)
        {
            this.label = label;

            var style_context = this.get_style_context ();
            style_context.add_class ("text-button");
        }

        private void set_bold_attribute (bool is_bold)
        {
            var child = this.get_child ();

            if (child is Gtk.Label)
            {
                var label = child as Gtk.Label;

                if (is_bold) {
                    var attr = Pango.attr_weight_new (Pango.Weight.BOLD);

                    label.attributes = new Pango.AttrList ();
                    label.attributes.insert (attr.copy ());
                }
                else {
                    label.attributes = null;
                }
            }
        }

        public override void get_preferred_width (out int minimum_width,
                                                  out int natural_width)
        {
            var child = this.get_child ();
            var width = 0;
            var width_bold = 0;

            base.get_preferred_width (out minimum_width, out natural_width);

            if (child is Gtk.Label)
            {
                var label = child as Gtk.Label;
                var layout = label.get_layout ();

                layout.get_pixel_size (out width, null);

                if (this.layout_bold == null)
                {
                    var font = child.get_style_context ()
                                    .get_font (Gtk.StateFlags.NORMAL);
                    font.set_weight (Pango.Weight.BOLD);

                    this.layout_bold = layout.copy ();
                    this.layout_bold.set_font_description (font);
                }

                this.layout_bold.get_pixel_size (out width_bold, null);

                minimum_width += int.max (width_bold - width, 0);
            }

            if (natural_width < minimum_width)
                natural_width = minimum_width;
        }

        public override void style_updated ()
        {
            this.layout_bold = null;
            base.style_updated ();
        }

        public override void clicked ()
        {
            if (this.can_toggle)
                base.clicked ();
        }

        public override void toggled ()
        {
            this.set_bold_attribute (this.active);
        }
    }
}


public class Pomodoro.KeybindingButton : Gtk.Box
{
    public bool active
    {
        get {
            return this.keybinding_button.active;
        }
        set {
            this.keybinding_button.active = value;
        }
    }

    public string label
    {
        get {
            return this.keybinding_button.label;
        }
        set {
            this.keybinding_button.label = value;
        }
    }

    public Keybinding keybinding { get; set; }
    private Keybinding tmp_keybinding;

    private Gtk.ToggleButton keybinding_button;
    private Gtk.Button clear_button;

    public KeybindingButton (Keybinding keybinding)
    {
        GLib.Object (orientation: Gtk.Orientation.HORIZONTAL,
                     spacing: 0,
                     halign: Gtk.Align.CENTER,
                     homogeneous: false,
                     can_focus: false);

        this.keybinding_button = new Gtk.ToggleButton ();
        this.keybinding_button.set_events (this.events |
                                           Gdk.EventMask.KEY_PRESS_MASK |
                                           Gdk.EventMask.FOCUS_CHANGE_MASK);
        this.keybinding_button.can_focus = true;

        this.clear_button = new SymbolicButton ("edit-clear-symbolic",
                                                Gtk.IconSize.MENU);
        this.clear_button.can_focus = true;
        this.clear_button.no_show_all = true;
        this.clear_button.clicked.connect (() => {
            this.keybinding.accelerator = null;
            this.active = false;
        });

        this.pack_start (this.keybinding_button, true, true, 0);
        this.pack_start (this.clear_button, false, true, 0);

        var style_context = this.get_style_context ();
        style_context.add_class (Gtk.STYLE_CLASS_LINKED);

        this.keybinding = keybinding;
        this.keybinding.changed.connect (() => {
            this.notify_property ("keybinding");
            this.refresh ();
        });

        this.tmp_keybinding = new Keybinding ();

        this.refresh ();
    }

    private void refresh ()
    {
        var label = this.keybinding.get_label ();
        if (label != "") {
            this.label = label;
        }
        else {
            this.label = _("Disabled");
        }

        this.clear_button.set_visible (this.keybinding.accelerator != "");
    }

    public void toggled ()
    {
        if (this.active) {
            this.grab_focus ();
        }
    }

    public override bool focus_out_event (Gdk.EventFocus event)
    {
        this.active = false;

        return base.focus_out_event (event);
    }

    public override bool key_press_event (Gdk.EventKey event)
    {
        if (!this.active) {
            return base.key_press_event (event);
        }

        switch (event.keyval)
        {
            case Gdk.Key.BackSpace:
                    this.keybinding.accelerator = null;
                    this.active = false;

                    return true;

            case Gdk.Key.Escape:
            case Gdk.Key.Return:
                    this.active = false;

                    return true;
        }

        try
        {
            this.tmp_keybinding.set_values (event.keyval, event.state);
            this.tmp_keybinding.verify ();
        }
        catch (KeybindingError error)
        {
            if (error is KeybindingError.TYPING_COLLISION)
            {
                this.active = false;

                var dialog = new Gtk.MessageDialog (
                        this.get_toplevel () as Gtk.Window,
                        Gtk.DialogFlags.DESTROY_WITH_PARENT | Gtk.DialogFlags.MODAL,
                        Gtk.MessageType.WARNING,
                        Gtk.ButtonsType.CANCEL,
                        _("The shortcut \"%s\" cannot be used because it will become impossible to type using this key.\nPlease try with a key such as Control, Alt or Shift at the same time."),
                        this.tmp_keybinding.get_label ());
                dialog.run ();
                dialog.destroy ();
            }

            return true;
        }

        this.keybinding.set_values (
                this.tmp_keybinding.key,
                this.tmp_keybinding.modifiers);

        this.active = false;

        return true;
    }
}


public enum Pomodoro.SoundBackend {
    CANBERRA,
    GSTREAMER
}


private string get_default_current_folder_uri ()
{
    var application = GLib.Application.get_default () as Pomodoro.Application;
    var settings = application.settings.get_child ("state");

    return settings.get_string ("open-uri");
}


private void set_default_current_folder_uri (string current_folder)
{
    var application = GLib.Application.get_default () as Pomodoro.Application;
    var settings = application.settings.get_child ("state");

    settings.set_string ("open-uri", current_folder);
}


public class Pomodoro.SoundChooserButton : Gtk.Box
{
    private enum RowType {
        BOOKMARK_SEPARATOR,
        BOOKMARK,
        CUSTOM_SEPARATOR,
        CUSTOM,
        OTHER_SEPARATOR,
        OTHER,
        EMPTY_SELECTION,

        INVALID = -1
    }

    private enum Column {
        ROW_TYPE,
        DISPLAY_NAME,
        FILE
    }

    private enum TargetType {
        TEXT_PLAIN,
        TEXT_URI_LIST
    }

    public Gtk.FileChooserDialog dialog { private get; construct set; }

    private SoundBackend _backend;
    public SoundBackend backend {
        get {
            return this._backend;
        }
        set {
            this._backend = value;
            this.update_filters ();
        }
        default=SoundBackend.CANBERRA;
    }

    private GLib.File _file;
    public GLib.File file {
        get {
            return this._file;
        }
        set {
            this._file = value;
            this.update_combo_box ();
        }
    }

    public double volume { get; set; default=0.5; }

    public string title {
        owned get {
            return this.dialog.title;
        }
        set {
            this.dialog.title = value;
        }
    }

    public bool focus_on_click {
        get {
            return this.combo_box.focus_on_click;
        }
        set {
            if (this.combo_box.focus_on_click != value) {
                this.combo_box.focus_on_click = value;
            }
        }
    }

    public bool has_volume_button { get; set; default=false; }

    public Gtk.ComboBox combo_box;
    private ulong combo_box_changed_handler_id;
    private Gtk.FileFilter filter;
    private Gtk.ListStore model;
    private Gtk.VolumeButton volume_button;

    private static Gtk.FileChooserDialog create_dialog ()
    {
        var dialog = new Gtk.FileChooserDialog (null, null,
                            Gtk.FileChooserAction.OPEN,
                            _("_No sound"),
                            Gtk.ResponseType.NONE,
                            _("_Cancel"),
                            Gtk.ResponseType.CANCEL,
                            _("_Open"),
                            Gtk.ResponseType.ACCEPT);

        dialog.set_default_response (Gtk.ResponseType.ACCEPT);
        dialog.set_alternative_button_order (Gtk.ResponseType.NONE,
                                             Gtk.ResponseType.ACCEPT,
                                             Gtk.ResponseType.CANCEL);
        dialog.title = _("Select a file");
        dialog.local_only = true;

        return dialog;
    }

    public SoundChooserButton.with_dialog (Gtk.FileChooserDialog dialog)
    {
        GLib.Object (
            dialog: dialog
        );
    }

    public SoundChooserButton ()
    {
        GLib.Object (
            dialog: create_dialog ()
        );
    }

    private Gtk.CellRendererText name_cell;

    construct
    {
        this.spacing = 6;

        /* Dialog */
        this.dialog.response.connect (this.on_dialog_response);
        this.dialog.delete_event.connect (this.on_dialog_delete_event);
        this.dialog.notify.connect (this.on_dialog_notify);

        /* Model */
        Gtk.TreeIter iter;

        this.model = new Gtk.ListStore (3,
                                        typeof (int),
                                        typeof (string),
                                        typeof (GLib.File));
        this.model_add_other ();
        this.model_add_none ();

        /* ComboBox */
        this.name_cell = new Gtk.CellRendererText ();
        this.name_cell.width = 120;  // TODO: make it adjustable

        this.combo_box = new Gtk.ComboBox.with_model (this.model);
        this.combo_box.can_focus = false;
        this.combo_box.pack_start (this.name_cell, true);

        this.combo_box.set_attributes (this.name_cell, "text", Column.DISPLAY_NAME);
        this.combo_box.set_row_separator_func (this.row_separator_func);
        this.combo_box.set_cell_data_func (this.name_cell, this.name_cell_data_func);
        this.combo_box.show ();

        this.combo_box_changed_handler_id =
                this.combo_box.changed.connect (this.on_combo_box_changed);

        this.pack_start (combo_box, true, true, 0);

        var filter = new Gtk.FileFilter ();
        filter.set_filter_name (_("All files"));
        filter.add_pattern ("*");
        this.add_filter (filter);

        this.update_filters ();

        /* Drag and drop */
        Gtk.TargetEntry[] target_entries = {};
        Gtk.drag_dest_set (this,
                           Gtk.DestDefaults.ALL,
                           target_entries,
                           Gdk.DragAction.COPY);
        var target_list = new Gtk.TargetList (target_entries);
        target_list.add_uri_targets (TargetType.TEXT_URI_LIST);
        target_list.add_text_targets (TargetType.TEXT_PLAIN);
        Gtk.drag_dest_set_target_list (this, target_list);

        this.volume_button = new Gtk.VolumeButton ();
        this.volume_button.no_show_all = true;
        this.volume_button.use_symbolic = true;
        this.volume_button.relief = Gtk.ReliefStyle.NORMAL;

        this.bind_property ("volume",
                            this.volume_button.adjustment,
                            "value",
                            GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL);

        this.bind_property ("has-volume-button",
                            this.volume_button,
                            "visible",
                            GLib.BindingFlags.DEFAULT);

        this.pack_start (this.volume_button, false, true);
    }

    private bool has_bookmark_separator = false;
    private bool has_custom_separator = false;
    private bool has_other_separator = false;
    private bool has_custom = false;
    private int n_bookmarks;

    public void add_bookmark (string display_name, GLib.File? file)
    {
        this.model_add_bookmark (display_name, file);
    }

    private int model_get_type_position (RowType row_type)
    {
        int retval = 0;

        if (row_type == RowType.BOOKMARK_SEPARATOR) {
            return retval;
        }

        retval += this.has_bookmark_separator ? 1 : 0;

        if (row_type == RowType.BOOKMARK) {
            return retval;
        }

        retval += this.n_bookmarks;

        if (row_type == RowType.CUSTOM_SEPARATOR) {
            return retval;
        }

        retval += this.has_custom_separator ? 1 : 0;

        if (row_type == RowType.CUSTOM) {
            return retval;
        }

        retval += this.has_custom ? 1 : 0;

        if (row_type == RowType.OTHER_SEPARATOR) {
            return retval;
        }

        retval += this.has_other_separator ? 1 : 0;

        if (row_type == RowType.OTHER) {
            return retval;
        }

        retval++;

        if (row_type == RowType.EMPTY_SELECTION) {
            return retval;
        }

        assert_not_reached ();

        return -1;
    }

    private static int model_sort_func (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b)
    {
        var a_type = RowType.INVALID;
        var b_type = RowType.INVALID;
        var a_display_name = "";
        var b_display_name = "";

        model.get (a, Column.ROW_TYPE, out a_type);
        model.get (b, Column.ROW_TYPE, out b_type);

        if (a_type < b_type) {
            return -1;
        }

        if (a_type > b_type) {
            return 1;
        }

        model.get (a, Column.DISPLAY_NAME, out a_display_name);
        model.get (b, Column.DISPLAY_NAME, out b_display_name);

        return strcmp (a_display_name, b_display_name);
    }

    private void model_add_other ()
    {
        Gtk.TreeIter iter;

        var pos = this.model_get_type_position (RowType.OTHER);

        this.model.insert (out iter, pos);
        this.model.set (iter,
                        Column.ROW_TYPE, RowType.OTHER,
                        Column.DISPLAY_NAME, _("Other\xE2\x80\xA6"));

        this.has_other_separator = true;

        this.model.insert (out iter, pos);
        this.model.set (iter,
                        Column.ROW_TYPE, RowType.OTHER_SEPARATOR);
    }

    private void model_add_none ()
    {
        this.add_bookmark (_("None"), null);
    }

    private void model_add_bookmark (string     display_name,
                                     GLib.File? file)
    {
        Gtk.TreeIter iter;

        var pos = this.model_get_type_position (RowType.BOOKMARK);

        this.model.iter_nth_child (out iter, null, pos);

        while (true)
        {
            var type = RowType.INVALID;
            var name = "";
            var next_iter = iter;

            if (!this.model.iter_next (ref next_iter)) {
                break;
            }

            this.model.get (iter,
                            Column.ROW_TYPE, out type,
                            Column.DISPLAY_NAME, out name);

            if (type != RowType.BOOKMARK) {
                break;
            }

            if (model_sort_func (this.model, iter, next_iter) < 0) {
                break;
            }

            iter = next_iter;
            pos += 1;
        }

        this.model.insert (out iter, pos);

        if (file != null) {
            this.model.set (iter,
                            Column.ROW_TYPE, RowType.BOOKMARK,
                            Column.DISPLAY_NAME, display_name,
                            Column.FILE, file);
        }
        else {
            this.model.set (iter,
                            Column.ROW_TYPE, RowType.BOOKMARK,
                            Column.DISPLAY_NAME, display_name);
        }

        this.n_bookmarks += 1;
    }

    private GLib.File? model_get_custom ()
    {
        GLib.File? file = null;
        Gtk.TreeIter iter;

        if (this.has_custom)
        {
            var pos = this.model_get_type_position (RowType.CUSTOM);

            this.model.iter_nth_child (out iter, null, pos);
            this.model.get (iter, Column.FILE, out file);
        }

        return file;
    }

    private void model_update_custom (GLib.File? file)
    {
        Gtk.TreeIter iter;
        int pos;

        if (file == null) {
            return;
        }

        if (!this.has_custom_separator)
        {
            pos = this.model_get_type_position (RowType.CUSTOM_SEPARATOR);
            this.model.insert (out iter, pos);
            this.model.set (iter,
                            Column.ROW_TYPE, RowType.CUSTOM_SEPARATOR);
            this.has_custom_separator = true;
        }

        pos = this.model_get_type_position (RowType.CUSTOM);

        if (!this.has_custom) {
            this.model.insert (out iter, pos);
            this.has_custom = true;
        }
        else {
            this.model.iter_nth_child (out iter, null, pos);
        }

        this.model.set (iter,
                        Column.ROW_TYPE, RowType.CUSTOM,
                        Column.DISPLAY_NAME, file.get_basename (),
                        Column.FILE, file);
    }

    /* Combo Box */

    private bool row_separator_func (Gtk.TreeModel model,
                                     Gtk.TreeIter  iter)
    {
        var type = RowType.INVALID;

        model.get (iter, Column.ROW_TYPE, out type);

        return (type == RowType.BOOKMARK_SEPARATOR ||
                type == RowType.CUSTOM_SEPARATOR ||
                type == RowType.OTHER_SEPARATOR);
    }

    private void name_cell_data_func (Gtk.CellLayout   layout,
                                      Gtk.CellRenderer cell,
                                      Gtk.TreeModel    model,
                                      Gtk.TreeIter     iter)
    {
        var type = RowType.INVALID;
        var name_cell = cell as Gtk.CellRendererText;

        model.get (iter,
                   Column.ROW_TYPE, out type);

        if (type == RowType.CUSTOM) {
            name_cell.ellipsize = Pango.EllipsizeMode.END;
        }
        else {
            name_cell.ellipsize = Pango.EllipsizeMode.NONE;
        }
    }

    private void select_combo_box_row_no_notify (int pos)
    {
        Gtk.TreeIter iter;

        this.model.iter_nth_child (out iter, null, pos);

        SignalHandler.block (this.combo_box,
                             this.combo_box_changed_handler_id);

        this.combo_box.set_active_iter (iter);

        SignalHandler.unblock (this.combo_box,
                               this.combo_box_changed_handler_id);
    }

    private void update_combo_box ()
    {
        Gtk.TreeIter iter;
        GLib.File? file = null;

        var selected_file = this.file;
        var row_found = false;
        var type = RowType.INVALID;

        this.model.get_iter_first (out iter);

        do {
            this.model.get (iter,
                            Column.ROW_TYPE, out type,
                            Column.FILE, out file);

            switch (type)
            {
                case RowType.BOOKMARK:
                case RowType.CUSTOM:
                    row_found = (file != null)
                        ? selected_file != null && file.equal (selected_file)
                        : selected_file == null || selected_file.get_uri () == "";
                    break;

                default:
                    row_found = false;
                    break;
            }

            if (row_found)
            {
                SignalHandler.block (this.combo_box,
                                     this.combo_box_changed_handler_id);

                this.combo_box.set_active_iter (iter);

                SignalHandler.unblock (this.combo_box,
                                       this.combo_box_changed_handler_id);
            }
        }
        while (!row_found && this.model.iter_next (ref iter));


        if (!row_found)
        {
            int pos;

            if (selected_file != null && selected_file.get_uri () != "")
            {
                this.model_update_custom (selected_file);
                pos = this.model_get_type_position (RowType.CUSTOM);
            }
            else
            {
                /* No selection; switch to that row */
                pos = this.model_get_type_position (RowType.EMPTY_SELECTION);
            }

            this.select_combo_box_row_no_notify (pos);
        }
    }

    private void on_combo_box_changed ()
    {
        var type = RowType.INVALID;
        GLib.File data = null;
        Gtk.TreeIter iter;

        if (combo_box.get_active_iter (out iter))
        {
            this.model.get (iter,
                            Column.ROW_TYPE, out type,
                            Column.FILE, out data);

            switch (type)
            {
                case RowType.BOOKMARK:
                case RowType.CUSTOM:
                case RowType.EMPTY_SELECTION:
                    this.file = data;
                    break;

                case RowType.OTHER:
                    this.open_dialog ();
                    break;

                default:
                    break;
            }
        }
    }

    /* Dialog */

    private void on_dialog_notify (GLib.ParamSpec property)
    {
        if (this.get_class ().find_property (property.name) != null) {
            this.notify_property (property.name);
        }
    }

    private void on_dialog_response (Gtk.Dialog dialog,
                                     int        response)
    {
        this.dialog.hide ();
        this.combo_box.set_sensitive (true);

        switch (response)
        {
            case Gtk.ResponseType.ACCEPT:
            case Gtk.ResponseType.OK:
                var current_folder = this.dialog.get_current_folder_uri ();
                set_default_current_folder_uri (current_folder);

                this.file = this.dialog.get_file ();
                break;

            case Gtk.ResponseType.NONE:
                this.file = null;
                break;

            default:
                this.update_combo_box ();
                break;
        }
    }

    private bool on_dialog_delete_event (Gdk.EventAny event)
    {
        this.dialog.response (Gtk.ResponseType.DELETE_EVENT);

        return true;
    }

    private void open_dialog ()
    {
        if (this.has_custom &&
            this.file == this.model_get_custom () &&
            this.file.query_exists ())
        {
            try {
                this.dialog.set_current_folder_file (this.file.get_parent ());
                this.dialog.select_file (this.file);
            }
            catch (Error error) {
            }
        }
        else
        {
            var current_folder = get_default_current_folder_uri ();

            this.dialog.set_current_folder_uri (current_folder);
        }

        /* Setup the dialog parent to be chooser button's toplevel, and be modal
           as needed. */
        if (!this.dialog.visible)
        {
            var toplevel = this.get_toplevel ();

            if (toplevel.is_toplevel () && toplevel is Gtk.Window)
            {
                this.dialog.set_transient_for (toplevel as Gtk.Window);
                this.dialog.set_modal ((toplevel as Gtk.Window).get_modal ());
            }
        }

        /* Select current file, instead of having 'Other...' selected */
        this.update_combo_box ();

        this.combo_box.set_sensitive (false);

        this.dialog.run ();
    }

    private void update_filters ()
    {
        if (this.filter != null) {
            this.remove_filter (this.filter);
        }

        switch (this.backend)
        {
            case SoundBackend.CANBERRA:
                this.filter = new Gtk.FileFilter ();
                this.filter.set_filter_name (_("Supported audio files"));
                this.filter.add_mime_type ("audio/x-vorbis+ogg");
                this.filter.add_mime_type ("audio/x-wav");
                this.add_filter (this.filter);
                this.set_filter (this.filter);
                break;

            case SoundBackend.GSTREAMER:
                this.filter = new Gtk.FileFilter ();
                this.filter.set_filter_name (_("Supported audio files"));
                this.filter.add_mime_type ("audio/*");
                this.add_filter (this.filter);
                this.set_filter (this.filter);
                break;

            default:
                this.filter = null;
                break;
        }
    }

    public override void drag_data_received (Gdk.DragContext   context,
                                             int               x,
                                             int               y,
                                             Gtk.SelectionData data,
                                             uint               type,
                                             uint               drag_time)
    {
        GLib.File file = null;

        if (base.drag_data_received != null) {
            base.drag_data_received (context,
                                     x, y,
                                     data, type,
                                     drag_time);
        }

        if (context == null || data == null || data.get_length () < 0) {
            return;
        }

        switch (type)
        {
            case TargetType.TEXT_URI_LIST:
                var uris = data.get_uris ();
                if (uris != null)
                    file = GLib.File.new_for_uri (uris[0]);
                break;

            case TargetType.TEXT_PLAIN:
                var text = data.get_text ();
                file = GLib.File.new_for_uri (text);
                break;

            default:
                break;
        }

        if (file != null)
        {
            this.file = file;
            try {
                this.dialog.select_file (file);
            }
            catch (Error e) {
                GLib.warning (e.message);
            }
        }

        Gtk.drag_finish (context, true, false, drag_time);
    }

    /* Gtk.FileChooser interface */

    public void add_filter (Gtk.FileFilter filter) {
        this.dialog.add_filter (filter);
    }

    public void remove_filter (Gtk.FileFilter filter) {
        this.dialog.remove_filter (filter);
    }

    public void set_filter (Gtk.FileFilter filter) {
        this.dialog.set_filter (filter);
    }
}


public class Pomodoro.LogScale : Gtk.Scale
{
    /* TODO: This widget is quite bad. We need custom GtkRange to
     *       do it right.
     */

    public double exponent { get; set; default = 1.0; }

    private Gtk.Adjustment base_adjustment;

    public LogScale (Gtk.Adjustment adjustment,
                     double         exponent)
    {
        GLib.Object (
            orientation: Gtk.Orientation.HORIZONTAL,
            digits: 0,
            draw_value: false,
            margin_top: 4,
            halign: Gtk.Align.FILL
        );

        this.exponent = exponent;

        this.do_set_adjustment (adjustment);
    }

    private void do_set_adjustment (Gtk.Adjustment base_adjustment)
    {
        var binding_flags =
                GLib.BindingFlags.DEFAULT |
                GLib.BindingFlags.BIDIRECTIONAL |
                GLib.BindingFlags.SYNC_CREATE;

        this.adjustment = new Gtk.Adjustment (0.0,
                                              0.0,
                                              1.0,
                                              0.0001,
                                              0.001,
                                              0.0);

        this.base_adjustment = base_adjustment;
        this.base_adjustment.bind_property ("value",
                                            this.adjustment,
                                            "value",
                                            binding_flags,
                                            this.transform_to,
                                            this.transform_from);
    }

    private bool transform_from (Binding   binding,
                                 Value     source_value,
                                 ref Value target_value)
    {
        var lower = this.base_adjustment.lower;
        var upper = this.base_adjustment.upper;
        var step_increment = this.base_adjustment.step_increment;

        var value = Math.pow (source_value.get_double (), this.exponent) * (upper - lower) + lower;

        target_value.set_double (step_increment * Math.floor (value / step_increment));

        return true;
    }

    private bool transform_to (Binding   binding,
                               Value     source_value,
                               ref Value target_value)
    {
        var lower = this.base_adjustment.lower;
        var upper = this.base_adjustment.upper;

        target_value.set_double (Math.pow (
                (source_value.get_double () - lower) / (upper - lower),
                1.0 / this.exponent));

        return true;
    }
}


public class Pomodoro.SymbolicButton : Gtk.Button
{
    public SymbolicButton (string icon_name, Gtk.IconSize icon_size)
    {
        this.set_alignment (0.5f, 0.5f);
        this.set_relief (Gtk.ReliefStyle.NORMAL);

        var icon = new Gtk.Image.from_icon_name (icon_name, icon_size);
        icon.show ();

        this.image = icon;
    }
}


public class Pomodoro.EnumComboBox : Gtk.ComboBox
{
    enum Column {
        VALUE,
        DISPLAY_NAME
    }

    construct {
        var model = new Gtk.ListStore (2,
                                       typeof (int),
                                       typeof (string));
        this.model = model;

        var cell = new Gtk.CellRendererText ();
        cell.width = 120;  /* TODO: make it adjustable */

        this.pack_start (cell, false);
        this.set_attributes (cell, "text", Column.DISPLAY_NAME);

        this.changed.connect (() => {
            this.notify_property ("value");
        });
    }

    public int value {
        get {
            Gtk.TreeIter iter;
            int iter_value = 0;

            if (this.get_active_iter (out iter))
            {
                this.model.get (iter,
                                Column.VALUE, out iter_value);
            }

            return iter_value;
        }
        set {
            Gtk.TreeIter iter;
            int iter_value = 0;

            if (this.model.get_iter_first (out iter))
            {
                do {
                    this.model.get (iter,
                                    Column.VALUE, out iter_value);

                    if (iter_value == value) {
                        this.set_active_iter (iter);
                        break;
                    }
                }
                while (this.model.iter_next (ref iter));
            }
        }
    }

    public void add_option (int value, string display_name)
    {
        Gtk.TreeIter iter;

        var model = this.model as Gtk.ListStore;

        model.append (out iter);
        model.set (iter,
                   Column.VALUE, value,
                   Column.DISPLAY_NAME, display_name);
    }
}
