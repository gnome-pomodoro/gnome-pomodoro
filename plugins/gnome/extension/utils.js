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

const Shell = imports.gi.Shell;

const Main = imports.ui.main;
const ExtensionSystem = imports.ui.extensionSystem;

const Extension = imports.misc.extensionUtils.getCurrentExtension();


const VIDEO_PLAYER_CATEGORIES = [
    ['Player', 'Video'],
    ['Player', 'AudioVideo'],
    ['Game'],
];


const Hook = new Lang.Class({
    Name: 'PomodoroHook',

    _init: function(object, property, func) {
        this.object = object;
        this.property = property;
        this.func = func;

        this.initial = object[property];

        this.check();
    },

    check: function() {
        if (this.initial === undefined) {
            logWarning('Hook "%s" for %s is not defined'.format(this.property, this.object));
            return;
        }
        if (!(this.initial instanceof Function)) {
            logWarning('Hook "%s" for %s is not callable'.format(this.property, this.object));
            return;
        }
    },

    override: function(func) {
        this.object[this.property] = func ? func : this.func;
    },

    restore: function() {
        this.object[this.property] = this.initial;
    }
});


const Patch = new Lang.Class({
    Name: 'PomodoroPatch',

    _init: function() {
        this._hooks = [];
    },

    addHooks: function(object, hooks) {
        for (let name in hooks) {
            this._hooks.push(new Hook(object, name, hooks[name]));
        };
    },

    apply: function() {
        this._hooks.forEach(Lang.bind(this,
            function(hook) {
                hook.override();
            }));
    },

    revert: function() {
        this._hooks.forEach(Lang.bind(this,
            function(hook) {
                hook.restore();
            }));
    }
});


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
