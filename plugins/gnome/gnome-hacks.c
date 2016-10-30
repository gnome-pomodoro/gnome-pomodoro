#include <gio/gio.h>


/**
 * gnome_idle_monitor_object_manager_client_get_proxy_type:
 * @manager: A #GDBusObjectManagerClient.
 * @object_path: The object path of the remote object (unused).
 * @interface_name: (allow-none): Interface name of the remote object or %NULL to get the object proxy #GType.
 * @user_data: User data (unused).
 *
 * A #GDBusProxyTypeFunc that maps @interface_name to the generated #GDBusObjectProxy<!-- -->- and #GDBusProxy<!-- -->-derived types.
 *
 * Returns: A #GDBusProxy<
 */
GType
gnome_idle_monitor_object_manager_client_get_proxy_type (GDBusObjectManagerClient *manager G_GNUC_UNUSED, const gchar *object_path G_GNUC_UNUSED, const gchar *interface_name, gpointer user_data G_GNUC_UNUSED)
{
  static gsize once_init_value = 0;
  static GHashTable *lookup_hash;
  GType ret;

  if (interface_name == NULL)
    return G_TYPE_DBUS_OBJECT_PROXY;
  if (g_once_init_enter (&once_init_value))
    {
      lookup_hash = g_hash_table_new (g_str_hash, g_str_equal);
      g_hash_table_insert (lookup_hash, (gpointer) "org.gnome.Mutter.IdleMonitor", GSIZE_TO_POINTER (meta_idle_monitor_proxy_get_type ()));
      g_once_init_leave (&once_init_value, 1);
    }
  ret = (GType) GPOINTER_TO_SIZE (g_hash_table_lookup (lookup_hash, interface_name));
  if (ret == (GType) 0)
    ret = G_TYPE_DBUS_PROXY;
  return ret;
}
