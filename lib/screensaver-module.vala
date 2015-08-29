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


/* Command to wake up or power on the screen */
private const string SCREENSAVER_DEACTIVATE_COMMAND = "xdg-screensaver reset";


namespace Gnome
{
    [DBus (name = "org.gnome.ScreenSaver")]
    public interface ScreenSaver : Object
    {
        public abstract bool @lock () throws IOError;

        public abstract bool get_active () throws IOError;

        public abstract void set_active (bool active) throws IOError;

        public abstract uint get_active_time () throws IOError;

        public signal void active_changed (bool active);

        public signal void wake_up_screen ();
    }
}


public class Pomodoro.ScreenSaverModule : Pomodoro.Module
{
    private unowned Pomodoro.Timer timer;
    private GLib.Settings settings;
    private Gnome.ScreenSaver proxy;

    public ScreenSaverModule (Pomodoro.Timer timer)
    {
        this.timer = timer;

        this.settings = Pomodoro.get_settings ().get_child ("preferences");

        try {
            this.proxy = GLib.Bus.get_proxy_sync (GLib.BusType.SESSION,
                                                  "org.gnome.ScreenSaver",
                                                  "/org/gnome/ScreenSaver");
        }
        catch (Error e) {
            GLib.warning ("Failed to connect to org.gnome.ScreenSaver: %s",
                          e.message);
            return;
        }
    }

    public override void enable ()
    {
        if (!this.enabled) {
//            this.timer.notify_pomodoro_start.connect (this.on_notify_pomodoro_start);
//            this.timer.notify_pomodoro_end.connect (this.on_notify_pomodoro_end);
        }

        base.enable ();
    }

    public override void disable ()
    {
        if (this.enabled)
        {
            SignalHandler.disconnect_by_func (this.timer,
                                              (void*) this.on_notify_pomodoro_start,
                                              (void*) this);
            SignalHandler.disconnect_by_func (this.timer,
                                              (void*) this.on_notify_pomodoro_end,
                                              (void*) this);
        }

        base.disable ();
    }

    private void deactivate_screensaver ()
    {
        if (this.proxy != null) {
            try {
                this.proxy.wake_up_screen ();
            }
            catch (IOError error) {
                GLib.warning ("Failed to deactivate screensaver: %s", error.message);
            }
        }
        else {
            try {
                GLib.Process.spawn_command_line_async (
                        SCREENSAVER_DEACTIVATE_COMMAND);
            }
            catch (GLib.SpawnError error) {
                GLib.warning ("Failed to spawn process: %s", error.message);
            }
        }
    }

    private void on_notify_pomodoro_start (bool is_requested)
    {
        if (this.settings.get_boolean ("wake-up-screen")) {
            this.deactivate_screensaver ();
        }
    }

    private void on_notify_pomodoro_end (bool is_completed)
    {
        if (this.settings.get_boolean ("wake-up-screen")) {
            this.deactivate_screensaver ();
        }
    }
}
