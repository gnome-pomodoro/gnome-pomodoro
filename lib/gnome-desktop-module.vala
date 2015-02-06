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
    private const string DESKTOP_SESSION_ENV_VARIABLE = "DESKTOP_SESSION";
}


namespace Gnome
{
    public const string SHELL_SCHEMA = "org.gnome.shell";
    public const string SHELL_ENABLED_EXTENSIONS_KEY = "enabled-extensions";

    public enum ExtensionState
    {
        /* Custom value suggesting there was DBus error */
        UNKNOWN = 0,

        ENABLED = 1,
        DISABLED = 2,
        ERROR = 3,
        OUT_OF_DATE = 4,
        DOWNLOADING = 5,
        INITIALIZED = 6,

        /* Used as an error state for operations on unknown extensions,
         * should never be in a real extensionMeta object.
         */
        UNINSTALLED = 99
    }

    public struct ExtensionInfo
    {
        public string uuid;
        public string path;
        public string version;
        public ExtensionState state;
    }

    [DBus (name = "org.gnome.Shell")]
    public interface Shell : GLib.Object
    {
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
    public interface ShellExtensions : GLib.Object
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

        public signal void extension_status_changed
                                       (string uuid,
                                        int state,
                                        string error);
    }
}


public class Pomodoro.GnomeDesktopModule : Pomodoro.Module
{
    private unowned Pomodoro.Timer timer;

    private Gnome.Shell shell_proxy;
    private Gnome.ShellExtensions shell_extensions_proxy;
    private uint name_watcher_id = 0;
    private uint extension_name_watcher_id = 0;
    private uint enable_extension_timeout_id = 0;
    private bool extension_available = false;
    private bool gnome_shell_restarted = false;

    public GnomeDesktopModule (Pomodoro.Timer timer)
    {
        this.timer = timer;
    }

    public static bool can_enable () {
        var desktop_session = GLib.Environment.get_variable
                                       (DESKTOP_SESSION_ENV_VARIABLE);

        return desktop_session == "gnome";
    }

    public override void enable ()
    {
        if (!this.enabled)
        {
            this.name_watcher_id = GLib.Bus.watch_name
                                       (GLib.BusType.SESSION,
                                        "org.gnome.Shell",
                                        GLib.BusNameWatcherFlags.NONE,
                                        () => { this.on_name_appeared (); } ,
                                        () => { this.on_name_vanished (); });

            this.extension_name_watcher_id = GLib.Bus.watch_name
                                       (GLib.BusType.SESSION,
                                        "org.gnome.Pomodoro.Extension",
                                        GLib.BusNameWatcherFlags.NONE,
                                        () => { this.on_extension_name_appeared (); } ,
                                        () => { this.on_extension_name_vanished (); });
        }

        base.enable ();
    }

    public override void disable ()
    {
        if (this.enabled)
        {
            this.on_name_vanished ();

            if (this.name_watcher_id != 0) {
                GLib.Bus.unwatch_name (this.name_watcher_id);
                name_watcher_id = 0;
            }

            var application = GLib.Application.get_default ()
                                       as Pomodoro.Application;

            application.withdraw_notification ("extension");
        }

        base.disable ();
    }

    private void on_name_appeared ()
    {
        this.gnome_shell_restarted = true;

        try {
            if (this.shell_proxy == null) {
                this.shell_proxy =
                        GLib.Bus.get_proxy_sync (GLib.BusType.SESSION,
                                                 "org.gnome.Shell",
                                                 "/org/gnome/Shell");
            }

            if (this.shell_extensions_proxy == null) {
                this.shell_extensions_proxy =
                        GLib.Bus.get_proxy_sync<Gnome.ShellExtensions>
                                   (GLib.BusType.SESSION,
                                    "org.gnome.Shell",
                                    "/org/gnome/Shell");

                this.shell_extensions_proxy.extension_status_changed.connect (
                        this.on_extension_status_changed);
            }
        }
        catch (IOError error) {
            GLib.warning (error.message);
        }

        this.enable_extension ();
    }

    private void on_name_vanished ()
    {
        if (this.enable_extension_timeout_id != 0) {
            GLib.Source.remove (this.enable_extension_timeout_id);
            this.enable_extension_timeout_id = 0;
        }

        this.shell_proxy = null;
        this.shell_extensions_proxy = null;
    }

    private void on_extension_name_appeared ()
    {
        this.extension_available = true;
    }

    private void on_extension_name_vanished ()
    {
        if (this.extension_available)
        {
            this.extension_available = false;
            this.notify_extension_disabled ();
        }
    }

    private void on_extension_status_changed (string uuid,
                                              int state,
                                              string error)
    {
        if (uuid == Config.EXTENSION_UUID)
        {
            GLib.debug ("Extension changed state to %d", state);

            switch (state)
            {
                case Gnome.ExtensionState.INITIALIZED:
                    break;

                case Gnome.ExtensionState.ENABLED:
                    this.extension_enabled ();
                    break;

                case Gnome.ExtensionState.DISABLED:
                    this.extension_disabled ();
                    break;

                case Gnome.ExtensionState.ERROR:
                    this.notify_extension_error ();
                    break;

                case Gnome.ExtensionState.OUT_OF_DATE:
                    this.notify_extension_out_of_date ();
                    break;

                default:
                    break;
            }
        }
    }

