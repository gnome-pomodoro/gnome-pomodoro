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

        public string path {
            get;
            construct set;
        }

        public string version {
            get;
            construct set;
        }

        public Gnome.ExtensionState state {
            get {
                return this._state;
            }
            private set {
                this._state = value;

                var enabled = value == Gnome.ExtensionState.ENABLED;
                if (this.enabled != enabled) {
                    this.enabled = enabled;
                }
            }
        }

        public bool enabled {
            get;
            private set;
        }

        private Gnome.ExtensionState   _state;
        private Gnome.ShellExtensions? proxy = null;
        private uint                   notify_state_source = 0;
        private GLib.Settings          settings = null;

        construct
        {
            this._state = Gnome.ExtensionState.UNKNOWN;

            var settings_schema = GLib.SettingsSchemaSource.get_default ()
                    .lookup (Gnome.SHELL_SCHEMA, false);

            if (settings_schema != null) {
                this.settings = new GLib.Settings.full (settings_schema, null, null);
            }
            else {
                GLib.critical ("Schema \"%s\" not installed", Gnome.SHELL_SCHEMA);
                return;
            }

            try
            {
                this.proxy = GLib.Bus.get_proxy_sync<Gnome.ShellExtensions> (
                                           GLib.BusType.SESSION,
                                           "org.gnome.Shell",
                                           "/org/gnome/Shell",
                                           GLib.DBusProxyFlags.DO_NOT_AUTO_START,
                                           null);
                this.proxy.extension_status_changed.connect (this.on_status_changed);
            }
            catch (GLib.IOError error)
            {
                GLib.critical ("%s", error.message);
                return;
            }
        }

        public GnomeShellExtension (string uuid,
                                    string path,
                                    string version)
        {
            GLib.Object (uuid: uuid,
                         path: path,
                         version: version);
        }

        private void on_status_changed (string uuid,
                                        int    state,
                                        string error)
        {
            if (uuid == this.uuid)
            {
                var info = this.get_info ();

                if (info != null)
                {
                    GLib.debug ("Extension %s changed state to %s", uuid, info.state.to_string ());

                    this.state = info.state;
                }
            }
        }

        /**
         * Wait until enabled, listening to D-Bus status changes.
         */
        private async void ensure_enabled (GLib.Cancellable? cancellable = null)
        {
            var cancellable_handler_id = (ulong) 0;

            if (this.enabled)
            {
                return;
            }

            if (cancellable == null || !cancellable.is_cancelled ())
            {
                var handler_id = this.notify["enabled"].connect_after (() => {
                    if (this.enabled) {
                        this.ensure_enabled.callback ();
                    }
                });

                if (cancellable != null) {
                    cancellable_handler_id = cancellable.cancelled.connect (() => {
                        this.ensure_enabled.callback ();
                    });
                }

                yield;

                this.disconnect (handler_id);

                if (cancellable != null) {
                    /* cancellable.disconnect() causes a deadlock here */
                    GLib.SignalHandler.disconnect (cancellable, cancellable_handler_id);
                }
            }
        }

        private void schedule_notify_state (uint timeout)
        {
            if (this.notify_state_source != 0) {
                GLib.Source.remove (this.notify_state_source);
                this.notify_state_source = 0;
            }

            this.notify_state_source = GLib.Timeout.add (timeout, () => {
                this.notify_state_source = 0;

                if (this.enabled) {
                    this.notify_enabled ();
                }
                else {
                    this.notify_disabled ();
                }

                return GLib.Source.REMOVE;
            });
        }

        private Gnome.ExtensionInfo? get_info ()
        {
            GLib.return_if_fail (this.proxy != null);

            var info = Gnome.ExtensionInfo ();

            GLib.HashTable<string,GLib.Variant> tmp;

            try {
                this.proxy.get_extension_info (this.uuid, out tmp);

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
                GLib.critical ("%s", error.message);
                return null;
            }
            catch (GLib.DBusError error)
            {
                GLib.critical ("%s", error.message);
                return null;
            }

            return info;
        }

        /**
         * GNOME Shell may not be aware of freshly installed extension. Load it explicitly.
         */
        private async void load ()
        {
            GLib.return_if_fail (this.proxy != null);

            GLib.debug ("Loading extension...");

            var handler_id = this.proxy.extension_status_changed.connect ((uuid, state, error) => {
                if (uuid == this.uuid) {
                    this.load.callback ();
                }
            });

            try {
                var script = """
(function() {
    let dir = Gio.File.new_for_path('""" + this.path + """');
    let uuid = '""" + this.uuid + """';
    let existing = ExtensionUtils.extensions[uuid];
    if (existing) {
        ExtensionSystem.unloadExtension(existing);
    }

    let perUserDir = Gio.File.new_for_path(global.userdatadir);
    let type = dir.has_prefix(perUserDir) ? ExtensionUtils.ExtensionType.PER_USER
                                          : ExtensionUtils.ExtensionType.SYSTEM;
    try {
        let extension = ExtensionUtils.createExtensionObject(uuid, dir, type);

        ExtensionSystem.loadExtension(extension);
    } catch(e) {
        logError(e, 'Could not load extension %s'.format(uuid));
        return;
    }
})();
""";
                var shell_proxy = GLib.Bus.get_proxy_sync<Gnome.Shell> (GLib.BusType.SESSION,
                                                                        "org.gnome.Shell",
                                                                        "/org/gnome/Shell",
                                                                        GLib.DBusProxyFlags.DO_NOT_AUTO_START);
                shell_proxy.eval (script);

                yield;
            }
            catch (GLib.IOError error) {
                GLib.warning ("Failed to load extension: %s",
                              error.message);
            }

            this.proxy.disconnect (handler_id);
        }

        private async void reload ()
        {
            GLib.return_if_fail (this.proxy != null);

            GLib.debug ("Reloading extension...");

            var handler_id = this.proxy.extension_status_changed.connect ((uuid, state, error) => {
                if (uuid == this.uuid) {
                    this.reload.callback ();
                }
            });

            try {
                this.proxy.reload_extension (this.uuid);
            }
            catch (GLib.IOError error) {
                GLib.critical ("%s", error.message);
            }

            this.proxy.disconnect (handler_id);
        }

        public async void enable (GLib.Cancellable? cancellable = null)
        {
            GLib.return_if_fail (this.settings != null);
            GLib.return_if_fail (this.proxy != null);

            var enabled_extensions = this.settings.get_strv
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
                this.settings.set_strv ("enabled-extensions",
                                        enabled_extensions);
                this.settings.apply ();

                enabled_in_settings = true;

                /* GNOME Shell needs a moment to apply change */
                GLib.Timeout.add (1000, () => {
                    this.enable.callback ();

                    return GLib.Source.REMOVE;
                });

                yield;
            }

            /* try load extension if not installed */
            var info = this.get_info ();

            if (info != null)
            {
                if (info.state == Gnome.ExtensionState.UNKNOWN ||
                    info.state == Gnome.ExtensionState.UNINSTALLED ||
                    info.path != this.path)
                {
                    this.load.begin ();
                }
                else if (info.state == Gnome.ExtensionState.ERROR ||
                         info.version != this.version)
                {
                    this.reload.begin ();
                }
                else {
                    this.state = info.state;
                }
            }
            else {
                /* broken DBus connection? */
            }

            yield this.ensure_enabled (cancellable);
        }

