
BUILT_SOURCES = \
	gnome-desktop-3.0.vapi

EXTRA_DIST = \
	gnome-desktop-3.0.vapi \
	GnomeDesktop-3.0.metadata \
	Gio-2.0.metadata

CLEANFILES = \
	$(BUILT_SOURCES)

gnome-desktop-3.0.vapi: $(INTROSPECTION_GIRDIR)/GnomeDesktop-3.0.gir GnomeDesktop-3.0.metadata gnome-desktop-3.0.deps
	$(AM_V_GEN) $(VAPIGEN) --library gnome-desktop-3.0 --metadatadir=$(srcdir) $<

dist-hook:
	cd $(distdir) && rm -f $(CLEANFILES)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
