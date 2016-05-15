/*
 * Copyright (c) 2016 gnome-pomodoro contributors
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
 */

using GLib;


namespace GnomePlugin
{
    private class GnomeShellExtension : GLib.Object
    {
        public string uuid {
            get;
            construct set;
        }

        [CCode (notify = false)]
        public bool enabled {
            get {
                return this._enabled;
            }
            private set {
                if (this._enabled != value) {
                    this._enabled = value;

                    if (this._enabled) {
                        this.notify_enabled ();
                    }
                    else {
                        this.notify_disabled ();
                    }
                }
            }
        }

        private string                 path;
        private string                 version;
        private Gnome.ExtensionState   state;
        private Gnome.ShellExtensions? shell_extensions_proxy = null;
        private bool                   _enabled               = false;
        private bool                   enabled_notified      = false;
        private uint                   notify_disabled_source = 0;

        public GnomeShellExtension (string uuid)
        {
            this.uuid = uuid;
        }

        construct
        {
            this.state = Gnome.ExtensionState.UNKNOWN;
        }

        private void on_status_changed (string uuid,
                                        int    state,
                                        string error)
        {
            var new_state = (Gnome.ExtensionState) state;

            if (uuid == this.uuid && new_state != this.state)
            {
                GLib.debug ("Extension %s changed state to %s", uuid, new_state.to_string ());

                this.state = new_state;
                this.enabled = this.state == Gnome.ExtensionState.ENABLED;
            }
        }

        private Gnome.ExtensionInfo? get_info ()
        {
            var info = Gnome.ExtensionInfo ();

            GLib.HashTable<string,GLib.Variant> tmp;

            try {
                this.shell_extensions_proxy.get_extension_info (this.uuid, out tmp);

                info.uuid = tmp.contains ("uuid")
                                ? tmp.lookup ("uuid").get_string ()
                                : this.uuid;
                info.path = tmp.contains ("path")
                                ? tmp.lookup ("path").get_string ()
                                : "";
                info.state = tmp.contains ("state")
                                ? (Gnome.ExtensionState) tmp.lookup ("state").get_double ()
                                : Gnome.ExtensionState.UNKNOWN;
                info.version = tmp.contains ("version")
                                ? tmp.lookup ("version").get_string ()
                                : "";
            }
            catch (GLib.IOError error) {
                return null;
            }

            return info;
        }

        /**
         * GNOME Shell may not be aware of installed extension. Make GNOME Shell to look
         * for new extensions.
         */
        private void load ()
        {
            try
            {
                var script = """
(function () {
    let finder = new ExtensionUtils.ExtensionFinder();
    finder.connect('extension-found',
        function(finder, extension) {
            let uuid = '""" + this.uuid + """';
            if (extension.uuid != uuid) {
                return;
            }

            let oldExtension = ExtensionUtils.extensions[uuid];
            if (oldExtension) {
                ExtensionSystem.unloadExtension(oldExtension);
            }

            ExtensionSystem.loadExtension(extension);
        });
    finder.scanExtensions();
})();
""";
                var shell_proxy = GLib.Bus.get_proxy_sync<Gnome.Shell> (GLib.BusType.SESSION,
                                                                        "org.gnome.Shell",
                                                                        "/org/gnome/Shell",
                                                                        GLib.DBusProxyFlags.DO_NOT_AUTO_START);

                var success = shell_proxy.eval (script);

                GLib.debug ("Reloaded extensions");
            }
            catch (GLib.IOError error) {
                GLib.warning ("Failed to reload extensions: %s",
                              error.message);
            }
        }

        private void reload ()
        {
            try {
                this.shell_extensions_proxy.reload_extension (this.uuid);

                GLib.debug ("Reloaded extension");
            }
            catch (GLib.IOError error) {
                GLib.critical ("%s", error.message);
            }
        }

