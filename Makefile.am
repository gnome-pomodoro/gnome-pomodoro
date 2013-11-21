include $(top_srcdir)/Makefile.include

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
    $(srcdir)/aclocal.m4 \
    $(srcdir)/config.log \
    $(srcdir)/config.status \
    $(srcdir)/configure

stale-files-clean-local:
	-$(RM) $(abs_top_builddir)/*.la $(abs_top_builddir)/*.gir $(abs_top_builddir)/*.typelib

uninstall-hook:
	rm -Rf $(pkgdatadir)

ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}

-include $(top_srcdir)/git.mk
