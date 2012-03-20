# Include all pomodoro specific variables

uuid = pomodoro@arun.codito.in
topextensiondir = $(datadir)/gnome-shell/extensions
extensiondir = $(topextensiondir)/$(uuid)

gschemas_in = org.gnome.shell.extensions.pomodoro.gschema.xml.in
gschemaname = $(gschemas_in:.xml.in=.xml)
