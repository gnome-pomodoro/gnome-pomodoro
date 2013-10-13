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

using GLib;


public class Pomodoro.AboutDialog : Gtk.AboutDialog
{
    public AboutDialog ()
    {
        this.title = _("About Pomodoro");
        this.program_name = _("Pomodoro");
        this.comments = _("A simple time management utility");
        this.logo_icon_name = Config.PACKAGE;
        this.version = Config.PACKAGE_VERSION;

        this.authors = {
            "Arun Mahapatra <pratikarun@gmail.com>",
            "Kamil Prusko <kamilprusko@gmail.com>"
        };
        this.translator_credits = _("translator-credits");

        this.copyright = "Copyright \xc2\xa9 2011-2013 Arun Mahapatra, Kamil Prusko";

        this.wrap_license = true;
        this.license_type = Gtk.License.GPL_3_0;
        this.license = _("This program is free software: you can  redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,  MA 02110-1301  USA");

        this.destroy_with_parent = true;
        this.modal = true;

        this.response.connect (() => {
            this.destroy ();
        });
    }
}
