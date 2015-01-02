
BUILT_SOURCES = \
    gnome-desktop-3.0.vapi

EXTRA_DIST = \
    gnome-desktop-3.0.vapi \
    gom-1.0.vapi \
    GnomeDesktop-3.0.metadata \
    Gio-2.0.metadata \
    Gom-1.0.metadata

CLEANFILES = \
    $(BUILT_SOURCES)

gnome-desktop-3.0.vapi: $(INTROSPECTION_GIRDIR)/GnomeDesktop-3.0.gir GnomeDesktop-3.0.metadata
	$(AM_V_GEN) $(VAPIGEN) --library gnome-desktop-3.0 --metadatadir=$(srcdir) --pkg gio-2.0 --pkg gtk+-3.0 $<

#gom-1.0.vapi: $(INTROSPECTION_GIRDIR)/Gom-1.0.gir Gom-1.0.metadata Gio-2.0.metadata
#	$(AM_V_GEN) $(VAPIGEN) --library gom-1.0 --metadatadir=$(srcdir) --pkg sqlite3 $<

dist-hook:
	cd $(distdir) && rm -f $(CLEANFILES)

-include $(top_srcdir)/git.mk
