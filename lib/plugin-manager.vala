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

namespace Pomodoro
{
    internal const string DESKTOP_SESSION_ENV_VARIABLE = "DESKTOP_SESSION";

    public class PluginManager : Peas.Engine
    {
        private static PluginManager instance;

        construct
        {
//            var repo = Introspection.Repository.get_default ();
//
//            try
//            {
//                repo.require ("Peas", "1.0", 0);
//            }
//            catch (GLib.Error e)
//            {
//                warning ("Could not load repository: %s", e.message);
//
//                return;
//            }

//            var plugins_path = 
//                GLib.Path.build_path (Config.PLUGIN_LIB_DIR);

//            var plugins_data_path = 
//                GLib.Path.build_path (Config.PLUGIN_DATA_DIR);

            message ("** plugin dir = %s", Config.PLUGIN_LIB_DIR);

            this.add_search_path (Config.PLUGIN_LIB_DIR, Config.PLUGIN_DATA_DIR);

//            // need to load plugins first
//            foreach (var plugin in this.get_plugin_list ())
//            {
//                message ("** plugin: %s", plugin.get_name ());
//
//                if (plugin.is_builtin ())
//                {
//                    this.load_plugin (plugin);
//                }
//            }

            foreach (var plugin in this.get_plugin_list ())
            {
                var extension = this.create_extension (plugin, typeof (Pomodoro.DesktopExtension));
            }
        }

        public Pomodoro.DesktopExtension? create_desktop_extension ()
        {
            var desktop_session = GLib.Environment.get_variable (DESKTOP_SESSION_ENV_VARIABLE);
            Pomodoro.DesktopExtension extension = null;

            if (desktop_session == "gnome")
            {
                var plugin = this.get_plugin_info ("gnome");

                if (this.try_load_plugin (plugin))
                {
                    extension = this.create_extension (plugin, typeof (Pomodoro.DesktopExtension)) as Pomodoro.DesktopExtension;
                }
            }

            return extension;
        }

        public new static unowned PluginManager get_default ()
        {
            if (PluginManager.instance == null)
            {
                PluginManager.instance = new PluginManager ();
                PluginManager.instance.add_weak_pointer (&instance);
            }

            return PluginManager.instance;
        }

//        public static void initialize ()
//        {
//            PluginManager.get_default ();
//        }
    }

    public interface DesktopExtension : GLib.Object
    {
    }
}
