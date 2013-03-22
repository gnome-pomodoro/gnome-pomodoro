NULL =

AM_CPPFLAGS = \
	-include config.h \
	$(LISTBOX_CFLAGS) \
	$(NULL)

AM_VALAFLAGS = \
	@LISTBOX_PACKAGES@ \
	--vapidir=. \
	$(NULL)

pkglib_LTLIBRARIES = libegglistbox.la

libegglistbox_la_SOURCES = egg-list-box.c egg-list-box.h
libegglistbox_la_LIBADD = $(LISTBOX_LIBS)

include $(INTROSPECTION_MAKEFILE)
INTROSPECTION_GIRS = EggListBox-1.0.gir

EggListBox-1.0.gir: libegglistbox.la Makefile
EggListBox_1_0_gir_NAMESPACE = EggListBox
EggListBox_1_0_gir_VERSION = 1.0
EggListBox_1_0_gir_LIBS = libegglistbox.la
EggListBox_1_0_gir_CFLAGS = $(LISTBOX_CPPFLAGS)
EggListBox_1_0_gir_SCANNERFLAGS = --warn-all --symbol-prefix=egg --identifier-prefix=Egg
EggListBox_1_0_gir_INCLUDES = \
   Gtk-3.0

EggListBox_1_0_gir_FILES = \
    $(addprefix $(srcdir)/,$(libegglistbox_la_SOURCES))

girdir = $(pkgdatadir)/gir-1.0
typelibdir = $(pkglibdir)/girepository-1.0

gir_DATA = $(INTROSPECTION_GIRS)
typelib_DATA = $(gir_DATA:.gir=.typelib)


noinst_PROGRAMS = test-list test-scrolled test-focus test-sel

test_sel_SOURCES = \
	test-sel.c \
	$(NULL)

test_sel_LDADD = \
	$(LISTBOX_LIBS) \
	libegglistbox.la \
	$(NULL)

test_list_SOURCES = \
	test-list.vala \
	$(NULL)

test_list_LDADD = \
	$(LISTBOX_LIBS) \
	libegglistbox.la \
	$(NULL)

test_list_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	--pkg egglistbox \
	$(NULL)

test_scrolled_SOURCES = \
	test-scrolled.vala \
	$(NULL)

test_scrolled_LDADD = \
	$(LISTBOX_LIBS) \
	libegglistbox.la \
	$(NULL)

test_scrolled_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	--pkg egglistbox \
	$(NULL)

test_focus_SOURCES = \
	test-focus.c \
	$(NULL)

test_focus_LDADD = \
	$(LISTBOX_LIBS) \
	libegglistbox.la \
	$(NULL)

CLEANFILES = \
	$(test_list_SOURCES:.vala=.c) \
	$(test_scrolled_SOURCES:.vala=.c) \
	*.stamp

EXTRA_DIST = \
	$(NULL)
