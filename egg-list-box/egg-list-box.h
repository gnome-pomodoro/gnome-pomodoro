#ifndef __EGG_LIST_BOX_H__
#define __EGG_LIST_BOX_H__

#include <glib.h>
#include <gtk/gtk.h>

G_BEGIN_DECLS


#define EGG_TYPE_LIST_BOX (egg_list_box_get_type ())
#define EGG_LIST_BOX(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), EGG_TYPE_LIST_BOX, EggListBox))
#define EGG_LIST_BOX_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), EGG_TYPE_LIST_BOX, EggListBoxClass))
#define EGG_IS_LIST_BOX(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), EGG_TYPE_LIST_BOX))
#define EGG_IS_LIST_BOX_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), EGG_TYPE_LIST_BOX))
#define EGG_LIST_BOX_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), EGG_TYPE_LIST_BOX, EggListBoxClass))

typedef struct _EggListBox EggListBox;
typedef struct _EggListBoxClass EggListBoxClass;
typedef struct _EggListBoxPrivate EggListBoxPrivate;

struct _EggListBox
{
  GtkContainer parent_instance;
  EggListBoxPrivate * priv;
};

struct _EggListBoxClass
{
  GtkContainerClass parent_class;
  void (*child_selected) (EggListBox* self, GtkWidget* child);
  void (*child_activated) (EggListBox* self, GtkWidget* child);
  void (*activate_cursor_child) (EggListBox* self);
  void (*toggle_cursor_child) (EggListBox* self);
  void (*move_cursor) (EggListBox* self, GtkMovementStep step, gint count);
};

typedef gboolean (*EggListBoxFilterFunc) (GtkWidget* child, void* user_data);
typedef gint (*EggListBoxSortFunc) (GtkWidget* child1, GtkWidget* child2, void* user_data);

/**
 * EggListBoxUpdateSeparatorFunc:
 * @separator: (out):
 * @child:
 * @before:
 * @user_data:
 */
typedef void (*EggListBoxUpdateSeparatorFunc) (GtkWidget** separator, GtkWidget* child, GtkWidget* before, void* user_data);

GType egg_list_box_get_type (void) G_GNUC_CONST;
GtkWidget*  egg_list_box_get_selected_child           (EggListBox                    *self);
GtkWidget*  egg_list_box_get_child_at_y               (EggListBox                    *self,
						       gint                           y);
void        egg_list_box_select_child                 (EggListBox                    *self,
						       GtkWidget                     *child);
void        egg_list_box_set_adjustment               (EggListBox                    *self,
						       GtkAdjustment                 *adjustment);
void        egg_list_box_add_to_scrolled              (EggListBox                    *self,
						       GtkScrolledWindow             *scrolled);
void        egg_list_box_set_selection_mode           (EggListBox                    *self,
						       GtkSelectionMode               mode);
void        egg_list_box_set_filter_func              (EggListBox                    *self,
						       EggListBoxFilterFunc           f,
						       void                          *f_target,
						       GDestroyNotify                 f_target_destroy_notify);
void        egg_list_box_set_separator_funcs          (EggListBox                    *self,
						       EggListBoxUpdateSeparatorFunc  update_separator,
						       void                          *update_separator_target,
						       GDestroyNotify                 update_separator_target_destroy_notify);
void        egg_list_box_refilter                     (EggListBox                    *self);
void        egg_list_box_resort                       (EggListBox                    *self);
void        egg_list_box_reseparate                   (EggListBox                    *self);
void        egg_list_box_set_sort_func                (EggListBox                    *self,
						       EggListBoxSortFunc             f,
						       void                          *f_target,
						       GDestroyNotify                 f_target_destroy_notify);
void        egg_list_box_child_changed                (EggListBox                    *self,
						       GtkWidget                     *widget);
void        egg_list_box_set_activate_on_single_click (EggListBox                    *self,
						       gboolean                       single);
void        egg_list_box_drag_unhighlight_widget      (EggListBox                    *self);
void        egg_list_box_drag_highlight_widget        (EggListBox                    *self,
						       GtkWidget                     *widget);
EggListBox* egg_list_box_new                          (void);

G_END_DECLS

#endif
