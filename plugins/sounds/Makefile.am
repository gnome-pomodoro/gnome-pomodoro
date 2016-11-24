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
	$(libsounds_la_VALASOURCES) \
	resources.c

libsounds_la_VALAFLAGS = \
	$(PLUGIN_VALAFLAGS) \
	--pkg gstreamer-1.0 \
	--pkg libcanberra \
	--gresources resources/resources.xml

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
	$(SOUNDS_PLUGIN_LIBS) \
	$(top_builddir)/lib/libgnome-pomodoro.la

gsettings_SCHEMAS = \
	org.gnome.pomodoro.plugins.sounds.gschema.xml
@GSETTINGS_RULES@

resources = \
	resources/resources.xml
resources_deps = \
	$(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir=resources $(resources))

resources.c: $(resources) $(resources_deps)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --generate-source --c-name="pomodoro" --sourcedir=resources --target=$@ $<

BUILT_SOURCES = \
	resources.c

CLEANFILES = \
	$(BUILT_SOURCES) \
	$(libsounds_la_SOURCES:.vala=.c) \
	libsounds.la \
	libsounds_la_vala.stamp

EXTRA_DIST = \
	$(gsettings_SCHEMAS) \
	$(libsounds_la_plugindata_DATA) \
	$(resources) \
	$(resources_deps)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
