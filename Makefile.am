ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}

SUBDIRS = src po

include extension.mk

# Install GSettings schema file 
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

# Targets
## Creates a zipped archive for extensions.gnome.org
## TODO: include icon, not sure how to access icon from local extension install
zip:
	blddir="$(abs_builddir)/_build"; \
	ziptarget="$${blddir}/$(PACKAGE_NAME).$(PACKAGE_VERSION).zip"; \
	rm -rf "$${blddir}"; \
	echo "$${blddir}"; \
	$(MKDIR_P) "$${blddir}"; \
	$(MAKE) install DESTDIR="$${blddir}"; \
	$(MKDIR_P) "$${blddir}$(extensiondir)/schemas"; \
	cp -r "$${blddir}$(datadir)/locale/" "$${blddir}$(extensiondir)"; \
	cp "$(gsettings_SCHEMAS)" "$${blddir}$(extensiondir)/schemas"; \
	cp "COPYING" "$${blddir}$(extensiondir)"; \
	cd "$${blddir}/$(extensiondir)/"; \
	zip -qr "$${ziptarget}" "."; \
	cd -;

## Updates the icon cache, post system-wide install
install-data-hook:
	if echo "Updating icon cache" && $(update_icon_cache); then \
		echo "Done."; \
	else \
		echo "*** GTK icon cache not updated. After install, run this:"; \
		echo $(update_icon_cache); \
	fi
uninstall-hook:
	echo "Updating icon cache" && $(update_icon_cache) && echo "Done."
