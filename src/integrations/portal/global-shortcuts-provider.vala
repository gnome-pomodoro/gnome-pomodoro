using GLib;


namespace Portal
{
    private errordomain GlobalShortcutsError
    {
        REQUEST,
        CREATE_SESSION,
        BIND_SHORTCUTS,
        CONFIGURE_SHORTCUTS,
        LIST_SHORTCUTS
    }


    public class GlobalShortcutsProvider : Pomodoro.Provider, Pomodoro.GlobalShortcutsProvider
    {
        /**
         * Warn if underlying `GlobalShortcuts` API version changes. Bump this value after testing.
         */
        private const uint COMAPTIBLE_VERSION = 0;

        private GLib.DBusConnection?            connection = null;
        private Portal.GlobalShortcuts?         proxy = null;
        private Portal.Shortcut[]               shortcuts = null;
        private GLib.Cancellable?               cancellable = null;
        private GLib.ObjectPath?                session_handle = null;
        private GLib.HashTable<string, string>? accelerators = null;
        private uint                            dbus_watcher_id = 0U;
        private uint                            bind_shortcuts_idle_id = 0U;
        private bool                            is_configured = false;

        private void mark_as_configured ()
        {
            if (!this.is_configured)
            {
                var settings = Pomodoro.get_settings ();
                settings.set_boolean ("global-shortcuts-configured", true);

                this.is_configured = true;
            }
        }

        private async void create_session () throws GlobalShortcutsError
        {
            var timestamp = Pomodoro.Timestamp.to_seconds_uint32 (Pomodoro.Timestamp.from_now ());

            try {
                var handle_token = yield Portal.create_request (
                    this.connection,
                    (response, results) => {
                        if (results != null)
                        {
                            var session_handle_variant = results.lookup ("session_handle");

                            if (session_handle_variant != null) {
                                this.session_handle = new GLib.ObjectPath (
                                        session_handle_variant.get_string ());
                            }
                        }

                        this.create_session.callback ();
                    });

                var options = new GLib.HashTable<string, GLib.Variant> (GLib.str_hash,
                                                                        GLib.str_equal);
                options.insert ("handle_token",
                                new GLib.Variant.string (handle_token));
                options.insert ("session_handle_token",
                                new GLib.Variant.string (@"gnomepomodoro_$(timestamp)"));

                yield this.proxy.create_session (options);

                yield;  // wait for response
            }
            catch (GLib.Error error) {
                throw new GlobalShortcutsError.CREATE_SESSION (error.message);
            }

            if (this.session_handle == null) {
                throw new GlobalShortcutsError.CREATE_SESSION ("No session_handle in response");
            }
        }

        private string parse_trigger_description (string? trigger_description)
        {
            if (trigger_description != null)
            {
                var position = trigger_description.index_of (" <");

                return position > 0
                    ? trigger_description.slice (position + 1, trigger_description.length)
                    : "";
            }

            return "";
        }

        private Portal.Shortcut[] parse_shortcuts (GLib.Variant shortcuts_variant)
        {
            GLib.debug ("Parsing shortcuts... %s", shortcuts_variant.print (false));

            var shortcuts = new Portal.Shortcut[0];
            var shortcuts_iterator = shortcuts_variant.iterator ();
            GLib.Variant? tuple_variant;

            while ((tuple_variant = shortcuts_iterator.next_value ()) != null)
            {
                var shortcut_id         = tuple_variant.get_child_value (0).get_string ();
                var properties_variant  = tuple_variant.get_child_value (1);
                var properties_iterator = properties_variant.iterator ();
                var properties          = new GLib.HashTable<string, GLib.Variant> (
                                                            GLib.str_hash, GLib.str_equal);

                string key;
                GLib.Variant variant;

                while (properties_iterator.next ("{sv}", out key, out variant))
                {
                    properties.insert (key, variant);
                }

                shortcuts += Portal.Shortcut () {
                    id         = shortcut_id,
                    properties = properties
                };
            }

            return shortcuts;
        }

