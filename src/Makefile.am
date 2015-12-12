bin_PROGRAMS = \
    gnome-pomodoro

gnome_pomodoro_SOURCES = \
    main.vala \
    resources.c \
    ../lib/gnome-pomodoro.vapi

gnome_pomodoro_DEPENDENCIES = \
    ../lib/libgnome-pomodoro.la

gnome_pomodoro_VALAFLAGS = \
    --vapidir=$(top_builddir)/vapi \
    --pkg config \
    --pkg gobject-2.0 \
    --pkg gio-2.0 \
    --pkg gdk-3.0 \
    --pkg gtk+-3.0

gnome_pomodoro_CPPFLAGS = \
    $(GNOME_POMODORO_CFLAGS) \
    $(WARNING_CFLAGS)

gnome_pomodoro_LDADD = \
    $(GNOME_POMODORO_LIBS) \
    $(top_builddir)/lib/libgnome-pomodoro.la


CLEANFILES = \
    $(BUILT_SOURCES) \
    $(gnome_pomodoro_SOURCES:.vala=.c) \
    gnome-pomodoro \
    gnome_pomodoro_vala.stamp

-include $(top_srcdir)/git.mk
