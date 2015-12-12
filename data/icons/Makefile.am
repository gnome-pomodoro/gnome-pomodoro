public_icon_themes = \
    hicolor

public_icons = \
    hicolor_apps_16x16_gnome-pomodoro.png \
    hicolor_apps_24x24_gnome-pomodoro.png \
    hicolor_apps_32x32_gnome-pomodoro.png \
    hicolor_apps_48x48_gnome-pomodoro.png \
    hicolor_apps_256x256_gnome-pomodoro.png \
    hicolor_apps_scalable_gnome-pomodoro-symbolic.svg

noinst_DATA = \
    gnome-pomodoro.svg

gtk_update_icon_cache = GTK_UPDATE_ICON_CACHE -f -t

update-icon-cache:
	@-if test -z "$(DESTDIR)"; then \
		echo "Updating Gtk icon cache."; \
		for theme in $(public_icon_themes); do \
			$(gtk_update_icon_cache) $(datadir)/icons/$$theme; \
		done; \
	else \
		echo "*** Icon cache not updated.  After (un)install, run this:"; \
		for theme in $(public_icon_themes); do \
			echo "***   $(gtk_update_icon_cache) $(datadir)/icons/$$theme"; \
		done; \
	fi

install-icons:
	for icon in $(public_icons); do \
		THEME=`echo $$icon | cut -d_ -f1`; \
		CONTEXT=`echo $$icon | cut -d_ -f2`; \
		SIZE=`echo $$icon | cut -d_ -f3`; \
		ICONFILE=`echo $$icon | cut -d_ -f4`; \
		$(MKDIR_P) $(DESTDIR)$(datadir)/icons/$$THEME/$$SIZE/$$CONTEXT; \
		$(INSTALL_DATA) $(srcdir)/$$icon $(DESTDIR)$(datadir)/icons/$$THEME/$$SIZE/$$CONTEXT/$$ICONFILE; \
	done

uninstall-icons:
	-for icon in $(public_icons); do \
		THEME=`echo $$icon | cut -d_ -f1`; \
		CONTEXT=`echo $$icon | cut -d_ -f2`; \
		SIZE=`echo $$icon | cut -d_ -f3`; \
		ICONFILE=`echo $$icon | cut -d_ -f4`; \
		rm -f $(DESTDIR)$(datadir)/icons/$$THEME/$$SIZE/$$CONTEXT/$$ICONFILE; \
	done

install-data-local: install-icons update-icon-cache

uninstall-local: uninstall-icons update-icon-cache

EXTRA_DIST = \
    $(public_icons) \
    $(noinst_DATA)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
