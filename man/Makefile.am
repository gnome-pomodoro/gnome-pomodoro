if HAVE_DOCBOOK2MAN

man_MANS = \
	gnome-pomodoro.1

gnome-pomodoro.1: gnome-pomodoro.sgml
	docbook2man $? > /dev/null

clean-local:
	rm -f *~
	rm -f *.1
	rm -f manpage.*

CLEANFILES = \
	manpage.links \
	manpage.log \
	manpage.refs \
	$(man_MANS)

endif

EXTRA_DIST = \
	gnome-pomodoro.sgml

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
