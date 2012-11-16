NULL =

public_sounds = \
	bell.wav \
	$(NULL)

EXTRA_DIST = \
	$(public_sounds)		\
	$(NULL)

###############################################################################

install-sounds:
	for sound in $(public_sounds); do \
		mkdir -p $(DESTDIR)$(pkgdatadir)/sounds; \
		$(INSTALL_DATA) $(srcdir)/$$sound $(DESTDIR)$(pkgdatadir)/sounds/$$sound; \
	done

uninstall-sounds:
	-for icon in $(public_icons); do \
		rm -f $(DESTDIR)$(pkgdatadir)/sounds/$$sound; \
	done

install-data-local: install-sounds

uninstall-local: uninstall-sounds
