ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}

SUBDIRS = src po


# Install GSettings schema file 
gschemas_in = org.gnome.shell.extensions.pomodoro.gschema.xml.in

@INTLTOOL_XML_NOMERGE_RULE@

gsettings_SCHEMAS = $(gschemas_in:.xml.in=.xml)

@GSETTINGS_RULES@

CLEANFILES = $(gschemas_in:.xml.in=.valid) $(gsettings_SCHEMAS)
EXTRA_DIST = $(gschemas_in)


# Install "timer-symbolic.svg" icon file 
hicolor = $(datadir)/icons/hicolor
iconsdir = $(hicolor)/scalable/status
icons_DATA = timer-symbolic.svg

EXTRA_DIST += $(icons_DATA)

update_icon_cache = gtk-update-icon-cache -f -t $(DESTDIR)$(hicolor)

install-data-hook:
	if echo "Updating icon cache" && $(update_icon_cache); then \
		echo "Done."; \
	else \
		echo "*** GTK icon cache not updated. After install, run this:"; \
		echo $(update_icon_cache); \
	fi
uninstall-hook:
	echo "Updating icon cache" && $(update_icon_cache) && echo "Done."
