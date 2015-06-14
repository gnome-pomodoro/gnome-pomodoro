AC_PREREQ([2.69])
AC_INIT([gnome-pomodoro],
        [0.11.1],
        [https://github.com/codito/gnome-pomodoro/issues],
        [gnome-pomodoro],
        [http://gnomepomodoro.org])
AC_CONFIG_SRCDIR([src])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([1.11 no-dist-gzip dist-xz foreign])
AM_MAINTAINER_MODE

# enable nice build output if available
m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

LT_INIT

IT_PROG_INTLTOOL([0.40.1])
PKG_PROG_PKG_CONFIG([0.22])
GOBJECT_INTROSPECTION_REQUIRE([1.36.0])

GETTEXT_PACKAGE=AC_PACKAGE_NAME
WARNING_CFLAGS=


# Extra configuration arguments.
AC_ARG_ENABLE(debug,
    AS_HELP_STRING([--enable-debug], [Turn on debugging]),,
    [enable_debug=no])

AC_ARG_ENABLE(profiling,
    AS_HELP_STRING([--enable-profiling], [Turn on profiling]),,
    [enable_profiling=no])

AC_ARG_ENABLE([more-warnings],
    AS_HELP_STRING([--enable-more-warnings], [Maximum compiler warnings]),,
    [enable_more_warnings=no])


# Checks for pkg-config packages.
GLIB_REQUIRED=2.36.0
GTK_REQUIRED=3.13.0
GNOME_REQUIRED=3.13.0
TELEPATHY_GLIB_REQUIRED=0.17.5

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
    libcanberra >= 0.30
    gstreamer-1.0 >= 1.0.10
    telepathy-glib >= $TELEPATHY_GLIB_REQUIRED
])


# Checks for programs.
AC_PROG_CC
AC_PROG_CXX
AC_PROG_INSTALL
AC_PROG_AWK
AC_PROG_LN_S
AC_PROG_MAKE_SET
AC_PROG_MKDIR_P

AM_PROG_VALAC([0.26])
AC_PATH_PROG(GLIB_COMPILE_RESOURCES, glib-compile-resources)

GLIB_GSETTINGS
VAPIGEN_CHECK

# Is docbook2man available?
AC_PATH_PROG(DOCBOOK2MAN, docbook2man, no)
if test "$DOCBOOK2MAN" = "no" ; then
	AC_MSG_WARN([docbook2man not found, will not be able to build man documentation])
fi
AM_CONDITIONAL(HAVE_DOCBOOK2MAN, [test "$DOCBOOK2MAN" != "no"])


# Checks for libraries.
AC_CHECK_LIB(m, floor)


# Checks for header files.
AC_CHECK_HEADERS([malloc.h float.h stdlib.h string.h])


# Checks for typedefs, structures, and compiler characteristics.
AC_TYPE_SIZE_T


# Checks for library functions.
AC_CHECK_FUNCS([atexit floor memchr memset mallopt])


# Checks for --enable-more-warnings.
AC_MSG_CHECKING([for more warnings, including -Werror])
if test "$GCC" = yes -a "$enable_more_warnings" = yes; then
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
        if test "$has_option" = yes; then
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


# Some variables to pass to Makefiles
AC_SUBST(EXTENSION_UUID, [pomodoro@arun.codito.in])
AC_SUBST(GETTEXT_PACKAGE)
AC_SUBST(WARNING_CFLAGS)

AC_SUBST(GLIB_REQUIRED)
AC_SUBST(GTK_REQUIRED)
AC_SUBST(GNOME_REQUIRED)
AC_SUBST(TELEPATHY_GLIB_REQUIRED)


# Some constants to pass to config.h
AC_DEFINE_UNQUOTED([GETTEXT_PACKAGE], "$GETTEXT_PACKAGE",
                   [The name of the gettext domain])

AC_DEFINE_UNQUOTED([EXTENSION_UUID], "$EXTENSION_UUID",
                   [UUID of the pomodoro extensoin])

if test "$enable_debug" = yes; then
	AC_DEFINE([ENABLE_DEBUG], [1], [Debug code])
else
	AC_DEFINE([ENABLE_DEBUG], [0], [Debug code])
fi

if test "$enable_profiling" = yes; then
	AC_DEFINE([ENABLE_PROFILING], [1], [Debug code])
else
	AC_DEFINE([ENABLE_PROFILING], [0], [Debug code])
fi


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
    man/Makefile
    packages/Makefile
    packages/debian/Makefile
    packages/rpm/Makefile
    tests/Makefile
])

AC_OUTPUT

echo "
gnome-pomodoro ${VERSION}:

    prefix:                 ${prefix}
    datadir:                ${datadir}
    srcdir:                 ${srcdir}
    compiler:               ${CC}
    cflags:                 ${CFLAGS}
    cppflags:               ${CPPFLAGS}
    ldflags:                ${LDFLAGS}
"
