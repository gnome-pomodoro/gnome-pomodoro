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
using Gnome;


namespace Gnome
{
    public const string SHELL_SCHEMA = "org.gnome.shell";
    public const string SHELL_ENABLED_EXTENSIONS_KEY = "enabled-extensions";

    private const string DESKTOP_SESSION_ENV_VARIABLE = "DESKTOP_SESSION";

    private enum ExtensionState {
        ENABLED = 1,
        DISABLED = 2,
        ERROR = 3,
        OUT_OF_DATE = 4,

        /* Used as an error state for operations on unknown extensions,
         * should never be in a real extensionMeta object.
         */
        UNINSTALLED = 99
    }

    [DBus (name = "org.gnome.Shell")]
    interface Shell : Object
    {
        /* TODO: Add "result" attribute, seems to be a collision at C level */
        public abstract bool eval (string script)
                                   throws IOError;

        public abstract bool grab_accelerator
                                       (string accelerator,
                                        uint32 flags,
                                        out uint action)
                                        throws IOError;

        public abstract bool ungrab_accelerator
                                       (uint32 action,
                                        out bool success)
                                        throws IOError;

        public signal void accelerator_activated
                                       (uint32 action,
                                        uint32 device_id,
                                        uint32 timestamp);

        public abstract bool @lock () throws IOError;

        public abstract bool get_active () throws IOError;

        public abstract void set_active (bool active) throws IOError;

        public abstract uint get_active_time () throws IOError;

        public signal void active_changed (bool active);
    }

    [DBus (name = "org.gnome.Shell.Extensions")]
    interface ShellExtensions : Object
    {
        public abstract void get_extension_info
                                       (string uuid,
                                        out HashTable<string,Variant> info)
                                        throws IOError;

        public abstract void get_extension_errors
                                       (string uuid,
                                        out string[] errors)
                                        throws IOError;

        public abstract void reload_extension
                                       (string uuid)
                                        throws IOError;

        public signal void extension_status_changed (string uuid,
                                                     int state,
                                                     string error);
    }
}


public class Pomodoro.GnomeDesktop : Object
{
    private unowned Pomodoro.Timer timer;

    private Gnome.Shell shell_proxy;
    private Gnome.ShellExtensions shell_extensions_proxy;

    public GnomeDesktop (Pomodoro.Timer timer)
    {
        this.timer = timer;

        this.enable ();
    }

    private void on_extension_status_changed (string uuid,
                                              int state,
                                              string error)
    {
        if (uuid == Config.EXTENSION_UUID) {
            GLib.debug ("Extension \"%s\" changed status to \"%d\"",
                        uuid,
                        state);
        }
    }

    public void enable ()
    {
        try {
            if (this.shell_proxy == null) {
                this.shell_proxy =
                        GLib.Bus.get_proxy_sync (GLib.BusType.SESSION,
                                                 "org.gnome.Shell",
                                                 "/org/gnome/Shell");
            }

            if (this.shell_extensions_proxy == null) {
                this.shell_extensions_proxy =
                        GLib.Bus.get_proxy_sync (GLib.BusType.SESSION,
                                                 "org.gnome.Shell",
                                                 "/org/gnome/Shell");

                this.shell_extensions_proxy.extension_status_changed.connect (
                        this.on_extension_status_changed);
            }
        }
        catch (IOError error) {
            GLib.warning (error.message);
        }

        if (GnomeDesktop.can_enable ()) {
            this.enable_extension (Config.EXTENSION_UUID,
                                   Config.PACKAGE_VERSION);
        }
    }

    public void disable ()
    {
        this.shell_proxy = null;
        this.shell_extensions_proxy = null;
    }

    static bool can_enable () {
        var desktop_session = GLib.Environment.get_variable
                                       (DESKTOP_SESSION_ENV_VARIABLE);

        return desktop_session == "gnome";
    }

    private ExtensionState get_extension_state (string  extension_uuid,
                                                string? extension_path,
                                                string? extension_version)
    {
        HashTable<string,Variant> info;

        var uuid = "";
        var version = "";
        var state = ExtensionState.ERROR;
        var path = "";

        try {
            this.shell_extensions_proxy.get_extension_info (extension_uuid,
                                                            out info);

            var tmp_uuid = info.lookup ("uuid");
            var tmp_version = info.lookup ("version");
            var tmp_state = info.lookup ("state");
            var tmp_path = info.lookup ("path");

            if (tmp_uuid != null) {
                uuid = tmp_uuid.get_string();
            }

            if (tmp_version != null) {
                version = tmp_version.get_string();
            }

            if (tmp_state != null) {
                state = (ExtensionState) tmp_state.get_double();
            }

            if (tmp_path != null) {
                path = tmp_path.get_string();
            }
        }
        catch (IOError error) {
            return ExtensionState.ERROR;
        }

        if (uuid != extension_uuid) {
            return ExtensionState.UNINSTALLED;
        }

        if (extension_path != "" && path != extension_path) {
            return ExtensionState.UNINSTALLED;
        }

        if (extension_version != "" && version != extension_version) {
            return ExtensionState.OUT_OF_DATE;
        }

        return state;
    }

    public void enable_extension (string extension_uuid,
                                  string extension_version)
    {
        var extension_is_enabled = false;

        var gnome_shell_settings = new GLib.Settings (Gnome.SHELL_SCHEMA);
        var enabled_extensions = gnome_shell_settings.get_strv
                                       (Gnome.SHELL_ENABLED_EXTENSIONS_KEY);

        foreach (var uuid in enabled_extensions)
        {
            if (uuid == extension_uuid) {
                extension_is_enabled = true;
            }
        }

        if (!extension_is_enabled)
        {
            enabled_extensions += extension_uuid;
            gnome_shell_settings.set_strv ("enabled-extensions",
                                           enabled_extensions);
        }

        try
        {
            var extension_path = GLib.Path.build_filename (Config.DATA_DIR,
                                                           "gnome-shell",
                                                           "extensions",
                                                           extension_uuid);
            var extension_state = this.get_extension_state (extension_uuid,
                                                            extension_path,
                                                            extension_version);

            switch (extension_state)
            {
                case ExtensionState.ENABLED:
                case ExtensionState.ERROR:
                    break;

                case ExtensionState.OUT_OF_DATE:
                    this.shell_extensions_proxy.reload_extension
                                       (extension_uuid);
                    break;

                default:
                    /* try to enable extension by force, in case gnome-shell
                     * isn't aware it's installed
                     */
                    var script = """
(function () {
    let uuid = '""" + extension_uuid +"""';
    let perUserDir = Gio.File.new_for_path(global.userdatadir);
    let extensionDir = Gio.File.new_for_path('""" + extension_path + """');
    let type = extensionDir.has_prefix(perUserDir) ? ExtensionUtils.ExtensionType.PER_USER
                                                   : ExtensionUtils.ExtensionType.SYSTEM;

    let oldExtension = ExtensionUtils.extensions[uuid];
    if (oldExtension) {
        ExtensionSystem.unloadExtension(oldExtension);
    }

    let newExtension = ExtensionUtils.createExtensionObject(uuid, extensionDir, type);
    ExtensionSystem.loadExtension(newExtension);
})();
""";
                    GLib.debug (
                            "Attempting to enable extension \"%s\" in \"%s\"",
                            GLib.Path.get_basename (extension_path),
                            GLib.Path.get_dirname (extension_path));

                    this.shell_proxy.eval (script);
                    break;
            }
        }
        catch (IOError error) {
            GLib.warning ("Could not enable extension \"%s\": %s",
                          extension_uuid,
                          error.message);
        }
    }
}
