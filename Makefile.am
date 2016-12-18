SUBDIRS = \
	lib \
	src \
	plugins \
	data \
	po \
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

MAINTAINERCLEANFILES = \
	$(GITIGNORE_MAINTAINERCLEANFILES_TOPLEVEL) \
	$(GITIGNORE_MAINTAINERCLEANFILES_MAKEFILE_IN) \
	$(GITIGNORE_MAINTAINERCLEANFILES_M4_LIBTOOL)

# We currently have no custom macros
GITIGNOREFILES = m4

.PHONY: test packages rpm rpm-src deb-src

clean-local:
	rm -rf $(builddir)/rpms

uninstall-hook:
	-rm -rf $(pkgdatadir)

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
