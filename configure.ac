AC_INIT([gnome-pomodoro],
        [0.11.0],
        [https://github.com/codito/gnome-shell-pomodoro/issues],
        [gnome-pomodoro],
        [https://github.com/codito/gnome-shell-pomodoro])
AC_CONFIG_MACRO_DIR([m4])
AM_INIT_AUTOMAKE([1.11 no-dist-gzip dist-xz foreign])
LT_INIT
AM_MAINTAINER_MODE
AC_CONFIG_HEADERS([config.h])

AC_PATH_PROG(VALAC, valac, valac)
AC_SUBST(VALAC)

AC_PATH_PROG(GLIB_COMPILE_RESOURCES, glib-compile-resources)

IT_PROG_INTLTOOL([0.40.1])

GETTEXT_PACKAGE=AC_PACKAGE_NAME
AC_SUBST(GETTEXT_PACKAGE)

GLIB_GSETTINGS

AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(LDFLAGS)

AC_CHECK_LIB(m, floor)
AC_CHECK_HEADERS(malloc.h)
AC_CHECK_FUNCS(mallopt)

PKG_PROG_PKG_CONFIG([0.22])
GOBJECT_INTROSPECTION_REQUIRE([1.36.0])

VAPIGEN_CHECK


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
AS_HELP_STRING([--enable-more-warnings], [Maximum compiler warnings]),
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


GLIB_REQUIRED=2.36.0
GTK_REQUIRED=3.10.0
GNOME_REQUIRED=3.10.0

PKG_CHECK_MODULES(GNOME_POMODORO, [
    glib-2.0 >= $GLIB_REQUIRED
    gio-2.0 >= $GLIB_REQUIRED
    gio-unix-2.0 >= $GLIB_REQUIRED
    gthread-2.0 >= $GLIB_REQUIRED
    gmodule-no-export-2.0 >= $GLIB_REQUIRED
    gtk+-3.0 >= $GTK_REQUIRED
    gsettings-desktop-schemas >= $GTK_REQUIRED
    gnome-desktop-3.0 >= $GNOME_REQUIRED
    dbus-glib-1
    upower-glib >= 0.9.20
    libcanberra >= 0.30
    gstreamer-1.0 >= 1.0.10
])


# Some helpful constants that are available to the application

AC_SUBST(EXTENSION_UUID, ["pomodoro@arun.codito.in"])

AC_SUBST(GLIB_REQUIRED)
AC_SUBST(GTK_REQUIRED)
AC_SUBST(GNOME_REQUIRED)

AC_DEFINE_UNQUOTED([GETTEXT_PACKAGE], ["$GETTEXT_PACKAGE"],
                   [The name of the gettext domain])

AC_DEFINE_UNQUOTED([EXTENSION_UUID], ["$EXTENSION_UUID"],
                   [UUID of the pomodoro extensoin])



AC_CONFIG_FILES([
    Makefile
    vapi/Makefile
    lib/Makefile
    src/Makefile
    extension/Makefile
    data/Makefile
    data/icons/Makefile
    data/sounds/Makefile
    po/Makefile.in
    packages/Makefile
    packages/rpm/Makefile
    tests/Makefile
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
