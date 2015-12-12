/*
 * Copyright (c) 2013 gnome-pomodoro contributors
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
    public enum PresenceStatus
    {
        AVAILABLE = 0,
        INVISIBLE = 1,
        BUSY = 2,
        IDLE = 3,
        DEFAULT = -1
    }

    public string presence_status_to_string (PresenceStatus presence_status)
    {
        switch (presence_status)
        {
            case PresenceStatus.AVAILABLE:
                return "available";

            case PresenceStatus.INVISIBLE:
                return "invisible";

            case PresenceStatus.BUSY:
                return "busy";

            case PresenceStatus.IDLE:
                return "idle";
        }

        return "";
    }

    public PresenceStatus string_to_presence_status (string? presence_status)
    {
        switch (presence_status)
        {
            case "available":
                return PresenceStatus.AVAILABLE;

            case "invisible":
                return PresenceStatus.INVISIBLE;

            case "busy":
                return PresenceStatus.BUSY;

            case "idle":
                return PresenceStatus.IDLE;
        }

        return PresenceStatus.DEFAULT;
    }
}
