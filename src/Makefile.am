bin_PROGRAMS = \
    gnome-pomodoro

BUILT_SOURCES = \
    resources.c

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


resources.c: $(top_srcdir)/data/gnome-pomodoro.gresource.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir=$(top_srcdir)/data/ $(top_srcdir)/data/gnome-pomodoro.gresource.xml)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(top_srcdir)/data/ --generate-source $<


CLEANFILES = \
    $(BUILT_SOURCES) \
    $(gnome_pomodoro_SOURCES:.vala=.c) \
    gnome-pomodoro \
    gnome_pomodoro_vala.stamp

#EXTRA_DIST = \
#    $(resource_files) \
#    gnome-pomodoro.gresource.xml

-include $(top_srcdir)/git.mk
