/*
 * Copyright (c) 2025 gnome-pomodoro contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Portal
{
    [DBus (name = "((s{sv}))")]
    public struct Shortcut
    {
        public string                               id;
        public GLib.HashTable<string, GLib.Variant> properties;
    }


    [DBus (name = "org.freedesktop.portal.Request")]
    public interface Request : GLib.Object
    {
        public abstract void close () throws GLib.DBusError, GLib.IOError;

        public signal void response (uint32                               response,
                                     GLib.HashTable<string, GLib.Variant> results);
    }


    [DBus (name = "org.freedesktop.portal.Background")]
    interface Background : GLib.Object
    {
        public abstract uint32 version { owned get; }

        public abstract async GLib.ObjectPath request_background (string                               parent_window,
                                                                  GLib.HashTable<string, GLib.Variant> options) throws GLib.DBusError, GLib.IOError;
    }


    [DBus (name = "org.freedesktop.portal.GlobalShortcuts")]
    public interface GlobalShortcuts : GLib.Object
    {
        public abstract uint32 version { owned get; }

        public abstract async GLib.ObjectPath create_session (GLib.HashTable<string, GLib.Variant> options) throws GLib.DBusError, GLib.IOError;

        public abstract async GLib.ObjectPath bind_shortcuts (GLib.ObjectPath                      session_handle,
                                                              Shortcut[]                           shortcuts,
                                                              string                               parent_window,
                                                              GLib.HashTable<string, GLib.Variant> options) throws GLib.DBusError, GLib.IOError;

        public abstract async GLib.ObjectPath list_shortcuts (GLib.ObjectPath                      session_handle,
                                                              GLib.HashTable<string, GLib.Variant> options) throws GLib.DBusError, GLib.IOError;

        public abstract async void configure_shortcuts (GLib.ObjectPath                      session_handle,
                                                        string                               parent_window,
                                                        GLib.HashTable<string, GLib.Variant> options) throws GLib.DBusError, GLib.IOError;

        public signal void activated (GLib.ObjectPath                      session_handle,
                                      string                               shortcut_id,
                                      uint64                               timestamp,
                                      GLib.HashTable<string, GLib.Variant> options);

        public signal void deactivated (GLib.ObjectPath                      session_handle,
                                        string                               shortcut_id,
                                        uint64                               timestamp,
                                        GLib.HashTable<string, GLib.Variant> options);

        public signal void shortcuts_changed (GLib.ObjectPath session_handle,
                                              Shortcut[]      shortcuts);
    }
}
