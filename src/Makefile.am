include ../Makefile.include

AM_CFLAGS = \
    -DGETTEXT_PACKAGE="\"$(GETTEXT_PACKAGE)\"" \
    -DPACKAGE_LOCALE_DIR="\"$(localedir)\"" \
    -DPACKAGE_SRC_DIR="\"$(srcdir)\"" \
    -DPACKAGE_DATA_DIR="\"$(pkgdatadir)\"" \
    -DGNOME_DESKTOP_USE_UNSTABLE_API \
    -Wall \
    -Wno-unused \
    -I$(srcdir)/../egg-list-box \
    $(GNOME_POMODORO_CFLAGS)

if DEBUG
    AM_CFLAGS += -O0 -DDEBUG
    AM_VALAFLAGS = -g -DDEBUG
endif

bin_PROGRAMS = gnome-pomodoro

gnome_pomodoro_SOURCES = \
    $(srcdir)/../egg-list-box/egg-list-box.c \
    about-dialog.vala \
    animation.vala \
    application.vala \
    command-line.vala \
    keybindings.vala \
    main.vala \
    preferences-dialog.vala \
    resources.c \
    service.vala \
    sounds.vala \
    timer.vala \
    utils.vala \
    widgets.vala

gnome_pomodoro_VALAFLAGS = \
    --vapidir=$(srcdir)/../vapi \
    --vapidir=$(srcdir)/../egg-list-box \
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

gnome_pomodoro_LDFLAGS = \
    -Wl,--export-dynamic

# FIXME: include libm more gracefully
gnome_pomodoro_LDADD = \
    $(GNOME_POMODORO_LIBS) -lm

BUILT_SOURCES = \
    resources.c \
    resources.h

resource_files = $(shell glib-compile-resources --sourcedir=$(srcdir) --generate-dependencies $(srcdir)/gnome-pomodoro.gresource.xml)
resources.c: gnome-pomodoro.gresource.xml $(resource_files)
	$(AM_V_GEN) glib-compile-resources --target=$@ --sourcedir=$(srcdir) --generate-source --c-name pomodoro $<
resources.h: gnome-pomodoro.gresource.xml $(resource_files)
	$(AM_V_GEN) glib-compile-resources --target=$@ --sourcedir=$(srcdir) --generate-header --c-name pomodoro $<

