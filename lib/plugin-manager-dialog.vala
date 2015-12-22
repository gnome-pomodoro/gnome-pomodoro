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
 *
 */

using GLib;


[GtkTemplate (ui = "/org/gnome/pomodoro/ui/plugin-row.ui")]
private class Pomodoro.PluginRow : Gtk.ListBoxRow
{
    [GtkChild]
    private Gtk.Label name_label;
    [GtkChild]
    private Gtk.Label description_label;

    public PluginRow (Peas.PluginInfo plugin)
    {
        name_label.label = plugin.get_name ();
        description_label.label = plugin.get_description ();
    }
}


[GtkTemplate (ui = "/org/gnome/pomodoro/ui/plugins-dialog.ui")]
public class Pomodoro.PluginManagerDialog : Gtk.Window
{
    [GtkChild]
    private Gtk.ListBox plugins_list;

    private Pomodoro.PluginManager engine;

    public PluginManagerDialog ()
    {
        this.engine = PluginManager.get_default ();

        this.fill_plugins_list ();
    }

    private void fill_plugins_list ()
    {
        foreach (var plugin in this.engine.get_plugin_list ())
        {
//                if (plugin.is_hidden ()) {
//                    continue;
//                }

            var row = new Pomodoro.PluginRow (plugin);

            if (plugin.is_loaded ()) {
                row.get_style_context ().add_class ("plugin-loaded");
            }

            this.plugins_list.prepend (row);
        }
    }
}
