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


public class Pomodoro.Widgets.SymbolicButton : Gtk.Button
{
    public SymbolicButton (string icon_name, Gtk.IconSize icon_size)
    {
        this.set_relief (Gtk.ReliefStyle.NORMAL);

        var icon = new Gtk.Image.from_icon_name (icon_name, icon_size);
        icon.show ();

        this.image = icon;
    }
}
