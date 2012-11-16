SUBDIRS = icons sounds

gsettingsschema_in_files = org.gnome.shell.extensions.pomodoro.gschema.xml.in
gsettings_SCHEMAS = $(gsettingsschema_in_files:.xml.in=.xml)
.PRECIOUS: $(gsettings_SCHEMAS)

@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

EXTRA_DIST= \
    $(gsettingsschema_in_files)

CLEANFILES = \
    $(gsettings_SCHEMAS)
