uuid = pomodoro@arun.codito.in
extensiondir = $(datadir)/gnome-shell/extensions/$(uuid)
gschemaname = org.gnome.shell.extensions.pomodoro

dist_extension_DATA = \
	dbus.js \
	extension.js \
	metadata.json \
	notification.js \
	stylesheet.css \
	timer.js \
	util.js

nodist_extension_DATA = metadata.json

EXTRA_DIST = metadata.json.in
CLEANFILES = metadata.json

metadata.json: metadata.json.in $(top_builddir)/config.status
	$(AM_V_GEN) sed -e "s|[@]UUID@|$(uuid)|" \
	    -e "s|[@]LOCALEDIR@|$(datadir)/locale|" \
	    -e "s|[@]GSCHEMANAME@|$(gschemaname)|" \
	    $< > $@

uninstall-hook:
	rmdir $(extensiondir)
