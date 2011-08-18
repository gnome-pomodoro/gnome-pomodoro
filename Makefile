NAME = gnome-shell-pomodoro
SRC = pomodoro@arun.codito.in
OUT = ${XDG_DATA_HOME}/gnome-shell/extensions/${SRC}
FILES = ${OUT}/extension.js ${OUT}/metadata.json ${OUT}/stylesheet.css
CONFIG_DIR = ${XDG_CONFIG_HOME}/${NAME}
CONFIG_FILE = ${CONFIG_DIR}/gnome_shell_pomodoro.json
MSG_INSTALL = " ${NAME} was successfully $@ed\n Press Alt+F2 and type 'r' to refresh"
MSG_SKIP_CONFIG = " ${CONFIG_FILE} is already present. Skipped installing it."

help:
	@echo "Usage:"
	@echo "   make install         Install ${NAME} extension"
	@echo "   make uninstall       Uninstall ${NAME} extension"

install: ${CONFIG_DIR} ${CONFIG_FILE} ${OUT} ${FILES}
	@echo -e ${MSG_INSTALL}

uninstall:
	@rm -rf ${OUT}
	@rm -rf ${CONFIG_DIR}
	@echo -e ${MSG_INSTALL}

$(OUT) $(CONFIG_DIR):
	@mkdir -p $@

$(OUT)/%: $(SRC)/%
	@cp $< $@

$(CONFIG_DIR)/%: %
    ifeq ($(wildcard ${CONFIG_FILE}),)
	@cp $< $@
    else
	@echo -e ${MSG_SKIP_CONFIG}
    endif

.PHONY: help install uninstall

