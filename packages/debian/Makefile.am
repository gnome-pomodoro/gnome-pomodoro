
DEB_RELEASE = 1
DEB_BASENAME = $(PACKAGE_NAME)_$(PACKAGE_VERSION)-$(DEB_RELEASE)

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

gnome_pomodoro_orig_tar_gzdir =
gnome_pomodoro_orig_tar_gz_DATA = $(PACKAGE_NAME)_$(PACKAGE_VERSION).orig.tar.gz

gnome_pomodoro_debiandir =
gnome_pomodoro_debian_in_files = \
    debian/changelog.in \
    debian/control.in \
    debian/rules.in
gnome_pomodoro_debian_DATA = $(gnome_pomodoro_debian_in_files:.in=)

gnome_pomodoro_debian_tar_gzdir =
gnome_pomodoro_debian_tar_gz_DATA = $(DEB_BASENAME).debian.tar.gz

gnome_pomodoro_dscdir =
gnome_pomodoro_dsc_in_files = \
    gnome-pomodoro.dsc.in
gnome_pomodoro_dsc_deps = \
    $(gnome_pomodoro_orig_tar_gz_DATA) \
    $(gnome_pomodoro_debian_tar_gz_DATA)
gnome_pomodoro_dsc_DATA = $(DEB_BASENAME).dsc


$(gnome_pomodoro_orig_tar_gz_DATA):
	cd $(top_builddir) && $(MAKE) $(AM_MAKEFLAGS) dist-gzip;
	$(AM_V_GEN) cp $(top_builddir)/$(PACKAGE_TARNAME)-$(PACKAGE_VERSION).tar.gz $@;

$(gnome_pomodoro_debian_DATA): $(gnome_pomodoro_debian_in_files)
	for file in $(gnome_pomodoro_debian_in_files); do \
		$(AM_V_GEN) $(SUBST) $$file > $${file%.*}; \
	done

$(gnome_pomodoro_debian_tar_gz_DATA): $(gnome_pomodoro_debian_DATA)
	$(AM_V_GEN) tar -cvzf $@ $(gnome_pomodoro_debian_DATA);

$(gnome_pomodoro_dsc_DATA): $(gnome_pomodoro_dsc_deps) $(gnome_pomodoro_dsc_in_files)
	$(AM_V_GEN) $(SUBST) $(gnome_pomodoro_dsc_in_files) > $@;
	echo "" >> $@; \
	echo "Files: " >> $@; \
	for file in $(gnome_pomodoro_dsc_deps); do \
		file_md5=`md5sum $$file | cut -d " " -f 1`; \
		file_size=`stat -c%s $$file`; \
		echo " $$file_md5 $$file_size $$file" >> $@; \
	done


deb-src: $(gnome_pomodoro_dsc_DATA)

EXTRA_DIST = \
    $(gnome_pomodoro_debian_in_files) \
    $(gnome_pomodoro_dsc_in_files)

CLEANFILES = \
    $(gnome_pomodoro_orig_tar_gz_DATA) \
    $(gnome_pomodoro_debian_tar_gz_DATA) \
    $(gnome_pomodoro_debian_DATA) \
    $(gnome_pomodoro_dsc_DATA)

-include $(top_srcdir)/git.mk
