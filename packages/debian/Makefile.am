
DEB_RELEASE = 1

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
	-e "s|@INTROSPECTION_REQUIRED[@]|$(INTROSPECTION_REQUIRED)|g" \
	-e "s|@LIBPEAS_REQUIRED[@]|$(LIBPEAS_REQUIRED)|g" \
	-e "s|@VALA_REQUIRED[@]|$(VALA_REQUIRED)|g" \
	-e "s|@prefix[@]|$(prefix)|g" \
	-e "s|@datadir[@]|$(datadir)|g" \
	-e "s|@pkgdatadir[@]|$(pkgdatadir)|g"


gnome_pomodoro_debian_in_files = \
	debian/changelog.in \
	debian/compat.in \
	debian/control.in \
	debian/rules.in
gnome_pomodoro_debian = $(gnome_pomodoro_debian_in_files:.in=)

gnome_pomodoro_orig_tar_gz = \
	$(PACKAGE_NAME)_$(PACKAGE_VERSION).orig.tar.gz

gnome_pomodoro_debian_tar_gz = \
	$(PACKAGE_NAME)_$(PACKAGE_VERSION)-$(DEB_RELEASE).debian.tar.gz

gnome_pomodoro_dsc_in_files = \
	gnome-pomodoro.dsc.in
gnome_pomodoro_dsc_deps = \
	$(gnome_pomodoro_orig_tar_gz) \
	$(gnome_pomodoro_debian_tar_gz)
gnome_pomodoro_dsc = \
	$(PACKAGE_NAME)_$(PACKAGE_VERSION)-$(DEB_RELEASE).dsc


deb-src:
	for file in $(gnome_pomodoro_debian_in_files); do \
		$(AM_V_GEN) $(SUBST) $$file > $${file%.*}; \
	done
	$(AM_V_GEN) tar -cvzf $(gnome_pomodoro_debian_tar_gz) $(gnome_pomodoro_debian);
	\
	cd $(top_builddir) && $(MAKE) $(AM_MAKEFLAGS) dist-gzip;
	$(AM_V_GEN) cp $(top_builddir)/$(PACKAGE_TARNAME)-$(PACKAGE_VERSION).tar.gz $(gnome_pomodoro_orig_tar_gz);
	\
	$(AM_V_GEN) $(SUBST) $(gnome_pomodoro_dsc_in_files) > $(gnome_pomodoro_dsc);
	echo "Files:" >> $(gnome_pomodoro_dsc); \
	for file in $(gnome_pomodoro_dsc_deps); do \
		file_md5=`md5sum $$file | cut -d " " -f 1`; \
		file_size=`stat -c%s $$file`; \
		echo " $$file_md5 $$file_size $$file" >> $(gnome_pomodoro_dsc); \
	done


EXTRA_DIST = \
	$(gnome_pomodoro_debian_in_files) \
	$(gnome_pomodoro_dsc_in_files)

CLEANFILES = \
	$(gnome_pomodoro_orig_tar_gz) \
	$(gnome_pomodoro_debian_tar_gz) \
	$(gnome_pomodoro_debian) \
	$(gnome_pomodoro_dsc)

.PHONY: all deb-src

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
