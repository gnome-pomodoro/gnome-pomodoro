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


public class Pomodoro.PresenceModule : Pomodoro.Module
{
    private unowned Pomodoro.Timer    timer;
    private GLib.Settings             settings;

    public PresenceModule (Pomodoro.Timer timer)
    {
        GLib.Object (name: "presence");

        this.timer = timer;

        this.settings = Pomodoro.get_settings ().get_child ("preferences");
        this.settings.changed.connect (this.on_settings_changed);
    }

    private void on_settings_changed (GLib.Settings settings,
                                      string        key)
    {
        switch (key)
        {
            case "presence-during-pomodoro":
                var status = string_to_presence_status (
                                                this.settings.get_string (key));
                if (this.timer.state == State.POMODORO) {
                    this.set_status (status);
                }
                break;

            case "presence-during-break":
                var status = string_to_presence_status (
                                                this.settings.get_string (key));
                if (this.timer.state != State.POMODORO) {
                    this.set_status (status);
                }
                break;

            case "change-presence-status":
                this.enable_plugins ();
                break;
        }
    }

    private void on_timer_state_changed (Pomodoro.Timer timer)
    {
        var status_string = timer.state == Pomodoro.State.POMODORO
                        ? this.settings.get_string ("presence-during-pomodoro")
                        : this.settings.get_string ("presence-during-break");

        this.set_status (string_to_presence_status (status_string));
    }


    private void enable_plugin (Pomodoro.Plugin plugin)
    {
        if (!plugin.enabled) {
            var status = string_to_presence_status (
                        this.timer.state == Pomodoro.State.POMODORO
                        ? this.settings.get_string ("presence-during-pomodoro")
                        : this.settings.get_string ("presence-during-break"));

            plugin.enable ();

            (plugin as Pomodoro.PresencePlugin).set_status (status);
        }
    }

    private void disable_plugin (Pomodoro.Plugin plugin)
    {
        if (plugin.enabled) {
            var status = string_to_presence_status (
                        this.settings.get_string ("presence-during-break"));

            (plugin as Pomodoro.PresencePlugin).set_status (status);

            plugin.disable ();
        }
    }

    private void enable_plugins ()
    {
        foreach (var plugin in this.plugins)
        {
            if ((plugin is Pomodoro.GnomeSessionManagerPlugin) ||
                (this.settings.get_boolean ("change-presence-status")))
            {
                this.enable_plugin (plugin);
            }
            else {
                this.disable_plugin (plugin);
            }
        }
    }

    public override void enable ()
    {
        if (!this.enabled) {
            this.plugins.append (new Pomodoro.GnomeSessionManagerPlugin ());
            this.plugins.append (new Pomodoro.TelepathyPlugin ());
            this.plugins.append (new Pomodoro.SkypePlugin ());

            this.enable_plugins ();

            this.timer.state_changed.connect (this.on_timer_state_changed);
            this.on_timer_state_changed (this.timer);
        }

        base.enable ();
    }

    public override void disable ()
    {
        if (this.enabled)
        {
            SignalHandler.disconnect_by_func (this.timer,
                                              (void*) this.on_timer_state_changed, (void*) this);

            foreach (var plugin in this.plugins) {
                this.disable_plugin (plugin);
            }

            this.plugins = null;
        }

        base.disable ();
    }

    public void set_status (Pomodoro.PresenceStatus status)
    {
        foreach (var item in this.plugins)
        {
            var plugin = item as Pomodoro.PresencePlugin;

            if (!plugin.enabled) {
                continue;
            }

            if (plugin is Pomodoro.GnomeSessionManagerPlugin) {
                plugin.set_status.begin (
                                   this.timer.state == Pomodoro.State.POMODORO
                                   ? Pomodoro.PresenceStatus.BUSY
                                   : Pomodoro.PresenceStatus.AVAILABLE);
            }
            else {
                plugin.set_status.begin (status);
            }
        }
    }
}
