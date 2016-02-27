bin_PROGRAMS = \
	gnome-pomodoro

gnome_pomodoro_SOURCES = \
	main.vala \
	$(top_builddir)/lib/gnome-pomodoro.vapi

gnome_pomodoro_VALAFLAGS = \
	--target-glib=$(GLIB_REQUIRED) \
	--vapidir=$(top_builddir)/vapi \
	--pkg config \
	--pkg gobject-2.0 \
	--pkg gio-2.0 \
	--pkg gtk+-3.0 \
	--pkg libpeas-1.0

gnome_pomodoro_CFLAGS = \
	$(GNOME_POMODORO_CFLAGS) \
	$(WARNING_CFLAGS)

gnome_pomodoro_LDADD = \
	$(GNOME_POMODORO_LIBS) \
	-lm \
	$(top_builddir)/lib/libgnome-pomodoro.la


CLEANFILES = \
	$(BUILT_SOURCES) \
	$(gnome_pomodoro_SOURCES:.vala=.c) \
	gnome-pomodoro \
	gnome_pomodoro_vala.stamp

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
