extensiondir = $(datadir)/gnome-shell/extensions/$(EXTENSION_UUID)

dist_extension_DATA = \
    dbus.js \
    extension.js \
    indicator.js \
    metadata.json \
    notifications.js \
    stylesheet.css \
    tasklist.js

nodist_extension_DATA = \
    metadata.json

EXTRA_DIST = \
    metadata.json.in

CLEANFILES = \
    metadata.json

metadata.json: metadata.json.in Makefile
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

uninstall-hook:
	rm -rf $(extensiondir)

-include $(top_srcdir)/git.mk