//        private async void disable ()
//        {
//            string[] tmp = {};
//
//            if (this.settings != null)
//            {
//                var enabled_extensions = this.settings.get_strv
//                                               (Gnome.SHELL_ENABLED_EXTENSIONS_KEY);
//                var enabled_in_settings = false;
//
//                foreach (var uuid in enabled_extensions)
//                {
//                    if (uuid == this.uuid)
//                    {
//                        enabled_in_settings = true;
//
//                        break;
//                    }
//                }
//
//                if (enabled_in_settings)
//                {
//                    GLib.debug ("Disabling extension \"%s\" in settings",
//                                this.uuid);
//
//                    foreach (var uuid in enabled_extensions)
//                    {
//                        if (uuid == this.uuid)
//                        {
//                            tmp += uuid;
//                        }
//                    }
//
//                    this.settings.set_strv ("enabled-extensions", tmp);
//                    this.settings.apply ();
//                }
//            }
//        }

        private void notify_uninstalled ()
        {
            GLib.return_if_fail (this._state == Gnome.ExtensionState.UNINSTALLED ||
                                 this._state == Gnome.ExtensionState.UNKNOWN);

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
            GLib.return_if_fail (this._state == Gnome.ExtensionState.OUT_OF_DATE);

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
            GLib.return_if_fail (this._state == Gnome.ExtensionState.ERROR);
            GLib.return_if_fail (this.proxy != null);

            string[] errors = null;

            try {
                this.proxy.get_extension_errors (this.uuid, out errors);
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
            switch (this._state)
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
            if (this.notify_state_source != 0) {
                GLib.Source.remove (this.notify_state_source);
                this.notify_state_source = 0;
            }

            this.proxy = null;

            GLib.Application.get_default ()
                            .withdraw_notification ("extension");

            base.dispose ();
        }
    }
}
