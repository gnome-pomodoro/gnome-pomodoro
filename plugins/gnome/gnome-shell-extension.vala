//namespace Pomodoro
//{
//    [DBus (name = "org.gnome.Pomodoro.Extension")]
//    public interface Extension : GLib.Object
//    {
//        public abstract void get_capabilities (string[] capabilities)
//                                               throws IOError;
//    }
//}

namespace Pomodoro.Plugins
{
    private class GnomeShellExtension : GLib.Object
    {
        public string uuid {
            get;
            construct set;
        }

        public bool is_enabled {
            get;
            private set;
            default = false;
        }

        private string                 path;
        private string                 version;
        private Gnome.ExtensionState   state;
        private Gnome.Shell?           shell_proxy            = null;
        private Gnome.ShellExtensions? shell_extensions_proxy = null;
        private uint                   enable_timeout_id      = 0;

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
            if (uuid == this.uuid)
            {
                var new_state = (Gnome.ExtensionState) state;

                GLib.debug ("Extension changed state to %d", new_state);

                this.state = new_state;

                if (this.state == Gnome.ExtensionState.ENABLED) {
                    this.enabled ();
                }
                else {
                    this.disabled ();
                }
            }
        }

        private Gnome.ExtensionInfo? get_info ()
        {
            var info = Gnome.ExtensionInfo ();
            
            HashTable<string,Variant> tmp;

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
            catch (GLib.DBusError error) {
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
            var success = false;

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
                success = this.shell_proxy.eval (script);

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

        private async void connect_shell ()
        {
            var shell_proxy_flags = GLib.DBusProxyFlags.DO_NOT_LOAD_PROPERTIES
                                           | GLib.DBusProxyFlags.DO_NOT_CONNECT_SIGNALS
                                           | GLib.DBusProxyFlags.DO_NOT_AUTO_START;

            if (this.shell_proxy == null)
            {
                GLib.Bus.get_proxy.begin<Gnome.Shell> (GLib.BusType.SESSION,
                                                       "org.gnome.Shell",
                                                       "/org/gnome/Shell",
                                                       shell_proxy_flags,
                                                       null,
                                                       (obj, res) =>
                    {
                        try
                        {
                            this.shell_proxy = GLib.Bus.get_proxy.end (res);
                        }
                        catch (GLib.IOError error)
                        {
                            GLib.critical ("%s", error.message);
                        }

                        if (this.shell_proxy != null &&
                            this.shell_extensions_proxy != null)
                        {
                            this.connect_shell.callback ();
                        }
                    });
            }

            if (this.shell_extensions_proxy == null)
            {
                GLib.Bus.get_proxy.begin<Gnome.ShellExtensions> (GLib.BusType.SESSION,
                                                                 "org.gnome.Shell",
                                                                 "/org/gnome/Shell",
                                                                 shell_proxy_flags,
                                                                 null,
                                                                 (obj, res) =>
                    {
                        try
                        {
                            this.shell_extensions_proxy = GLib.Bus.get_proxy.end (res);

                            this.shell_extensions_proxy.extension_status_changed.connect (
                                    this.on_status_changed);
                        }
                        catch (GLib.IOError error)
                        {
                            GLib.critical ("%s", error.message);
                        }

                        if (this.shell_proxy != null &&
                            this.shell_extensions_proxy != null)
                        {
                            this.connect_shell.callback ();
                        }
                    });
            }

            if (this.shell_proxy == null ||
                this.shell_extensions_proxy == null)
            {
                yield;
            }
        }

        private bool on_enable_timeout ()
        {
            this.enable_timeout_id = 0;

            return false;
        }

//        public async void check_state ()
//        {
//        }

        private async void wait_enabled ()
        {
            var callback_id = this.shell_extensions_proxy.extension_status_changed.connect (
                (uuid, state, error) => {
                    if (uuid == this.uuid && state == Gnome.ExtensionState.ENABLED)
                    {
                        this.wait_enabled.callback ();
                    }
                });

            yield;

            this.shell_extensions_proxy.disconnect (callback_id);
        }

        public async bool enable ()
        {
            this.enable_timeout_id = Timeout.add (5000, this.on_enable_timeout);

            if (this.shell_proxy == null ||
                this.shell_extensions_proxy == null)
            {
                /* Wait until connected to shell d-bus */
                yield this.connect_shell ();
            }

            message ("connected");

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

                        this.disabled ();
                    }
                }
                else
                {
                    GLib.debug ("Extension state = %d", info.state);

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

                    // TODO FIXME
                    //if (info.state != Gnome.ExtensionState.ENABLED)
                    //{
                    //    yield this.wait_enabled ();
                    //}

                    if (info.state == Gnome.ExtensionState.ENABLED)
                    {
                        this.enabled ();
                    }
                    else {
                        this.disabled ();
                    }
                }

                break;
            }

            return this.is_enabled;
        }

        private async void disable ()
        {
            string[] tmp = null;

            /* Disable extension in gnome-shell settings */
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

            if (enabled_in_settings)
            {
                GLib.debug ("Disabling extension \"%s\" in settings",
                            this.uuid);

                foreach (var uuid in enabled_extensions)
                {
                    if (uuid == this.uuid)
                    {
                        tmp += uuid;
                    }
                }

                gnome_shell_settings.set_strv ("enabled-extensions", tmp);
                gnome_shell_settings.apply ();
            }
        }

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

//        private void notify_disabled ()
//        {
//            GLib.return_if_fail (this.state == Gnome.ExtensionState.DISABLED);
//
//            var notification = new GLib.Notification (_("Pomodoro extension is disabled"));
//            notification.set_body (_("Extension provides better desktop integration for the pomodoro app."));
//            notification.add_button (_("Enable"), "app.enable-extension");
//
//            try {
//                notification.set_icon (GLib.Icon.new_for_string (Config.PACKAGE_NAME));
//            }
//            catch (GLib.Error error) {
//                GLib.warning (error.message);
//            }
//
//            GLib.Application.get_default ()
//                            .send_notification ("extension", notification);
//        }

        public virtual signal void enabled ()
        {
            this.is_enabled = true;

            GLib.Application.get_default ()
                            .withdraw_notification ("extension");
        }

        public virtual signal void disabled ()
        {
            this.is_enabled = false;

            switch (this.state)
            {
                case Gnome.ExtensionState.UNKNOWN:
                case Gnome.ExtensionState.UNINSTALLED:
                    this.notify_uninstalled ();
                    break;

                //case Gnome.ExtensionState.DISABLED:
                //    this.notify_disabled ();
                //    break;

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
            this.shell_proxy = null;
            this.shell_extensions_proxy = null;

            GLib.Application.get_default ()
                            .withdraw_notification ("extension");

            base.dispose ();
        }
    }
}
