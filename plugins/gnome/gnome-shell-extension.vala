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

        public bool enabled {
            get;
            private set;
        }

        private string                 path;
        private string                 version;
        private Gnome.ExtensionState   state;
        private Gnome.ShellExtensions? shell_extensions_proxy = null;
        private uint                   notify_disabled_source = 0;

        construct
        {
            this.state = Gnome.ExtensionState.UNKNOWN;
        }

        public GnomeShellExtension (string uuid)
        {
            this.uuid = uuid;
        }

        private void on_status_changed (string uuid,
                                        int    state,
                                        string error)
        {
            if (uuid == this.uuid)
            {
                var info = this.get_info ();

                GLib.debug ("Extension %s changed state to %s", uuid, info.state.to_string ());

                this.state   = info.state;
                this.path    = info.path;
                this.version = info.version;
                this.enabled = info.state == Gnome.ExtensionState.ENABLED;

                if (this.notify_disabled_source != 0) {
                    GLib.Source.remove (this.notify_disabled_source);
                    this.notify_disabled_source = 0;
                }

                this.notify_disabled_source = GLib.Timeout.add (1000, () => {
                    this.notify_disabled_source = 0;

                    if (this.enabled) {
                        this.notify_enabled ();
                    }
                    else {
                        this.notify_disabled ();
                    }

                    return GLib.Source.REMOVE;
                });
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
            GLib.debug ("Loading extension...");

            try {
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

                shell_proxy.eval (script);
            }
            catch (GLib.IOError error) {
                GLib.warning ("Failed to load extension: %s",
                              error.message);
            }
        }

        private void reload ()
        {
            GLib.debug ("Reloading extension...");

            try {
                this.shell_extensions_proxy.reload_extension (this.uuid);
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

        private async void wait_enabled (uint timeout = 2000)
        {
            if (!this.enabled && this.shell_extensions_proxy != null)
            {
                var timeout_source = (uint) 0;

                var handler_id = this.notify["enabled"].connect_after (() => {
                    this.wait_enabled.callback ();
                });

                timeout_source = GLib.Timeout.add (timeout, () => {
                    timeout_source = 0;
                    this.wait_enabled.callback ();

                    return GLib.Source.REMOVE;
                });

                yield;

                GLib.SignalHandler.disconnect (this, handler_id);

                if (timeout_source != 0) {
                    GLib.Source.remove (timeout_source);
                }
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

            /* Try enable extension */
            if (!enabled_in_settings)
            {
                GLib.debug ("Enabling extension \"%s\" in settings",
                            this.uuid);

                enabled_extensions += this.uuid;
                gnome_shell_settings.set_strv ("enabled-extensions",
                                               enabled_extensions);
                gnome_shell_settings.apply ();

                yield this.wait_enabled ();
            }

            var info = this.get_info ();
            var is_boundled = (info.uuid == this.uuid &&
                               info.path == Config.EXTENSION_DIR &&
                               info.version == Config.PACKAGE_VERSION);

            if (info == null || info.state == Gnome.ExtensionState.UNKNOWN)
            {
                this.load ();
                yield this.wait_enabled ();
            }
            else if (!is_boundled || info.state == Gnome.ExtensionState.ERROR)
            {
                this.reload ();
                yield this.wait_enabled ();
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
            GLib.Application.get_default ()
                            .withdraw_notification ("extension");
        }

        private void notify_disabled ()
        {
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
