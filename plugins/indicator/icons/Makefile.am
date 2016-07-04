SUBDIRS = \
	ambiance \
	radiance

generate-icons:
	for theme in $(SUBDIRS); do \
		generate-icons $$theme/theme.json \
	done

.PHONY: generate-icons

-include $(top_srcdir)/git.mk

# vi:ts=4:noet
