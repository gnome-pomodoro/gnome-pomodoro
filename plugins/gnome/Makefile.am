libgnome_la_pluginexecdir = $(GNOME_POMODORO_PLUGIN_LIB_DIR)
libgnome_la_pluginexec_LTLIBRARIES = \
	libgnome.la

libgnome_la_plugindatadir = $(GNOME_POMODORO_PLUGIN_LIB_DIR)
libgnome_la_plugindata_DATA = \
	gnome.plugin

libgnome_la_DEPENDENCIES = \
	$(top_builddir)/lib/libgnome-pomodoro.la

libgnome_la_VALASOURCES = \
	gnome-plugin.vala \
	$(top_builddir)/lib/gnome-pomodoro.vapi

libgnome_la_SOURCES = \
	$(libgnome_la_VALASOURCES)

libgnome_la_VALAFLAGS = \
    $(GNOME_POMODORO_PLUGIN_VALAFLAGS)

libgnome_la_CPPFLAGS = \
	$(GNOME_POMODORO_PLUGIN_CFLAGS)

libgnome_la_CFLAGS = \
	$(GNOME_POMODORO_PLUGIN_CFLAGS)

libgnome_la_LDFLAGS = \
	$(GNOME_POMODORO_PLUGIN_LIBTOOL_FLAGS)

libgnome_la_LIBADD = \
	$(top_builddir)/lib/libgnome-pomodoro.la

CLEANFILES = \
	$(libgnome_la_SOURCES:.vala=.c)

EXTRA_DIST = \
	$(libgnome_la_plugindata_DATA)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
