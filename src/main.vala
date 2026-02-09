/*
 * Copyright (c) 2013-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;


private void on_posix_signal (int signal)
{
    switch (signal)
    {
        case Posix.Signal.INT:
        case Posix.Signal.TERM:
            var application = Ft.Application.get_default ();
            if (application != null) {
                application.quit ();
            }
            break;

        default:
            break;
    }
}


public int main (string[] args)
{
    GLib.Intl.setlocale (GLib.LocaleCategory.ALL, "");
    GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.PACKAGE_LOCALE_DIR);
    GLib.Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    GLib.Intl.textdomain (Config.GETTEXT_PACKAGE);

    GLib.Environment.set_application_name (_("Focus Timer"));
    GLib.Environment.set_prgname (Config.APPLICATION_ID);

    Posix.signal (Posix.Signal.INT, on_posix_signal);
    Posix.signal (Posix.Signal.TERM, on_posix_signal);

    var application = new Ft.Application ();

    return application.run (args);
}
