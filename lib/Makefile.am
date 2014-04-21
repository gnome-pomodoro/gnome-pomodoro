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
    screensaver.vala \
    service.vala \
    settings.vala \
    sounds.vala \
    timer.vala \
    utils.vala \
    widgets.vala

libgnome_pomodoro_la_VALAFLAGS = \
    --library=gnome-pomodoro \
    --header=gnome-pomodoro.h \
    --vapi=gnome-pomodoro.vapi \
    --vapidir=$(abs_top_srcdir) \
    --vapidir=$(abs_top_srcdir)/vapi \
    --vapidir=$(abs_top_builddir)/vapi \
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
    --pkg gstreamer-1.0

libgnome_pomodoro_la_CPPFLAGS = \
    $(GNOME_POMODORO_CFLAGS) \
    $(WARNING_CFLAGS) \
    -I$(abs_top_builddir) \
    -DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
    -DPACKAGE_LOCALE_DIR=\"$(localedir)\" \
    -DPACKAGE_DATA_DIR=\"$(pkgdatadir)\" \
    -DGNOME_DESKTOP_USE_UNSTABLE_API

libgnome_pomodoro_la_DEPENDENCIES = \
    $(top_builddir)/vapi/gnome-desktop-3.0.vapi \
    $(top_builddir)/vapi/upower-glib.vapi


CLEANFILES = \
    $(libgnome_pomodoro_la_SOURCES:.vala=.c) \
    gnome-pomodoro.h \
    gnome-pomodoro.vapi \
    libgnome-pomodoro.la \
    libgnome_pomodoro_la_vala.stamp

dist-hook:
	cd $(distdir) && rm -f $(CLEANFILES)

-include $(top_srcdir)/git.mk
