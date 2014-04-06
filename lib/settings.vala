/*
 * Copyright (c) 2014 gnome-pomodoro contributors
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


namespace Pomodoro
{
    private GLib.Settings settings = null;

    private void unload_settings ()
    {
        if (settings != null) {
            settings.dispose ();
            settings = null;
        }
    }

    private void load_settings ()
    {
        settings = new GLib.Settings ("org.gnome.pomodoro");
    }

    public void set_settings (GLib.Settings settings)
    {
        Pomodoro.settings = settings;
    }

    public GLib.Settings get_settings ()
    {
        if (settings == null) {
            load_settings ();
        }

        return Pomodoro.settings;
    }
}
