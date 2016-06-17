AC_PREREQ([2.69])
AC_INIT([gnome-pomodoro],
        [0.12.1],
        [https://github.com/codito/gnome-pomodoro/issues],
        [gnome-pomodoro],
        [http://gnomepomodoro.org])
AC_CONFIG_SRCDIR([src])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([1.11 no-dist-gzip dist-xz foreign])
AM_MAINTAINER_MODE([enable])

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
VALA_REQUIRED=0.28
GLIB_REQUIRED=2.38.0
GTK_REQUIRED=3.16.0
GNOME_REQUIRED=3.16.0
INTROSPECTION_REQUIRED=0.10.1
LIBPEAS_REQUIRED=1.5.0

PKG_CHECK_MODULES(GNOME_POMODORO, [
    glib-2.0 >= $GLIB_REQUIRED
    gio-2.0 >= $GLIB_REQUIRED
    gtk+-3.0 >= $GTK_REQUIRED
    gsettings-desktop-schemas >= $GTK_REQUIRED
    gobject-introspection-1.0 >= $INTROSPECTION_REQUIRED
    libpeas-1.0 >= $LIBPEAS_REQUIRED
])

PKG_CHECK_MODULES(PLUGIN, [
    glib-2.0 >= $GLIB_REQUIRED
    gtk+-3.0 >= $GTK_REQUIRED
    libpeas-1.0 >= $LIBPEAS_REQUIRED
])

PKG_CHECK_MODULES(SOUNDS_PLUGIN, [
    gstreamer-1.0 >= 1.0.10
    libcanberra >= 0.30
])

PKG_CHECK_MODULES(GNOME_PLUGIN, [
    gnome-desktop-3.0 >= $GNOME_REQUIRED
], [with_gnome_plugin=yes], [with_gnome_plugin=no])


# Checks for programs.
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_MAKE_SET
AC_PROG_MKDIR_P
AM_PROG_VALAC($VALA_REQUIRED)

AC_PATH_PROG(GLIB_COMPILE_RESOURCES, glib-compile-resources)
AC_PATH_PROG(GTK_UPDATE_ICON_CACHE, gtk-update-icon-cache)

GOBJECT_INTROSPECTION_REQUIRE($INTROSPECTION_REQUIRED)
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


# Project constants
GNOME_POMODORO_VALAFLAGS=" \
    --target-glib \$(GLIB_REQUIRED) \
    --vapidir=\$(abs_top_srcdir) \
    --pkg config \
    --pkg gobject-2.0 \
    --pkg gio-2.0 \
    --pkg gtk+-3.0 \
    --pkg libpeas-1.0"
GNOME_POMODORO_CPPFLAGS="$GNOME_POMODORO_CPPFLAGS \
    -I\$(abs_top_srcdir) \
    -I\$(abs_top_srcdir)/lib"
GNOME_POMDORO_LIBS="$GNOME_POMDORO_LIBS -lm"

PLUGIN_VALAFLAGS="$PLUGIN_VALAFLAGS \
    --target-glib \$(GLIB_REQUIRED) \
    --vapidir=\$(abs_top_srcdir) \
    --pkg config \
    --pkg gobject-2.0 \
    --pkg gio-2.0 \
    --pkg gtk+-3.0 \
    --pkg libpeas-1.0"
PLUGIN_CPPFLAGS="$PLUGIN_CPPFLAGS \
    -I\$(abs_top_srcdir) \
    -I\$(abs_top_srcdir)/lib"
PLUGIN_LIBS="$PLUGIN_LIBS -lm"
PLUGIN_LIBTOOL_FLAGS="-module -avoid-version"

# RECURSIVE_EVAL(VALUE, RESULT)
#
# Interpolate the VALUE in loop until it doesn't change,
# and set the result to $RESULT.
# WARNING: It's easy to get an infinite loop with some unsane input.
#
AC_DEFUN([RECURSIVE_EVAL],
         [_lcl_receval="$1"
          $2=`(test "x$prefix" = xNONE && prefix="$ac_default_prefix"
               test "x$exec_prefix" = xNONE && exec_prefix="${prefix}"
               _lcl_receval_old=''
               while test "[$]_lcl_receval_old" != "[$]_lcl_receval"; do
                   _lcl_receval_old="[$]_lcl_receval"
                   eval _lcl_receval="\"[$]_lcl_receval\""
               done
               echo "[$]_lcl_receval")`])

RECURSIVE_EVAL("$localedir", [PACKAGE_LOCALE_DIR])
RECURSIVE_EVAL("$datadir/gnome-pomodoro", [PACKAGE_DATA_DIR])
RECURSIVE_EVAL("$libdir/gnome-pomodoro", [PACKAGE_LIB_DIR])
RECURSIVE_EVAL("$datadir/gnome-pomodoro/plugins", [PLUGIN_DATA_DIR])
RECURSIVE_EVAL("$libdir/gnome-pomodoro/plugins", [PLUGIN_LIB_DIR])
RECURSIVE_EVAL("$datadir/gnome-shell/extensions/pomodoro@arun.codito.in", [EXTENSION_DIR])
RECURSIVE_EVAL("$gsettingsschemadir", [GSETTINGS_SCHEMA_DIR])


# Some variables to pass to Makefiles
AC_SUBST([EXTENSION_UUID], [pomodoro@arun.codito.in])
AC_SUBST([EXTENSION_DIR])
AC_SUBST([GETTEXT_PACKAGE])
AC_SUBST([WARNING_CFLAGS])
AC_SUBST([PACKAGE_DATA_DIR])
AC_SUBST([PACKAGE_LOCALE_DIR])
AC_SUBST([GSETTINGS_SCHEMA_DIR])

AC_SUBST([GLIB_REQUIRED])
AC_SUBST([GTK_REQUIRED])
AC_SUBST([GNOME_REQUIRED])
AC_SUBST([INTROSPECTION_REQUIRED])
AC_SUBST([LIBPEAS_REQUIRED])
AC_SUBST([VALA_REQUIRED])

AC_SUBST([GNOME_POMODORO_VALAFLAGS])
AC_SUBST([GNOME_POMODORO_CPPFLAGS])
AC_SUBST([GNOME_POMODORO_CFLAGS])
AC_SUBST([GNOME_POMODORO_LIBS])

AC_SUBST([PLUGIN_DATA_DIR], [$PLUGIN_DATA_DIR])
AC_SUBST([PLUGIN_LIB_DIR], [$PLUGIN_LIB_DIR])
AC_SUBST([PLUGIN_VALAFLAGS])
AC_SUBST([PLUGIN_CPPFLAGS])
AC_SUBST([PLUGIN_CFLAGS])
AC_SUBST([PLUGIN_LIBS])
AC_SUBST([PLUGIN_LIBTOOL_FLAGS])

AM_CONDITIONAL([WITH_GNOME_PLUGIN], [test "$with_gnome_plugin" = yes])


# Some constants to pass to config.h
AC_DEFINE_UNQUOTED([GETTEXT_PACKAGE], "$GETTEXT_PACKAGE",
                   [The name of the gettext domain])
AC_DEFINE_UNQUOTED([GSETTINGS_SCHEMA_DIR], "$GSETTINGS_SCHEMA_DIR",
                   [GSettings schema dir])
AC_DEFINE_UNQUOTED([EXTENSION_UUID], "$EXTENSION_UUID",
                   [UUID of the pomodoro extension])
AC_DEFINE_UNQUOTED([EXTENSION_DIR], "$EXTENSION_DIR",
                   [Path of the pomodoro extension])
AC_DEFINE_UNQUOTED([PACKAGE_LOCALE_DIR], "$PACKAGE_LOCALE_DIR",
                   [Locale dir])
AC_DEFINE_UNQUOTED([PACKAGE_DATA_DIR], "$PACKAGE_DATA_DIR",
                   [Data dir])
AC_DEFINE_UNQUOTED([PACKAGE_LIB_DIR], "$PACKAGE_LIB_DIR",
                   [Lib dir])
AC_DEFINE_UNQUOTED([PLUGIN_DATA_DIR], "$PLUGIN_DATA_DIR",
                   [Plugin data dir])
AC_DEFINE_UNQUOTED([PLUGIN_LIB_DIR], "$PLUGIN_LIB_DIR",
                   [Plugin lib dir])

AC_DEFINE([GNOME_DESKTOP_USE_UNSTABLE_API], [],
          [We are aware that GNOME_DESKTOP's API can change])

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
    lib/Makefile
    src/Makefile
    data/Makefile
    data/icons/Makefile
    data/icons/16x16/Makefile
    data/icons/24x24/Makefile
    data/icons/32x32/Makefile
    data/icons/48x48/Makefile
    data/icons/256x256/Makefile
    data/icons/symbolic/Makefile
    data/sounds/Makefile
    po/Makefile.in
    man/Makefile
    packages/Makefile
    packages/debian/Makefile
    packages/rpm/Makefile
    plugins/Makefile
    plugins/dark-theme/Makefile
    plugins/gnome/Makefile
    plugins/gnome/extension/config.js
    plugins/gnome/extension/metadata.json
    plugins/gnome/extension/Makefile
    plugins/sounds/Makefile
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
