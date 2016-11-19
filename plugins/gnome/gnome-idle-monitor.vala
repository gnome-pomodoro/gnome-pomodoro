/*
 * Adapted from gnome-session/gnome-session/gs-idle-monitor.h
 * and from gnome-desktop/libgnome-session/gnome-idle-monitor.h
 *
 * Copyright (C) 2012 Red Hat, Inc.
 * Copyright (C) 2016 gnome-pomodoro contributors.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses/>.
 *
 * Original author: William Jon McCann <mccann@jhu.edu>
 */

using GLib;


namespace GnomePlugin
{
    public delegate void IdleMonitorWatchFunc (GnomePlugin.IdleMonitor monitor,
                                               uint                    id);

    private class IdleMonitorWatch : GLib.InitiallyUnowned
    {
        public unowned GnomePlugin.IdleMonitor   monitor;
        public uint                              id;
        public uint                              upstream_id;
        public GnomePlugin.IdleMonitorWatchFunc? callback;
        public uint64                            timeout_msec;

        private static uint next_id = 1;

        construct
        {
            this.id = this.get_next_id ();
        }

        public IdleMonitorWatch (GnomePlugin.IdleMonitor monitor,
                                 uint64	                         timeout_msec,
                                 owned IdleMonitorWatchFunc?     callback)
        {
            this.monitor = monitor;
            this.timeout_msec = timeout_msec;
            this.callback = callback;
        }

        private uint get_next_id ()
        {
            var next_id = IdleMonitorWatch.next_id;

            IdleMonitorWatch.next_id++;

            return next_id;
        }
    }

    public class IdleMonitor : GLib.Object, GLib.Initable
    {
        /**
         * GnomeIdleMonitor:device:
         *
         * The device to listen to idletime on.
         */
        public Gdk.Device device {
            construct {
                this._device = value; // TODO: .dup_object ();

                this.path = this._device != null
                        ? "/org/gnome/Mutter/IdleMonitor/Device%d".printf (Gdk.X11.device_get_id (this._device as Gdk.X11.DeviceCore))
                        : "/org/gnome/Mutter/IdleMonitor/Core";
            }
            owned get {
                return this._device;
            }
        }

        private GLib.Cancellable         cancellable;
        private Meta.IdleMonitor         proxy;
        private GLib.DBusObjectManager   object_manager;
        private uint                     name_watch_id;
        private GLib.HashTable<uint,GnomePlugin.IdleMonitorWatch>           watches;
        private GLib.HashTable<uint,unowned GnomePlugin.IdleMonitorWatch>   watches_by_upstream_id;
        private Gdk.Device               _device;
        private string                   path;


        construct
        {
            this.watches = new GLib.HashTable<uint,IdleMonitorWatch>
                                       (null,
                                        null);
            this.watches_by_upstream_id = new GLib.HashTable<uint,unowned IdleMonitorWatch>
                                       (null,
                                        null);

            this.cancellable = new GLib.Cancellable ();
        }

        /**
         * gnome_idle_monitor_new:
         *
         * Returns: a new #GnomeIdleMonitor that tracks the server-global
         * idletime for all devices. To track device-specific idletime,
         * use gnome_idle_monitor_new_for_device().
         */
        public IdleMonitor () throws GLib.Error
        {
            ((GLib.Initable) this).init (null);
        }

        /**
         * gnome_idle_monitor_new_for_device:
         * @device: A #GdkDevice to get the idle time for.
         * @error: A pointer to a #GError or %NULL.
         *
         * Returns: a new #GnomeIdleMonitor that tracks the device-specific
         * idletime for @device. If device-specific idletime is not available,
         * %NULL is returned, and @error is set. To track server-global
         * idletime for all devices, use gnome_idle_monitor_new().
         */
        public IdleMonitor.for_device (Gdk.Device device)
                                       throws GLib.Error
        {
            GLib.Object (device: device);

            ((GLib.Initable) this).init (null);
        }

        public override void dispose ()
        {
            if (this.cancellable != null) {
                this.cancellable.cancel ();
            }

            if (this.name_watch_id != 0) {
                GLib.Bus.unwatch_name (this.name_watch_id);
                this.name_watch_id = 0;
            }

            base.dispose ();
        }

