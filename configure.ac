AC_INIT([Pomodoro],
        [0.7],
        [https://github.com/codito/gnome-shell-pomodoro/issues],
        [gnome-shell-pomodoro],
        [https://github.com/codito/gnome-shell-pomodoro])
AC_PREREQ(2.63)

AM_CONFIG_HEADER(config/config.h)
AC_CONFIG_SRCDIR([src])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([config])

m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

AC_CANONICAL_TARGET

AM_INIT_AUTOMAKE([1.11 dist-xz no-dist-gzip tar-ustar foreign])
AM_MAINTAINER_MODE([enable])

GETTEXT_PACKAGE=AC_PACKAGE_TARNAME
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED([GETTEXT_PACKAGE], ["$GETTEXT_PACKAGE"],
                   [The name of the gettext domain])
IT_PROG_INTLTOOL(0.40.0)
PKG_PROG_PKG_CONFIG([0.22])

AM_GNU_GETTEXT([external])
AM_GNU_GETTEXT_VERSION([0.17])

GOBJECT_INTROSPECTION_REQUIRE([0.9.6])

## don't rerun to this point if we abort
AC_CACHE_SAVE

AC_PROG_CC
AM_PROG_CC_C_O
AC_PROG_CXX
AC_ISC_POSIX
AC_HEADER_STDC

# enable valac
AM_PROG_VALAC([0.16.0])

# no stupid static libraries
AM_DISABLE_STATIC
# enable libtool
AC_PROG_LIBTOOL
# avoid libtool for LTCOMPILE, use it only to link

## don't rerun to this point if we abort
AC_CACHE_SAVE

GLIB_GSETTINGS

AC_CHECK_LIBM
AC_SUBST(LIBM)

## EggListBox submodule
#prev_top_build_prefix=$ac_top_build_prefix
#prev_ac_configure_args=$ac_configure_args
##AX_CONFIG_DIR([egg-list-box])
#ac_top_build_prefix=$prev_top_build_prefix
#ac_configure_args=$prev_ac_configure_args

#export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:"$ac_top_build_prefix"egg-list-box

GLIB_MIN_VERSION=2.31.6
GTK_MIN_VERSION=3.4
GOBJECT_INTROSPECTION_MIN_VERSION=1.31.6
GDATA_MIN_VERSION=0.13.1
GOA_MIN_VERSION=3.2.0
CLUTTER_MIN_VERSION=1.2.0
CLUTTER_GTK_MIN_VERSION=1.2.0

PKG_CHECK_MODULES(POMODORO,
                  clutter-gtk-1.0 >= $CLUTTER_GTK_MIN_VERSION
                  gjs-1.0
                  glib-2.0 >= $GLIB_MIN_VERSION
                  gio-2.0 >= $GLIB_MIN_VERSION
                  libgdata >= $GDATA_MIN_VERSION
                  gobject-introspection-1.0 >= $GOBJECT_INTROSPECTION_MIN_VERSION
                  gtk+-3.0 >= $GTK_MIN_VERSION
                  gnome-desktop-3.0
                  goa-1.0 >= $GOA_MIN_VERSION)

# egg-list-box
pkg_modules="gtk+-3.0 >= 3.4.0
	     glib-2.0 >= 2.31.10"
PKG_CHECK_MODULES(LISTBOX, [$pkg_modules])

LISTBOX_PACKAGES="--pkg gtk+-3.0"
AC_SUBST(LISTBOX_PACKAGES)


GJS_CONSOLE=`$PKG_CONFIG --variable=gjs_console gjs-1.0`
AC_SUBST(GJS_CONSOLE)

GLIB_COMPILE_RESOURCES=`$PKG_CONFIG --variable glib_compile_resources gio-2.0`
AC_SUBST(GLIB_COMPILE_RESOURCES)

AC_CONFIG_FILES([
  Makefile
  egg-list-box/Makefile
  src/Makefile
  extension/Makefile
  data/Makefile
  data/icons/Makefile
  data/sounds/Makefile
  po/Makefile.in
])
AC_OUTPUT

dnl ==========================================================================
echo "
        gnome-shell-pomodoro $VERSION
        ==================

        prefix:    ${prefix}
        compiler:  ${CC}
"
