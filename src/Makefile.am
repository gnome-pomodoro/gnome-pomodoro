include $(top_srcdir)/Makefile.include

bin_PROGRAMS = gnome-pomodoro

AM_CFLAGS = \
    -I$(top_srcdir) \
    -I$(top_builddir) \
    -I$(top_srcdir)/egg-list-box \
    $(GNOME_POMODORO_CFLAGS) \
    $(WARNING_CFLAGS) \
    -DGETTEXT_PACKAGE="\"$(GETTEXT_PACKAGE)\"" \
    -DPACKAGE_LOCALE_DIR="\"$(localedir)\"" \
    -DPACKAGE_SRC_DIR="\"$(srcdir)\"" \
    -DPACKAGE_DATA_DIR="\"$(pkgdatadir)\"" \
    -DGNOME_DESKTOP_USE_UNSTABLE_API \
    -Wall \
    -Wno-unused

resource_files = $(shell glib-compile-resources --sourcedir=$(srcdir) --generate-dependencies $(srcdir)/gnome-pomodoro.gresource.xml)

resources.c: gnome-pomodoro.gresource.xml $(resource_files)
	glib-compile-resources --target=$@ --sourcedir=$(srcdir) --generate-source --c-name pomodoro gnome-pomodoro.gresource.xml

resources.h: gnome-pomodoro.gresource.xml $(resource_files)
	glib-compile-resources --target=$@ --sourcedir=$(srcdir) --generate-header --c-name pomodoro gnome-pomodoro.gresource.xml

gnome_pomodoro_built_sources = \
    resources.c \
    resources.h

gnome_pomodoro_SOURCES = \
    $(top_srcdir)/egg-list-box/egg-list-box.c \
    about-dialog.vala \
    animation.vala \
    application.vala \
    command-line.vala \
    gnome-desktop.vala \
    keybindings.vala \
    main.vala \
    power.vala \
    preferences-dialog.vala \
    presence.vala \
    resources.c \
    service.vala \
    sounds.vala \
    timer.vala \
    utils.vala \
    widgets.vala

gnome_pomodoro_VALAFLAGS = \
    --vapidir=$(top_srcdir)/vapi \
    --vapidir=$(top_srcdir)/egg-list-box \
    --pkg config \
    --pkg gobject-2.0 \
    --pkg gio-2.0 \
    --pkg gdk-3.0 \
    --pkg gtk+-3.0 \
    --pkg dbus-glib-1 \
    --pkg pango \
    --pkg cairo \
    --pkg gnome-desktop-3.0 \
    --pkg upower-glib \
    --pkg libcanberra \
    --pkg egglistbox \
    --pkg gstreamer-0.10

gnome_pomodoro_LDADD = \
    $(GNOME_POMODORO_LIBS)

BUILT_SOURCES = \
    $(gnome_pomodoro_built_sources)

CLEANFILES = \
    $(BUILT_SOURCES)

EXTRA_DIST = \
    $(resource_files) \
    gnome-pomodoro.gresource.xml

dist-hook:
	cd $(distdir); rm -f $(CLEANFILES)

-include $(top_srcdir)/git.mk
