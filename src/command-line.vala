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


[Compact]
public class Pomodoro.CommandLine
{
    public bool no_default_window = false;
    public bool preferences = false;

    public bool parse_ref ([CCode (array_length_pos = 0.9)] ref unowned string[]? args)
    {
        var option_context = new GLib.OptionContext ("- A simple pomodoro timer");
        option_context.set_help_enabled (true);
        option_context.add_group (Gtk.get_option_group (true));
        option_context.add_group (Gst.init_get_option_group ());

        var options = new GLib.OptionEntry[2];
        options[0] = { "preferences", 0, 0, GLib.OptionArg.NONE, ref this.preferences,
                       "Show preferences", null };
        options[1] = { "no-default-window", 0, 0, GLib.OptionArg.NONE, ref this.no_default_window,
                       "Run as background service", null };

        option_context.add_main_entries (options, Config.GETTEXT_PACKAGE);

        try {
            if (!option_context.parse (ref args)) {
                return false;
            }
        }
        catch (GLib.OptionError e) {
            stdout.printf ("Could not parse arguments: %s\n", e.message);
            stdout.printf ("Run '%s --help' to see a full list of available command line options.\n", args[0]);

            return false;
        }

        return true;
    }

    public bool parse (string[]? args)
    {
        /* We have to make an extra copy of the array, since parse() assumes
         * that it can remove strings from the array without freeing them.
         */
        var tmp = new string[args.length];
        for (int i = 0; i < args.length; i++) {
            tmp[i] = args[i];
        }

        unowned string[] unowned_args = tmp;

        return this.parse_ref (ref unowned_args);
    }
}
