ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}

SUBDIRS = \
	vapi \
	lib \
	src \
	plugins \
	data \
	po \
	man \
	tests \
	packages

distdir = $(PACKAGE_TARNAME)-$(VERSION)

rpm-src:
	cd packages/rpm && $(MAKE) rpm-src

rpm:
	cd packages/rpm && $(MAKE) rpm

deb-src:
	cd packages/debian && $(MAKE) deb-src

packages: rpm-src deb-src

test:
	cd tests && $(MAKE) $@

EXTRA_DIST = \
	autogen.sh \
	config.vapi \
	COPYING \
	NEWS \
	README.md

DISTCLEANFILES = \
	intltool-extract \
	intltool-merge \
	intltool-update \
	po/.intltool-merge-cache

.PHONY: test packages rpm rpm-src deb-src

clean-local:
	rm -rf $(builddir)/rpms

uninstall-hook:
	-rm -rf $(pkgdatadir)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
