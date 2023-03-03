/*
 * Copyright (c) 2014,2017 gnome-pomodoro contributors
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

const Gio = imports.gi.Gio;

const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Utils = Extension.imports.utils;


/**
 * Helps in managing presence for GNOME Shell according to the Pomodoro state.
 */
var Presence = class {
    constructor() {
        this._busy = false;

        // Setup a patch for suppressing presence handlers.
        // When applied the main presence controller becomes gnome-pomodoro.
        this._patch = new Utils.Patch(MessageTray.MessageTray.prototype, {
            _onStatusChanged(status) {
                this._updateState();
            }
        });
        this._patch.connect('applied', this._onPatchApplied.bind(this));
        this._patch.connect('reverted', this._onPatchReverted.bind(this));

        this._settings = new Gio.Settings({
            schema_id: 'org.gnome.desktop.notifications',
        });
    }

    setBusy(value) {
        this._busy = value;

        if (!this._patch.applied) {
            this._patch.apply();
        }
        else {
            this._onPatchApplied();
        }

        this._settings.set_boolean('show-banners', !value);
    }

    setDefault() {
        this._settings.set_boolean('show-banners', true);

        if (this._patch.applied) {
            this._patch.revert();
        }
    }

    _onPatchApplied() {
        try {
            Main.messageTray._busy = this._busy;
            Main.messageTray._onStatusChanged();
        }
        catch (error) {
            Utils.logWarning(error.message);
        }
    }

    _onPatchReverted() {
        try {
            const status = Main.messageTray._presence.status;

            Main.messageTray._onStatusChanged(status);
        }
        catch (error) {
            Utils.logWarning(error.message);
        }
    }

    destroy() {
        if (this._patch) {
            this._patch.destroy();
            this._patch = null;
        }

        if (this._settings) {
            this._settings.run_dispose();
            this._settings = null;
        }
    }
};
