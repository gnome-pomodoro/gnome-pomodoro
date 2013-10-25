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


private enum ExitStatus
{
    SUCCESS = 0,
    FAILURE = 1
}


public int main (string[] args)
{
    GLib.Environment.set_application_name (Config.PACKAGE);

    #if ENABLE_NLS
        Intl.bindtextdomain (Config.GETTEXT_PACKAGE,
                             Config.PACKAGE_LOCALE_DIR);
        Intl.textdomain (Config.GETTEXT_PACKAGE);
    #endif

    Gtk.init (ref args);

    var command_line = new Pomodoro.CommandLine ();

    /* Arguments are also parsed by application.command_line signal handler,
     * so here we work on a copy.
     */
    if (command_line.parse (args))
    {
        var application = new Pomodoro.Application ();
        application.set_default ();

        try {
            if (application.register ())
            {
                // if (!command_line.no_default_window) {
                //     application.activate_action ("preferences", "");
                // }

                return application.run (args);
            }
        }
        catch (Error e) {
            GLib.critical ("%s", e.message);
        }
    }

    return ExitStatus.FAILURE;
}
