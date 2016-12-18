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
const Utils = Extension.imports.utils;


const PresenceManager = new Lang.Class({
    Name: 'PomodoroPresenceManager',

    _init: function() {
        this._enabled = false;
        this._busy = false;
        this._setHideSystemNotifications = false;

        // Setup a patch for suppressing presence handlers.
        // When applied the main presence controller becomes gnome-pomodoro.
        this._patch = new Utils.Patch();
        this._patch.addHooks(MessageTray.MessageTray.prototype, {
            _onStatusChanged:
                function(status) {
                    this._updateState();
                }
        });
    },

    enable: function() {
        if (!this._enabled) {
            this._enabled = true;

            this._patch.apply();

            this._onEnabledChanged();
        }
    },

    disable: function() {
        if (this._enabled) {
            this._enabled = false;

            this._onEnabledChanged();

            this._patch.revert();
        }
    },

    setHideSystemNotifications: function(value) {
        this._setHideSystemNotifications = value;
    },

    setBusy: function(value) {
        this._busy = value;
    },

    _onEnabledChanged: function() {
        try {
            Main.messageTray._busy = this._enabled;
            Main.messageTray._updateState();
        }
        catch (error) {
            Utils.logWarning(error.message);
        }
    },

    destroy: function() {
        if (this._patch) {
            this._patch.revert();
            this._patch = null;
        }
    }
});
