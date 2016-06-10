SUBDIRS = \
	extension

BUILT_SOURCES = \
	gnome-desktop-3.0.vapi

libgnome_la_pluginexecdir = $(PLUGIN_LIB_DIR)
libgnome_la_pluginexec_LTLIBRARIES = \
	libgnome.la

libgnome_la_plugindatadir = $(PLUGIN_LIB_DIR)
libgnome_la_plugindata_DATA = \
	gnome.plugin

libgnome_la_VALASOURCES = \
	gnome.vala \
	gnome-plugin.vala \
	gnome-shell-extension.vala \
	gnome-desktop-3.0.vapi \
	$(top_builddir)/lib/gnome-pomodoro.vapi

libgnome_la_SOURCES = \
	$(libgnome_la_VALASOURCES)

libgnome_la_VALAFLAGS = \
	$(PLUGIN_VALAFLAGS)

libgnome_la_CPPFLAGS = \
	$(PLUGIN_CPPFLAGS) \
	$(GNOME_PLUGIN_CPPFLAGS) \
	-DGNOME_DESKTOP_USE_UNSTABLE_API

libgnome_la_CFLAGS = \
	$(PLUGIN_CFLAGS) \
	$(GNOME_PLUGIN_CFLAGS)

libgnome_la_LDFLAGS = \
	$(PLUGIN_LIBS) \
	$(PLUGIN_LIBTOOL_FLAGS) \
	$(GNOME_PLUGIN_LIBS)

libgnome_la_LIBADD = \
	$(top_builddir)/lib/libgnome-pomodoro.la

gnome-desktop-3.0.vapi: $(INTROSPECTION_GIRDIR)/GnomeDesktop-3.0.gir GnomeDesktop-3.0.metadata gnome-desktop-3.0.deps
	$(AM_V_GEN) $(VAPIGEN) --library gnome-desktop-3.0 --metadatadir=$(srcdir) $<

CLEANFILES = \
	$(BUILT_SOURCES) \
	$(libgnome_la_SOURCES:.vala=.c) \
	libgnome.la \
	libgnome_la_vala.stamp

EXTRA_DIST = \
	gnome-desktop-3.0.deps \
	gnome-desktop-3.0.vapi \
	GnomeDesktop-3.0.metadata \
	Gio-2.0.metadata \
	$(libgnome_la_plugindata_DATA)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