        public new bool init (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
            this.name_watch_id = GLib.Bus.watch_name (
                                       GLib.BusType.SESSION,
                                       "org.gnome.Mutter.IdleMonitor",
                                       GLib.BusNameWatcherFlags.NONE,
                                       this.on_name_appeared,
                                       this.on_name_vanished);

            // TODO: we want to check wether IdleMonitor will be in a working state

            return true;
        }

        private void on_watch_fired (Meta.IdleMonitor proxy,
                                     uint             upstream_id)
        {
            var watch = this.watches_by_upstream_id.lookup (upstream_id);

            if (watch != null)
            {
                if (watch.callback != null) {
                    watch.callback (watch.monitor, watch.id);
                }

                if (watch.timeout_msec == 0) {
                    this.remove_watch_internal (watch);
                }
            }
        }

        private void on_object_added (GLib.DBusObjectManager manager,
                                      GLib.DBusObject        object)
        {
            if (this.path != object.get_object_path ()) {
                return;
            }

            this.connect_proxy (object);

            GLib.SignalHandler.disconnect_by_func (manager, (void*) this.on_object_added, this);
        }

        private void add_idle_watch_internal (IdleMonitorWatch watch)
        {
            try {
                // TODO: consider proxy.add_idle_watch to be async
                this.proxy.add_idle_watch (watch.timeout_msec, out watch.upstream_id);

                this.watches_by_upstream_id.insert (watch.upstream_id, watch);
            }
            catch (GLib.IOError error) {
                GLib.warning ("Failed to add idle watch: %s", error.message);
            }
        }

        private void add_user_active_watch_internal (IdleMonitorWatch watch)
        {
            try {
                // TODO: consider proxy.add_user_active_watch to be async
                this.proxy.add_user_active_watch (out watch.upstream_id);

                this.watches_by_upstream_id.insert (watch.upstream_id, watch);
            }
            catch (GLib.IOError error) {
                GLib.warning ("Failed to add user-active watch: %s", error.message);
            }
        }

        private void remove_watch_internal (IdleMonitorWatch watch)
        {
            this.watches.remove (watch.id);

            if (watch.upstream_id != 0) {
                this.watches_by_upstream_id.remove (watch.upstream_id);
                watch.upstream_id = 0;
            }
        }

        /**
         * gnome_idle_monitor_add_idle_watch:
         * @monitor: A #GnomeIdleMonitor
         * @interval_msec: The idletime interval, in milliseconds
         * @callback: (allow-none): The callback to call when the user has
         *     accumulated @interval_msec milliseconds of idle time.
         * @user_data: (allow-none): The user data to pass to the callback
         * @notify: A #GDestroyNotify
         *
         * Returns: a watch id
         *
         * Adds a watch for a specific idle time. The callback will be called
         * when the user has accumulated @interval_msec milliseconds of idle time.
         * This function will return an ID that can either be passed to
         * gnome_idle_monitor_remove_watch(), or can be used to tell idle time
         * watches apart if you have more than one.
         *
         * Also note that this function will only care about positive transitions
         * (user's idle time exceeding a certain time). If you want to know about
         * when the user has become active, use
         * gnome_idle_monitor_add_user_active_watch().
         */
        public uint add_idle_watch (uint64	                    interval_msec,
                                    owned IdleMonitorWatchFunc? callback)
                                    requires (interval_msec > 0)
        {
            var watch = new IdleMonitorWatch (this,
                                              interval_msec,
                                              callback);

            this.watches.insert (watch.id, watch);

            if (this.proxy != null) {
                this.add_idle_watch_internal (watch);
            }

            return watch.id;
        }

        /**
         * gnome_idle_monitor_add_user_active_watch:
         * @monitor: A #GnomeIdleMonitor
         * @callback: (allow-none): The callback to call when the user is
         *     active again.
         * @user_data: (allow-none): The user data to pass to the callback
         * @notify: A #GDestroyNotify
         *
         * Returns: a watch id
         *
         * Add a one-time watch to know when the user is active again.
         * Note that this watch is one-time and will de-activate after the
         * function is called, for efficiency purposes. It's most convenient
         * to call this when an idle watch, as added by
         * gnome_idle_monitor_add_idle_watch(), has triggered.
         */
        public uint add_user_active_watch (IdleMonitorWatchFunc callback)
        {
            var watch = new IdleMonitorWatch (this,
                                              0,
                                              callback);

            this.watches.insert (watch.id, watch);

            if (this.proxy != null) {
                this.add_user_active_watch_internal (watch);
            }

            return watch.id;
        }

