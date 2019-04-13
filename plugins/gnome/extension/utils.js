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

const Signals = imports.signals;

const Shell = imports.gi.Shell;

const Main = imports.ui.main;
const ExtensionSystem = imports.ui.extensionSystem;

const Extension = imports.misc.extensionUtils.getCurrentExtension();


const VIDEO_PLAYER_CATEGORIES = [
    ['Player', 'Video'],
    ['Player', 'AudioVideo'],
    ['Game']
];


var Patch = class {
    constructor(object, overrides) {
        this.object = object;
        this.overrides = overrides;
        this.initial = {};
        this.applied = false;

        for (let name in this.overrides) {
            this.initial[name] = this.object[name];

            if (typeof(this.initial[name]) == 'undefined') {
                logWarning('Property "%s" for %s is not defined'.format(name, this.object));
            }
        }
    }

    apply() {
        if (!this.applied) {
            for (let name in this.overrides) {
                this.object[name] = this.overrides[name];
            }

            this.applied = true;

            this.emit('applied');
        }
    }

    revert() {
        if (this.applied) {
            for (let name in this.overrides) {
                this.object[name] = this.initial[name];
            }

            this.applied = false;

            this.emit('reverted');
        }
    }

    destroy() {
        this.revert();
        this.disconnectAll();
    }
};
Signals.addSignalMethods(Patch.prototype);


function arrayContains(array1, array2) {
    for (let i = 0; i < array2.length; i++) {
        if (array1.indexOf(array2[i]) < 0) {
            return false;
        }
    }

    return true;
}


function getFocusedWindowInfo() {
    let app = Shell.WindowTracker.get_default().focus_app;
    let appInfo = app ? app.get_app_info() : null;
    let window = global.display.focus_window;

    let result = {
        app: app,
        window: window,
        isPlayer: false,
        isFullscreen: false
    };

    if (appInfo) {
        let categoriesStr = appInfo.get_categories();
        let categories    = categoriesStr ? categoriesStr.split(';') : [];

        for (let i = 0; i < VIDEO_PLAYER_CATEGORIES.length; i++) {
            if (arrayContains(categories, VIDEO_PLAYER_CATEGORIES[i])) {
                result.isPlayer = true;
                break;
            }
        }
    }

    if (window) {
        let monitor = Main.layoutManager.monitors[window.get_monitor()];

        result.isFullscreen = monitor.inFullscreen;
    }

    return result;
}


function logError(message) {
    ExtensionSystem.logExtensionError(Extension.metadata.uuid, message);
}


function logWarning(message) {
    log(message);
}


function versionCheck(required) {
    let current = imports.misc.config.PACKAGE_VERSION;
    let currentArray = current.split('.');
    let requiredArray = required.split('.');

    if (requiredArray[0] <= currentArray[0] &&
        requiredArray[1] <= currentArray[1] &&
        (requiredArray[2] <= currentArray[2] ||
         requiredArray[2] == undefined)) {
        return true;
    }

    return false;
}


function disableExtension(uuid) {
    let enabledExtensions = global.settings.get_strv(ExtensionSystem.ENABLED_EXTENSIONS_KEY);
    let extensionIndex = enabledExtensions.indexOf(uuid);

    if (extensionIndex != -1) {
        enabledExtensions.splice(extensionIndex, 1);
        global.settings.set_strv(ExtensionSystem.ENABLED_EXTENSIONS_KEY, enabledExtensions);
    }
}
