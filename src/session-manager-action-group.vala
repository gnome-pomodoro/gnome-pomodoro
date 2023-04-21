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
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Pomodoro
{
    public class SessionManagerActionGroup : GLib.SimpleActionGroup
    {
        public Pomodoro.SessionManager session_manager { get; construct; }

        public SessionManagerActionGroup ()
        {
            GLib.Object (
                session_manager: Pomodoro.SessionManager.get_default ()
            );
        }

        construct
        {
            var advance_action = new GLib.SimpleAction ("advance", null);
            advance_action.activate.connect (this.activate_advance);
            this.add_action (advance_action);
        }

        private void activate_advance (GLib.SimpleAction action,
                                       GLib.Variant?     parameter)
        {
            this.session_manager.advance ();
        }
    }
}
