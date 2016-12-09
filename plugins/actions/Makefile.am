libactions_la_pluginexecdir = $(PLUGIN_LIB_DIR)
libactions_la_pluginexec_LTLIBRARIES = \
	libactions.la

libactions_la_plugindatadir = $(PLUGIN_LIB_DIR)
libactions_la_plugindata_DATA = \
	actions.plugin

libactions_la_VALASOURCES = \
	action-listboxrow.vala \
	action-page.vala \
	actions.vala \
	action.vala \
	enums.vala \
	preferences-page.vala \
	$(top_builddir)/lib/gnome-pomodoro.vapi

libactions_la_SOURCES = \
	$(libactions_la_VALASOURCES) \
	resources.c

libactions_la_VALAFLAGS = \
	$(PLUGIN_VALAFLAGS) \
	--gresources resources/resources.xml

libactions_la_CPPFLAGS = \
	$(PLUGIN_CPPFLAGS) \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DPACKAGE_LOCALE_DIR=\""$(localedir)"\" \
	-DPACKAGE_DATA_DIR=\""$(pkgdatadir)"\"

libactions_la_CFLAGS = \
	$(PLUGIN_CFLAGS)

libactions_la_LDFLAGS = \
	$(PLUGIN_LDFLAGS)

libactions_la_LIBADD = \
	$(PLUGIN_LIBS) \
	$(top_builddir)/lib/libgnome-pomodoro.la

gsettings_SCHEMAS = \
	org.gnome.pomodoro.plugins.actions.gschema.xml
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
	$(libactions_la_SOURCES:.vala=.c) \
	libactions.la \
	libactions_la_vala.stamp

EXTRA_DIST = \
	$(gsettings_SCHEMAS) \
	$(libactions_la_plugindata_DATA) \
	$(resources) \
	$(resources_deps)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
