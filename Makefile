NAME = gnome-shell-pomodoro
SRC = pomodoro@arun.codito.in
OUT = ${HOME}/.local/share/gnome-shell/extensions/${SRC}
FILES = ${OUT}/extension.js ${OUT}/metadata.json ${OUT}/stylesheet.css
MSG = " ${NAME} was successfully $@ed\n Press Alt+F2 and type 'r' to refresh"

help:
	@echo "Usage:"
	@echo "   make install         Install ${NAME} extension"
	@echo "   make uninstall       Uninstall ${NAME} extension"

install: ${OUT} ${FILES}
	@echo -e ${MSG}

uninstall:
	@rm -rf ${OUT}
	@echo -e ${MSG}

$(OUT):
	@mkdir -p $@

$(OUT)/%: $(SRC)/%
	@cp $< $@

.PHONY: help install uninstall

