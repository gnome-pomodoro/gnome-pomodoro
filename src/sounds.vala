/*
 * Copyright (c) 2013 gnome-shell-pomodoro contributors
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

private enum Pomodoro.EventType {
    POMODORO_START = 1,
    POMODORO_END = 2
}

internal class Pomodoro.Sounds : Object
{
    private unowned Pomodoro.Timer timer;
    private bool is_enabled = false;

    private Settings settings;
    private Canberra.Context context;

    public Sounds (Pomodoro.Timer timer)
    {
        this.timer = timer;

        var application = GLib.Application.get_default() as Pomodoro.Application;

        this.settings = application.settings as GLib.Settings;
        this.settings = this.settings.get_child ("preferences").get_child ("sounds");
        this.settings.changed.connect (this.on_settings_changed);

        this.ensure_context();

        this.on_settings_changed (this.settings, "enabled");
    }

    private void on_settings_changed (GLib.Settings settings, string key)
    {
        int status;
        string file_path;

        switch (key)
        {
            case "enabled":
                var enabled = settings.get_boolean ("enabled");

                if (enabled && !this.is_enabled) {
                    this.timer.notify_pomodoro_end.connect (this.on_notify_pomodoro_end);
                    this.timer.notify_pomodoro_start.connect (this.on_notify_pomodoro_start);
                }
                if (!enabled && this.is_enabled) {
                    SignalHandler.disconnect_by_func (this.timer,
                              (void*) this.on_notify_pomodoro_end, (void*) this);
                    SignalHandler.disconnect_by_func (this.timer,
                              (void*) this.on_notify_pomodoro_start, (void*) this);
                }
                this.is_enabled = enabled;
                break;

            case "pomodoro-end-sound":
                file_path = this.get_file_path ("pomodoro-end-sound");
                this.ensure_context();

                if (this.context != null) {
                    status = this.context.cache(
                            Canberra.PROP_EVENT_ID, "pomodoro-end",
                            Canberra.PROP_MEDIA_FILENAME, file_path);
                    if (status != Canberra.SUCCESS)
                        GLib.warning ("Couldn't update canberra cache - %s", Canberra.strerror(status));
                }
                break;
  
            case "pomodoro-start-sound":
                file_path = this.get_file_path ("pomodoro-start-sound");
                this.ensure_context();

                if (this.context != null) {
                    status = this.context.cache(
                            Canberra.PROP_EVENT_ID, "pomodoro-start",
                            Canberra.PROP_MEDIA_FILENAME, file_path);
                    if (status != Canberra.SUCCESS)
                        GLib.warning ("Couldn't update canberra cache - %s", Canberra.strerror(status));
                }
                break;
        }
    }

    private void ensure_context ()
    {
        int status;

        // Create context
        status = Canberra.Context.create (out this.context);

        if (status != Canberra.SUCCESS) {
            GLib.warning ("Couldn't create canberra context - %s", Canberra.strerror(status));
            return;
        }

        // Set properties about application
        status = this.context.change_props (
                Canberra.PROP_APPLICATION_NAME, Config.PACKAGE_NAME,
                Canberra.PROP_APPLICATION_ID, "org.gnome.Pomodoro");

        if (status != Canberra.SUCCESS) {
            GLib.warning ("Couldn't setup canberra context - %s", Canberra.strerror(status));
            return;
        }

        // Connect to the sound system
        status = this.context.open ();

        if (status != Canberra.SUCCESS) {
            GLib.warning ("Couldn't open canberra context - %s", Canberra.strerror(status));
            return;
        }
    }

    private string? get_file_path (string settings_key)
    {
        string uri = this.settings.get_string (settings_key);
        string path;

        try {
            path = Filename.from_uri (uri);
        }
        catch (ConvertError error) {
            path = uri;
        }

        if (!Path.is_absolute (path))
            path = Path.build_filename (Config.PACKAGE_DATA_DIR, "sounds", path);

        return path;
    }

    private void on_notify_pomodoro_start (bool is_requested)
    {
        int status;

        // Notify pomodoro start whether it was requested or not to take
        // advantage of Pavlovian conditioning

        this.ensure_context();

        if (this.context != null)
        {
            var file_path = this.get_file_path ("pomodoro-start-sound");

            status = this.context.play (EventType.POMODORO_START,
                    Canberra.PROP_EVENT_ID, "pomodoro-start",
                    Canberra.PROP_EVENT_DESCRIPTION, "Pomodoro started",
                    Canberra.PROP_MEDIA_FILENAME, file_path,
                    Canberra.PROP_MEDIA_ROLE, "event",
                    Canberra.PROP_CANBERRA_CACHE_CONTROL, "permanent");

            if (status != Canberra.SUCCESS)
                GLib.warning ("Couldn't play sound '%s' - %s", file_path, Canberra.strerror(status));
        }
    }

    private void on_notify_pomodoro_end (bool is_completed)
    {
        int status;

        this.ensure_context();

        if (this.context != null && is_completed)
        {
            var file_path = this.get_file_path ("pomodoro-end-sound");

            status = this.context.play (EventType.POMODORO_END,
                    Canberra.PROP_EVENT_ID, "pomodoro-end",
                    Canberra.PROP_EVENT_DESCRIPTION, "Pomodoro ended",
                    Canberra.PROP_MEDIA_FILENAME, file_path,
                    Canberra.PROP_MEDIA_ROLE, "event",
                    Canberra.PROP_CANBERRA_CACHE_CONTROL, "permanent");

            if (status != Canberra.SUCCESS)
                GLib.warning ("Couldn't play sound '%s' - %s", file_path, Canberra.strerror(status));
        }
    }
}

