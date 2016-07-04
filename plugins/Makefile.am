SUBDIRS = \
	dark-theme \
	sounds

DIST_SUBDIRS = \
	dark-theme \
	gnome \
	sounds

if WITH_GNOME_PLUGIN
SUBDIRS += gnome
endif

if WITH_INDICATOR_PLUGIN
SUBDIRS += indicator
endif

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
