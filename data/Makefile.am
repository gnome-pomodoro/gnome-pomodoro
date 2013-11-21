include $(top_srcdir)/Makefile.include

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
	@$(do_subst) $<> $@

-include $(top_srcdir)/git.mk
