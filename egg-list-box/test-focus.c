#include <gtk/gtk.h>
#include <egg-list-box.h>

static GdkPixbuf *
get_pix (GtkStyleContext *context,
    const gchar *icon_name,
    gint icon_size)
{
  static GHashTable *cache = NULL;
  GtkStateFlags state;
  gchar *key;
  GtkIconInfo *icon_info;
  GdkPixbuf *pix;
  GError *error = NULL;

  if (cache == NULL)
    {
      cache = g_hash_table_new_full (g_str_hash, g_str_equal,
          g_free, g_object_unref);
    }

  state = gtk_style_context_get_state (context);
  key = g_strdup_printf ("%s-%u-%u", icon_name, icon_size, state);
  pix = g_hash_table_lookup (cache, key);
  if (pix != NULL)
    {
      g_free (key);
      return pix;
    }

  icon_info = gtk_icon_theme_lookup_icon (gtk_icon_theme_get_default (),
      icon_name, icon_size, 0);
  pix = gtk_icon_info_load_symbolic_for_context (icon_info, context, NULL, &error);
  g_assert_no_error (error);

  /* Takes ownership of key and pix */
  g_hash_table_insert (cache, key, pix);

  return pix;
}

static void
image_update_pixbuf (GtkWidget *image)
{
  const gchar *icon_name;
  gint icon_size;
  GdkPixbuf *pix;

  icon_name = g_object_get_data ((GObject *) image, "icon-name");
  icon_size = GPOINTER_TO_INT (g_object_get_data ((GObject *) image, "icon-size"));
  pix = get_pix (gtk_widget_get_style_context (image), icon_name, icon_size);

  gtk_image_set_from_pixbuf ((GtkImage *) image, pix);
}

static GtkWidget *
new_image (const gchar *icon_name,
    gint icon_size)
{
  GtkWidget *image;

  image = gtk_image_new ();
  g_object_set_data ((GObject *) image, "icon-name", (gchar *) icon_name);
  g_object_set_data ((GObject *) image, "icon-size", GINT_TO_POINTER (icon_size));
  g_signal_connect (image, "style-updated",
      G_CALLBACK (image_update_pixbuf), NULL);

  image_update_pixbuf (image);

  return image;
}

static void
add_row (EggListBox *view)
{
  GtkWidget *main_box, *box, *first_line_box;
  GtkStyleContext *context;
  GtkWidget *avatar;
  GtkWidget *first_line_alig;
  //GtkWidget *alias;
  GtkWidget *phone_icon;
  //GtkWidget *presence_msg;
  GtkWidget *presence_icon;

  main_box = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 8);

  /* Avatar */
  avatar = new_image ("avatar-default-symbolic", 48);

  gtk_widget_set_size_request (avatar, 48, 48);

  gtk_box_pack_start (GTK_BOX (main_box), avatar, FALSE, FALSE, 0);
  gtk_widget_show (avatar);

  box = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);

  /* Alias and phone icon */
  first_line_alig = gtk_alignment_new (0, 0.5, 1, 1);
  first_line_box = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 0);

/*
  alias = gtk_label_new ("My Cool Alias");
  gtk_label_set_ellipsize (GTK_LABEL (alias), PANGO_ELLIPSIZE_END);
  gtk_box_pack_start (GTK_BOX (first_line_box), alias,
      FALSE, FALSE, 0);
  gtk_misc_set_alignment (GTK_MISC (alias), 0, 0.5);
  gtk_widget_show (alias);
*/
  phone_icon = new_image ("phone-symbolic", 24);
  gtk_misc_set_alignment (GTK_MISC (phone_icon), 0, 0.5);
  gtk_box_pack_start (GTK_BOX (first_line_box), phone_icon,
      TRUE, TRUE, 0);

  gtk_container_add (GTK_CONTAINER (first_line_alig),
      first_line_box);
  gtk_widget_show (first_line_alig);

  gtk_box_pack_start (GTK_BOX (box), first_line_alig,
      TRUE, TRUE, 0);
  gtk_widget_show (first_line_box);

  gtk_box_pack_start (GTK_BOX (main_box), box, TRUE, TRUE, 0);
  gtk_widget_show (box);

  /* Presence */
/*
  presence_msg = gtk_label_new ("My Cool Presence Message");
  gtk_label_set_ellipsize (GTK_LABEL (presence_msg),
      PANGO_ELLIPSIZE_END);
  gtk_box_pack_start (GTK_BOX (box), presence_msg, TRUE, TRUE, 0);
  gtk_widget_show (presence_msg);

  context = gtk_widget_get_style_context (presence_msg);
  gtk_style_context_add_class (context, GTK_STYLE_CLASS_DIM_LABEL);
*/
  /* Presence icon */
  presence_icon = new_image ("user-available", 16);

  gtk_box_pack_start (GTK_BOX (main_box), presence_icon,
      FALSE, FALSE, 0);
  gtk_widget_show (presence_icon);

  gtk_container_add (GTK_CONTAINER (view), main_box);
  gtk_widget_show (main_box);
}

gint
main (gint argc,
    gchar ** argv)
{
  GtkWidget *window;
  GtkWidget *sw;
  EggListBox *view;
  guint i;

  gtk_init (&argc, &argv);

  window = gtk_window_new (GTK_WINDOW_TOPLEVEL);
  sw = gtk_scrolled_window_new (NULL, NULL);
  gtk_container_add (GTK_CONTAINER (window), sw);
  gtk_widget_show (sw);

  view = egg_list_box_new ();
  egg_list_box_add_to_scrolled (view, GTK_SCROLLED_WINDOW (sw));
  gtk_widget_show (GTK_WIDGET (view));

  for (i = 0; i < 1000; i++)
    add_row (view);


  gtk_widget_show (window);

  gtk_main ();

  gtk_widget_destroy (window);

  return 0;
}



