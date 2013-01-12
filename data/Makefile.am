include ../Makefile.include

SUBDIRS = icons sounds

@INTLTOOL_DESKTOP_RULE@
desktopdir = $(datadir)/applications
desktop_in_files = $(PACKAGE_TARNAME).desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)

@GSETTINGS_RULES@
@INTLTOOL_XML_NOMERGE_RULE@
gsettings_in_files = org.gnome.shell.extensions.pomodoro.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_files:.xml.in=.xml)
.PRECIOUS: $(gsettings_SCHEMAS)

styledir = $(pkgdatadir)
style_files = \
    gtk-style.css \
    $(NULL)
style_DATA = $(style_files)

EXTRA_DIST = \
    $(desktop_in_files) \
    $(gsettings_in_files) \
    $(style_files) \
    $(NULL)

CLEANFILES = \
    $(desktop_DATA) \
    $(gsettings_SCHEMAS) \
    $(NULL)
