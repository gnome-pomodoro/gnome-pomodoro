/*
 * Copyright (c) 2016 gnome-pomodoro contributors
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
 */

using GLib;


namespace IndicatorPlugin
{
    public class ApplicationExtension : Peas.ExtensionBase, Pomodoro.ApplicationExtension
    {
        private Pomodoro.CapabilityGroup capabilities;

        construct
        {
            var capability = new IndicatorPlugin.IndicatorCapability ("indicator");

            this.capabilities = new Pomodoro.CapabilityGroup ("indicator");
            this.capabilities.add (capability);

            var application = Pomodoro.Application.get_default ();
            application.capabilities.add_group (this.capabilities, Pomodoro.Priority.DEFAULT);
        }
    }
}


[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
    var object_module = module as Peas.ObjectModule;

    object_module.register_extension_type (typeof (Pomodoro.ApplicationExtension),
                                           typeof (IndicatorPlugin.ApplicationExtension));
}
