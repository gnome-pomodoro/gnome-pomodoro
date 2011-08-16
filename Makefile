NAME = gnome-shell-pomodoro
SRC = pomodoro@arun.codito.in
OUT = ${HOME}/.local/share/gnome-shell/extensions/${SRC}
CONFIG_DIR = ${HOME}/.config/${NAME}
CONFIG_FILE = gnome_shell_pomodoro.json

CONFIRM = echo -e "\n ${NAME} was successfully $@ed\n" \
                  "Press Alt+F2 and type 'r' to restart gnome-shell\n"

FILES = ${SRC}/extension.js \
        ${SRC}/metadata.json \
        ${SRC}/stylesheet.css

help:
	@echo "Usage:"
	@echo
	@echo "   make install         Install ${NAME} extension"
	@echo "   make uninstall       Uninstall ${NAME} extension"
	@echo

install: ${FILES}
	@mkdir -p ${OUT}
	@install --compare --mode=644 ${FILES} ${OUT}
	@mkdir -p ${CONFIG_DIR}
	@cp ${CONFIG_FILE} ${CONFIG_DIR}
	@$(CONFIRM)

uninstall:
	@rm -rf ${OUT}
	@rm -rf ${CONFIG_DIR}
	@$(CONFIRM)

.PHONY: help install uninstall

