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


public int main (string[] args)
{
    Pomodoro.Application application;
    Pomodoro.CommandLine command_line;
    int exit_status = 0;

    GLib.Environment.set_application_name (Config.PACKAGE);

    #if ENABLE_NLS
        Intl.bindtextdomain (Config.GETTEXT_PACKAGE,
                             Config.PACKAGE_LOCALE_DIR);
        Intl.textdomain (Config.GETTEXT_PACKAGE);
    #endif

    Gtk.init (ref args);
    Gst.init (ref args);

    command_line = new Pomodoro.CommandLine ();

    // Arguments are also parsed by application.command_line signal handler,
    // so here we work on a copy. Though parsed arguments should be freed.
    if (command_line.parse (args))
    {
        application = new Pomodoro.Application ();
        application.is_service = command_line.no_default_window;
        application.set_default ();

        try {
            if (application.register ())
                exit_status = application.run (args);
        }
        catch (Error e) {
            GLib.critical ("%s", e.message);
            exit_status = 1;
        }
    }
    else {
        exit_status = 1;
    }

    return exit_status;
}

