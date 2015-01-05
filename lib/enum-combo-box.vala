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


public class Pomodoro.Widgets.EnumComboBox : Gtk.ComboBox
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
