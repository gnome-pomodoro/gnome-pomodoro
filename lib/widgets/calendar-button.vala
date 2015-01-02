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


public class Pomodoro.Widgets.CalendarButton : Gtk.Button
{
    private static string DATE_TIME_FORMAT = "%a, %e %B %Y";

    public int day { get; set; default = 0; }
    public int month { get; set; default = 0; }
    public int year { get; set; default = 0; }

    construct
    {
        this.label = "24 July 2014";
//        this.image = new Gtk.Image.from_icon_name ("x-office-calendar-symbolic",
//                                                   Gtk.IconSize.MENU);
//        this.image_position = Gtk.PositionType.LEFT;
//        this.always_show_image = true;
    }

    private void show_popover ()
    {
        var calendar = new Gtk.Calendar ();
        calendar.halign = Gtk.Align.FILL;
        calendar.valign = Gtk.Align.FILL;
        calendar.margin = 4;
        calendar.show_week_numbers = false;
        calendar.show_heading = true;
        calendar.show_details = true;
        calendar.show_day_names = true;
        calendar.set_size_request (300, -1);

        if (this.day > 0) {
            calendar.day = this.day;
            calendar.mark_day (this.day);
        }

        if (this.month > 0) {
            calendar.month = this.month;
        }

        if (this.year > 0) {
            calendar.year = this.year;
        }

        var popover = new Gtk.Popover (this);
        popover.set_position (Gtk.PositionType.BOTTOM);
        popover.add (calendar);

        calendar.day_selected.connect (() => {
            // TODO: block notify event
            this.day = calendar.day;
            this.month = calendar.month;
            this.year = calendar.year;

            calendar.clear_marks ();
            calendar.mark_day (this.day);

            this.date_selected ();
        });

        calendar.day_selected_double_click.connect (() => {
            popover.destroy ();
        });

        popover.show_all ();
    }

    public override void clicked ()
    {
        this.show_popover ();
    }

    public virtual signal void date_selected ()
    {
        var datetime = new DateTime.local (this.year,
                                           this.month + 1,
                                           this.day,
                                           0,
                                           0,
                                           0.0);

        this.label = datetime.format (DATE_TIME_FORMAT);
    }
}

