
RPM_DEFINES = \
	--define "_sourcedir $(abs_builddir)" \
	--define "_specdir $(abs_srcdir)"

SUBST=sed \
	-e "s|@GETTEXT_PACKAGE[@]|$(GETTEXT_PACKAGE)|g" \
	-e "s|@PACKAGE_BUGREPORT[@]|$(PACKAGE_BUGREPORT)|g" \
	-e "s|@PACKAGE_NAME[@]|$(PACKAGE_NAME)|g" \
	-e "s|@PACKAGE_STRING[@]|$(PACKAGE_STRING)|g" \
	-e "s|@PACKAGE_TARNAME[@]|$(PACKAGE_TARNAME)|g" \
	-e "s|@PACKAGE_URL[@]|$(PACKAGE_URL)|g" \
	-e "s|@PACKAGE_VERSION[@]|$(PACKAGE_VERSION)|g" \
	-e "s|@EXTENSION_UUID[@]|$(EXTENSION_UUID)|g" \
	-e "s|@GLIB_REQUIRED[@]|$(GLIB_REQUIRED)|g" \
	-e "s|@GTK_REQUIRED[@]|$(GTK_REQUIRED)|g" \
	-e "s|@GNOME_REQUIRED[@]|$(GNOME_REQUIRED)|g" \
	-e "s|@TELEPATHY_GLIB_REQUIRED[@]|$(TELEPATHY_GLIB_REQUIRED)|g" \
	-e "s|@prefix[@]|$(prefix)|g" \
	-e "s|@datadir[@]|$(datadir)|g" \
	-e "s|@pkgdatadir[@]|$(pkgdatadir)|g"


gnome_pomodoro_spec_in_files = \
	$(PACKAGE_NAME).spec.in

gnome_pomodoro_spec = \
	$(PACKAGE_NAME)-$(PACKAGE_VERSION).spec

gnome_pomodoro_tar_gz = \
	$(PACKAGE_NAME)-$(PACKAGE_VERSION).tar.xz


rpm-src:
	cd $(top_builddir) && $(MAKE) $(AM_MAKEFLAGS) dist-xz;
	$(AM_V_GEN) cp $(top_builddir)/$(PACKAGE_TARNAME)-$(PACKAGE_VERSION).tar.xz $(gnome_pomodoro_tar_gz);
	\
	$(AM_V_GEN) $(SUBST) $(gnome_pomodoro_spec_in_files) > $(gnome_pomodoro_spec)

rpm: rpm-src
	env -i PATH=/usr/bin/:/bin SHELL=$(SHELL) HOSTNAME=$${HOSTNAME} HOME=$${HOME} \
	rpmbuild $(RPM_DEFINES) -ba $(gnome_pomodoro_spec)

EXTRA_DIST = \
	$(gnome_pomodoro_spec_in_files)

CLEANFILES = \
	$(gnome_pomodoro_tar_gz) \
	$(gnome_pomodoro_spec)

.PHONY: all rpm rpm-src

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
