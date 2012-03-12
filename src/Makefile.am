uuid = pomodoro@arun.codito.in
gnome_shell_extension_path = $(datadir)/gnome-shell/extensions/$(uuid)
cinnamon_extension_path = $(datadir)/cinnamon/extensions/$(uuid)


if HAVE_GNOME_SHELL
extensiondir = $(gnome_shell_extension_path)

dist_extension_DATA = \
	dbus.js \
	bell.wav \
	extension.js \
	metadata.json \
	notification.js \
	stylesheet.css \
	timer.js

nodist_extension_DATA = metadata.json
endif


if HAVE_CINNAMON
cinnamonextensiondir = $(cinnamon_extension_path)

dist_cinnamonextension_DATA = \
	dbus.js \
	bell.wav \
	extension.js \
	metadata.json \
	notification.js \
	stylesheet.css \
	timer.js

nodist_cinnamonextension_DATA = metadata.json
endif


EXTRA_DIST = metadata.json.in
CLEANFILES = metadata.json

metadata.json: metadata.json.in $(top_builddir)/config.status
	$(AM_V_GEN) sed -e "s|[@]UUID@|$(uuid)|" \
		-e "s|[@]LOCALEDIR@|$(datadir)/locale|" $< > $@

uninstall-hook:
	rmdir $(gnome_shell_extension_path) 
	rmdir $(cinnamon_extension_path) 
