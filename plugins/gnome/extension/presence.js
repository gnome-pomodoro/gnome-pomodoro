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
const Settings = Extension.imports.settings;
const Timer = Extension.imports.timer;
const Utils = Extension.imports.utils;


const NOTIFICATIONS_DURING_BREAK = true;


const Presence = new Lang.Class({
    Name: 'PomodoroPresence',

    _init: function() {
        this._settings = null;
        this._settingsChangedId = 0;
        this._timerStateChangedId = 0;
        this._timerState;

        // Setup a patch for suppressing presence handlers.
        // When applied the main presence controller becomes gnome-pomodoro.
        this._patch = new Utils.Patch();
        this._patch.addHooks(MessageTray.MessageTray.prototype, {
            _onStatusChanged:
                function(status) {
                    this._updateState();
                }
        });

        try {
            this._settings = Settings.getSettings('org.gnome.pomodoro.plugins.gnome');
            this._settingsChangedId = this._settings.connect(
                                       'changed::hide-system-notifications',
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
            case 'hide-system-notifications':
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
                !this._settings.get_boolean('hide-system-notifications');
        this._notificationsDuringBreak = NOTIFICATIONS_DURING_BREAK;
    },

    update: function() {
        try {
            let busy = this._timerState == Timer.State.POMODORO
                                 ? !this._notificationsDuringPomodoro
                                 : !this._notificationsDuringBreak;

            let isDialogOpened = Extension.extension.dialog && Extension.extension.dialog.isOpened;

            Main.messageTray._busy = busy || isDialogOpened;
            Main.messageTray._updateState();
        }
        catch (error) {
            Utils.logWarning(error.message);
        }
    },

    setNotificationsDuringPomodoro: function(value) {
        if (this._notificationsDuringPomodoro != value) {
            this._notificationsDuringPomodoro = value;

            this.update();
        }
    },

    setNotificationsDuringBreak: function(value) {
        if (this._notificationsDuringBreak != value) {
            this._notificationsDuringBreak = value;

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
