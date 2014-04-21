AM_CFLAGS = \
    $(GNOME_POMODORO_CFLAGS) \
    $(WARNING_CFLAGS)

noinst_PROGRAMS = \
    tests

tests_SOURCES = \
    tests.vala \
    test-timer.vala

gnome_pomodoro_DEPENDENCIES = \
    ../lib/libgnome-pomodoro.la

tests_VALAFLAGS = \
    --vapidir=$(abs_top_srcdir) \
    --vapidir=$(abs_top_srcdir)/lib \
    --vapidir=$(abs_top_srcdir)/vapi \
    --vapidir=$(abs_top_builddir)/vapi \
    --pkg gnome-pomodoro \
    --pkg config \
    --pkg gobject-2.0 \
    --pkg gio-2.0 \
    --pkg gdk-3.0 \
    --pkg gtk+-3.0 \
    --pkg posix

tests_CPPFLAGS = \
    $(GNOME_POMODORO_CFLAGS) \
    $(WARNING_CFLAGS) \
    -I$(abs_top_srcdir) \
    -I$(abs_top_srcdir)/lib \
    -DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
    -DPACKAGE_LOCALE_DIR=\"$(localedir)\" \
    -DPACKAGE_DATA_DIR=\"$(pkgdatadir)\" \
    -DGNOME_DESKTOP_USE_UNSTABLE_API

tests_LDADD = \
    $(GNOME_POMODORO_LIBS) \
    $(top_builddir)/lib/libgnome-pomodoro.la


test: tests
	$(builddir)/$<

# run make test as part of make check
check-local: test

.PHONY: test

-include $(top_srcdir)/git.mk
