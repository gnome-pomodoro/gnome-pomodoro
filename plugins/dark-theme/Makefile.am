libdark_theme_la_pluginexecdir = $(PLUGIN_LIB_DIR)
libdark_theme_la_pluginexec_LTLIBRARIES = \
	libdark-theme.la

libdark_theme_la_plugindatadir = $(PLUGIN_LIB_DIR)
libdark_theme_la_plugindata_DATA = \
	dark-theme.plugin

libdark_theme_la_DEPENDENCIES = \
	$(top_builddir)/lib/libgnome-pomodoro.la

libdark_theme_la_VALASOURCES = \
	dark-theme-plugin.vala \
	$(top_builddir)/lib/gnome-pomodoro.vapi

libdark_theme_la_SOURCES = \
	$(libdark_theme_la_VALASOURCES)

libdark_theme_la_VALAFLAGS = \
	$(PLUGIN_VALAFLAGS)

libdark_theme_la_CPPFLAGS = \
	$(PLUGIN_CPPFLAGS)

libdark_theme_la_CFLAGS = \
	$(PLUGIN_CFLAGS)

libdark_theme_la_LDFLAGS = \
	$(PLUGIN_LIBS) \
	$(PLUGIN_LIBTOOL_FLAGS)

libdark_theme_la_LIBADD = \
	$(top_builddir)/lib/libgnome-pomodoro.la


CLEANFILES = \
	$(libdark_theme_la_SOURCES:.vala=.c)

EXTRA_DIST = \
	$(libdark_theme_la_plugindata_DATA)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
