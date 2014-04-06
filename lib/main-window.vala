/*
 * Copyright (c) 2014 gnome-pomodoro contributors
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

using GLib;


public class Pomodoro.MainWindow : Gtk.ApplicationWindow
{
    private GLib.Settings settings;

    private Gtk.Box vbox;
    private Gtk.SearchBar search_bar;
    private Gtk.Widget search_bar_container;
    private Gtk.HeaderBar header_bar;
    private Gtk.Stack stack;

    public MainWindow ()
    {
        this.title = _("Tasks");

        var geometry = Gdk.Geometry ();
        geometry.min_width = 500;
        geometry.min_height = 300;

        var geometry_hints = Gdk.WindowHints.MIN_SIZE;

        this.set_geometry_hints (this,
                                 geometry,
                                 geometry_hints);

        this.set_default_size (-1, 706);

        this.set_destroy_with_parent (false);

        this.set_type_hint (Gdk.WindowTypeHint.NORMAL);

        this.settings = Pomodoro.get_settings ().get_child ("preferences");

        this.setup ();
    }

    private void setup ()
    {
        var context = this.get_style_context ();
        context.add_class ("main-window");

        this.setup_header_bar ();
        this.setup_search_bar ();

        this.stack = new Gtk.Stack ();
        this.stack.homogeneous = true;
        this.stack.transition_duration = 150;
        this.stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        this.stack.show ();

        this.vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        this.vbox.pack_start (this.search_bar_container, false, true);
        this.vbox.pack_end (this.stack, true, true);
        this.vbox.show ();

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.set_policy (Gtk.PolicyType.NEVER,
                                    Gtk.PolicyType.AUTOMATIC);
        scrolled_window.set_size_request (500, 300);
        scrolled_window.show ();
        this.stack.add_named (scrolled_window, "tasks");

        this.add (this.vbox);

        this.key_press_event.connect (this.on_key_press_event);
    }

    private void setup_header_bar ()
    {
        this.header_bar = new Gtk.HeaderBar ();
        this.header_bar.show_close_button = true;
        this.header_bar.show_all ();

        var context = this.header_bar.get_style_context ();
        context.add_class ("headerbar");

        var bookmark_icon = GLib.Icon.new_for_string (
                "resource:///org/gnome/pomodoro/" + Stock.BOOKMARK + ".svg");
        var urgency_status = new Gtk.Image.from_gicon (bookmark_icon,
                                                       Gtk.IconSize.MENU);

        var urgency_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
        urgency_box.pack_start (urgency_status, false, false);

        var urgency_label = new Gtk.Label (_("Today"));
        urgency_box.pack_start (urgency_label, true, false);

        var urgency_button = new Gtk.Button ();
        urgency_button.set_relief (Gtk.ReliefStyle.NONE);
        urgency_button.add (urgency_box);


        urgency_button.show_all();
        this.header_bar.pack_start (urgency_button);

        //

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        hbox.get_style_context ().add_class ("titlebar");

        Gtk.Label label;

        label = new Gtk.Label ("Projects");
        label.valign = Gtk.Align.BASELINE;
        hbox.pack_start (label, false, false);

        label = new Gtk.Label ("❯");
        label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        label.get_style_context ().add_class ("arrow-right");
        hbox.pack_start (label, false, false);

        label = new Gtk.Label ("Personal");
        hbox.pack_start (label, false, false);

        hbox.show_all ();


        this.header_bar.set_custom_title (hbox);


        // var search_button = new Gtk.ToggleButton ();
        // search_button.set_image (new Gtk.Image.from_icon_name ("edit-find-symbolic", Gtk.IconSize.MENU));
        // search_button.show_all();
        // this.header_bar.pack_end (search_button);
        // search_button.bind_property ("active", this.search_bar, "search-mode-enabled", GLib.BindingFlags.BIDIRECTIONAL);

        this.set_titlebar (this.header_bar);
    }

    private void setup_search_bar ()
    {
        var entry = new Gtk.SearchEntry ();
        entry.set_width_chars (30);

        this.search_bar = new Gtk.SearchBar ();
        this.search_bar.add (entry);

        var revealer = new Gtk.Revealer ();
        revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        revealer.bind_property ("reveal-child",
                                this.search_bar,
                                "search-mode-enabled",
                                GLib.BindingFlags.BIDIRECTIONAL);
        revealer.add (this.search_bar);
        revealer.show_all ();

        this.search_bar_container = revealer as Gtk.Widget;
    }

    private bool on_key_press_event (Gdk.EventKey event)
    {
        return this.search_bar.handle_event (Gtk.get_current_event ());
    }
}
