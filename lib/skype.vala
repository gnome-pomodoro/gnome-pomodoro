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
        UNKNOWN,
        ONLINE,
        OFFLINE,
        AWAY,
        NOT_AVAILABLE,
        DO_NOT_DISTURB,
        INVISIBLE,
        LOGGED_OUT
    }

    public enum AuthenticationStatus
    {
        DISCONNECTED,
        CONNECTING,
        CONNECTED,
        AUTHENTICATING,
        AUTHENTICATED
    }

    public errordomain Error
    {
        CONNECTION,
        AUTHENTICATION
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
    public interface Api : GLib.Object
    {
        public abstract async string invoke (string request) throws IOError;
    }

    public class Connection : GLib.Object
    {
        public string application_name;

        private Api proxy;
        private AuthenticationStatus status;
        private uint name_watcher_id = 0;

        private static uint PROTOCOL_VERSION = 5;

        public Connection (string application_name)
        {
            this.application_name = application_name;

            this.proxy = null;
            this.status = AuthenticationStatus.DISCONNECTED;

            this.name_watcher_id = GLib.Bus.watch_name (
                                       GLib.BusType.SESSION,
                                       "com.Skype.API",
                                       GLib.BusNameWatcherFlags.NONE,
                                       () => { this.connect (); } ,
                                       () => { this.disconnect (); });
        }

        ~Connection () {
            if (this.name_watcher_id != 0) {
                GLib.Bus.unwatch_name (this.name_watcher_id);
            }
        }

        /* hides GLib.Object.connect */
        public new void connect ()
        {
            if (this.proxy == null &&
                this.status != AuthenticationStatus.CONNECTING)
            {
                try {
                    this.status = AuthenticationStatus.CONNECTING;
                    this.proxy = GLib.Bus.get_proxy_sync (GLib.BusType.SESSION,
                                                          "com.Skype.API",
                                                          "/com/Skype");
                    this.status = AuthenticationStatus.CONNECTED;

                    this.connected ();
                }
                catch (GLib.IOError error) {
                    GLib.warning ("%s", error.message);

                    this.disconnect ();
                }
            }
        }

        /* hides GLib.Object.disconnect */
        public new void disconnect ()
        {
            var previous_status = this.status;

            this.proxy = null;
            this.status = AuthenticationStatus.DISCONNECTED;

            if (previous_status != AuthenticationStatus.DISCONNECTED &&
                previous_status != AuthenticationStatus.CONNECTING)
            {
                this.disconnected ();
            }
        }

        public bool is_connected ()
        {
            return this.status == AuthenticationStatus.CONNECTED ||
                   this.status == AuthenticationStatus.AUTHENTICATING ||
                   this.status == AuthenticationStatus.AUTHENTICATED;
        }

        public bool is_authenticated ()
        {
            return this.status == AuthenticationStatus.AUTHENTICATED;
        }

        private bool on_authenticate_timeout ()
        {
            if (this.status == AuthenticationStatus.AUTHENTICATING)
            {
                try {
                    this.status = AuthenticationStatus.CONNECTED;
                    this.authenticate.begin ();
                }
                catch (GLib.IOError error) {
                    GLib.warning ("%s", error.message);
                }
            }

            return false;
        }

        public async void authenticate () throws Skype.Error
        {
            if (this.status == AuthenticationStatus.AUTHENTICATED ||
                this.status == AuthenticationStatus.AUTHENTICATING)
            {
                /* FIXME: should return only if authentication ended */
                return;
            }

            if (this.status == AuthenticationStatus.DISCONNECTED)
            {
                this.connect ();
            }

            assert (this.status == AuthenticationStatus.CONNECTED);

            try {
                this.status = AuthenticationStatus.AUTHENTICATING;

                var response = yield this.proxy.invoke ("NAME " + this.application_name);
                var response_type = response.split (" ")[0];

                switch (response_type)
                {
                    case "OK":
                        response = yield this.proxy.invoke ("PROTOCOL " +
                                                 PROTOCOL_VERSION.to_string ());

                        this.status = AuthenticationStatus.AUTHENTICATED;
                        this.authenticated ();

                        break;

                    case "CONNSTATUS":
                        GLib.Timeout.add_seconds (1, this.on_authenticate_timeout);

                        break;

                    default:
                        /* Rejected authorization */
                        this.status = AuthenticationStatus.CONNECTED;

                        break;
                }
            }
            catch (GLib.IOError error) {
                throw new Skype.Error.CONNECTION (error.message);
            }
        }

        private void assert_authenticated () throws Skype.Error
        {
            if (this.status != AuthenticationStatus.AUTHENTICATED) {
                throw new Skype.Error.AUTHENTICATION ("Skype is not authenticated");
            }
        }

        public async void set_status (PresenceStatus status) throws Skype.Error
        {
            this.assert_authenticated ();
     
            try {
                var status_string = presence_status_to_string (status);

                yield this.proxy.invoke ("SET USERSTATUS " + status_string);
            }
            catch (GLib.IOError error) {
                throw new Skype.Error.CONNECTION (error.message);
            }
        }

        public async void set_auto_away (bool enabled) throws Skype.Error
        {
            this.assert_authenticated ();

            try {
                var enabled_string = enabled ? "ON" : "OFF";

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

        public virtual signal void connected ()
        {
            if (this.status == AuthenticationStatus.CONNECTED)
            {
                try {
                    this.authenticate.begin ();
                }
                catch (GLib.IOError error) {
                    GLib.warning ("%s", error.message);
                }
            }
        }

        public virtual signal void disconnected ()
        {
        }

        public virtual signal void authenticated ()
        {
        }
    }
}
