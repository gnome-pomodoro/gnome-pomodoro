namespace Plugins
{
    public class GnomeDesktopPlugin : GLib.Object, Pomodoro.DesktopExtension
    {
//        private const string version = Config.PACKAGE_VERSION;

//        public string id
//        {
//            owned get { return "/org/gnome/gitg/Panels/Diff"; }
//        }

//        public bool available
//        {
//            get { return true; }
//        }

//        public string display_name
//        {
//            owned get { return _("Diff"); }
//        }

//        public string description
//        {
//            owned get { return _("Show the changes introduced by the selected commit"); }
//        }

//        public string? icon
//        {
//            owned get { return "diff-symbolic"; }
//        }

        construct
        {
            message ("GnomeDesktopPlugin.construct()");
        }
    }
}



//    internal const string DESKTOP_SESSION_ENV_VARIABLE = "DESKTOP_SESSION";

//    public class GnomeDesktopModule : Pomodoro.Module
//    {
//        private Gnome.IdleMonitor idle_monitor;
//        private uint became_active_id;

//        public GnomeDesktopModule (Pomodoro.Timer timer)
//        {
////            this.plugins.

////            GnomeShellExtension
////            GnomeIdleMonitor
//        }

//        public static bool can_enable () {
//            var desktop_session = GLib.Environment.get_variable
//                                           (DESKTOP_SESSION_ENV_VARIABLE);

//            return desktop_session == "gnome";
//        }
//    }


[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
    var object_module = module as Peas.ObjectModule;

    object_module.register_extension_type (typeof (Pomodoro.DesktopExtension),
                                           typeof (Plugins.GnomeDesktopPlugin));
}
