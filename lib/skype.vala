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


namespace Skype
{
    public enum PresenceStatus
    {
        UNKNOWN = 0,
        ONLINE = 1,
        OFFLINE = 2,
        AWAY = 3,
        NOT_AVAILABLE = 4,
        DO_NOT_DISTURB = 5,
        INVISIBLE = 6,
        LOGGED_OUT = 7
    }

    public errordomain Error
    {
        CONNECTION,
        NOT_AUTHENTICATED
    }

    public string presence_status_to_string (PresenceStatus presence_status)
    {
        switch (presence_status)
        {
            case PresenceStatus.ONLINE:
                return "ONLINE";

            case PresenceStatus.OFFLINE:
                return "OFFLINE";

            case PresenceStatus.AWAY:
                return "AWAY";

            case PresenceStatus.NOT_AVAILABLE:
                return "NA";

            case PresenceStatus.DO_NOT_DISTURB:
                return "DND";

            case PresenceStatus.INVISIBLE:
                return "INVISIBLE";

            case PresenceStatus.LOGGED_OUT:
                return "LOGGEDOUT";
        }

        return "UNKNOWN";
    }

    public PresenceStatus string_to_presence_status (string presence_status)
    {
        switch (presence_status)
        {
            case "ONLINE":
                return PresenceStatus.ONLINE;

            case "OFFLINE":
                return PresenceStatus.OFFLINE;

            case "AWAY":
                return PresenceStatus.AWAY;

            case "NA":
                return PresenceStatus.NOT_AVAILABLE;

            case "DND":
                return PresenceStatus.DO_NOT_DISTURB;

            case "INVISIBLE":
                return PresenceStatus.INVISIBLE;

            case "LOGGEDOUT":
                return PresenceStatus.LOGGED_OUT;
        }

        return PresenceStatus.UNKNOWN;
    }

    [DBus (name = "com.Skype.API")]
    public interface ApiInterface : Object
    {
        public abstract async string invoke (string request) throws IOError;
    }

    public class Api : Object
    {
        public string application_name { get; construct set; }
        public bool is_authenticated { get; set; default=false; }

        private static uint PROTOCOL_VERSION = 5;
        private ApiInterface proxy;

        public Api (string application_name)
        {
            this.application_name = application_name;

            try {
                this.proxy = Bus.get_proxy_sync (BusType.SESSION,
                                                 "com.Skype.API",
                                                 "/com/Skype");
            }
            catch (GLib.IOError error) {
                GLib.warning ("%s", error.message);
            }
        }

        public async void authenticate () throws Skype.Error
        {
            string response;

            try {
                response = yield this.proxy.invoke ("NAME " + this.application_name);

                switch (response)
                {
                    case "OK":
                        try {
                            yield this.proxy.invoke ("PROTOCOL " +
                                                     PROTOCOL_VERSION.to_string ());

                            this.is_authenticated = true;

                            this.authenticated ();
                        }
                        catch (GLib.IOError error) {
                            GLib.warning ("Failed to initialize skype protocol: %s",
                                          error.message);
                        }

                        break;

                    case "ERROR 68":
                        /* user not gave permission */
                        break;
                }
            }
            catch (GLib.IOError error) {
                throw new Skype.Error.CONNECTION (error.message);
            }
        }

        private void assert_authenticated () throws Skype.Error
        {
            if (!this.is_authenticated) {
                throw new Skype.Error.NOT_AUTHENTICATED ("Skype is not authenticated");
            }
        }

        public async void set_status (PresenceStatus status) throws Skype.Error
        {
            var status_string = presence_status_to_string (status);

            this.assert_authenticated ();
     
            try {
                yield this.proxy.invoke ("SET USERSTATUS " + status_string);
            }
            catch (GLib.IOError error) {
                throw new Skype.Error.CONNECTION (error.message);
            }
        }

        public async void set_auto_away (bool enabled) throws Skype.Error
        {
            var enabled_string = enabled ? "ON" : "OFF";

            this.assert_authenticated ();

            try {
                yield this.proxy.invoke ("SET AUTOAWAY " + enabled_string);
            }
            catch (GLib.IOError error) {
                throw new Skype.Error.CONNECTION (error.message);
            }
        }

        public async void reset_idle_timer () throws Skype.Error
        {
            this.assert_authenticated ();

            try {
                yield this.proxy.invoke ("RESETIDLETIMER");
            }
            catch (GLib.IOError error) {
                throw new Skype.Error.CONNECTION (error.message);
            }
        }

        public signal void authenticated ();
    }
}
