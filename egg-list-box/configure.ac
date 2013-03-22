AC_PREREQ([2.67])
AC_INIT([egg-list-box],[3.5.1],[http://bugzilla.gnome.org/enter_bug.cgi?product=gnome-contacts])
AC_CONFIG_SRCDIR([test-list.vala])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_MACRO_DIR([m4])
AM_INIT_AUTOMAKE
# Enable silent rules is available
AM_SILENT_RULES([yes])
AM_MAINTAINER_MODE([enable])
AC_CONFIG_FILES([Makefile
		])

LT_INIT
AC_PROG_CC
AM_PROG_VALAC([0.16.0])
AC_PROG_INSTALL

pkg_modules="gtk+-3.0 >= 3.4.0
	     glib-2.0 >= 2.31.10"
PKG_CHECK_MODULES(LISTBOX, [$pkg_modules])

LISTBOX_PACKAGES="--pkg gtk+-3.0"
AC_SUBST(LISTBOX_PACKAGES)

AC_OUTPUT( egg-list-box-uninstalled.pc )
