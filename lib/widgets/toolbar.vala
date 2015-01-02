/*
 * Copyright (c) 2013 gnome-pomodoro contributors
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


public class Pomodoro.Widgets.Toolbar : Gtk.Toolbar
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