    private Gnome.ExtensionInfo? get_extension_info ()
    {
        var extension_uuid = "";
        var extension_path = "";
        var extension_version = "";
        var extension_state = Gnome.ExtensionState.UNKNOWN;

        HashTable<string,Variant> extension_info;

        try {
            this.shell_extensions_proxy.get_extension_info
                                       (Config.EXTENSION_UUID,
                                        out extension_info);

            var tmp_uuid = extension_info.lookup ("uuid");
            var tmp_path = extension_info.lookup ("path");
            var tmp_state = extension_info.lookup ("state");
            var tmp_version = extension_info.lookup ("version");

            if (tmp_uuid != null) {
                extension_uuid = tmp_uuid.get_string ();
            }

            if (tmp_path != null) {
                extension_path = tmp_path.get_string ();
            }

            if (tmp_state != null) {
                extension_state = (Gnome.ExtensionState) tmp_state.get_double ();
            }

            if (tmp_version != null) {
                extension_version = tmp_version.get_string ();
            }
        }
        catch (GLib.IOError error) {
            return null;
        }
        catch (GLib.DBusError error) {
            return null;
        }

        /* We only care for boundled extension */
        if (extension_uuid != Config.EXTENSION_UUID ||
            extension_version != Config.PACKAGE_VERSION ||
            extension_path != this.get_extension_path ())
        {
            extension_state = Gnome.ExtensionState.UNINSTALLED;
        }

        return Gnome.ExtensionInfo () {
            uuid    = extension_uuid,
            path    = extension_path,
            state   = extension_state,
            version = extension_version
        };
    }

    private bool on_enable_extension_timeout ()
    {
        this.enable_extension_timeout_id = 0;

        this.enable_extension ();

        return false;
    }

    private string get_extension_path ()
    {
        return GLib.Path.build_filename (Config.DATA_DIR,
                                         "gnome-shell",
                                         "extensions",
                                         Config.EXTENSION_UUID);
    }

    public void enable_extension ()
    {
        /* Enable extension in gnome-shell settings */
        var gnome_shell_settings = new GLib.Settings (Gnome.SHELL_SCHEMA);
        var enabled_extensions = gnome_shell_settings.get_strv
                                       (Gnome.SHELL_ENABLED_EXTENSIONS_KEY);
        var enabled_in_settings = false;

        foreach (var uuid in enabled_extensions)
        {
            if (uuid == Config.EXTENSION_UUID)
            {
                enabled_in_settings = true;

                break;
            }
        }
      
        if (!enabled_in_settings)
        {
            GLib.debug ("Enabling extension \"%s\" in settings",
                        Config.EXTENSION_UUID);

            enabled_extensions += Config.EXTENSION_UUID;
            gnome_shell_settings.set_strv ("enabled-extensions",
                                           enabled_extensions);
            gnome_shell_settings.apply ();
        }

        /* Enable extension by Shell D-Bus */
        var reloaded = false;

        while (true)
        {
            var extension_info = this.get_extension_info ();

            if (extension_info == null)
            {
                if (this.enable_extension_timeout_id == 0)
                {
                    this.enable_extension_timeout_id = GLib.Timeout.add
                                           (1000,
                                            this.on_enable_extension_timeout);
                }
            }
            else
            {
                GLib.debug ("Extension state = %d", extension_info.state);

                if (!reloaded &&
                    extension_info.state == Gnome.ExtensionState.UNINSTALLED)
                {
                    this.reload_extension ();

                    reloaded = true;

                    continue;
                }

                switch (extension_info.state)
                {
                    case Gnome.ExtensionState.INITIALIZED:
                        /* not likely, but should change */
                        break;

                    case Gnome.ExtensionState.ENABLED:
                        break;

                    case Gnome.ExtensionState.DISABLED:
                        /* not likely */
                        this.notify_extension_disabled ();
                        break;

                    case Gnome.ExtensionState.OUT_OF_DATE:
                        this.notify_extension_out_of_date ();
                        break;

                    case Gnome.ExtensionState.ERROR:
                        this.notify_extension_error ();
                        break;

                    default:
                        this.enable_uninstalled_extension ();
                        break;
                }
            }

            break;
        }
    }

