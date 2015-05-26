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


public class Pomodoro.SkypePlugin : Pomodoro.PresencePlugin
{
    private Skype.Connection skype;
    private Pomodoro.PresenceStatus pending_status = Pomodoro.PresenceStatus.DEFAULT;

    public SkypePlugin ()
    {
        GLib.Object (label: "Skype",
                     name: "skype",
                     icon_name: "skype");
    }

    private bool has_pending_status ()
    {
        return this.pending_status != Pomodoro.PresenceStatus.DEFAULT;
    }

    private void set_pending_status (Pomodoro.PresenceStatus status)
    {
        this.pending_status = status;
    }

    private void unset_pending_status ()
    {
        this.pending_status = Pomodoro.PresenceStatus.DEFAULT;
    }

    private void on_skype_authenticated ()
    {
        if (this.has_pending_status ())
        {
            var status = this.pending_status;

            this.unset_pending_status ();

            this.set_status.begin (status);
        }
    }

    public override async void set_status (Pomodoro.PresenceStatus status)
    {
        // assert (this.enabled);

        if (this.enabled && this.skype != null)
        {
            try {
                var skype_status = this.convert_from_pomodoro_presence_status (status);

                yield this.skype.set_status (skype_status);
            }
            catch (Skype.Error error) {
                this.set_pending_status (status);
            }
        }
        else {
            this.set_pending_status (status);
        }
    }

    public override bool can_enable ()
    {
        /* check if installed */
        var path = GLib.Environment.find_program_in_path ("skype");

        return (path != null);
    }

    public override void enable ()
    {
        if (this.skype == null)
        {
            this.skype = new Skype.Connection (Config.PACKAGE_NAME);
            this.skype.authenticated.connect (this.on_skype_authenticated);

            base.enable ();
        }
    }

    public override void disable ()
    {
        base.disable ();

        this.unset_pending_status ();

        this.skype = null;
    }

    public void authenticate ()
    {
        try {
            if (this.skype != null) {
                this.skype.authenticate.begin ();
            }
        }
        catch (GLib.IOError error) {
            GLib.warning ("%s", error.message);
        }
    }

    private Skype.PresenceStatus convert_from_pomodoro_presence_status
                                       (Pomodoro.PresenceStatus status)
    {
        switch (status)
        {
            case Pomodoro.PresenceStatus.AVAILABLE:
                return Skype.PresenceStatus.ONLINE;

            case Pomodoro.PresenceStatus.BUSY:
                return Skype.PresenceStatus.DO_NOT_DISTURB;

            case Pomodoro.PresenceStatus.IDLE:
                return Skype.PresenceStatus.AWAY;

            case Pomodoro.PresenceStatus.INVISIBLE:
                return Skype.PresenceStatus.INVISIBLE;
        }

        return Skype.PresenceStatus.UNKNOWN;
    }
}
