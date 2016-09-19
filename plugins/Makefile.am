SUBDIRS = \
	actions \
	dark-theme \
	sounds

DIST_SUBDIRS = \
	actions \
	dark-theme \
	gnome \
	indicator \
	sounds

if WITH_GNOME_PLUGIN
SUBDIRS += gnome
endif

if WITH_INDICATOR_PLUGIN
SUBDIRS += indicator
endif

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
