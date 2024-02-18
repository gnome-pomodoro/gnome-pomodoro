namespace Gnome
{
    [DBus (name = "org.gnome.ScreenSaver")]
    public interface ScreenSaver : GLib.Object
    {
        public abstract async bool get_active () throws GLib.DBusError, GLib.IOError;
        [DBus (no_reply = true)]
        public abstract async void @lock () throws GLib.DBusError, GLib.IOError;

        public signal void active_changed (bool active);
    }


    [DBus (name = "org.gnome.Mutter.IdleMonitor")]
    public interface IdleMonitor : GLib.Object
    {
        public abstract uint32 add_idle_watch (uint64 interval) throws GLib.DBusError, GLib.IOError;
        public abstract uint32 add_user_active_watch () throws GLib.DBusError, GLib.IOError;
        public abstract uint64 get_idletime () throws GLib.DBusError, GLib.IOError;
        public abstract void remove_watch (uint32 id) throws GLib.DBusError, GLib.IOError;

        public signal void watch_fired (uint32 id);
    }
}