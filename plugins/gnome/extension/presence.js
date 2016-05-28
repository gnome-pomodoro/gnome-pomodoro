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
        this._timerStateChangedId = 0;
        this._timerState;

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

        try {
            this._settingsChangedId = Extension.extension.settings.connect(
                                       'changed::hide-notifications-during-pomodoro',
                                       Lang.bind(this, this._onSettingsChanged));
        }
        catch (error) {
            Utils.logWarning(error.message);
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

    _setNotificationDefaults: function() {
        this._notificationsDuringPomodoro =
                !Extension.extension.settings.get_boolean('hide-notifications-during-pomodoro');
        this._notificationsDuringBreak = NOTIFICATIONS_DURING_BREAK;
    },

    update: function() {
        try {
            let messageTray = Main.messageTray;
            let busy = this._timerState == Timer.State.POMODORO
                                 ? !this._notificationsDuringPomodoro
                                 : !this._notificationsDuringBreak;

            let isDialogOpened = Extension.extension.dialog && Extension.extension.dialog.isOpened;

            messageTray._busy = busy || isDialogOpened;
            messageTray._updateState();
        }
        catch (error) {
            Utils.logWarning(error.message);
        }
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
        if (this._settingsChangedId) {
            Extension.extension.settings.disconnect(this._settingsChangedId);
            this._settingsChangedId = 0;
        }

        if (this._timerStateChangedId) {
            Extension.extension.timer.disconnect(this._timerStateChangedId);
            this._timerStateChangedId = 0;
        }

        if (this._patch) {
            this._patch.revert();
            this._patch = null;
        }
    }
});
