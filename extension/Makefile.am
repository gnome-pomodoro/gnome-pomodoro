extensiondir = $(datadir)/gnome-shell/extensions/$(EXTENSION_UUID)

dist_extension_DATA = \
    dbus.js \
    extension.js \
    indicator.js \
    metadata.json \
    notifications.js \
    settings.js \
    stylesheet.css \
    tasklist.js

nodist_extension_DATA = \
    config.js \
    metadata.json

EXTRA_DIST = \
    config.js.in \
    metadata.json.in

CLEANFILES = \
    config.js \
    metadata.json

config.js: config.js.in Makefile
	$(AM_V_GEN) sed -e "s|@GETTEXT_PACKAGE[@]|$(GETTEXT_PACKAGE)|g" \
	                -e "s|@PACKAGE_BUGREPORT[@]|$(PACKAGE_BUGREPORT)|g" \
	                -e "s|@PACKAGE_NAME[@]|$(PACKAGE_NAME)|g" \
	                -e "s|@PACKAGE_STRING[@]|$(PACKAGE_STRING)|g" \
	                -e "s|@PACKAGE_TARNAME[@]|$(PACKAGE_TARNAME)|g" \
	                -e "s|@PACKAGE_URL[@]|$(PACKAGE_URL)|g" \
	                -e "s|@PACKAGE_VERSION[@]|$(PACKAGE_VERSION)|g" \
	                -e "s|@PACKAGE_DATA_DIR[@]|$(pkgdatadir)|g" \
	                -e "s|@EXTENSION_UUID[@]|$(EXTENSION_UUID)|g" \
	                -e "s|@LOCALE_DIR[@]|$(localedir)|g" \
	                -e "s|@BIN_DIR[@]|$(bindir)|g" \
	                -e "s|@DATA_DIR[@]|$(datadir)|g" \
	                -e "s|@GSETTINGS_SCHEMA_DIR[@]|$(gsettingsschemadir)|g" \
	                $< > $@

metadata.json: metadata.json.in Makefile
	$(AM_V_GEN) sed -e "s|@GETTEXT_PACKAGE[@]|$(GETTEXT_PACKAGE)|g" \
	                -e "s|@PACKAGE_BUGREPORT[@]|$(PACKAGE_BUGREPORT)|g" \
	                -e "s|@PACKAGE_NAME[@]|$(PACKAGE_NAME)|g" \
	                -e "s|@PACKAGE_STRING[@]|$(PACKAGE_STRING)|g" \
	                -e "s|@PACKAGE_TARNAME[@]|$(PACKAGE_TARNAME)|g" \
	                -e "s|@PACKAGE_URL[@]|$(PACKAGE_URL)|g" \
	                -e "s|@PACKAGE_VERSION[@]|$(PACKAGE_VERSION)|g" \
	                -e "s|@PACKAGE[@]|$(PACKAGE)|g" \
	                -e "s|@EXTENSION_UUID[@]|$(EXTENSION_UUID)|g" \
	                $< > $@

uninstall-hook:
	rm -rf $(extensiondir)

-include $(top_srcdir)/git.mk