        private async void connect_proxy ()
        {
            if (this.shell_extensions_proxy == null)
            {
                GLib.Bus.get_proxy.begin<Gnome.ShellExtensions> (GLib.BusType.SESSION,
                                                                 "org.gnome.Shell",
                                                                 "/org/gnome/Shell",
                                                                 GLib.DBusProxyFlags.DO_NOT_AUTO_START,
                                                                 null,
                                                                 (obj, res) =>
                {
                    try
                    {
                        this.shell_extensions_proxy = GLib.Bus.get_proxy.end (res);

                        this.shell_extensions_proxy.extension_status_changed.connect (this.on_status_changed);
                    }
                    catch (GLib.IOError error)
                    {
                        GLib.critical ("%s", error.message);
                    }

                    this.connect_proxy.callback ();
                });

                yield;
            }
        }

        public async void enable ()
        {
            if (this.shell_extensions_proxy == null)
            {
                /* Wait until connected to shell d-bus */
                yield this.connect_proxy ();
            }

            /* Enable extension in gnome-shell settings */
            var gnome_shell_settings = new GLib.Settings (Gnome.SHELL_SCHEMA);
            var enabled_extensions = gnome_shell_settings.get_strv
                                           (Gnome.SHELL_ENABLED_EXTENSIONS_KEY);
            var enabled_in_settings = false;

            foreach (var uuid in enabled_extensions)
            {
                if (uuid == this.uuid)
                {
                    enabled_in_settings = true;

                    break;
                }
            }

            if (!enabled_in_settings)
            {
                GLib.debug ("Enabling extension \"%s\" in settings",
                            this.uuid);

                enabled_extensions += this.uuid;
                gnome_shell_settings.set_strv ("enabled-extensions",
                                               enabled_extensions);
                gnome_shell_settings.apply ();

                /* gnome-shell may need some time to acknowledge new extension */
            }

            /* Check state */
            var reloaded = false;
            var loaded = false;

            while (true)
            {
                var info = this.get_info ();

                if (info == null || info.state == Gnome.ExtensionState.UNKNOWN)
                {
                    if (!loaded)
                    {
                        this.load ();

                        loaded = true;

                        continue;
                    }
                    else {
                        GLib.warning ("Extension seems to be uninstalled");

                        this.state = Gnome.ExtensionState.UNINSTALLED;

                        this.enabled = false;
                    }
                }
                else
                {
                    GLib.debug ("Extension state = %s", info.state.to_string ());

                    var is_boundled = (info.uuid == this.uuid &&
                                       info.path == Config.EXTENSION_DIR &&
                                       info.version == Config.PACKAGE_VERSION);

                    if (!is_boundled && !loaded && !reloaded)
                    {
                        this.reload ();

                        reloaded = true;

                        continue;
                    }

//                    if (!loaded && info.state != Gnome.ExtensionState.ENABLED)
//                    {
//                        this.load ();  /* enable manually */
//
//                        loaded = true;
//
//                        continue;
//                    }

                    this.state   = info.state;
                    this.path    = info.path;
                    this.version = info.version;

                    this.enabled = info.state == Gnome.ExtensionState.ENABLED;
                }

                break;
            }
        }

//        private async void disable ()
//        {
//            string[] tmp = null;
//
//            /* Disable extension in gnome-shell settings */
//            var gnome_shell_settings = new GLib.Settings (Gnome.SHELL_SCHEMA);
//            var enabled_extensions = gnome_shell_settings.get_strv
//                                           (Gnome.SHELL_ENABLED_EXTENSIONS_KEY);
//            var enabled_in_settings = false;
//
//            foreach (var uuid in enabled_extensions)
//            {
//                if (uuid == this.uuid)
//                {
//                    enabled_in_settings = true;
//
//                    break;
//                }
//            }
//
//            if (enabled_in_settings)
//            {
//                GLib.debug ("Disabling extension \"%s\" in settings",
//                            this.uuid);
//
//                foreach (var uuid in enabled_extensions)
//                {
//                    if (uuid == this.uuid)
//                    {
//                        tmp += uuid;
//                    }
//                }
//
//                gnome_shell_settings.set_strv ("enabled-extensions", tmp);
//                gnome_shell_settings.apply ();
//            }
//        }

