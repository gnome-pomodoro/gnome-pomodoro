/*
 * Copyright (c) 2013-2025 gnome-pomodoro contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
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

        about_dialog.add_link (_("Donate"), Config.PACKAGE_DONATE_URL);

        return about_dialog;
    }
}
