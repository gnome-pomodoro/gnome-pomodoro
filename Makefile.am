ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}

SUBDIRS = \
    vapi \
    lib \
    src \
    extension \
    data \
    po \
    packages

distdir = $(PACKAGE_TARNAME)-$(VERSION)

uninstall-hook:
	rm -Rf $(pkgdatadir)

rpmdefines = \
	--define "_sourcedir $(abs_builddir)" \
	--define "_specdir $(abs_srcdir)"

rpm: dist $(top_srcdir)/packages/rpm/gnome-pomodoro.spec
	env -i PATH=/usr/bin/:/bin SHELL=$(SHELL) HOSTNAME=$${HOSTNAME} HOME=$${HOME} \
	rpmbuild $(rpmdefines) -ba $(top_srcdir)/packages/rpm/gnome-pomodoro.spec

EXTRA_DIST = \
    autogen.sh \
    config.vapi \
    COPYING \
    README.md

DISTCLEANFILES = \
	intltool-extract \
	intltool-merge \
	intltool-update \
	po/.intltool-merge-cache

clean-local:
	rm -Rf $(builddir)/rpms

-include $(top_srcdir)/git.mk
