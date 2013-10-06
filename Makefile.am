include Makefile.include

ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}

SUBDIRS = \
    egg-list-box \
    vapi \
    src \
    extension \
    data \
    po

EXTRA_DIST = \
    autogen.sh \
    COPYING \
    Makefile.include \
    README.md

MAINTAINERCLEANFILES = \
    aclocal.m4 \
    config.log \
    config.status \
    configure

stale-files-clean-local:
	-$(RM) $(abs_top_builddir)/*.la $(abs_top_builddir)/*.gir $(abs_top_builddir)/*.typelib

uninstall-hook:
	rm -Rf $(pkgdatadir)
