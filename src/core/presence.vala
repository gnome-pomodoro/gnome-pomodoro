/*
 * Copyright (c) 2013-2025 gnome-pomodoro contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
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
        DEFAULT = -1;

        public string to_string ()
        {
            switch (this)
            {
                case AVAILABLE:
                    return "available";

                case BUSY:
                    return "busy";

                case IDLE:
                    return "idle";

                case INVISIBLE:
                    return "invisible";

                default:
                    return "";
            }
        }

        public static PresenceStatus from_string (string? presence_status)
        {
            switch (presence_status)
            {
                case "available":
                    return PresenceStatus.AVAILABLE;

                case "busy":
                    return PresenceStatus.BUSY;

                case "idle":
                    return PresenceStatus.IDLE;

                case "invisible":
                    return PresenceStatus.INVISIBLE;

                default:
                    return PresenceStatus.DEFAULT;
            }
        }

        public string get_label ()
        {
            switch (this)
            {
                case AVAILABLE:
                    return _("Available");

                case BUSY:
                    return _("Busy");

                case IDLE:
                    return _("Idle");

                case INVISIBLE:
                    return _("Invisible");

                default:
                    return "";
           }
        }
    }
}
