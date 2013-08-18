AC_INIT([Pomodoro],
        [0.8],
        [https://github.com/codito/gnome-shell-pomodoro/issues],
        [gnome-pomodoro],
        [https://github.com/codito/gnome-shell-pomodoro])
AC_PREREQ(2.63)

AM_CONFIG_HEADER(config/config.h)
AC_CONFIG_SRCDIR([src])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([config])

AC_CANONICAL_TARGET

AM_INIT_AUTOMAKE([1.13 dist-xz no-dist-gzip tar-ustar foreign])
AM_MAINTAINER_MODE([enable])

AM_SILENT_RULES([yes])

GETTEXT_PACKAGE=AC_PACKAGE_TARNAME
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED([GETTEXT_PACKAGE], ["$GETTEXT_PACKAGE"],
                   [The name of the gettext domain])
AM_GNU_GETTEXT([external])
AM_GNU_GETTEXT_VERSION([0.17])

IT_PROG_INTLTOOL(0.40.0)
PKG_PROG_PKG_CONFIG([0.22])
GOBJECT_INTROSPECTION_REQUIRE([1.36.0])

## don't rerun to this point if we abort
AC_CACHE_SAVE

AC_PROG_CC
AC_ISC_POSIX
AC_HEADER_STDC

LT_INIT

# enable valac
AM_PROG_VALAC([0.20.0])

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

GLIB_MIN_VERSION=2.36.1
GTK_MIN_VERSION=3.8.0
GOBJECT_INTROSPECTION_MIN_VERSION=1.36.0
GDATA_MIN_VERSION=0.13.3
CAIRO_MIN_VERSION=1.12.14
CLUTTER_MIN_VERSION=1.14.2
CLUTTER_GTK_MIN_VERSION=1.4.4
PANGO_MIN_VERSION=1.34.0
GNOME_DESKTOP_MIN_VERSION=3.8.0
UPOWER_GLIB_MIN_VERSION=0.9.20
CANBERRA_MIN_VERSION=0.30
GSTREAMER_MIN_VERSION=0.10

PKG_CHECK_MODULES(GNOME_POMODORO,
                  gio-2.0 >= $GLIB_MIN_VERSION
                  glib-2.0 >= $GLIB_MIN_VERSION
                  gtk+-3.0 >= $GTK_MIN_VERSION
                  gobject-introspection-1.0 >= $GOBJECT_INTROSPECTION_MIN_VERSION
                  libgdata >= $GDATA_MIN_VERSION
                  cairo >= $CAIRO_MIN_VERSION
                  clutter-gtk-1.0 >= $CLUTTER_GTK_MIN_VERSION
                  pango >= $PANGO_MIN_VERSION
                  gnome-desktop-3.0 >= $GNOME_DESKTOP_MIN_VERSION
                  upower-glib >= $UPOWER_GLIB_MIN_VERSION
                  libcanberra >= $CANBERRA_MIN_VERSION
                  gstreamer-0.10 >= $GSTREAMER_MIN_VERSION
                  )

# egg-list-box
pkg_modules="gtk+-3.0 >= 3.4.0
	         glib-2.0 >= 2.31.10"
PKG_CHECK_MODULES(LISTBOX, [$pkg_modules])

LISTBOX_PACKAGES="--pkg gtk+-3.0"
AC_SUBST(LISTBOX_PACKAGES)

GLIB_COMPILE_RESOURCES=`$PKG_CONFIG --variable glib_compile_resources gio-2.0`
AC_SUBST(GLIB_COMPILE_RESOURCES)

AC_ARG_ENABLE([debug],
              AS_HELP_STRING([--enable-debug], [turn on debugging]),
              [case "${enableval}" in
                    yes) debug=true ;;
                    no)  debug=false ;;
                    *)   AC_MSG_ERROR([bad value ${enableval} for --enable-debug]) ;;
               esac],
               [debug=false])
AM_CONDITIONAL([DEBUG], [test x$debug = xtrue])

AC_CONFIG_FILES([
  Makefile
  egg-list-box/Makefile
  vapi/Makefile
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
        ${PACKAGE_TARNAME} ${VERSION}
        ==================

        prefix:    ${prefix}
        compiler:  ${CC}
"
