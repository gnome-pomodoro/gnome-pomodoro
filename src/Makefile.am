include ../Makefile.include

bin_SCRIPTS = \
    gnome-shell-pomodoro \
    $(NULL)

resourcedir = $(pkgdatadir)
resource_DATA = gnome-shell-pomodoro.gresource

BUILT_SOURCES = \
    $(NULL)

EXTRA_DIST = \
    gnome-shell-pomodoro.in \
    gnome-shell-pomodoro.gresource.xml \
    resources/app-menu.ui \
    $(NULL)

CLEANFILES = \
    gnome-shell-pomodoro \
    gnome-shell-pomodoro.gresource \
    $(NULL)

include Makefile-js.am

gnome-shell-pomodoro: gnome-shell-pomodoro.in
	$(AM_V_GEN) $(do_subst) $< > $@
	chmod +x $@

gnome-shell-pomodoro.gresource: gnome-shell-pomodoro.gresource.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies $(srcdir)/gnome-shell-pomodoro.gresource.xml)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(srcdir) $<
