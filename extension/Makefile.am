include ../Makefile.include

dist_extension_DATA = \
    dbus.js \
    extension.js \
    indicator.js \
    metadata.json \
    notifications.js \
    stylesheet.css \
    utils.js \
    $(NULL)

nodist_extension_DATA = \
    metadata.json \
    $(NULL)

EXTRA_DIST = \
    metadata.json.in \
    $(NULL)

CLEANFILES = \
    metadata.json \
    $(NULL)

metadata.json: metadata.json.in $(top_builddir)/config.status
	$(AM_V_GEN) $(do_subst) $(srcdir)/metadata.json.in > $@

uninstall-hook:
	rmdir --ignore-fail-on-non-empty $(extensiondir)
