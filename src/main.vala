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

internal class Pomodoro.Main
{
    static bool no_default_window;

	const OptionEntry[] options = {
		{ "no-default-window", 0, 0, OptionArg.NONE, ref no_default_window,
		  "Run as background service", null},
		{ null }
	};


    public static int main (string[] args)
    {
        Pomodoro.Application application;
        GLib.OptionContext   option_context;
        int                  status = 0;

        GLib.Environment.set_application_name (Config.PACKAGE);

        #if ENABLE_NLS
            Intl.bindtextdomain (Config.GETTEXT_PACKAGE,
                                 Config.PACKAGE_LOCALE_DIR);
            Intl.textdomain (Config.GETTEXT_PACKAGE);
        #endif

        Gtk.init (ref args);

        /* Setup command line options */
        option_context = new GLib.OptionContext ("- A simple pomodoro timer");
        option_context.set_help_enabled (true);
        option_context.add_group (Gtk.get_option_group (true));
        option_context.add_main_entries (options, Config.GETTEXT_PACKAGE);

		try {
			if (!option_context.parse(ref args)) {
				return 1;
			}
		}
		catch (GLib.OptionError e) {
            stdout.printf ("Could not parse arguments: %s\n", e.message);
			stdout.printf ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
			return 1;
		}

        application = new Pomodoro.Application();
        application.set_default();

        if (no_default_window) {
            application.is_service = true;
        }

        try {
            if (application.register ()) {
                status = application.run (args);
            }
        }
        catch (Error e) {
            GLib.critical ("%s", e.message);
            status = 1;
        }

        return status;
    }
}

