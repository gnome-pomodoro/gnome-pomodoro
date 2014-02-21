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
    private Gtk.HeaderBar header_bar;
    private Gtk.Stack stack;

    public MainWindow ()
    {
        this.title = _("Tasks");

        var geometry = Gdk.Geometry ();
        geometry.min_width = 500;
        geometry.max_width = 500;
        geometry.min_height = 200;
        geometry.max_height = 1000;

        var geometry_hints = Gdk.WindowHints.MAX_SIZE |
                             Gdk.WindowHints.MIN_SIZE;

        this.set_geometry_hints (this,
                                 geometry,
                                 geometry_hints);

        this.set_default_size (-1, 706);

        this.set_destroy_with_parent (false);

        this.set_type_hint (Gdk.WindowTypeHint.NORMAL);

        var application = GLib.Application.get_default () as Pomodoro.Application;
        this.settings = application.settings.get_child ("preferences");

        this.setup ();
    }

    private void setup ()
    {
        var context = this.get_style_context ();
        context.add_class ("main-window");

        this.header_bar = new Gtk.HeaderBar ();
        this.header_bar.show_close_button = true;
        this.header_bar.title = _("Tasks");
        this.header_bar.show_all ();
        this.set_titlebar (this.header_bar);

        this.stack = new Gtk.Stack ();
        this.stack.homogeneous = true;
        this.stack.transition_duration = 150;
        this.stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        this.stack.show ();

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.set_policy (Gtk.PolicyType.NEVER,
                                    Gtk.PolicyType.AUTOMATIC);
        scrolled_window.set_size_request (500, 300);
        scrolled_window.show ();
        this.stack.add_named (scrolled_window, "tasks");

        this.vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        this.vbox.pack_end (this.stack, true, true);
        this.vbox.show ();

        this.add (this.vbox);
    }
}
