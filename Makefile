NAME = gnome-shell-pomodoro
SRC = pomodoro@arun.codito.in
OUT = ${HOME}/.local/share/gnome-shell/extensions/${SRC}

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
	@$(CONFIRM)

uninstall:
	@rm -rf ${OUT}
	@$(CONFIRM)

.PHONY: help install uninstall

