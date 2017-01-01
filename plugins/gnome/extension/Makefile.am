extensiondir = $(EXTENSION_DIR)
dist_extension_DATA = \
	dbus.js \
	dialogs.js \
	extension.js \
	indicator.js \
	metadata.json \
	notifications.js \
	presence.js \
	settings.js \
	stylesheet.css \
	timer.js \
	utils.js

nodist_extension_DATA = \
	config.js \
	metadata.json

EXTRA_DIST = \
	config.js.in \
	metadata.json.in

CLEANFILES = \
	config.js \
	metadata.json

uninstall-hook:
	rm -rf $(extensiondir)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
