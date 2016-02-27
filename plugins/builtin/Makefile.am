libsounds_la_pluginexecdir = $(PLUGIN_LIB_DIR)
libsounds_la_pluginexec_LTLIBRARIES = \
	libsounds.la

libsounds_la_plugindatadir = $(PLUGIN_LIB_DIR)
libsounds_la_plugindata_DATA = \
	sounds.plugin

libsounds_la_DEPENDENCIES = \
	$(top_builddir)/lib/libgnome-pomodoro.la

libsounds_la_VALASOURCES = \
	sound-player.vala \
	sounds-plugin.vala \
	$(top_builddir)/lib/gnome-pomodoro.vapi

libsounds_la_SOURCES = \
	$(libsounds_la_VALASOURCES)

libsounds_la_VALAFLAGS = \
	$(PLUGIN_VALAFLAGS) \
	--pkg gstreamer-1.0 \
	--pkg libcanberra \
	--gresources "$(top_srcdir)/lib/resources/resources.xml"

libsounds_la_CPPFLAGS = \
	$(PLUGIN_CPPFLAGS) \
	$(BUILTIN_PLUGIN_CPPFLAGS)

libsounds_la_CFLAGS = \
	$(PLUGIN_CFLAGS) \
	$(BUILTIN_PLUGIN_CFLAGS)

libsounds_la_LDFLAGS = \
	$(PLUGIN_LIBS) \
	$(PLUGIN_LIBTOOL_FLAGS) \
	$(BUILTIN_PLUGIN_LIBS)

libsounds_la_LIBADD = \
	$(top_builddir)/lib/libgnome-pomodoro.la

CLEANFILES = \
	$(libsounds_la_SOURCES:.vala=.c)

EXTRA_DIST = \
	$(libsounds_la_plugindata_DATA)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
