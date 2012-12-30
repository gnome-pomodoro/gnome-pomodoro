include Makefile.include

ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}

SUBDIRS = src extension data po

EXTRA_DIST = \
    autogen.sh \
    COPYING \
    Makefile.include \
    README.md \
    $(NULL)

MAINTAINERCLEANFILES = \
    aclocal.m4 \
    config.log \
    config.status \
    configure

zip: local-build
	gsettings_SCHEMA=$(builddir)/usr/share/glib-2.0/schemas/*.xml; \
	$(MKDIR_P) $(builddir)$(extensiondir)/schemas; \
	cp $${gsettings_SCHEMA} $(builddir)$(extensiondir)/schemas; \
	glib-compile-schemas $(builddir)$(extensiondir)/schemas; \
	\
	cp -r $(builddir)$(datadir)/$(PACKAGE_NAME)/* $(builddir)$(extensiondir); \
	cp -r $(builddir)$(datadir)/icons $(builddir)$(extensiondir);
	cp -r $(builddir)$(datadir)/locale $(builddir)$(extensiondir); \
	\
	ziptarget=$(PACKAGE_NAME)-$(PACKAGE_VERSION).zip; \
	(cd $(builddir)$(extensiondir); \
		zip -qr $(abs_builddir)/$${ziptarget} .; \
	);

local-build:
	rm -Rf $(builddir); \
	$(MKDIR_P) $(builddir); \
	$(MAKE) install DESTDIR=$(builddir);

local-uninstall:
	if [ -d $(localdir)/$(uuid) ]; then \
		rm -Rf $(localdir)/$(uuid); \
	fi;

local-install: zip local-uninstall
	zipfile=$(PACKAGE_NAME)-$(PACKAGE_VERSION).zip; \
	$(MKDIR_P) $(localdir)/$(uuid); \
	(cd $(localdir)/$(uuid); \
		unzip -q $(abs_builddir)/$${zipfile}; \
	);

uninstall-hook:
	rm -Rf $(pkgdatadir)
