NAME = gnome-shell-pomodoro
SRC = pomodoro@arun.codito.in
OUT = ${HOME}/.local/share/gnome-shell/extensions/${SRC}
FILES = ${OUT}/extension.js ${OUT}/metadata.json ${OUT}/stylesheet.css
MSG = " ${NAME} was successfully $@ed\n Press Alt+F2 and type 'r' to refresh"
CONFIG_DIR = ${HOME}/.config/${NAME}
CONFIG_FILE = ${CONFIG_DIR}/gnome_shell_pomodoro.json

help:
	@echo "Usage:"
	@echo "   make install         Install ${NAME} extension"
	@echo "   make uninstall       Uninstall ${NAME} extension"

install: ${CONFIG_DIR} ${CONFIG_FILE} ${OUT} ${FILES}
	@echo -e ${MSG}

uninstall:
	@rm -rf ${OUT}
	@rm -rf ${CONFIG_DIR}
	@echo -e ${MSG}

$(OUT) $(CONFIG_DIR):
	@mkdir -p $@

$(OUT)/%: $(SRC)/%
	@cp $< $@

$(CONFIG_DIR)/%: %
	@cp $< $@

.PHONY: help install uninstall

