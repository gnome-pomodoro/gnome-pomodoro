
BUILT_SOURCES = \
	upower-glib.vapi \
	gnome-desktop-3.0.vapi

upower-glib.vapi: /usr/share/gir-1.0/UPowerGlib-1.0.gir UPowerGlib-1.0.metadata
	vapigen --library upower-glib --pkg gio-2.0 --metadatadir=$(srcdir) $<

gnome-desktop-3.0.vapi: /usr/share/gir-1.0/GnomeDesktop-3.0.gir GnomeDesktop-3.0.metadata
	vapigen --library gnome-desktop-3.0 --pkg gio-2.0 --pkg gtk+-3.0 --metadatadir=$(srcdir) $<

-include $(top_srcdir)/git.mk
