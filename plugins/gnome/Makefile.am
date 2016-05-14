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

libgnome_la_DEPENDENCIES = \
	$(top_builddir)/lib/libgnome-pomodoro.la

libgnome_la_VALASOURCES = \
	gnome.vala \
	gnome-plugin.vala \
	gnome-shell-extension.vala \
	$(top_builddir)/lib/gnome-pomodoro.vapi

libgnome_la_SOURCES = \
	$(libgnome_la_VALASOURCES)

libgnome_la_VALAFLAGS = \
	$(PLUGIN_VALAFLAGS) \
	--vapidir=$(srcdir) \
	--pkg gnome-desktop-3.0

libgnome_la_CPPFLAGS = \
	$(GNOME_PLUGIN_CPPFLAGS) \
	$(PLUGIN_CFLAGS)

libgnome_la_CFLAGS = \
	$(GNOME_PLUGIN_CFLAGS) \
	$(PLUGIN_CFLAGS)

libgnome_la_LDFLAGS = \
	$(GNOME_PLUGIN_LIBS) \
	$(PLUGIN_LIBS) \
	$(PLUGIN_LIBTOOL_FLAGS)

libgnome_la_LIBADD = \
	$(top_builddir)/lib/libgnome-pomodoro.la

gnome-desktop-3.0.vapi: $(INTROSPECTION_GIRDIR)/GnomeDesktop-3.0.gir GnomeDesktop-3.0.metadata gnome-desktop-3.0.deps
	$(AM_V_GEN) $(VAPIGEN) --library gnome-desktop-3.0 --metadatadir=$(srcdir) $<

dist-hook:
	cd $(distdir) && rm -f $(CLEANFILES)

CLEANFILES = \
	$(BUILT_SOURCES) \
	$(libgnome_la_SOURCES:.vala=.c)

EXTRA_DIST = \
	gnome-desktop-3.0.vapi \
	GnomeDesktop-3.0.metadata \
	Gio-2.0.metadata \
	$(libgnome_la_plugindata_DATA)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
