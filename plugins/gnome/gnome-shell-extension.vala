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

        construct
        {
            this._state = Gnome.ExtensionState.UNKNOWN;

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

                    if (this.enabled) {
                        this.notify_enabled ();
                    }
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

            return info;
        }

        /**
         * GNOME Shell has no public API to enable extensions
         */
        private async void eval (string            script,
                                 GLib.Cancellable? cancellable = null)
        {
            GLib.return_if_fail (this.proxy != null);

            if (cancellable != null && cancellable.is_cancelled ()) {
                return;
            }

            var handler_id = this.proxy.extension_status_changed.connect_after ((uuid, state, error) => {
                if (uuid == this.uuid) {
                    this.eval.callback ();
                }
            });
            var cancellable_id = (ulong) 0;

            if (cancellable != null) {
                cancellable_id = cancellable.connect (() => {
                    this.eval.callback ();
                });
            }

            try {
                var shell_proxy = GLib.Bus.get_proxy_sync<Gnome.Shell> (GLib.BusType.SESSION,
                                                                        "org.gnome.Shell",
                                                                        "/org/gnome/Shell",
                                                                        GLib.DBusProxyFlags.DO_NOT_AUTO_START);
                shell_proxy.eval (script);

                yield;
            }
            catch (GLib.IOError error) {
                GLib.warning ("Failed to eval script: %s",
                              error.message);
            }

            if (cancellable_id != 0) {
                cancellable.disconnect (cancellable_id);
            }

            this.proxy.disconnect (handler_id);
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

        let enabledExtensions = global.settings.get_strv('enabled-extensions');
        if (enabledExtensions.indexOf(uuid) == -1) {
            enabledExtensions.push(uuid);
            global.settings.set_strv('enabled-extensions', enabledExtensions);
        }
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
            GLib.return_if_fail (this.proxy != null);

            var info = this.get_info ();

            if (info != null)
            {
                this.state = info.state;

                if (this.state == Gnome.ExtensionState.INITIALIZED ||
                    this.state == Gnome.ExtensionState.DISABLED)
                {
                    yield this.eval ("""
(function() {
    let uuid = '""" + this.uuid + """';
    let enabledExtensions = global.settings.get_strv('enabled-extensions');

    if (enabledExtensions.indexOf(uuid) == -1) {
        enabledExtensions.push(uuid);
        global.settings.set_strv('enabled-extensions', enabledExtensions);
    }
})();
""", cancellable);
                }
                else if (this.state == Gnome.ExtensionState.UNKNOWN ||
                    this.state == Gnome.ExtensionState.UNINSTALLED)
                {
                    this.load.begin ();
                }
                else if (this.state == Gnome.ExtensionState.ERROR)
                {
                    this.reload.begin ();
                }

                yield this.ensure_enabled (cancellable);
            }

            if (!this.enabled) {
                this.notify_disabled ();
            }
        }

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
