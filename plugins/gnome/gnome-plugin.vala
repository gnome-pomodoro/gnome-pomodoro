namespace Pomodoro.Plugins
{
    public class GnomeDesktopPlugin : Peas.ExtensionBase, Pomodoro.DesktopExtension
    {
        private GnomeShellExtension shell_extension { get; private set; }
        private Gnome.IdleMonitor   idle_monitor;

        construct
        {
            GLib.message ("GnomeDesktopPlugin.construct()");

            this.shell_extension = new GnomeShellExtension (Config.EXTENSION_UUID);
            this.shell_extension.enable.begin ((obj, res) => {
                var success = this.shell_extension.enable.end (res);

                if (success) {
                    GLib.message ("Extension enabled");
                }
            });
        }

        public virtual signal void presence_changed ()
        {
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
                                           typeof (Pomodoro.Plugins.GnomeDesktopPlugin));
}
