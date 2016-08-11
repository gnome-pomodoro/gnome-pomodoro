libsounds_la_pluginexecdir = $(PLUGIN_LIB_DIR)
libsounds_la_pluginexec_LTLIBRARIES = \
	libsounds.la

libsounds_la_plugindatadir = $(PLUGIN_LIB_DIR)
libsounds_la_plugindata_DATA = \
	sounds.plugin

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
	$(SOUNDS_PLUGIN_CPPFLAGS) \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DPACKAGE_LOCALE_DIR=\""$(localedir)"\" \
	-DPACKAGE_DATA_DIR=\""$(pkgdatadir)"\"

libsounds_la_CFLAGS = \
	$(PLUGIN_CFLAGS) \
	$(SOUNDS_PLUGIN_CFLAGS)

libsounds_la_LDFLAGS = \
	$(PLUGIN_LDFLAGS)

libsounds_la_LIBADD = \
	$(PLUGIN_LIBS) \
	$(SOUNDS_PLUGIN_LIBS)
	$(top_builddir)/lib/libgnome-pomodoro.la


CLEANFILES = \
	$(libsounds_la_SOURCES:.vala=.c) \
	libsounds.la \
	libsounds_la_vala.stamp

EXTRA_DIST = \
	$(libsounds_la_plugindata_DATA)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