        private void update_accelerators (GLib.Variant shortcuts_variant)
        {
            var changed_ids      = new GLib.GenericSet<string> (GLib.str_hash, GLib.str_equal);
            var new_accelerators = new GLib.HashTable<string, string> (GLib.str_hash, GLib.str_equal);
            var is_initialized   = this.accelerators != null;

            foreach (var shortcut in this.shortcuts)
            {
                if (this.accelerators != null &&
                    this.accelerators.contains (shortcut.id) &&
                    this.accelerators.lookup (shortcut.id) != "")
                {
                    changed_ids.add (shortcut.id);
                }

                new_accelerators.insert (shortcut.id, "");
            }

            foreach (var shortcut in this.parse_shortcuts (shortcuts_variant))
            {
                var existing_accelerator = this.accelerators != null && this.accelerators.contains (shortcut.id)
                        ? this.accelerators.lookup (shortcut.id)
                        : "";
                var accelerator = this.parse_trigger_description (
                        shortcut.properties.lookup ("trigger_description").get_string ());

                if (accelerator == existing_accelerator) {
                    changed_ids.remove (shortcut.id);
                }
                else if (accelerator != "") {
                    changed_ids.add (shortcut.id);
                }

                new_accelerators.insert (shortcut.id, accelerator);
            }

            this.accelerators = new_accelerators;

            if (is_initialized) {
                changed_ids.@foreach (
                    (shortcut_id) => {
                        this.accelerator_changed (shortcut_id);
                    });
            }
        }

        /**
         * `ListShortcuts` lists shortcuts if they have been changed during the session.
         *
         * We use it to update `this.accelerators`.
         */
        private async void list_shortcuts () throws GlobalShortcutsError
                                             requires (this.session_handle != null)

        {
            string handle_token;
            GLib.Variant? shortcuts_variant = null;

            try {
                handle_token = yield Portal.create_request (
                    this.connection,
                    (response, results) => {
                        shortcuts_variant = results != null ? results.lookup ("shortcuts") : null;

                        this.list_shortcuts.callback ();
                    });
            }
            catch (GLib.Error error) {
                throw new GlobalShortcutsError.REQUEST (error.message);
            }

            try {
                var options = new GLib.HashTable<string, GLib.Variant> (GLib.str_hash, GLib.str_equal);
                options.insert ("handle_token", new GLib.Variant.string (handle_token));

                yield this.proxy.list_shortcuts (this.session_handle, options);

                yield;  // wait for response
            }
            catch (GLib.Error error) {
                throw new GlobalShortcutsError.LIST_SHORTCUTS (error.message);
            }

            if (shortcuts_variant != null) {
                this.update_accelerators (shortcuts_variant);
            }
        }

        private async void bind_shortcuts () throws GlobalShortcutsError
        {
            string handle_token;

            try {
                handle_token = yield Portal.create_request (
                    this.connection,
                    (response, results) => {
                        this.bind_shortcuts.callback ();
                    });
            }
            catch (GLib.Error error) {
                throw new GlobalShortcutsError.REQUEST (error.message);
            }

            try {
                var options = new GLib.HashTable<string, GLib.Variant> (GLib.str_hash, GLib.str_equal);
                options.insert ("handle_token", new GLib.Variant.string (handle_token));

                yield this.proxy.bind_shortcuts (this.session_handle,
                                                 this.shortcuts,
                                                 "",
                                                 options);

                yield;  // wait for response
            }
            catch (GLib.Error error) {
                throw new GlobalShortcutsError.BIND_SHORTCUTS (error.message);
            }

            // Update accelerators
            if (this.accelerators == null) {
                yield this.list_shortcuts ();
            }
        }

