AC_INIT([Pomodoro],
        [0.7],
        [https://github.com/codito/gnome-shell-pomodoro/issues],
        [gnome-shell-pomodoro],
        [https://github.com/codito/gnome-shell-pomodoro])
AC_PREREQ(2.63)

AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([src])
AC_CONFIG_AUX_DIR([config])

m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

AM_INIT_AUTOMAKE([1.11 dist-xz no-dist-gzip tar-ustar foreign])
AM_MAINTAINER_MODE

GLIB_GSETTINGS

GLIB_MIN_VERSION=2.31.6
GTK_MIN_VERSION=3.4
GOA_MIN_VERSION=3.2.0
CLUTTER_MIN_VERSION=1.2.0
CLUTTER_GTK_MIN_VERSION=1.2.0

GNOME_COMMON_INIT
GNOME_MAINTAINER_MODE_DEFINES

IT_PROG_INTLTOOL(0.40)

GETTEXT_PACKAGE=AC_PACKAGE_TARNAME
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED([GETTEXT_PACKAGE], ["$GETTEXT_PACKAGE"],
                   [GETTEXT package name])
AM_GLIB_GNU_GETTEXT

PKG_CHECK_MODULES(GJS, [gjs-1.0])
PKG_CHECK_MODULES(CAIRO, [cairo])
PKG_CHECK_MODULES(CLUTTER, [clutter-1.0 >= $CLUTTER_MIN_VERSION])
PKG_CHECK_MODULES(CLUTTER_GTK, [clutter-gtk-1.0 >= $CLUTTER_GTK_MIN_VERSION])
PKG_CHECK_MODULES(GLIB, [glib-2.0 >= $GLIB_MIN_VERSION])
PKG_CHECK_MODULES(GIO, [gio-2.0])
PKG_CHECK_MODULES(GTK, [gtk+-3.0 >= GTK_MIN_VERSION])

PKG_CHECK_MODULES(GOA, [goa-1.0 >= GOA_MIN_VERSION])
AC_DEFINE([GOA_API_IS_SUBJECT_TO_CHANGE], [], [We are aware that GOA's API can change])

GJS_CONSOLE=`$PKG_CONFIG --variable=gjs_console gjs-1.0`
AC_SUBST(GJS_CONSOLE)

GLIB_COMPILE_RESOURCES=`$PKG_CONFIG --variable glib_compile_resources gio-2.0`
AC_SUBST(GLIB_COMPILE_RESOURCES)

AC_CONFIG_FILES([
  Makefile
  src/Makefile
  extension/Makefile
  data/Makefile
  data/icons/Makefile
  data/sounds/Makefile
  po/Makefile.in
])
AC_OUTPUT

echo "
    $PACKAGE_STRING
    ========================

    prefix: ${prefix}
"
