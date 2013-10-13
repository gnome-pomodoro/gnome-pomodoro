/*
 * Copyright (c) 2013 gnome-pomodoro contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;
using Gnome.SessionManager;


namespace Gnome.SessionManager
{
    public enum PresenceStatus {
        AVAILABLE = 0,
        INVISIBLE = 1,
        BUSY = 2,
        IDLE = 3,
        DEFAULT = -1
    }

    [DBus (name = "org.gnome.SessionManager.Presence")]
    interface Presence : Object
    {
        public abstract uint status { get; set; }

        public signal void status_changed (uint status);
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

    public PresenceStatus string_to_presence_status (string presence_status)
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


class Pomodoro.Presence : Object
{
    private unowned Pomodoro.Timer timer;
    private GLib.Settings settings;
    private Gnome.SessionManager.Presence proxy;
    private PresenceStatus previous_status;
    private PresenceStatus status;

    private bool ignore_next_status;

    public Presence (Pomodoro.Timer timer)
    {
        this.timer = timer;

        var application = GLib.Application.get_default () as Pomodoro.Application;

        this.settings = application.settings as GLib.Settings;
        this.settings = this.settings.get_child ("preferences");
        this.settings.changed.connect (this.on_settings_changed);

        this.ignore_next_status = false;

        try {
            this.proxy = GLib.Bus.get_proxy_sync (GLib.BusType.SESSION,
                                                  "org.gnome.SessionManager",
                                                  "/org/gnome/SessionManager/Presence");

            this.status = (PresenceStatus) this.proxy.status;
            this.previous_status = this.status;

            this.proxy.status_changed.connect (this.on_status_changed);
        }
        catch (Error e) {
            stderr.printf ("%s\n", e.message);

            return;
        }

        this.timer.pomodoro_start.connect (this.on_timer_pomodoro_start);
        this.timer.pomodoro_end.connect (this.on_timer_pomodoro_end);
    }

    ~Presence ()
    {
        /* TODO: Restore user status on exit */
    }

    private void on_settings_changed (GLib.Settings settings,
                                      string        key)
    {
        switch (key)
        {
            case "presence-during-pomodoro":
                var status = string_to_presence_status (
                                                this.settings.get_string (key));
                if (timer.state == State.POMODORO) {
                    this.set_status (status);
                }
                break;

            case "presence-during-break":
                var status = string_to_presence_status (
                                                this.settings.get_string (key));
                if (timer.state != State.POMODORO) {
                    this.set_status (status);
                }
                break;
        }
    }

    private void on_status_changed (uint status)
    {
        if (!this.ignore_next_status)
        {
            this.previous_status = this.status;
            this.status = (PresenceStatus) status;

            this.ignore_next_status = false;
        }
    }

    private void on_timer_pomodoro_start (bool is_requested)
    {
        var status = string_to_presence_status (
                this.settings.get_string ("presence-during-pomodoro"));

        this.set_status (status);
    }

    private void on_timer_pomodoro_end (bool is_completed)
    {
        var status = string_to_presence_status (
                this.settings.get_string ("presence-during-break"));

        this.set_status (status);
    }

    public void set_status (PresenceStatus status)
    {
        assert (this.proxy != null);

        this.ignore_next_status = true;

        if (status == PresenceStatus.DEFAULT) {
            this.proxy.status = this.previous_status;
        }
        else {
            this.proxy.status = status;
        }
    }

    /* mapping from settings to presence combobox */
    public static bool get_status_mapping (GLib.Value   value,
                                           GLib.Variant variant,
                                           void*        user_data)
    {
        var status = string_to_presence_status (variant.get_string ());

        value.set_int ((int) status);

        return true;
    }

    /* mapping from presence combobox to settings */
    public static Variant set_status_mapping (GLib.Value       value,
                                              GLib.VariantType expected_type,
                                              void*            user_data)
    {
        var status = PresenceStatus.DEFAULT;

        status = (PresenceStatus) value.get_int ();

        return new Variant.string (presence_status_to_string (status));
    }
}
