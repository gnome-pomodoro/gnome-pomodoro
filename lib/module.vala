/*
 * Copyright (c) 2015 gnome-pomodoro contributors
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
 */

using GLib;


public abstract class Pomodoro.Module : GLib.Object
{
    public string? name { get; construct; }
    public bool enabled { get; set; default = false; }

    protected List<Pomodoro.Plugin> plugins;

    ~Module ()
    {
        if (this.enabled) {
            this.disable ();
        }
    }

    public unowned List<Pomodoro.Plugin> get_plugins ()
    {
        return this.plugins;
    }

    public virtual void enable ()
    {
        this.enabled = true;
    }

    public virtual void disable ()
    {
        this.enabled = false;
    }
}
