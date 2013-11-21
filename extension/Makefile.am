include $(top_srcdir)/Makefile.include

dist_extension_DATA = \
    dbus.js \
    extension.js \
    indicator.js \
    metadata.json \
    notifications.js \
    stylesheet.css

nodist_extension_DATA = \
    metadata.json

EXTRA_DIST = \
    metadata.json.in

CLEANFILES = \
    metadata.json

metadata.json: metadata.json.in Makefile
	$(AM_V_GEN) $(do_subst) $(srcdir)/metadata.json.in > $@

uninstall-hook:
	rmdir --ignore-fail-on-non-empty $(extensiondir)

-include $(top_srcdir)/git.mk
