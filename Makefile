NAME = gnome-shell-pomodoro
SRC = pomodoro@arun.codito.in

ifneq (${XDG_DATA_HOME},)
    OUT = ${XDG_DATA_HOME}/gnome-shell/extensions/${SRC}
else
    OUT = ${HOME}/.local/share/gnome-shell/extensions/${SRC}
endif
FILES = ${OUT}/extension.js ${OUT}/metadata.json ${OUT}/stylesheet.css ${OUT}/bell.wav ${OUT}/timer-symbolic.svg

ifneq (${XDG_CONFIG_HOME},)
    CONFIG_DIR = ${XDG_CONFIG_HOME}/${NAME}
else
    CONFIG_DIR = ${HOME}/.config/${NAME}
endif
CONFIG_FILE = ${CONFIG_DIR}/gnome_shell_pomodoro.json
CONFIG_OVERWRITE = 

ifeq ($(wildcard ${CONFIG_FILE}),)
    CONFIG_OVERWRITE = YES
endif
MSG_INSTALL = " ${NAME} was successfully $@ed\n Press Alt+F2 and type 'r' to refresh"
MSG_SKIP_CONFIG = " Config file '${CONFIG_FILE}' is already present. Skipped installing it."

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
    ifneq (${CONFIG_OVERWRITE},)
	@cp $< $@
    else
	@echo -e ${MSG_SKIP_CONFIG}
    endif

.PHONY: help install uninstall

