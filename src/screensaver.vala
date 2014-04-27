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


/* Command to wake up or power on the screen */
private const string SCREENSAVER_DEACTIVATE_COMMAND = "xdg-screensaver reset";


namespace Gnome
{
    [DBus (name = "org.gnome.ScreenSaver")]
    interface ScreenSaver : Object
    {
        public abstract bool @lock () throws IOError;

        public abstract bool get_active () throws IOError;

        public abstract void set_active (bool active) throws IOError;

        public abstract uint get_active_time () throws IOError;

        public signal void active_changed (bool active);

        public signal void wake_up_screen ();
    }
}


public class Pomodoro.ScreenSaver : Object
{
    private unowned Pomodoro.Timer timer;
    private GLib.Settings settings;
    private Gnome.ScreenSaver proxy;

    public ScreenSaver (Pomodoro.Timer timer)
    {
        this.timer = timer;

        var application = GLib.Application.get_default () as Pomodoro.Application;

        this.settings = application.settings as GLib.Settings;
        this.settings = this.settings.get_child ("preferences");
        this.settings.changed.connect (this.on_settings_changed);

        try {
            this.proxy = GLib.Bus.get_proxy_sync (GLib.BusType.SESSION,
                                                  "org.gnome.ScreenSaver",
                                                  "/org/gnome/ScreenSaver");
        }
        catch (Error e) {
            stderr.printf ("%s\n", e.message);

            return;
        }

        this.enable ();
    }

    ~ScreenSaver ()
    {
        this.disable ();
    }

    public void enable ()
    {
        this.timer.notify_pomodoro_start.connect (
                this.on_notify_pomodoro_start);
        this.timer.notify_pomodoro_end.connect (
                this.on_notify_pomodoro_end);
    }

    public void disable ()
    {
        SignalHandler.disconnect_by_func (this.timer,
                  (void*) this.on_notify_pomodoro_start, (void*) this);
        SignalHandler.disconnect_by_func (this.timer,
                  (void*) this.on_notify_pomodoro_end, (void*) this);
    }

    private void deactivate_screensaver ()
    {
        try {
            GLib.Process.spawn_command_line_async (
                    SCREENSAVER_DEACTIVATE_COMMAND);
        }
        catch (GLib.SpawnError error) {
            warning ("Failed to spawn process - %s", error.message);
        }

        /* TODO: In GNOME 3.8 set_active(false) does not wake up the screen...
         */
        // try {
        //     this.proxy.set_active (false);
        // }
        // catch (IOError error) {
        //     warning ("Failed to deactivate screensaver - %s", error.message);
        // }
    }

    private void on_settings_changed (GLib.Settings settings,
                                      string        key)
    {
        switch (key)
        {
            case "pomodoro-start-deactivate-screensaver":
                break;

            case "pomodoro-end-deactivate-screensaver":
                break;
        }
    }

    private void on_notify_pomodoro_start (bool is_requested)
    {
        if (this.settings.get_boolean ("pomodoro-start-deactivate-screensaver")) {
            this.deactivate_screensaver ();
        }
    }

    private void on_notify_pomodoro_end (bool is_completed)
    {
        if (this.settings.get_boolean ("pomodoro-end-deactivate-screensaver")) {
            this.deactivate_screensaver ();
        }
    }
}
