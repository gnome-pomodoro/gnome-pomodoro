include $(top_srcdir)/Makefile.include

AM_CFLAGS = \
    -I$(top_srcdir) \
    -I$(top_builddir) \
    -I$(top_builddir)/lib \
    $(WARNING_CFLAGS) \
    -DGETTEXT_PACKAGE="\"$(GETTEXT_PACKAGE)\"" \
    -DPACKAGE_LOCALE_DIR="\"$(localedir)\"" \
    -DPACKAGE_SRC_DIR="\"$(srcdir)\"" \
    -DPACKAGE_DATA_DIR="\"$(pkgdatadir)\"" \
    -DGNOME_DESKTOP_USE_UNSTABLE_API \
    -Wall \
    -Wno-unused


bin_PROGRAMS = gnome-pomodoro

gnome_pomodoro_SOURCES = \
    main.vala

gnome_pomodoro_VALAFLAGS = \
    --vapidir=$(top_srcdir)/vapi \
    --vapidir=$(top_builddir)/vapi \
    --vapidir=$(top_builddir)/lib \
    --pkg gnome-pomodoro \
    --pkg config

gnome_pomodoro_CPPFLAGS = \
    $(GNOME_POMODORO_CFLAGS)

gnome_pomodoro_LDADD = \
    $(GNOME_POMODORO_LIBS) \
    $(top_builddir)/lib/libgnome-pomodoro.la

gnome_pomodoro_vala.stamp: $(top_builddir)/lib/libgnome-pomodoro.la


CLEANFILES = \
    gnome-pomodoro \
    gnome_pomodoro_vala.stamp

dist-hook:
	cd $(distdir); rm -f $(CLEANFILES)

-include $(top_srcdir)/git.mk
