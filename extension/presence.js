/*
 * Copyright (c) 2014 gnome-pomodoro contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */

const Lang = imports.lang;

const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const PopupMenu = imports.ui.popupMenu;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Config = Extension.imports.config;
const Timer = Extension.imports.timer;
const Utils = Extension.imports.utils;


const NOTIFICATIONS_DURING_BREAK = true;


const Presence = new Lang.Class({
    Name: 'PomodoroPresence',

    _init: function() {
        this._settingsChangedId = 0;
        this._menuItemToggledId = 0;
        this._timerStateChangedId = 0;
        this._timerState;
        this._menuItemText;

        // Setup a patch for suppressing presence handlers.
        // When applied the main presence controller becomes gnome-pomodoro.
        let self = this;

        this._patch = new Utils.Patch();
        this._patch.addHooks(MessageTray.MessageTray.prototype, {
            _onStatusChanged:
                function(status) {
                    this._updateState();
                }
        });

        if (!Utils.versionCheck('3.16')) {
            this._patch.addHooks(MessageTray.MessageTrayMenu.prototype, {
                _onStatusChanged:
                    function(status) {
                        this._sessionStatus = status;
                    },
                _onIMPresenceChanged:
                    function(accountManager, type) {
                    },
                _updatePresence:
                    Lang.bind(this, this._onNotificationsMenuItemToggled),
            });

            // We need to reconnect the 'toggled' signal to use method from
            // the prototype.
            try {
                let menu = this._getMessageTrayMenu();
                let menuItem = this._getNotificationsMenuItem();

                if (menuItem && menu) {
                    menuItem.disconnectAll();
                    menuItem.connect('toggled', Lang.bind(menu,
                        function(item, state) {
                            this._updatePresence(item, state);
                        }));
                }
            }
            catch (error) {
                Extension.extension.logError(error.message);
            }
        }

        try {
            this._settingsChangedId = Extension.extension.settings.connect(
                                       'changed::hide-notifications-during-pomodoro',
                                       Lang.bind(this, this._onSettingsChanged));
        }
        catch (error) {
            Extension.extension.logError(error.message);
        }

        this._timerStateChangedId = Extension.extension.timer.connect('state-changed',
                                                                      Lang.bind(this, this._onTimerStateChanged));

        this._setNotificationDefaults();
        this._onTimerStateChanged();
    },

    _onSettingsChanged: function(settings, key) {
        switch (key) {
            case 'hide-notifications-during-pomodoro':
                this.setNotificationsDuringPomodoro(!settings.get_boolean(key));
                break;
        }
    },

    _onTimerStateChanged: function() {
        let timerState = Extension.extension.timer.getState();
        let isRunning = timerState != Timer.State.NULL;

        if (timerState !== this._timerState) {
            this._timerState = timerState;

            if (isRunning) {
                this._patch.apply();

                this.update();
            }
            else {
                this.update();

                this._patch.revert();
                this._setNotificationDefaults();
            }
        }
    },

    _onNotificationsMenuItemToggled: function(item, state) {
        if (!this._notificationsMenuItemLock) {
            let isRunning = (this._timerState != Timer.State.NULL);

            if (isRunning && this._timerState == Timer.State.POMODORO) {
                this.setNotificationsDuringPomodoro(state);
            }

            if (isRunning && this._timerState != Timer.State.POMODORO) {
                this.setNotificationsDuringBreak(state);
            }
        }
    },

    _updateNotificationsMenuItem: function() {
        let timerState = this._timerState;
        let isRunning = timerState != Timer.State.NULL;

        try {
            let menuItem = this._getNotificationsMenuItem();
            let menuItemMarkup;
            let menuItemHint;

            if (menuItem) {
                if (!this._menuItemText) {
                    this._menuItemText = menuItem.label.get_text();
                }

                if (isRunning) {
                    // translators: Full text is actually "Notifications during...",
                    //              the "Notifications" label is taken from gnome-shell
                    menuItemHint = timerState == Timer.State.POMODORO
                                       ? _("during pomodoro")
                                       : _("during break");

                    menuItemMarkup = '%s\n<small><i>%s</i></small>'.format(this._menuItemText,
                                                                           menuItemHint);

                    menuItem.label.clutter_text.set_markup(menuItemMarkup);
                }
                else {
                    menuItem.label.clutter_text.set_markup(this._menuItemText);
                }
            }
        }
        catch (error) {
            Extension.extension.logError(error.message);
        }
    },

    _getMessageTray: function() {
        return Main.messageTray;
    },

    _getMessageTrayMenu: function() {
        if (Utils.versionCheck('3.16'))
            return undefined;

        return Main.messageTray._messageTrayMenuButton
            ? Main.messageTray._messageTrayMenuButton._menu : undefined;
    },

    _getNotificationsMenuItem: function() {
        if (Utils.versionCheck('3.16'))
            return undefined;

        let menu = this._getMessageTrayMenu();

        return menu && menu._busyItem
            ? Main.messageTray._messageTrayMenuButton._menu._busyItem : undefined;
    },

    _setNotificationDefaults: function() {
        this._notificationsDuringPomodoro =
                !Extension.extension.settings.get_boolean('hide-notifications-during-pomodoro');
    },

    update: function() {
        try {
            let messageTray = this._getMessageTray();
            let menuItem = this._getNotificationsMenuItem();

            let busy = this._timerState == Timer.State.POMODORO
                                 ? !this._notificationsDuringPomodoro
                                 : !this._notificationsDuringBreak;

            let isDialogOpened = Extension.extension.dialog && Extension.extension.dialog.isOpened;

            messageTray._busy = busy || isDialogOpened;
            messageTray._updateState();

            if (menuItem && menuItem.state != !messageTray._busy) {
                this._notificationsMenuItemLock = true;
                menuItem.toggle();
                this._notificationsMenuItemLock = false;
            }
        }
        catch (error) {
            Extension.extension.logError(error.message);
        }

        this._updateNotificationsMenuItem();
    },

    setNotificationsDuringPomodoro: function(enabled) {
        if (this._notificationsDuringPomodoro != enabled) {
            this._notificationsDuringPomodoro = enabled;

            this.update();
        }
    },

    setNotificationsDuringBreak: function(enabled) {
        if (this._notificationsDuringBreak != enabled) {
            this._notificationsDuringBreak = enabled;

            this.update();
        }
    },

    destroy: function() {
        let menuItem = this._getNotificationsMenuItem();

        if (this._settingsChangedId) {
            Extension.extension.settings.disconnect(this._settingsChangedId);
            this._settingsChangedId = 0;
        }

        if (this._timerStateChangedId) {
            Extension.extension.timer.disconnect(this._timerStateChangedId);
            this._timerStateChangedId = 0;
        }

        if (menuItem && this._menuItemText) {
            menuItem.label.clutter_text.set_markup(this._menuItemText);
        }

        if (this._patch) {
            this._patch.revert();
            this._patch = null;
        }
    }
});
