gnome_pomodoro_specdir =

dist_gnome_pomodoro_spec_DATA = \
    gnome-pomodoro.spec

gnome-pomodoro.spec: gnome-pomodoro.spec.in
	$(AM_V_GEN) sed -e "s|@GETTEXT_PACKAGE[@]|$(GETTEXT_PACKAGE)|g" \
	                -e "s|@PACKAGE_BUGREPORT[@]|$(PACKAGE_BUGREPORT)|g" \
	                -e "s|@PACKAGE_NAME[@]|$(PACKAGE_NAME)|g" \
	                -e "s|@PACKAGE_STRING[@]|$(PACKAGE_STRING)|g" \
	                -e "s|@PACKAGE_TARNAME[@]|$(PACKAGE_TARNAME)|g" \
	                -e "s|@PACKAGE_URL[@]|$(PACKAGE_URL)|g" \
	                -e "s|@PACKAGE_VERSION[@]|$(PACKAGE_VERSION)|g" \
	                -e "s|@UUID[@]|$(EXTENSION_UUID)|g" \
	                -e "s|@GLIB_REQUIRED[@]|$(GLIB_REQUIRED)|g" \
	                -e "s|@GTK_REQUIRED[@]|$(GTK_REQUIRED)|g" \
	                -e "s|@GNOME_REQUIRED[@]|$(GNOME_REQUIRED)|g" \
	                -e "s|@distdir[@]|$(PACKAGE_TARNAME)|g" \
	                -e "s|@datadir[@]|$(datadir)|g" \
	                -e "s|@pkgdatadir[@]|$(pkgdatadir)|g" \
	                $< > $@

EXTRA_DIST = \
    gnome-pomodoro.spec.in

CLEANFILES = \
    gnome-pomodoro.spec

# "rpm" rule is defined in topmost Makefile.am

-include $(top_srcdir)/git.mk