    /**
     * Enable extension in case gnome-shell isn't aware it's installed.
     */
    private void enable_uninstalled_extension ()
    {
        var extension_uuid = Config.EXTENSION_UUID;
        var extension_path = this.get_extension_path ();

        try
        {
            var script = """
(function () {
    const Gio = imports.gi.Gio;

    let uuid = '""" + extension_uuid + """';
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
            GLib.debug ("Attempting to enable extension from \"%s\"",
                        extension_path);

            var success = this.shell_proxy.eval (script);
            
            GLib.message ("success = %s", (success ? "yes" : "no"));
        }
        catch (IOError error) {
            GLib.warning ("Could not enable extension: %s",
                          error.message);
        }

        var extension_info = this.get_extension_info ();

        if (!gnome_shell_restarted &&
            (extension_info == null || extension_info.uuid != Config.EXTENSION_UUID))
        {
            var dialog = new Gtk.MessageDialog (null,
                                                Gtk.DialogFlags.MODAL,
                                                Gtk.MessageType.QUESTION,
                                                Gtk.ButtonsType.NONE,
                                                _("Indicator for Pomodoro will show up after you restart your desktop."));
            dialog.add_button (_("_Cancel"), Gtk.ResponseType.CANCEL);
            dialog.add_button (_("_Restart"), Gtk.ResponseType.OK);
            dialog.set_default_response (Gtk.ResponseType.OK);

            dialog.response.connect (
                (response_id) => {
                    if (response_id == Gtk.ResponseType.OK) {
                        this.gnome_shell_restarted = true;

                        this.restart_gnome_shell ();
                    }

                    dialog.destroy ();
                });

            var application = GLib.Application.get_default () as Pomodoro.Application;        
            var parent_window = application.get_last_focused_window ();

            if (parent_window != null) {
                dialog.set_transient_for (parent_window);
            }

            dialog.run ();
        }
        else {
            var extension_state = (extension_info != null)
                                       ? extension_info.state
                                       : Gnome.ExtensionState.UNKNOWN;

            GLib.debug ("Extension state = %d", extension_state);

            switch (extension_state)
            {
                case Gnome.ExtensionState.INITIALIZED:
                    /* state should change */
                    break;

                case Gnome.ExtensionState.ENABLED:
                    break;

                case Gnome.ExtensionState.DISABLED:
                    /* not likely */
                    this.notify_extension_disabled ();
                    break;

                case Gnome.ExtensionState.OUT_OF_DATE:
                    this.notify_extension_out_of_date ();
                    break;

                default:
                    this.notify_extension_error ();
                    break;
            }
        }
    }

    private void reload_extension ()
    {
        try {
            this.shell_extensions_proxy.reload_extension (Config.EXTENSION_UUID);

            GLib.debug ("Reloaded extension");
        }
        catch (GLib.IOError error) {
        }
    }

    private void restart_gnome_shell ()
    {
        try {
            if (this.shell_proxy.eval ("""Meta.restart(_("Restarting…"));""")) {
                GLib.debug ("Restarted gnome-shell");
            }
            else {
                GLib.debug ("Failed to restart gnome-shell");
            }
        }
        catch (GLib.IOError error) {
        }
    }

    private void notify_extension_out_of_date ()
    {
        var notification = new GLib.Notification (
                                       _("Extension does not support shell version"));
        notification.set_body (_("You need to upgrade Pomodoro."));
        notification.add_button (_("Upgrade"), "app.visit-website");

        var application = GLib.Application.get_default ()
                                       as Pomodoro.Application;
        application.send_notification ("extension", notification);
    }

    private void notify_extension_error ()
    {
        string[] errors = null;

        var extension_path = this.get_extension_path ();

        if (GLib.FileUtils.test (extension_path, GLib.FileTest.IS_DIR))
        {
            try {
                this.shell_extensions_proxy.get_extension_errors
                                           (Config.EXTENSION_UUID, out errors);
            }
            catch (IOError error) {
            }
        }
        else {
            errors = {
                _("Could not find extension \"%s\" in \"%s\"").printf (
                                   GLib.Path.get_basename (extension_path),
                                   GLib.Path.get_dirname (extension_path))
            };
        }

        var errors_string = string.joinv ("\n", errors);

        GLib.warning ("Error loading extension: %s", errors_string);

        /* popup notification only when failed to load extension */
        if (this.shell_extensions_proxy == null)
        {
            var notification = new GLib.Notification (_("Error loading extension"));
            notification.add_button (_("Report issue"), "app.report-issue");

            if (errors_string != null) {
                notification.set_body (errors_string);
            }

            var application = GLib.Application.get_default ()
                                           as Pomodoro.Application;
            application.send_notification ("extension", notification);
        }
    }

    private void notify_extension_disabled ()
    {
        var notification = new GLib.Notification (_("Pomodoro extension is disabled"));
        notification.set_body (_("Extension provides better desktop integration for the pomodoro app."));
        notification.add_button (_("Enable"), "app.enable-extension");

        var application = GLib.Application.get_default ()
                                       as Pomodoro.Application;
        application.send_notification ("extension", notification);
    }

    public virtual signal void extension_enabled ()
    {
        var application = GLib.Application.get_default ()
                                       as Pomodoro.Application;
        application.withdraw_notification ("extension");
    }

    public virtual signal void extension_disabled ()
    {
    }
}
