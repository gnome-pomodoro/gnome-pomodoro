/*
 * Copyright (c) 2025 gnome-pomodoro contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;


namespace Portal
{
    public class BackgroundProvider : Pomodoro.Provider, Pomodoro.BackgroundProvider
    {
        /**
         * Warn if underlying `Background` API version changes. Bump this value after testing.
         */
        private const uint COMAPTIBLE_VERSION = 2U;

        private GLib.DBusConnection?                 connection = null;
        private Portal.Background?                   proxy = null;
        private GLib.Cancellable?                    cancellable = null;
        private GLib.HashTable<uint, Portal.Request> requests = null;
        private uint                                 dbus_watcher_id = 0U;

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

        public override async void initialize (GLib.Cancellable? cancellable) throws GLib.Error
        {
            this.requests = new GLib.HashTable<uint, Portal.Request> (GLib.direct_hash,
                                                                      GLib.direct_equal);

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

            try {
                this.proxy = yield GLib.Bus.get_proxy<Portal.Background>
                                    (GLib.BusType.SESSION,
                                     "org.freedesktop.portal.Desktop",
                                     "/org/freedesktop/portal/desktop",
                                     GLib.DBusProxyFlags.NONE,
                                     this.cancellable);

                if (this.proxy.version > COMAPTIBLE_VERSION) {
                    GLib.warning ("Using Background API version %u. Implementation was aimed for older version.",
                                  this.proxy.version);
                }
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

            this.proxy = null;
            this.requests = null;
        }

        public override async void uninitialize () throws GLib.Error
        {
            if (this.dbus_watcher_id != 0) {
                GLib.Bus.unwatch_name (this.dbus_watcher_id);
                this.dbus_watcher_id = 0;
            }

            this.cancellable = null;
        }

        public async bool request_background (string parent_window)
        {
            string handle_token;

            var allowed = false;

            try {
                handle_token = yield Portal.create_request (
                    this.connection,
                    (response, results) => {
                        if (results != null)
                        {
                            var background_variant = results.lookup ("background");

                            if (background_variant != null) {
                                allowed = background_variant.get_boolean ();
                            }
                        }

                        this.request_background.callback ();
                    });
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while requesting background: %s", error.message);
                return allowed;
            }

            var options = new GLib.HashTable<string, GLib.Variant> (GLib.str_hash, GLib.str_equal);
            options.insert ("handle_token", new GLib.Variant.string (handle_token));
            options.insert ("dbus-activatable", new GLib.Variant.boolean (true));

            this.proxy.request_background.begin (
                parent_window,
                options,
                (obj, res) => {
                    try {
                        this.proxy.request_background.end (res);
                    }
                    catch (GLib.Error error) {
                        GLib.warning ("Error while requesting background: %s", error.message);
                    }
                });

            yield;  // wait for response

            return allowed;
        }
    }
}
