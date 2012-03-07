uuid = pomodoro@arun.codito.in
topextensiondir = $(datadir)/gnome-shell/extensions
extensiondir = $(topextensiondir)/$(uuid)

dist_extension_DATA = \
	dbus.js \
	bell.wav \
	extension.js \
	metadata.json \
	notification.js \
	stylesheet.css \
	timer.js

nodist_extension_DATA = metadata.json

EXTRA_DIST = metadata.json.in
CLEANFILES = metadata.json

metadata.json: metadata.json.in $(top_builddir)/config.status
	$(AM_V_GEN) sed -e "s|[@]UUID@|$(uuid)|" \
		-e "s|[@]LOCALEDIR@|$(datadir)/locale|" $< > $@

uninstall-hook:
	rmdir $(extensiondir)
