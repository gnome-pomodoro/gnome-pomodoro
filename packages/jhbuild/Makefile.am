noinst_SCRIPTS = \
	gnome-pomodoro-jhbuild

SUBST=sed \
	-e "s|[@]abs_srcdir[@]|$(abs_srcdir)|g" \
	-e "s|[@]abs_top_srcdir[@]|$(abs_top_srcdir)|g"

gnome-pomodoro-jhbuild: gnome-pomodoro-jhbuild.in
	$(AM_V_GEN) $(SUBST) < $< > $@
	chmod +x $@

CLEANFILES = \
	gnome-pomodoro-jhbuild

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
