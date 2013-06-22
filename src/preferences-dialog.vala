/*
 * Copyright (c) 2013 gnome-shell-pomodoro contributors
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

public class Pomodoro.PreferencesDialog : Gtk.ApplicationWindow
{
    public PreferencesDialog () {
        this.title = _("Preferences");
        this.set_default_size (500, 600);
        this.set_modal (true);
        this.set_destroy_with_parent (true);

        this.set_position (Gtk.WindowPosition.CENTER);
        
//        this.set_position (Gtk.WindowPosition.CENTER_ON_PARENT);
//        this.set_transient_for ();
    }
}

