/*
 * Copyright (c) 2013-2025 gnome-pomodoro contributors
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


namespace Pomodoro
{
    public Adw.AboutDialog create_about_dialog ()
    {
        var about_dialog = new Adw.AboutDialog ();
        about_dialog.application_icon = Config.APPLICATION_ID;
        about_dialog.application_name = _("Pomodoro");
        about_dialog.version = Config.PACKAGE_VERSION;
        about_dialog.website = Config.PACKAGE_WEBSITE;
        about_dialog.issue_url = Config.PACKAGE_ISSUE_URL;
        about_dialog.support_url = Config.PACKAGE_SUPPORT_URL;
        about_dialog.developer_name = "Kamil Prusko";
        about_dialog.developers = {
            "Kamil Prusko <kamilprusko@gmail.com>",
            "Arun Mahapatra <pratikarun@gmail.com>"
        };
        about_dialog.copyright = "\xc2\xa9 2011-2025 Arun Mahapatra, Kamil Prusko";
        about_dialog.license_type = Gtk.License.GPL_3_0;

        var translator_credits = _("translator-credits");

        if (translator_credits != "translator-credits") {
            about_dialog.translator_credits = translator_credits;
        }

        // XXX: `add_link` doesn't work
        // about_dialog.add_link (_("Donate"), Config.PACKAGE_URL);

        return about_dialog;
    }
}
