SUBDIRS = \
	icons \
	sounds

#BUILT_SOURCES = \
#	gschemas.compiled

desktopdir = $(datadir)/applications
desktop_in_files = org.gnome.Pomodoro.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)

%.desktop: %.desktop.in
	msgfmt --desktop -d $(top_srcdir)/po --template $< -o $@

@GSETTINGS_RULES@
gsettings_in_files = org.gnome.pomodoro.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_files:.xml.in=.xml)
.PRECIOUS: $(gsettings_SCHEMAS)

servicedir = $(datadir)/dbus-1/services
service_in_files = \
	org.gnome.Pomodoro.service.in
service_DATA = $(service_in_files:.service.in=.service)

$(service_DATA): $(service_in_files)
	$(AM_V_GEN) sed -e "s|@bindir[@]|$(bindir)|g" $< > $@

appstream_in_files = \
	org.gnome.Pomodoro.appdata.xml.in
appstream_XML = $(appstream_in_files:.appdata.xml.in=.appdata.xml)
@APPSTREAM_XML_RULES@

$(appdata_DATA): $(appdata_in_files)
	$(AM_V_GEN) $(MSGFMT) --xml --template $< -d $(top_srcdir)/po -o $@

# We need to compile schemas at make time
# to run from source tree
#gschemas.compiled: $(gsettings_SCHEMAS)
#	$(AM_V_GEN) $(GLIB_COMPILE_SCHEMAS) \
#		$(addprefix --schema-file=,$(GTK_GSETTINGS_SCHEMAS)) \
#		--targetdir=$(builddir)

EXTRA_DIST = \
	$(appstream_in_files) \
	$(desktop_in_files) \
	$(gsettings_in_files) \
	$(service_in_files)

CLEANFILES = \
	$(appstream_XML) \
	$(desktop_DATA) \
	$(gsettings_SCHEMAS) \
	$(service_DATA)
#	gschemas.compiled

AM_DISTCHECK_CONFIGURE_FLAGS == --enable-appdata-check

dist-hook:
	cd $(distdir) && rm -f $(CLEANFILES)

# all-local: gschemas.compiled

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
