/*
 * Copyright (c) 2024-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;


namespace Ft
{
    private class TimezoneEntry : Gom.Resource
    {
        public int64 id { get; set; }
        public int64 time { get; set; }
        public string identifier { get; set; }

        static construct
        {
            set_table ("timezones");
            set_primary_key ("id");
            set_unique ("time");
            set_notnull ("time");
            set_notnull ("identifier");
        }
    }
}
