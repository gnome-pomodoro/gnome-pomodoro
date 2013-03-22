
#include <gtk/gtk.h>
#include <egg-list-box.h>

GtkWidget *window;
GtkWidget *box;

int main() {
    GtkWidget *s;
    gtk_init (0, NULL);
    window = gtk_window_new (GTK_WINDOW_TOPLEVEL);
    box = GTK_WIDGET (egg_list_box_new ());
    gtk_container_add (GTK_CONTAINER (box), gtk_label_new ("one"));
    s = gtk_label_new ("two");
    gtk_container_add (GTK_CONTAINER (box), s);
    egg_list_box_select_child (EGG_LIST_BOX (box), s);
    gtk_container_add (GTK_CONTAINER (box), gtk_label_new ("three"));
    gtk_container_add (GTK_CONTAINER (window), box);
    gtk_widget_show_all (window);
    gtk_main ();
    return 0;
}
