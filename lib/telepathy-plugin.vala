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


public class Pomodoro.TelepathyPlugin : Pomodoro.PresencePlugin
{
    private TelepathyGLib.AccountManager account_manager;

//    public TelepathyPlugin ()
//    {
//    }

    public override void enable ()
    {
        if (this.account_manager == null) {
            this.account_manager = TelepathyGLib.AccountManager.dup ();
        }

        base.enable ();
    }

    public override void disable ()
    {
        this.account_manager = null;

        base.disable ();
    }

    public override async void set_status (Pomodoro.PresenceStatus status)
    {
        string message;
        string current_status_string;

        if (this.account_manager != null)
        {
            var current_status = this.account_manager.get_most_available_presence (
                                           out current_status_string,
                                           out message);
            var new_status = TelepathyGLib.ConnectionPresenceType.UNSET;
            var new_status_string = "";

            switch (status)
            {
                case Pomodoro.PresenceStatus.BUSY:
                    if (current_status == TelepathyGLib.ConnectionPresenceType.AVAILABLE)
                    {
                        new_status = TelepathyGLib.ConnectionPresenceType.BUSY;
                        new_status_string = "busy";
                    }

                    break;

                case Pomodoro.PresenceStatus.AVAILABLE:
                    if (current_status == TelepathyGLib.ConnectionPresenceType.BUSY)
                    {
                        new_status = TelepathyGLib.ConnectionPresenceType.AVAILABLE;
                        new_status_string = "available";
                    }

                    break;
            }

            if (new_status != TelepathyGLib.ConnectionPresenceType.UNSET) {
                this.account_manager.set_all_requested_presences (new_status,
                                                                  new_status_string,
                                                                  message);
            }
        }
    }

    private TelepathyGLib.ConnectionPresenceType convert_from_pomodoro_presence_status
                                       (Pomodoro.PresenceStatus status)
    {
        switch (status)
        {
            case Pomodoro.PresenceStatus.AVAILABLE:
                return TelepathyGLib.ConnectionPresenceType.AVAILABLE;

            case Pomodoro.PresenceStatus.BUSY:
                return TelepathyGLib.ConnectionPresenceType.BUSY;

            case Pomodoro.PresenceStatus.IDLE:
                return TelepathyGLib.ConnectionPresenceType.AWAY;

            case Pomodoro.PresenceStatus.INVISIBLE:
                return TelepathyGLib.ConnectionPresenceType.HIDDEN;
        }

        return TelepathyGLib.ConnectionPresenceType.UNKNOWN;
    }
}