        private void schedule_bind_shortcuts ()
        {
            if (this.bind_shortcuts_idle_id != 0) {
                return;
            }

            this.bind_shortcuts_idle_id = GLib.Idle.add (
                () => {
                    this.bind_shortcuts_idle_id = 0;

                    this.bind_shortcuts.begin (
                        (obj, res) => {
                            try {
                                this.bind_shortcuts.end (res);
                            }
                            catch (GLib.Error error) {
                                GLib.warning ("Error while binding shortcuts: %s", error.message);
                            }
                        });

                    return GLib.Source.REMOVE;
                });
            GLib.Source.set_name_by_id (this.bind_shortcuts_idle_id,
                                        "Portal.GlobalShortcutsProvider.bind_shortcuts");
        }

        /**
         * `BindShortcuts` only displays a dialog if there are new entries. To force display
         * a dialog we add an "Unsed" shortcut.
         */
        private Portal.Shortcut[] mutulate_shortcuts ()
        {
            var timestamp = Pomodoro.Timestamp.to_seconds_uint32 (Pomodoro.Timestamp.from_now ());
            var shortcut_id = @"unused-$(timestamp)";
            var shortcut_properties = new GLib.HashTable<string, GLib.Variant> (GLib.str_hash,
                                                                                GLib.str_equal);
            shortcut_properties.insert ("description", new GLib.Variant.string (_("Unused")));

            var shortcuts = this.shortcuts.copy ();

            shortcuts += Portal.Shortcut () {
                id         = shortcut_id,
                properties = shortcut_properties
            };

            return shortcuts;
        }

        private async void open_global_shortcuts_dialog_async (string window_identifier)
                                                               throws GlobalShortcutsError
        {
            string handle_token;

            if (this.proxy == null || this.shortcuts.length == 0) {
                return;
            }

            // HACK: It's possible to open the dialog only once per session.
            yield this.create_session ();

            try {
                handle_token = yield Portal.create_request (
                    this.connection,
                    (response, results) => {
                        this.open_global_shortcuts_dialog_async.callback ();
                    });
            }
            catch (GLib.Error error) {
                throw new GlobalShortcutsError.REQUEST (error.message);
            }

            var options = new GLib.HashTable<string, GLib.Variant> (GLib.str_hash, GLib.str_equal);
            options.insert ("handle_token", new GLib.Variant.string (handle_token));

            if (this.proxy.version >= 2 && this.is_configured)
            {
                try {
                    yield this.proxy.configure_shortcuts (this.session_handle,
                                                          window_identifier,
                                                          options);
                }
                catch (GLib.Error error) {
                    yield new GlobalShortcutsError.CONFIGURE_SHORTCUTS (error.message);
                }
            }
            else {
                try {
                    yield this.proxy.bind_shortcuts (this.session_handle,
                                                     this.mutulate_shortcuts (),
                                                     window_identifier,
                                                     options);
                }
                catch (GLib.Error error) {
                    yield new GlobalShortcutsError.BIND_SHORTCUTS (error.message);
                }
            }

            yield;  // wait for response
        }

        private void on_name_appeared (GLib.DBusConnection connection,
                                       string              name,
                                       string              name_owner)
        {
            this.available = true;
            this.connection = connection;
        }

        private void on_name_vanished (GLib.DBusConnection? connection,
                                       string               name)
        {
            this.available = false;
            this.connection = null;
        }

        private void on_activated (GLib.ObjectPath                      session_handle,
                                   string                               shortcut_id,
                                   uint64                               timestamp,
                                   GLib.HashTable<string, GLib.Variant> options)
        {
            this.shortcut_activated (shortcut_id);
        }

        private void on_shortcuts_changed (GLib.ObjectPath   session_handle,
                                           Portal.Shortcut[] shortcuts)
        {
            if (this.accelerators != null)
            {
                this.list_shortcuts.begin (
                    (obj, res) => {
                        try {
                            this.list_shortcuts.end (res);
                        }
                        catch (GLib.Error error) {
                            GLib.warning ("Error while listing shortcuts: %s", error.message);
                        }
                    });
            }

            if (shortcuts.length > 0) {
                this.mark_as_configured ();
            }
        }

