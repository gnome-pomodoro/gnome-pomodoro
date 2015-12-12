namespace Gnome
{
    public const string SHELL_SCHEMA = "org.gnome.shell";
    public const string SHELL_ENABLED_EXTENSIONS_KEY = "enabled-extensions";

//    public enum ExtensionState
//    {
//        /* Custom value suggesting there was DBus error */
//        UNKNOWN = 0,
//
//        ENABLED = 1,
//        DISABLED = 2,
//        ERROR = 3,
//        OUT_OF_DATE = 4,
//        DOWNLOADING = 5,
//        INITIALIZED = 6,
//
//        /* Used as an error state for operations on unknown extensions,
//         * should never be in a real extensionMeta object.
//         */
//        UNINSTALLED = 99
//    }

//    public struct ExtensionInfo
//    {
//        public string uuid;
//        public string path;
//        public string version;
//        public ExtensionState state;
//    }

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

        public abstract bool @lock () throws IOError;

        public abstract bool get_active () throws IOError;

        public abstract void set_active (bool active) throws IOError;

        public abstract uint get_active_time () throws IOError;

        public signal void active_changed (bool active);
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
