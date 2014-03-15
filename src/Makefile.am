
bin_PROGRAMS = \
    gnome-pomodoro

gnome_pomodoro_SOURCES = \
    main.vala

gnome_pomodoro_VALAFLAGS = \
    --vapidir=$(top_srcdir) \
    --vapidir=$(top_builddir)/vapi \
    --vapidir=$(top_builddir)/lib \
    --pkg gnome-pomodoro \
    --pkg config \
    --pkg gobject-2.0 \
    --pkg gio-2.0 \
    --pkg gdk-3.0 \
    --pkg gtk+-3.0

gnome_pomodoro_CPPFLAGS = \
    $(GNOME_POMODORO_CFLAGS) \
    $(WARNING_CFLAGS) \
    -I$(top_srcdir) \
    -I$(top_srcdir)/lib \
    -DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
    -DPACKAGE_LOCALE_DIR=\"$(localedir)\" \
    -DPACKAGE_DATA_DIR=\"$(pkgdatadir)\" \
    -DGNOME_DESKTOP_USE_UNSTABLE_API

gnome_pomodoro_LDADD = \
    $(GNOME_POMODORO_LIBS) \
    $(top_builddir)/lib/libgnome-pomodoro.la


CLEANFILES = \
    gnome-pomodoro

dist-hook:
	cd $(distdir); rm -f $(CLEANFILES)

-include $(top_srcdir)/git.mk
