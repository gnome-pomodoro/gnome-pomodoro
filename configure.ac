AC_PREREQ(2.63)

AC_INIT([Pomodoro],
        [0.9.0],
        [https://github.com/codito/gnome-shell-pomodoro/issues],
        [gnome-pomodoro],
        [https://github.com/codito/gnome-shell-pomodoro])

AC_CONFIG_SRCDIR([src])
AM_CONFIG_HEADER([config/config.h])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([config])

AM_INIT_AUTOMAKE([1.13 dist-xz no-dist-gzip tar-ustar foreign])
AM_SILENT_RULES([yes])
AM_MAINTAINER_MODE([enable])
GNOME_MAINTAINER_MODE_DEFINES

AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET
AM_PROG_VALAC([0.20.0])

AC_PATH_PROG(PKG_CONFIG, pkg-config, no)

# Initialize libtool
LT_PREREQ([2.2])
LT_INIT([disable-static])


GETTEXT_PACKAGE=gnome-pomodoro
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED([GETTEXT_PACKAGE], ["$GETTEXT_PACKAGE"],
                   [The name of the gettext domain])

AM_GLIB_GNU_GETTEXT
GLIB_DEFINE_LOCALEDIR(GNOMELOCALEDIR)

GLIB_GSETTINGS

IT_PROG_INTLTOOL([0.40.1])


# Enable Debug
AC_ARG_ENABLE(debug,
  AS_HELP_STRING([--disable-debug],[Disable debugging code]),
  [
    case "${enableval}" in
      yes|no) enable_debug="${enableval}" ;;
      *)   AC_MSG_ERROR(bad value ${enableval} for --enable-debug) ;;
    esac
  ],
  [enable_debug=yes])

if test "$enable_debug" = yes; then
  AC_DEFINE(ENABLE_DEBUG, [], [Enable debug code])
else
  enable_debug=no
fi

# Enable Profiling
AC_ARG_ENABLE(profiling,
        [AS_HELP_STRING([--enable-profiling],
                        [turn on profiling])],
        , enable_profiling=yes)

if test "x$enable_profiling" = "xyes"; then
    AC_DEFINE(ENABLE_PROFILING,1,[enable profiling])
fi


# Turn on the additional warnings last, so -Werror doesn't affect other tests.
WARNING_CFLAGS=""

AC_ARG_ENABLE(more-warnings,
AS_HELP_STRING([--enable-more-warnings],[Maximum compiler warnings]),
set_more_warnings="$enableval",[
if test -d $srcdir/.git; then
    is_cvs_version=true
    set_more_warnings=yes
else
    set_more_warnings=no
fi
])
AC_MSG_CHECKING(for more warnings, including -Werror)
if test "$GCC" = "yes" -a "$set_more_warnings" != "no"; then
    AC_MSG_RESULT(yes)
    WARNING_CFLAGS="\
    -Wall \
    -Wmissing-declarations -Wmissing-prototypes \
    -Wnested-externs -Wpointer-arith \
    -Wcast-align "

    for option in -Wstrict-aliasing=0 -Wno-pointer-sign; do
        SAVE_CFLAGS="$CFLAGS"
        CFLAGS="$CFLAGS $option"
        AC_MSG_CHECKING([whether gcc understands $option])
        AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[]], [[]])],
                          [has_option=yes],
                          [has_option=no])
        if test $has_option = yes; then
               WARNING_CFLAGS="$WARNING_CFLAGS $option"
        fi
        AC_MSG_RESULT($has_option)
        CFLAGS="$SAVE_CFLAGS"
        unset has_option
        unset SAVE_CFLAGS
    done
    unset option
else
    AC_MSG_RESULT(no)
fi

AC_SUBST(WARNING_CFLAGS)


# don't rerun to this point if we abort
AC_CACHE_SAVE

m4_define(glib_minver,                 2.36.1)
m4_define(gnome_desktop_minver,        3.8.0)
m4_define(pango_minver,                1.32.0)
m4_define(gtk_minver,                  3.8.0)
m4_define(schemas_minver,              3.8.0)
m4_define(upower_minver,               0.9.20)
m4_define(canberra_minver,             0.30)
m4_define(gstreamer_minver,            0.10)

AC_CHECK_LIB(m, floor)
AC_CHECK_HEADERS(malloc.h)
AC_CHECK_FUNCS(mallopt)

PKG_PROG_PKG_CONFIG([0.22])
GOBJECT_INTROSPECTION_REQUIRE([1.36.0])

PKG_CHECK_MODULES(GNOME_POMODORO, [
    glib-2.0 >= glib_minver
    gtk+-3.0 >= gtk_minver
    gio-2.0 >= glib_minver
    gio-unix-2.0 >= glib_minver
    dbus-glib-1
    gnome-desktop-3.0 >= gnome_desktop_minver
    gthread-2.0 >= glib_minver
    gmodule-no-export-2.0 >= glib_minver
    gsettings-desktop-schemas >= schemas_minver
    upower-glib >= upower_minver
    libcanberra >= canberra_minver
    gstreamer-0.10 >= gstreamer_minver
])

# egg-list-box
PKG_CHECK_MODULES(LISTBOX, [
    glib-2.0 >= 2.31.10
    gtk+-3.0 >= 3.4.0
])

LISTBOX_PACKAGES="--pkg gtk+-3.0"
AC_SUBST(LISTBOX_PACKAGES)


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

echo "
gnome-pomodoro ${VERSION}:

    prefix:                 ${prefix}
    source code location:   ${srcdir}
    compiler:               ${CC}
    debugging support:      ${enable_debug}
    profiling support:      ${enable_profiling}
"
