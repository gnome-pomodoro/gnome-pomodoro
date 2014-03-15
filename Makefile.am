ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}

SUBDIRS = \
    vapi \
    lib \
    src \
    extension \
    data \
    po \
    packages

EXTRA_DIST = \
    autogen.sh \
    config.vapi \
    COPYING \
    README.md

distdir = $(PACKAGE_TARNAME)-$(VERSION)

uninstall-hook:
	rm -Rf $(pkgdatadir)

rpmdefines = \
	--define "_sourcedir $(abs_builddir)" \
	--define "_specdir $(abs_srcdir)"

rpm: dist $(top_srcdir)/packages/rpm/gnome-pomodoro.spec
	env -i PATH=/usr/bin/:/bin SHELL=$(SHELL) HOSTNAME=$${HOSTNAME} HOME=$${HOME} \
	rpmbuild $(rpmdefines) -ba $(top_srcdir)/packages/rpm/gnome-pomodoro.spec

clean-local:
	rm -Rf $(builddir)/rpms

-include $(top_srcdir)/git.mk