        public override async void initialize (GLib.Cancellable? cancellable) throws GLib.Error
        {
            this.shortcuts = new Portal.Shortcut[0];

            if (this.dbus_watcher_id == 0) {
                this.dbus_watcher_id = GLib.Bus.watch_name (GLib.BusType.SESSION,
                                                            "org.freedesktop.portal.Desktop",
                                                            GLib.BusNameWatcherFlags.NONE,
                                                            this.on_name_appeared,
                                                            this.on_name_vanished);
            }
        }

        public override async void enable (GLib.Cancellable? cancellable) throws GLib.Error
        {
            if (this.proxy != null) {
                return;
            }

            this.cancellable = cancellable != null
                ? cancellable
                : new GLib.Cancellable ();

            this.is_configured = Pomodoro.get_settings ().get_boolean ("global-shortcuts-configured");

            try {
                this.proxy = yield GLib.Bus.get_proxy<Portal.GlobalShortcuts>
                                    (GLib.BusType.SESSION,
                                     "org.freedesktop.portal.Desktop",
                                     "/org/freedesktop/portal/desktop",
                                     GLib.DBusProxyFlags.NONE,
                                     this.cancellable);
                this.proxy.activated.connect (this.on_activated);
                this.proxy.shortcuts_changed.connect (this.on_shortcuts_changed);

                if (this.proxy.version > COMAPTIBLE_VERSION) {
                    GLib.warning ("Using GlobalShortcuts API version %u. Implementation was aimed for older version.",
                                  this.proxy.version);
                }

                yield this.create_session ();
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while creating global shortcuts session: %s", error.message);
                throw error;
            }
        }

        public override async void disable () throws GLib.Error
        {
            if (this.cancellable != null) {
                this.cancellable.cancel ();
            }

            if (this.bind_shortcuts_idle_id != 0) {
                GLib.Source.remove (this.bind_shortcuts_idle_id);
                this.bind_shortcuts_idle_id = 0;
            }

            if (this.proxy != null) {
                this.proxy.activated.disconnect (this.on_activated);
                this.proxy.shortcuts_changed.disconnect (this.on_shortcuts_changed);
                this.proxy = null;
            }

            this.session_handle = null;
        }

        public override async void uninitialize () throws GLib.Error
        {
            if (this.dbus_watcher_id != 0) {
                GLib.Bus.unwatch_name (this.dbus_watcher_id);
                this.dbus_watcher_id = 0;
            }

            this.cancellable = null;
            this.shortcuts = null;
            this.accelerators = null;
        }

        public void add_shortcut (string name,
                                  string description,
                                  string default_accelerator = "")
                                  requires (this.session_handle != null)
        {
            var shortcut_properties = new GLib.HashTable<string, GLib.Variant> (GLib.str_hash,
                                                                                GLib.str_equal);
            shortcut_properties.insert ("description", new GLib.Variant.string (description));

            if (default_accelerator != "") {
                shortcut_properties.insert ("preferred_trigger",
                                            new GLib.Variant.string (default_accelerator));
            }

            var shortcut = Portal.Shortcut () {
                id         = name,
                properties = shortcut_properties
            };

            this.shortcuts += shortcut;

            // We need to bind shortcuts for the `activate` signal to work, even if they have been
            // configured before. Binding shortcuts may show a dialog. We want to prevent the dialog
            // from showing up on app start.
            if (this.is_configured) {
                this.schedule_bind_shortcuts ();
            }
        }

        public string lookup_accelerator (string name)
        {
            if (this.accelerators == null) {
                return "";
            }

            var accelerator = this.accelerators.lookup (name);

            return accelerator != null ? accelerator : "";
        }

        public void open_global_shortcuts_dialog (string window_identifier)
        {
            this.open_global_shortcuts_dialog_async.begin (
                window_identifier,
                (obj, res) => {
                    try {
                        this.open_global_shortcuts_dialog_async.end (res);
                    }
                    catch (GLib.Error error) {
                        GLib.warning ("Error opening shortcuts dialog: %s", error.message);
                    }
                });
        }
    }
}
