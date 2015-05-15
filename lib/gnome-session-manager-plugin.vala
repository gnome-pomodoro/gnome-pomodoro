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


public class Pomodoro.GnomeSessionManagerPlugin : Pomodoro.PresencePlugin
{
    private Gnome.SessionManager.Presence proxy;

    private bool ignore_next_status = false;

//    public GnomeSessionManagerPlugin ()
//    {
//        base ();
//    }

    private void on_status_changed (uint status)
    {
        if (this.ignore_next_status)
        {
            var presence_status = this.convert_to_pomodoro_presence_status (
                                        (Gnome.SessionManager.PresenceStatus) status);

    //        if (this.default_status = )
            this.status_changed (presence_status);

            this.ignore_next_status = false;
        }
    }

    public override void enable ()
    {
        try {
            this.proxy = GLib.Bus.get_proxy_sync (GLib.BusType.SESSION,
                                                  "org.gnome.SessionManager",
                                                  "/org/gnome/SessionManager/Presence");

            this.proxy.status_changed.connect (this.on_status_changed);
        }
        catch (Error error) {
            GLib.warning ("%s", error.message);
        }

        base.enable ();
    }

    public override void disable ()
    {
        this.proxy = null;

        base.disable ();
    }

    public Pomodoro.PresenceStatus get_default_status (Pomodoro.State timer_state)
    {
        var settings = this.global_settings;
        var settings_key = timer_state == State.POMODORO
                                       ? "presence-during-pomodoro"
                                       : "presence-during-break";

        return string_to_presence_status (settings.get_string (settings_key));
    }    

    public Pomodoro.PresenceStatus get_status ()
    {
        var status = (Gnome.SessionManager.PresenceStatus) this.proxy.status;

        return this.convert_to_pomodoro_presence_status (status);
    }

    public override async void set_status (Pomodoro.PresenceStatus status)
    {
        this.ignore_next_status = true;
//        if (status == Pomodoro.PresenceStatus.DEFAULT) {
//            this.proxy.status = (Gnome.SessionManager.PresenceStatus) this.previous_status;
//        }
//        else {
        this.proxy.status = this.convert_from_pomodoro_presence_status (status);
//        }
    }

    private Gnome.SessionManager.PresenceStatus convert_from_pomodoro_presence_status
                                       (Pomodoro.PresenceStatus status)
    {
        switch (status)
        {
            case Pomodoro.PresenceStatus.AVAILABLE:
                return Gnome.SessionManager.PresenceStatus.AVAILABLE;

            case Pomodoro.PresenceStatus.BUSY:
                return Gnome.SessionManager.PresenceStatus.BUSY;

            case Pomodoro.PresenceStatus.IDLE:
                return Gnome.SessionManager.PresenceStatus.IDLE;

            case Pomodoro.PresenceStatus.INVISIBLE:
                return Gnome.SessionManager.PresenceStatus.INVISIBLE;
        }

        return Gnome.SessionManager.PresenceStatus.DEFAULT;
    }

    private Pomodoro.PresenceStatus convert_to_pomodoro_presence_status
                                       (Gnome.SessionManager.PresenceStatus status)
    {
        switch (status)
        {
            case Gnome.SessionManager.PresenceStatus.AVAILABLE:
                return Pomodoro.PresenceStatus.AVAILABLE;

            case Gnome.SessionManager.PresenceStatus.BUSY:
                return Pomodoro.PresenceStatus.BUSY;

            case Gnome.SessionManager.PresenceStatus.IDLE:
                return Pomodoro.PresenceStatus.IDLE;

            case Gnome.SessionManager.PresenceStatus.INVISIBLE:
                return Pomodoro.PresenceStatus.INVISIBLE;
        }

        return Pomodoro.PresenceStatus.DEFAULT;
    }

    public signal void status_changed (Pomodoro.PresenceStatus presence_status);
}