        /**
         * gnome_idle_monitor_remove_watch:
         * @monitor: A #GnomeIdleMonitor
         * @id: A watch ID
         *
         * Removes an idle time watcher, previously added by
         * gnome_idle_monitor_add_idle_watch() or
         * gnome_idle_monitor_add_user_active_watch().
         */
        public void remove_watch (uint id)
        {
            var watch = this.watches.lookup (id);

            if (watch == null) {
                return;
            }

            if (watch.upstream_id != 0) {
                try {
                    this.proxy.remove_watch (watch.upstream_id);
                }
                catch (GLib.IOError error) {
                    GLib.warning ("Failed to remove watch: %s", error.message);
                }
            }

            this.remove_watch_internal (watch);
        }

        /**
         * gnome_idle_monitor_get_idletime:
         * @monitor: A #GnomeIdleMonitor
         *
         * Returns: The current idle time, in milliseconds
         */
        public uint64 get_idletime ()
        {
            uint64 value = 0;

            if (this.proxy != null) {
                try {
                    this.proxy.get_idletime (out value);
                }
                catch (GLib.IOError error) {
                    GLib.warning ("Failed to get idletime: %s", error.message);
                }
            }

            return value;
        }

        public void connect_proxy (GLib.DBusObject object)
        {
            var proxy = object.get_interface ("org.gnome.Mutter.IdleMonitor");

	        if (proxy == null) {
		        GLib.critical ("Unable to get org.gnome.Mutter.IdleMonitor interface object at %s",
			                   object.get_object_path ());
	        }


            this.proxy = proxy != null ? (proxy as Meta.IdleMonitor) : null;

	        if (this.proxy == null) {
		        GLib.critical ("Unable to get idle monitor from object at %s",
			                   object.get_object_path ());
	        }
            else {
                this.proxy.watch_fired.connect (this.on_watch_fired);

                this.watches.@foreach ((id, watch) => {
                    assert (watch != null);

                    if (watch.timeout_msec == 0) {
                        this.add_user_active_watch_internal (watch);
                    }
                    else {
                        this.add_idle_watch_internal (watch);
                    }
                });
            }
        }

        // TODO: is there a way of getting GLib.Type of a generated Meta.IdleMonitorProxy?
        // public static GLib.Type get_proxy_type (GLib.DBusObjectManagerClient manager,
        //                                         string                       object_path,
        //                                         string?                      interface_name)
        // {
        //     if (interface_name == null) {
        //         return typeof (GLib.DBusObjectProxy);
        //     }
        //
        //     if (interface_name == "org.gnome.Mutter.IdleMonitor") {
        //         return typeof (Meta.IdleMonitor);
        //     }
        //     else {
        //         return typeof (GLib.DBusProxy);
        //     }
        // }

        private void on_name_appeared (GLib.DBusConnection connection,
                                       string              name,
                                       string              name_owner)
        {
            /**
             * acync constructor was broken until commit 4123914c1eecf16696d53cc25367440c221be94d in vala
             * by Rico Tzschichholz
             */
            try {
                GLib.DBusObjectManagerClient.@new.begin
                                       (connection,
                                        GLib.DBusObjectManagerClientFlags.NONE,
                                        name_owner,
                                        "/org/gnome/Mutter/IdleMonitor",
                                        (GLib.DBusProxyTypeFunc) Gnome.idle_monitor_object_manager_client_get_proxy_type,
                                        this.cancellable,
                                        (obj, res) => {
                    try
                    {
                        this.object_manager = GLib.DBusObjectManagerClient.@new.end (res);

                        var object = this.object_manager.get_object (this.path);

                        if (object != null) {
                            this.connect_proxy (object);
                        }
                        else {
                            this.object_manager.object_added.connect (this.on_object_added);
                        }
                    }
                    catch (GLib.IOError error)
                    {
                        GLib.warning ("Failed to acquire idle monitor object manager: %s", error.message);
                    }
                });
            }
            catch (GLib.Error error) {
                GLib.warning ("Failed to create object manager: %s", error.message);
            }
        }

        private void on_name_vanished (GLib.DBusConnection connection,
                                       string              name)
        {
            this.watches.@foreach ((id, watch) => {
                this.watches_by_upstream_id.remove (watch.upstream_id);
                watch.upstream_id = 0;
            });

            this.proxy = null;
            this.object_manager = null;
        }
    }
}
