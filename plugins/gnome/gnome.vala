namespace Gnome
{
    public const string SHELL_SCHEMA = "org.gnome.shell";
    public const string SHELL_ENABLED_EXTENSIONS_KEY = "enabled-extensions";

    public enum ExtensionState
    {
        /* Custom value suggesting there was DBus error */
        UNKNOWN = 0,

        ENABLED = 1,
        DISABLED = 2,
        ERROR = 3,
        OUT_OF_DATE = 4,
        DOWNLOADING = 5,
        INITIALIZED = 6,

        /* Used as an error state for operations on unknown extensions,
         * should never be in a real extensionMeta object.
         */
        UNINSTALLED = 99;

        public string to_string ()
        {
            switch (this)
            {
                case ENABLED:
                    return "enabled";

                case DISABLED:
                    return "disabled";

                case ERROR:
                    return "error";

                case OUT_OF_DATE:
                    return "out-of-date";

                case DOWNLOADING:
                    return "downloading";

                case INITIALIZED:
                    return "initialized";

                case UNINSTALLED:
                    return "uninstalled";

                default:
                    assert_not_reached ();
            }
        }
    }

    public struct ExtensionInfo
    {
        public string         uuid;
        public string         path;
        public string         version;
        public ExtensionState state;
    }

    [DBus (name = "org.gnome.Shell")]
    public interface Shell : GLib.Object
    {
        public abstract bool eval (string script)
                                   throws IOError;

        public abstract bool grab_accelerator
                                       (string accelerator,
                                        uint32 flags,
                                        out uint action)
                                        throws IOError;

        public abstract bool ungrab_accelerator
                                       (uint32 action,
                                        out bool success)
                                        throws IOError;

        public signal void accelerator_activated
                                       (uint32 action,
                                        uint32 device_id,
                                        uint32 timestamp);
    }

    [DBus (name = "org.gnome.Shell.Extensions")]
    public interface ShellExtensions : GLib.Object
    {
        public abstract void get_extension_info
                                       (string uuid,
                                        out HashTable<string,Variant> info)
                                        throws IOError;

        public abstract void get_extension_errors
                                       (string uuid,
                                        out string[] errors)
                                        throws IOError;

        public abstract void reload_extension
                                       (string uuid)
                                        throws IOError;

        public signal void extension_status_changed
                                       (string uuid,
                                        int state,
                                        string error);
    }
}


/* Mutter interfaces */
namespace Meta
{
    [DBus (name = "org.gnome.Mutter.IdleMonitor")]
    public interface IdleMonitor : GLib.Object
    {
        public abstract void get_idletime
                                       (out uint64 idletime)
                                        throws IOError;

        public abstract void add_idle_watch
                                       (uint64   interval,
                                        out uint id)
                                        throws IOError;

        public abstract void add_user_active_watch (out uint id)
                                        throws IOError;

        public abstract void remove_watch
                                       (uint id)
                                        throws IOError;

        public signal void watch_fired (uint id);
    }
}
