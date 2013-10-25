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
 */

using GLib;
using Gnome;


namespace Pomodoro
{
    public const string EXTENSION_UUID = "pomodoro@arun.codito.in";
}


namespace Gnome
{
    public const string SHELL_SCHEMA = "org.gnome.shell";
    public const string SHELL_ENABLED_EXTENSIONS_KEY = "enabled-extensions";
}


public class Pomodoro.GnomeDesktop : Object
{
    private unowned Pomodoro.Timer timer;

    public GnomeDesktop (Pomodoro.Timer timer)
    {
        this.timer = timer;

        this.enable_extension (Pomodoro.EXTENSION_UUID);
    }

    public bool enable_extension (string extension_uuid)
    {
        var gnome_shell_settings = new GLib.Settings (Gnome.SHELL_SCHEMA);
        var enabled_extensions = gnome_shell_settings.get_strv (Gnome.SHELL_ENABLED_EXTENSIONS_KEY);
        var has_enabled = false;

        foreach (var uuid in enabled_extensions)
        {
            if (uuid == extension_uuid) {
                has_enabled = true;
            }
        }

        if (!has_enabled)
        {
            enabled_extensions += extension_uuid;

            return gnome_shell_settings.set_strv ("enabled-extensions",
                                                  enabled_extensions);
        }

        return true;
    }
}
