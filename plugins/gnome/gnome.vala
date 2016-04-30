namespace Gnome
{
    public const string SHELL_SCHEMA = "org.gnome.shell";
    public const string SHELL_ENABLED_EXTENSIONS_KEY = "enabled-extensions";

    [Flags]
    public enum ActionMode
    {
        NONE          = 0,
        NORMAL        = 1,
        OVERVIEW      = 2,
        LOCK_SCREEN   = 4,
        UNLOCK_SCREEN = 8,
        LOGIN_SCREEN  = 16,
        SYSTEM_MODAL  = 32,
        LOOKING_GLASS = 64,
        POPUP         = 128,
        ALL           = 255,
    }

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
        public string uuid;
        public string path;
        public string version;
        public ExtensionState state;
    }

    [DBus (name = "org.gnome.Shell")]
    public interface Shell : GLib.Object
    {
        public abstract bool eval (string script)
                                   throws GLib.IOError;

        public abstract uint32 grab_accelerator
                                       (string accelerator,
                                        uint32 flags)
                                        throws GLib.IOError;

        public abstract bool ungrab_accelerator
                                       (uint32 action)
                                        throws GLib.IOError;

        public signal void accelerator_activated
                                       (uint32 action,
                                        GLib.HashTable<string, GLib.Variant> accelerator_params);
    }

    [DBus (name = "org.gnome.Shell.Extensions")]
    public interface ShellExtensions : GLib.Object
    {
        public abstract void get_extension_info
                                       (string uuid,
                                        out GLib.HashTable<string, GLib.Variant> info)
                                        throws GLib.IOError;

        public abstract void get_extension_errors
                                       (string uuid,
                                        out string[] errors)
                                        throws GLib.IOError;

        public abstract void reload_extension
                                       (string uuid)
                                        throws GLib.IOError;

        public signal void extension_status_changed
                                       (string uuid,
                                        int state,
                                        string error);
    }
}
