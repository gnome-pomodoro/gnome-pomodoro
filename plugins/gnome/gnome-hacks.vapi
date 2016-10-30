[CCode (cheader_filename = "gnome-hacks.h")]
namespace Gnome
{
    [CCode (cname = "gnome_idle_monitor_object_manager_client_get_proxy_type")]
    public GLib.Type idle_monitor_object_manager_client_get_proxy_type (GLib.DBusObjectManagerClient manager,
                                                                        string                       object_path,
                                                                        string?                      interface_name,
                                                                        void*                        user_data);
}
