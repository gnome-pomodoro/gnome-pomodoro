ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}

SUBDIRS = \
    vapi \
    lib \
    src \
    extension \
    data \
    po \
    packages \
    tests

distdir = $(PACKAGE_TARNAME)-$(VERSION)

rpmdefines = \
	--define "_sourcedir $(abs_builddir)" \
	--define "_specdir $(abs_srcdir)"

rpm: packages/rpm/gnome-pomodoro.spec dist
	env -i PATH=/usr/bin/:/bin SHELL=$(SHELL) HOSTNAME=$${HOSTNAME} HOME=$${HOME} \
	rpmbuild $(rpmdefines) -ba $(abs_top_builddir)/packages/rpm/gnome-pomodoro.spec

test:
	cd tests && $(MAKE) $@

EXTRA_DIST = \
    autogen.sh \
    config.vapi \
    COPYING \
    ChangeLog \
    README.md

DISTCLEANFILES = \
	intltool-extract \
	intltool-merge \
	intltool-update \
	po/.intltool-merge-cache

.PHONY: test rpm

clean-local:
	rm -rf $(builddir)/rpms

uninstall-hook:
	-rm -rf $(pkgdatadir)

-include $(top_srcdir)/git.mk
