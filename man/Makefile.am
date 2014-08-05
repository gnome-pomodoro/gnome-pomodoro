EXTRA_DIST = \
	gnome-pomodoro.sgml

if HAVE_DOCBOOK2MAN
man_MANS = \
	gnome-pomodoro.1
endif

if HAVE_DOCBOOK2MAN
gnome-pomodoro.1: gnome-pomodoro.sgml
	docbook2man $? > /dev/null
endif

clean-local :
	rm -f *~
	rm -f *.1
	rm -f manpage.*

CLEANFILES = \
	manpage.links \
	manpage.log \
	manpage.refs \
	$(man_MANS)

-include $(top_srcdir)/git.mk
