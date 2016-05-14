SUBDIRS = \
	16x16 \
	24x24 \
	32x32 \
	48x48 \
	256x256 \
	symbolic

noinst_DATA = \
	gnome-pomodoro.svg

gtk_update_icon_cache = $(GTK_UPDATE_ICON_CACHE) -f -t $(datadir)/icons/hicolor

update-icon-cache:
	@-if test -z "$(DESTDIR)"; then \
		echo "Updating Gtk icon cache."; \
		$(gtk_update_icon_cache); \
	else \
		echo "*** Icon cache not updated.  After (un)install, run this:"; \
		echo "***   $(gtk_update_icon_cache)"; \
	fi

install-data-hook: update-icon-cache

uninstall-hook: update-icon-cache

EXTRA_DIST = \
	$(noinst_DATA)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
