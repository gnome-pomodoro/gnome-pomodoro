namespace Freedesktop
{
    public struct Session
    {
        public string session_id;
        public uint32 user_id;
        public string user_name;
        public string seat_id;
        public string object_path;
    }


    [DBus (name = "((s{sv}))")]
    public struct Shortcut
    {
        public string                               id;
        public GLib.HashTable<string, GLib.Variant> properties;
    }


    [DBus (name = "org.freedesktop.login1.Manager")]
    public interface LoginManager : GLib.Object
    {
        public abstract async Session[] list_sessions () throws GLib.DBusError, GLib.IOError;

        public signal void prepare_for_sleep (bool active);
    }


    [DBus (name = "org.freedesktop.login1.Session")]
    public interface LoginSession : GLib.Object
    {
        public abstract string id { owned get; }
        public abstract bool active { get; }
        public abstract bool locked_hint { get; }

        [DBus (no_reply = true)]
        public abstract async void @lock () throws GLib.DBusError, GLib.IOError;
    }


    [DBus (name = "org.freedesktop.ScreenSaver")]
    public interface ScreenSaver : GLib.Object
    {
        public abstract async bool get_active () throws GLib.DBusError, GLib.IOError;

        public signal void active_changed (bool active);
    }


    [DBus (name = "org.freedesktop.timedate1")]
    public interface TimeDate : GLib.Object
    {
        public abstract string timezone { owned get; }
    }


    [DBus (name = "org.freedesktop.Notifications")]
    public interface Notifications : GLib.Object
    {
        public abstract async void get_capabilities (out string[] capabilities) throws GLib.DBusError, GLib.IOError;

        public abstract async void get_server_information (out string name,
                                                           out string vendor,
                                                           out string version,
                                                           out string spec_version) throws GLib.DBusError, GLib.IOError;
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
