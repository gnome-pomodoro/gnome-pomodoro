bin_PROGRAMS = \
	gnome-pomodoro

gnome_pomodoro_SOURCES = \
	main.vala \
	$(top_builddir)/lib/gnome-pomodoro.vapi

gnome_pomodoro_VALAFLAGS = \
	$(GNOME_POMODORO_VALAFLAGS) \
	--pkg posix

gnome_pomodoro_CPPFLAGS = \
	$(GNOME_POMODORO_CPPFLAGS) \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DPACKAGE_LOCALE_DIR=\""$(localedir)"\" \
	-DPACKAGE_DATA_DIR=\""$(pkgdatadir)"\"

gnome_pomodoro_CFLAGS = \
	$(GNOME_POMODORO_CFLAGS)

gnome_pomodoro_LDADD = \
	$(GNOME_POMODORO_LIBS) \
	$(top_builddir)/lib/libgnome-pomodoro.la


CLEANFILES = \
	$(gnome_pomodoro_SOURCES:.vala=.c) \
	gnome-pomodoro \
	gnome_pomodoro_vala.stamp

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
