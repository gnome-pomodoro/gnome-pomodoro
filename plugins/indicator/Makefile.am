SUBDIRS = \
	icons

libindicator_la_pluginexecdir = $(PLUGIN_LIB_DIR)
libindicator_la_pluginexec_LTLIBRARIES = \
	libindicator.la

libindicator_la_plugindatadir = $(PLUGIN_LIB_DIR)
libindicator_la_plugindata_DATA = \
	indicator.plugin

libindicator_la_VALASOURCES = \
	indicator-capability.vala \
	indicator-plugin.vala \
	$(top_builddir)/lib/gnome-pomodoro.vapi

libindicator_la_SOURCES = \
	$(libindicator_la_VALASOURCES)

libindicator_la_VALAFLAGS = \
	$(PLUGIN_VALAFLAGS) \
	--pkg appindicator3-0.1

libindicator_la_CPPFLAGS = \
	$(PLUGIN_CPPFLAGS) \
	$(INDICATOR_PLUGIN_CPPFLAGS)

libindicator_la_CFLAGS = \
	$(PLUGIN_CFLAGS) \
	$(INDICATOR_PLUGIN_CFLAGS)

libindicator_la_LDFLAGS = \
	$(PLUGIN_LDFLAGS)

libindicator_la_LIBADD = \
	$(PLUGIN_LIBS) \
	$(INDICATOR_PLUGIN_LIBS) \
	$(top_builddir)/lib/libgnome-pomodoro.la


CLEANFILES = \
	$(libindicator_la_SOURCES:.vala=.c)
	libindicator.la \
	libindicator_la_vala.stamp

EXTRA_DIST = \
	$(libindicator_la_plugindata_DATA)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
