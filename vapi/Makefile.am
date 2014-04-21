
BUILT_SOURCES = \
    upower-glib.vapi \
    gnome-desktop-3.0.vapi

EXTRA_DIST = \
    libcanberra.vapi \
    upower-glib.vapi \
    gnome-desktop-3.0.vapi \
    UPowerGlib-1.0.metadata \
    GnomeDesktop-3.0.metadata

CLEANFILES = \
    $(BUILT_SOURCES)

upower-glib.vapi: $(INTROSPECTION_GIRDIR)/UPowerGlib-1.0.gir UPowerGlib-1.0.metadata
	$(AM_V_GEN) $(VAPIGEN) --library upower-glib --metadatadir=$(srcdir) --pkg gio-2.0 $<

gnome-desktop-3.0.vapi: $(INTROSPECTION_GIRDIR)/GnomeDesktop-3.0.gir GnomeDesktop-3.0.metadata
	$(AM_V_GEN) $(VAPIGEN) --library gnome-desktop-3.0 --metadatadir=$(srcdir) --pkg gio-2.0 --pkg gtk+-3.0 $<

dist-hook:
	cd $(distdir) && rm -f $(CLEANFILES)

-include $(top_srcdir)/git.mk
