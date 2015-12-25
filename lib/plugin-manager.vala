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
    public class PluginManager : Peas.Engine
    {
        private static PluginManager instance;

        construct
        {
            this.add_search_path (Config.PLUGIN_LIB_DIR, Config.PLUGIN_DATA_DIR);

//            this.initialize ();
        }

//        public Pomodoro.DesktopExtension? create_desktop_extension ()
//        {
//            var desktop_session = GLib.Environment.get_variable (DESKTOP_SESSION_ENV_VARIABLE);
//            Pomodoro.DesktopExtension extension = null;
//
//            if (desktop_session == "gnome")
//            {
//                var plugin = this.get_plugin_info ("gnome");
//
//                if (this.try_load_plugin (plugin))
//                {
//                    extension = this.create_extension (plugin, typeof (Pomodoro.DesktopExtension)) as Pomodoro.DesktopExtension;
//                }
//            }
//
//            return extension;
//        }

        public new static unowned PluginManager get_default ()
        {
            if (PluginManager.instance == null)
            {
                PluginManager.instance = new PluginManager ();
                PluginManager.instance.add_weak_pointer (&instance);
            }

            return PluginManager.instance;
        }

// TODO?
//        private void initialize ()
//        {
//            foreach (var plugin in this.get_plugin_list ())
//            {
//                if (plugin.is_builtin ()) {
//                    this.load_plugin (plugin);
//                }
//
//                // var extension = this.create_extension (plugin, typeof (Pomodoro.DesktopExtension));
//            }
//        }

        /**
         * The load-plugin signal is emitted when a plugin is being loaded.
         */
        public override void load_plugin (Peas.PluginInfo info)
        {
            message ("load plugin \"%s\"", info.get_name ());

            base.load_plugin (info);
        }

        /**
         * The unload-plugin signal is emitted when a plugin is being unloaded.
         */
        public override void unload_plugin (Peas.PluginInfo info)
        {
            message ("unload plugin \"%s\"", info.get_name ());

            base.unload_plugin (info);
        }
    }

    public interface DesktopExtension : Peas.ExtensionBase
    {
    }
}
