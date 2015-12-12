noinst_LTLIBRARIES = \
    libgnome-pomodoro.la

libgnome_pomodoro_la_VALASOURCES = \
    about-dialog.vala \
    animation.vala \
    application.vala \
    calendar-button.vala \
    enum-combo-box.vala \
    gnome-desktop-module.vala \
    gnome-session-manager.vala \
    gnome-session-manager-plugin.vala \
    keybinding-chooser-button.vala \
    keybindings.vala \
    log-scale.vala \
    mode-button.vala \
    module.vala \
    plugin.vala \
    preferences-dialog.vala \
    presence-module.vala \
    presence-plugin.vala \
    screensaver-module.vala \
    service.vala \
    settings.vala \
    skype.vala \
    skype-plugin.vala \
    sound-chooser-button.vala \
    sounds-module.vala \
    symbolic-button.vala \
    telepathy-plugin.vala \
    timer.vala \
    timer-state.vala \
    utils.vala

libgnome_pomodoro_la_SOURCES = \
    $(libgnome_pomodoro_la_VALASOURCES) \
	resources.c

libgnome_pomodoro_la_VALAFLAGS = \
    --library=gnome-pomodoro \
    --header=gnome-pomodoro.h \
    --vapi=gnome-pomodoro.vapi \
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
    --pkg libcanberra \
    --pkg gstreamer-1.0 \
    --pkg telepathy-glib \
    --enable-experimental \
	--gresources resources/resources.xml

libgnome_pomodoro_la_CPPFLAGS = \
    $(GNOME_POMODORO_CPPFLAGS)

libgnome_pomodoro_la_CFLAGS = \
    $(GNOME_POMODORO_CFLAGS) \
    $(WARNING_CFLAGS)

libgnome_pomodoro_la_LIBADD = \
    $(GNOME_POMODORO_LIBS)

libgnome_pomodoro_la_DEPENDENCIES = \
    $(top_builddir)/vapi/gnome-desktop-3.0.vapi

resources = \
	resources/resources.xml
resources_deps = \
	$(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir=resources $(resources))

resources.c: $(resources) $(resources_deps)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --generate-source --sourcedir=resources --target=$@ $<

# A hack to make plugins/ and src/ build after the lib/
# gnome-pomodoro.vapi: libgnome-pomodoro.la

BUILT_SOURCES = \
	resources.c

CLEANFILES = \
    $(libgnome_pomodoro_la_SOURCES:.vala=.c) \
    gnome-pomodoro.h \
    gnome-pomodoro.vapi \
    libgnome-pomodoro.la \
    libgnome_pomodoro_la_vala.stamp \
    resources.c

EXTRA_DIST = \
	$(resources_deps)

-include $(top_srcdir)/git.mk
