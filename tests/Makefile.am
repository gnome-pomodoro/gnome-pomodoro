noinst_PROGRAMS = \
	tests

tests_SOURCES = \
	tests.vala \
	test-application.vala \
	test-capability.vala \
	test-capability-group.vala \
	test-capability-manager.vala \
	test-timer.vala \
	$(top_builddir)/lib/gnome-pomodoro.vapi

tests_VALAFLAGS = \
	$(GNOME_POMODORO_VALAFLAGS)

tests_CPPFLAGS = \
	$(GNOME_POMODORO_CPPFLAGS)

tests_CFLAGS = \
	$(GNOME_POMODORO_CFLAGS)

tests_LDADD = \
	$(GNOME_POMODORO_LIBS) \
	$(top_builddir)/lib/libgnome-pomodoro.la

test: tests
	$(builddir)/$<

# run make test as part of make check
check-local: test

.PHONY: test

CLEANFILES = \
	$(tests_SOURCES:.vala=.c) \
	tests \
	tests.stamp

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
