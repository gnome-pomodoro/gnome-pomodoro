include $(top_srcdir)/Makefile.include

AM_CFLAGS = \
    -I$(top_srcdir) \
    -I$(top_builddir) \
    $(WARNING_CFLAGS) \
    -DGETTEXT_PACKAGE="\"$(GETTEXT_PACKAGE)\"" \
    -DPACKAGE_LOCALE_DIR="\"$(localedir)\"" \
    -DPACKAGE_SRC_DIR="\"$(srcdir)\"" \
    -DPACKAGE_DATA_DIR="\"$(pkgdatadir)\"" \
    -DGNOME_DESKTOP_USE_UNSTABLE_API \
    -Wall \
    -Wno-unused


noinst_LTLIBRARIES = \
    libgnome-pomodoro.la

libgnome_pomodoro_la_SOURCES = \
    about-dialog.vala \
    animation.vala \
    application.vala \
    command-line.vala \
    gnome-desktop.vala \
    keybindings.vala \
    main-window.vala \
    power.vala \
    preferences-dialog.vala \
    presence.vala \
    resources.c \
    screensaver.vala \
    service.vala \
    sounds.vala \
    timer.vala \
    utils.vala \
    widgets.vala

libgnome_pomodoro_la_VALAFLAGS = \
    --vapidir=$(top_srcdir)/vapi \
    --vapidir=$(top_builddir)/vapi \
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
    --pkg gstreamer-1.0 \
    --library gnome-pomodoro \
    --vapi gnome-pomodoro.vapi \
    -H gnome-pomodoro.h

libgnome_pomodoro_la_CPPFLAGS = \
    $(GNOME_POMODORO_CFLAGS)

libgnome_pomodoro_la_LIBADD = \
    $(GNOME_POMODORO_LIBS)

libgnome_pomodoro_la_DEPENDENCIES = \
    $(top_builddir)/vapi/gnome-desktop-3.0.vapi \
    $(top_builddir)/vapi/upower-glib.vapi

libgnome_pomodoro_la_vala.stamp: \
    $(top_builddir)/vapi/gnome-desktop-3.0.vapi \
    $(top_builddir)/vapi/upower-glib.vapi


resource_files = $(shell glib-compile-resources --sourcedir=$(srcdir) --generate-dependencies $(srcdir)/gnome-pomodoro.gresource.xml)

resources.c: gnome-pomodoro.gresource.xml $(resource_files)
	$(AM_V_GEN) glib-compile-resources --target=$@ --sourcedir=$(srcdir) --generate-source --c-name pomodoro $<

resources.h: gnome-pomodoro.gresource.xml $(resource_files)
	$(AM_V_GEN) glib-compile-resources --target=$@ --sourcedir=$(srcdir) --generate-header --c-name pomodoro $<


BUILT_SOURCES = \
    resources.c \
    resources.h

CLEANFILES = \
    $(BUILT_SOURCES) \
    libgnome_pomodoro_la_vala.stamp

EXTRA_DIST = \
    $(resource_files) \
    gnome-pomodoro.gresource.xml

dist-hook:
	cd $(distdir); rm -f $(CLEANFILES)

-include $(top_srcdir)/git.mk
