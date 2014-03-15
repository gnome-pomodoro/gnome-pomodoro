SUBDIRS = \
    icons \
    sounds

@INTLTOOL_DESKTOP_RULE@
desktopdir = $(datadir)/applications
desktop_in_files = $(PACKAGE_TARNAME).desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)

@GSETTINGS_RULES@
@INTLTOOL_XML_NOMERGE_RULE@
gsettings_in_files = org.gnome.pomodoro.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_files:.xml.in=.xml)
.PRECIOUS: $(gsettings_SCHEMAS)

servicedir = $(datadir)/dbus-1/services
service_in_files = \
    org.gnome.Pomodoro.service.in
service_DATA = $(service_in_files:.service.in=.service)

EXTRA_DIST = \
    $(desktop_in_files) \
    $(gsettings_in_files) \
    $(service_in_files)

CLEANFILES = \
    $(desktop_DATA) \
    $(gsettings_SCHEMAS) \
    $(service_DATA)

$(service_DATA): $(service_in_files) Makefile
	$(AM_V_GEN) sed -e 's|@GETTEXT_PACKAGE@|$(GETTEXT_PACKAGE)|g' \
	                -e 's|@PACKAGE_BUGREPORT@|$(PACKAGE_BUGREPORT)|g' \
	                -e 's|@PACKAGE_NAME@|$(PACKAGE_NAME)|g' \
	                -e 's|@PACKAGE_STRING@|$(PACKAGE_STRING)|g' \
	                -e 's|@PACKAGE_TARNAME@|$(PACKAGE_TARNAME)|g' \
	                -e 's|@PACKAGE_URL@|$(PACKAGE_URL)|g' \
	                -e 's|@PACKAGE_VERSION@|$(PACKAGE_VERSION)|g' \
	                -e 's|@PACKAGE@|$(PACKAGE)|g' \
	                -e 's|@UUID@|$(EXTENSION_UUID)|g' \
	                $<> $@

$(service_DATA): $(service_in_files)

-include $(top_srcdir)/git.mk
