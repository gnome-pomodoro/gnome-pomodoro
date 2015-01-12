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
    public enum PresenceStatus {
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
}


class Pomodoro.TelepathyPresence : Object
{
    protected TelepathyGLib.AccountManager account_manager;

    public TelepathyPresence ()
    {
        this.account_manager = TelepathyGLib.AccountManager.dup ();
    }

    public void set_status (Pomodoro.PresenceStatus status)
    {
        string message;
        string status_string;

        var type = this.account_manager.get_most_available_presence (
                                       out status_string,
                                       out message);
        var new_type = TelepathyGLib.ConnectionPresenceType.UNSET;
        var new_status_string = "";

        if (status == Pomodoro.PresenceStatus.BUSY &&
            type == TelepathyGLib.ConnectionPresenceType.AVAILABLE)
        {
            new_type = TelepathyGLib.ConnectionPresenceType.BUSY;
            new_status_string = "busy";
        } else if (status == Pomodoro.PresenceStatus.AVAILABLE &&
                   type == TelepathyGLib.ConnectionPresenceType.BUSY)
        {
            new_type = TelepathyGLib.ConnectionPresenceType.AVAILABLE;
            new_status_string = "available";
        }

        if (new_type != TelepathyGLib.ConnectionPresenceType.UNSET) {
            this.account_manager.set_all_requested_presences (new_type,
                                                              new_status_string,
                                                              message);
        }
    }
}


private class Pomodoro.SkypePlugin : Object
{
    private Skype.Api skype_api;
    private Pomodoro.PresenceStatus pending_status;

    public SkypePlugin ()
    {
        this.pending_status = Pomodoro.PresenceStatus.DEFAULT;

        this.skype_api = new Skype.Api (Config.PACKAGE_NAME);

        this.skype_api.authenticated.connect (this.on_skype_authenticated);

        this.skype_api.authenticate ();
    }

    private bool has_pending_status ()
    {
        return this.pending_status != Pomodoro.PresenceStatus.DEFAULT;
    }

    private void set_pending_status (Pomodoro.PresenceStatus status)
    {
        this.pending_status = status;

        /* TODO: schedule changing status later */
    }

    private void unset_pending_status ()
    {
        this.pending_status = Pomodoro.PresenceStatus.DEFAULT;
    }

    private void on_skype_authenticated ()
    {
        if (this.has_pending_status ())
        {
            this.set_status (this.pending_status);
            this.unset_pending_status ();
        }
    }

    public void set_status (Pomodoro.PresenceStatus status)
    {
        var skype_status = this.convert_presence_status (status);

        if (this.skype_api.is_authenticated)
        {
            try {
                this.skype_api.set_status (skype_status);
            }
            catch (Skype.Error error) {
                this.set_pending_status (status);
            }
        }
        else {
            this.set_pending_status (status);
        }
    }

    private Skype.PresenceStatus convert_presence_status
                                       (Pomodoro.PresenceStatus status)
    {
        switch (status)
        {
            case PresenceStatus.AVAILABLE:
                return Skype.PresenceStatus.ONLINE;

            case PresenceStatus.BUSY:
                return Skype.PresenceStatus.DO_NOT_DISTURB;

            case PresenceStatus.IDLE:
                return Skype.PresenceStatus.AWAY;

            case PresenceStatus.INVISIBLE:
                return Skype.PresenceStatus.INVISIBLE;
        }

        return Skype.PresenceStatus.UNKNOWN;
    }
}


public class Pomodoro.PresenceModule : Pomodoro.Module
{
    private unowned Pomodoro.Timer timer;
    private Pomodoro.TelepathyPresence telepathy_presence;
    private Pomodoro.SkypePlugin skype_plugin;

    private GLib.Settings settings;
    private Gnome.SessionManager.Presence proxy;
    private PresenceStatus previous_status;
    private PresenceStatus status;

    private bool ignore_next_status;

    public PresenceModule (Pomodoro.Timer timer)
    {
        this.timer = timer;

        this.settings = Pomodoro.get_settings ().get_child ("preferences");
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

        this.enable ();
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

    private void on_timer_state_changed (Pomodoro.Timer timer)
    {
//        var status = string_to_presence_status (
//                this.settings.get_string ("presence-during-pomodoro"));

//        var status = string_to_presence_status (
//                this.settings.get_string ("presence-during-break"));

        this.set_status (timer.state == Pomodoro.State.POMODORO
                                       ? PresenceStatus.BUSY
                                       : PresenceStatus.AVAILABLE);
    }

    public new void enable ()
    {
        this.telepathy_presence = new Pomodoro.TelepathyPresence ();
        this.skype_plugin = new Pomodoro.SkypePlugin ();

        this.timer.state_changed.connect (this.on_timer_state_changed);

        this.on_timer_state_changed (this.timer);
    }

    public new void disable ()
    {
        this.telepathy_presence = null;
        this.skype_plugin = null;

        SignalHandler.disconnect_by_func (this.timer,
                                          (void*) this.on_timer_state_changed, (void*) this);

        /* TODO: Restore user status on exit */
    }

    public void set_status (Pomodoro.PresenceStatus status)
    {
        assert (this.proxy != null);

        this.ignore_next_status = true;

        if (status == Pomodoro.PresenceStatus.DEFAULT) {
            this.proxy.status = (Gnome.SessionManager.PresenceStatus) this.previous_status;
        }
        else {
            this.proxy.status = (Gnome.SessionManager.PresenceStatus) status;
        }

        this.telepathy_presence.set_status (status);
        this.skype_plugin.set_status (status);
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
    [CCode (has_target = false)]
    public static Variant set_status_mapping (GLib.Value       value,
                                              GLib.VariantType expected_type,
                                              void*            user_data)
    {
        var status = (PresenceStatus) value.get_int ();

        return new Variant.string (presence_status_to_string (status));
    }
}
