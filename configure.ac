AC_PREREQ(2.63)
AC_INIT([gnome-shell-pomodoro],[0.7],[https://github.com/codito/gnome-shell-pomodoro])

AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([config])

AM_INIT_AUTOMAKE([1.11 dist-xz no-dist-gzip tar-ustar foreign])

m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

GETTEXT_PACKAGE=gnome-shell-pomodoro
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE, "$GETTEXT_PACKAGE",
                   [The prefix for our gettext translation domains.])
IT_PROG_INTLTOOL(0.40)

PKG_PROG_PKG_CONFIG([0.22])

GLIB_GSETTINGS

AC_CONFIG_FILES([
  Makefile
  src/Makefile
  po/Makefile.in
])

AC_OUTPUT

dnl ==========================================================================
echo "
    $PACKAGE $VERSION
    ========================

    prefix: ${prefix}
"
