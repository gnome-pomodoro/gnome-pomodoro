AC_PREREQ(2.63)
AC_INIT([gnome-shell-pomodoro],[0.6],[https://github.com/codito/gnome-shell-pomodoro])

AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([config])

AM_INIT_AUTOMAKE([1.10 dist-bzip2 no-dist-gzip foreign tar-ustar])

m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

GETTEXT_PACKAGE=gnome-shell-pomodoro
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE, "$GETTEXT_PACKAGE",
                   [The prefix for our gettext translation domains.])
IT_PROG_INTLTOOL(0.26)

PKG_PROG_PKG_CONFIG([0.22])

GLIB_GSETTINGS


AC_MSG_CHECKING([whether to support gnome-shell])
AC_ARG_ENABLE([gnome-shell],
              [AS_HELP_STRING([--enable-gnome-shell],
                              [Install extension for gnome-shell])],
              [ENABLE_GNOME_SHELL="${enableval}"], [ENABLE_GNOME_SHELL='yes'])
AC_MSG_RESULT(${ENABLE_GNOME_SHELL})

AC_MSG_CHECKING([whether to support cinnamon])
AC_ARG_ENABLE([cinnamon],
              [AS_HELP_STRING([--enable-cinnamon],
                              [Install extension for cinamon])],
              [ENABLE_CINNAMON="${enableval}"], [ENABLE_CINNAMON='yes'])
AC_MSG_RESULT(${ENABLE_CINNAMON})

AM_CONDITIONAL(ENABLE_GNOME_SHELL, [test x$ENABLE_GNOME_SHELL = xyes])
AM_CONDITIONAL(ENABLE_CINNAMON, [test x$ENABLE_CINNAMON = xyes])

AM_CONDITIONAL(HAVE_GNOME_SHELL, true)
AM_CONDITIONAL(HAVE_CINNAMON, true)

if test "x${ENABLE_GNOME_SHELL}" = xyes; then
  AC_CHECK_PROGS(GNOME_SHELL, gnome-shell)
  if test -z "$GNOME_SHELL"; then
    AC_MSG_NOTICE([gnome-shell not found])
    AM_CONDITIONAL(HAVE_GNOME_SHELL, false)
  fi
fi

if test "x${ENABLE_CINNAMON}" = xyes; then
  AC_CHECK_PROGS(CINNAMON, cinnamon)
  if test -z "$CINNAMON"; then
    AC_MSG_NOTICE([cinnamon not found])
    AM_CONDITIONAL(HAVE_CINNAMON, false)
  fi
fi


AC_CONFIG_FILES([
  src/Makefile
  Makefile
  po/Makefile.in
])
AC_OUTPUT