        private void notify_uninstalled ()
        {
            GLib.return_if_fail (this.state == Gnome.ExtensionState.UNINSTALLED ||
                                 this.state == Gnome.ExtensionState.UNKNOWN);

            var notification = new GLib.Notification (
                                           _("Failed to enable extension"));
            notification.set_body (_("It seems to be uninstalled"));

            try {
                notification.set_icon (GLib.Icon.new_for_string (Config.PACKAGE_NAME));
            }
            catch (GLib.Error error) {
                GLib.warning (error.message);
            }

            GLib.Application.get_default ()
                            .send_notification ("extension", notification);
        }

        private void notify_out_of_date ()
        {
            GLib.return_if_fail (this.state == Gnome.ExtensionState.OUT_OF_DATE);

            var notification = new GLib.Notification (
                                           _("Failed to enable extension"));
            notification.set_body (_("Extension is out of date"));
            notification.add_button (_("Upgrade"), "app.visit-website");

            try {
                notification.set_icon (GLib.Icon.new_for_string (Config.PACKAGE_NAME));
            }
            catch (GLib.Error error) {
                GLib.warning (error.message);
            }

            GLib.Application.get_default ()
                            .send_notification ("extension", notification);
        }

        private void notify_error ()
        {
            GLib.return_if_fail (this.state == Gnome.ExtensionState.ERROR);

            string[] errors = null;

            try {
                this.shell_extensions_proxy.get_extension_errors
                                           (Config.EXTENSION_UUID, out errors);
            }
            catch (GLib.IOError error) {
                GLib.critical (error.message);
            }

            var errors_string = string.joinv ("\n", errors);

            GLib.warning ("Extension error: %s", errors_string);

            var notification = new GLib.Notification (_("Failed to enable extension"));
            notification.set_body (errors_string);
            notification.add_button (_("Report issue"), "app.report-issue");

            try {
                notification.set_icon (GLib.Icon.new_for_string (Config.PACKAGE_NAME));
            }
            catch (GLib.Error error) {
                GLib.warning (error.message);
            }

            GLib.Application.get_default ()
                            .send_notification ("extension", notification);
        }

        private void notify_enabled ()
        {
            if (this.notify_disabled_source != 0) {
                GLib.Source.remove (this.notify_disabled_source);
                this.notify_disabled_source = 0;
            }

            if (!this.enabled_notified) {
                this.enabled_notified = true;

                this.notify_property ("enabled");

                GLib.Application.get_default ()
                                .withdraw_notification ("extension");
            }
        }

        private void notify_disabled ()
        {
            if (this.notify_disabled_source != 0) {
                GLib.Source.remove (this.notify_disabled_source);
            }

            this.notify_disabled_source = GLib.Timeout.add (1000, () => {
                this.notify_disabled_source = 0;

                if (this.enabled_notified) {
                    this.enabled_notified = false;
                    this.notify_property ("enabled");

                    switch (this.state)
                    {
                        case Gnome.ExtensionState.UNKNOWN:
                        case Gnome.ExtensionState.UNINSTALLED:
                            this.notify_uninstalled ();
                            break;

                        case Gnome.ExtensionState.OUT_OF_DATE:
                            this.notify_out_of_date ();
                            break;

                        case Gnome.ExtensionState.ERROR:
                            this.notify_error ();
                            break;

                        default:
                            break;
                    }
                }

                return GLib.Source.REMOVE;
            });
        }

        public override void dispose ()
        {
            if (this.notify_disabled_source != 0) {
                GLib.Source.remove (this.notify_disabled_source);
                this.notify_disabled_source = 0;
            }

            this.shell_extensions_proxy = null;

            GLib.Application.get_default ()
                            .withdraw_notification ("extension");

            base.dispose ();
        }
    }
}
