SUBDIRS = \
	icons \
	sounds

desktopdir = $(datadir)/applications
desktop_in_files = org.gnome.Pomodoro.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)

$(desktop_DATA): $(desktop_in_files)
	$(AM_V_GEN) $(MSGFMT) --desktop -d $(top_srcdir)/po --template $< -o $@

gsettings_SCHEMAS = \
	org.gnome.pomodoro.gschema.xml
@GSETTINGS_RULES@

servicedir = $(datadir)/dbus-1/services
service_in_files = \
	org.gnome.Pomodoro.service.in
service_DATA = $(service_in_files:.service.in=.service)

$(service_DATA): $(service_in_files)
	$(AM_V_GEN) sed -e "s|@bindir[@]|$(bindir)|g" $< > $@

appstream_in_files = \
	org.gnome.Pomodoro.appdata.xml.in
appstream_XML = $(appstream_in_files:.xml.in=.xml)
@APPSTREAM_XML_RULES@

$(appstream_XML): $(appstream_in_files)
	$(AM_V_GEN) $(MSGFMT) --xml -d $(top_srcdir)/po --template $< -o $@

EXTRA_DIST = \
	$(appstream_in_files) \
	$(desktop_in_files) \
	$(service_in_files) \
	$(gsettings_SCHEMAS)

CLEANFILES = \
	$(appstream_XML) \
	$(desktop_DATA) \
	$(service_DATA)

AM_DISTCHECK_CONFIGURE_FLAGS = \
	--enable-appdata-check

check-local: $(desktop_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

dist-hook:
	cd $(distdir) && rm -f $(CLEANFILES)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
