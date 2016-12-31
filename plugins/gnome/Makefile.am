SUBDIRS = \
	extension

libgnome_la_pluginexecdir = $(PLUGIN_LIB_DIR)
libgnome_la_pluginexec_LTLIBRARIES = \
	libgnome.la

libgnome_la_plugindatadir = $(PLUGIN_LIB_DIR)
libgnome_la_plugindata_DATA = \
	gnome.plugin

libgnome_la_VALASOURCES = \
	gnome.vala \
	gnome-idle-monitor.vala \
	gnome-plugin.vala \
	gnome-shell-extension.vala \
	$(top_builddir)/lib/gnome-pomodoro.vapi

libgnome_la_SOURCES = \
	$(libgnome_la_VALASOURCES)

libgnome_la_VALAFLAGS = \
	$(PLUGIN_VALAFLAGS)

libgnome_la_CPPFLAGS = \
	$(PLUGIN_CPPFLAGS) \
	$(GNOME_PLUGIN_CPPFLAGS) \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DPACKAGE_LOCALE_DIR=\""$(localedir)"\" \
	-DPACKAGE_DATA_DIR=\""$(pkgdatadir)"\"

libgnome_la_CFLAGS = \
	$(PLUGIN_CFLAGS) \
	$(GNOME_PLUGIN_CFLAGS)

libgnome_la_LDFLAGS = \
	$(PLUGIN_LDFLAGS)

libgnome_la_LIBADD = \
	$(PLUGIN_LIBS) \
	$(GNOME_PLUGIN_LIBS) \
	$(top_builddir)/lib/libgnome-pomodoro.la

gsettings_SCHEMAS = \
	org.gnome.pomodoro.plugins.gnome.gschema.xml
@GSETTINGS_RULES@


CLEANFILES = \
	gnome.c \
	gnome-plugin.c \
	gnome-shell-extension.c \
	libgnome.la \
	libgnome_la_vala.stamp

EXTRA_DIST = \
	$(gsettings_SCHEMAS) \
	$(libgnome_la_plugindata_DATA)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
