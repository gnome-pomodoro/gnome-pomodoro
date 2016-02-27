namespace GnomePlugin
{
    public class DesktopExtension : Peas.ExtensionBase, Pomodoro.DesktopExtension
    {
//        private const uint64 IDLE_TIME = 60000;  // in milliseconds

        private GnomePlugin.GnomeShellExtension shell_extension;
        private Gnome.IdleMonitor               idle_monitor;
        private Pomodoro.PresenceStatus         presence_status;
        private uint                            become_active_id = 0;

        construct
        {
            this.shell_extension = new GnomeShellExtension (Config.EXTENSION_UUID);
            this.shell_extension.enable.begin ((obj, res) => {
                var success = this.shell_extension.enable.end (res);

                if (success) {
                    GLib.debug ("Extension enabled");
                }
                else {
                    // TODO: disable extension
                }
            });

//            this.presence_changed (Pomodoro.PresenceStatus.IDLE);

//            var timer = Pomodoro.Timer.get_default ();

            this.idle_monitor = new Gnome.IdleMonitor ();
//            this.become_idle_id   = this.idle_monitor.add_idle_watch (IDLE_TIME,
//                                                                      this.on_become_idle);
//            this.become_active_id = this.idle_monitor.add_user_active_watch (this.on_become_active);
        }

        public Pomodoro.PresenceStatus get_presence_status ()
        {
            return this.presence_status;
        }

        public void set_presence_status (Pomodoro.PresenceStatus status)
        {
            if (this.presence_status != status) {
                this.presence_status = status;

                if (this.presence_status == Pomodoro.PresenceStatus.IDLE)
                {
                    if (this.become_active_id == 0) {
                        this.become_active_id = this.idle_monitor.add_user_active_watch (this.on_become_active);
                    }
                }
                else {
                    if (this.become_active_id != 0) {
                        this.idle_monitor.remove_watch (this.become_active_id);
                        this.become_active_id = 0;
                    }
                }

                this.presence_changed ();
            }
        }

//        public signal void presence_changed ();

//        private void on_timer_state_enter (Pomodoro.Timer      timer,
//                                           Pomodoro.TimerState state)
//        {
//            if (state is Pomodoro.PomodoroState) {
//                timer.pause ();
//            }
//        }

//        private void on_become_idle (Gnome.IdleMonitor monitor, uint id)
//        {
//        }

        private void on_become_active (Gnome.IdleMonitor monitor, uint id)
        {
            message ("user become active idletime = %u", (uint) monitor.get_idletime ());

            this.set_presence_status (Pomodoro.PresenceStatus.AVAILABLE);
        }

//        public override void presence_changed (Pomodoro.PresenceStatus status)
//        {
//        }
    }

/*
	public class Gnome.IdleMonitor : GLib.Object, GLib.Initable {
		[CCode (has_construct_function = false)]
		public IdleMonitor ();
		public uint add_idle_watch (uint64 interval_msec, owned Gnome.IdleMonitorWatchFunc? callback);
		public uint add_user_active_watch (owned Gnome.IdleMonitorWatchFunc? callback);
		[CCode (has_construct_function = false)]
		public IdleMonitor.for_device (Gdk.Device device) throws GLib.Error;
		public uint64 get_idletime ();
		public void remove_watch (uint id);
		[NoAccessorMethod]
		public Gdk.Device device { owned get; construct; }
	}
*/


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


//            var indicator_type_label = new Gtk.Label (_("Show indicator in top panel"));
//            indicator_type_label.set_alignment (0.0f, 0.5f);
//            var indicator_type_combo_box = this.create_indicator_type_combo_box ();

//            var indicator_type_hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
//            indicator_type_hbox.pack_start (indicator_type_label, true, true);
//            indicator_type_hbox.pack_start (indicator_type_combo_box, false, false);
//            this.box.pack_start (indicator_type_hbox);

//            this.settings.bind_with_mapping ("indicator-type",
//                                             indicator_type_combo_box,
//                                             "value",
//                                             SETTINGS_BIND_FLAGS,
//                                             (SettingsBindGetMappingShared) get_indicator_type_mapping,
//                                             (SettingsBindSetMappingShared) set_indicator_type_mapping,
//                                             null,
//                                             null);

    public class PreferencesDialogExtension : Peas.ExtensionBase, Pomodoro.PreferencesDialogExtension
    {
        private Pomodoro.PreferencesDialog dialog;

        private GLib.Settings settings;
        private GLib.List<Gtk.ListBoxRow> rows;

        construct
        {
            this.settings = Pomodoro.get_settings ()
                                    .get_child ("preferences");

            this.dialog = Pomodoro.PreferencesDialog.get_default ();
        }

        ~PreferencesDialogExtension ()
        {
            foreach (var row in this.rows) {
                row.destroy ();
            }

            this.rows = null;
        }

        private Gtk.ListBoxRow create_row (string label,
                                           string name,
                                           string settings_key)
        {
            var name_label = new Gtk.Label (label);
            name_label.halign = Gtk.Align.START;
            name_label.valign = Gtk.Align.BASELINE;

            var value_label = new Gtk.Label (null);
            value_label.halign = Gtk.Align.END;
            value_label.get_style_context ().add_class ("dim-label");

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 30);
            box.pack_start (name_label, true, true, 0);
            box.pack_start (value_label, false, true, 0);

            var row = new Gtk.ListBoxRow ();
            row.name = name;
            row.selectable = false;
            row.add (box);
            row.show_all ();

            return row;
        }
    }
}


[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
    var object_module = module as Peas.ObjectModule;

    object_module.register_extension_type (typeof (Pomodoro.DesktopExtension),
                                           typeof (GnomePlugin.DesktopExtension));

    object_module.register_extension_type (typeof (Pomodoro.PreferencesDialogExtension),
                                           typeof (GnomePlugin.PreferencesDialogExtension));
}
