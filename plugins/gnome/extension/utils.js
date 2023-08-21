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

import Gio from 'gi://Gio';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import {EventEmitter} from 'resource:///org/gnome/shell/misc/signals.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import * as Config from './config.js';

const ENABLED_EXTENSIONS_KEY = 'enabled-extensions';

const VIDEO_PLAYER_CATEGORIES = [
    ['Player', 'Video'],
    ['Player', 'AudioVideo'],
    ['VideoConference'],
    ['Telephony'],
    ['Game'],
];


export const Patch = class extends EventEmitter {
    constructor(object, overrides) {
        super();

        this.object = object;
        this.overrides = overrides;
        this.initial = {};
        this.applied = false;

        for (let name in this.overrides) {
            this.initial[name] = this.object[name];

            if (typeof(this.initial[name]) == 'undefined') {
                logWarning(`Property "${name}" for ${this.object} is not defined`);
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


export const TransitionGroup = class {

    /* Helper class to share property transition between multiple actors */

    constructor() {
        this._actors = [];
        this._referenceActor = null;
    }

    _setReferenceActor(actor) {
        this._referenceActor = actor;
    }

    _findActor(actor) {
        for (var index = 0; index < this._actors.length; index++) {
            if (this._actors[index].actor === actor) {
                return index;
            }
        }

        return -1;
    }

    addActor(actor) {
        let index = this._findActor(actor);

        if (!actor || index >= 0) {
            return;
        }

        const meta = {
            actor: actor,
            destroyId: actor.connect('destroy', () => {
                this.removeActor(actor);
                meta.destroyId = 0;
            }),
        };
        this._actors.push(meta);

        if (!this._referenceActor) {
            this._setReferenceActor(actor);
        }
    }

    removeActor(actor) {
        let index = this._findActor(actor);
        if (index >= 0) {
            const meta = this._actors.splice(index, 1);
            if (meta.destroyId) {
                actor.disconnect(meta.destroyId);
            }
        }

        if (this._referenceActor === actor) {
            this._setReferenceActor(this._actors.length > 0 ? this._actors[0].actor : null);
        }
    }

    easeProperty(name, target, params) {
        let onStopped = params.onStopped;
        let onComplete = params.onComplete;

        this._actors.forEach((meta) => {
            let localParams = Object.assign({
                onStopped: (isFinished) => {
                    if (onStopped && meta.actor === this._referenceActor)
                        onStopped(isFinished);
                },
                onComplete: () => {
                     if (onComplete && meta.actor === this._referenceActor)
                         onComplete();
                }
            }, params);

            meta.actor.ease_property(name, target, localParams);
        });
    }

    setProperty(name, target) {
        let properties = {};
        properties[name] = target

        this._actors.forEach((meta) => {
            meta.actor.set(properties);
        });
    }

    removeAllTransitions() {
        this._actors.forEach((meta) => {
            meta.actor.remove_all_transitions();
        });
    }

    destroy() {
        this._actors.slice().forEach((meta) => {
            this.removeActor(meta.actor);
        });
    }
}


function isSubset(subset, set) {
    for (let value of subset) {
        if (set.indexOf(value) < 0) {
            return false;
        }
    }

    return true;
}


function _isVideoPlayer(app) {
    const appInfo = app.get_app_info();
    if (!appInfo) {
        return false;
    }

    const categoriesStr = appInfo.get_categories();
    const categories    = categoriesStr ? categoriesStr.split(';') : [];

    if (!categories.length) {
        return false;
    }

    for (let videoPlayerCategories of VIDEO_PLAYER_CATEGORIES) {
        if (isSubset(videoPlayerCategories, categories)) {
            return true;
        }
    }

    return false;
}


export function isVideoPlayerOpen() {
    const apps = Shell.AppSystem.get_default().get_running();

    for (let app of apps) {
        if (!_isVideoPlayer(app)) {
            continue;
        }

        for (let window of app.get_windows()) {
            if (window.window_type !== Meta.WindowType.NORMAL || window.is_hidden()) {
                continue;
            }

            if (window.fullscreen) {
                return true;
            }
        }
    }

    return false;
}


export function logError(error) {
    Main.extensionManager.logExtensionError(Config.EXTENSION_UUID, error);
}


export function logWarning(message) {
    console.warn(`Pomodoro: ${message}`);
}


export function versionCheck(required) {
    let current = Config.PACKAGE_VERSION;
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


export function disableExtension(uuid) {
    let enabledExtensions = global.settings.get_strv(ENABLED_EXTENSIONS_KEY);
    let extensionIndex = enabledExtensions.indexOf(uuid);

    if (extensionIndex != -1) {
        enabledExtensions.splice(extensionIndex, 1);
        global.settings.set_strv(ENABLED_EXTENSIONS_KEY, enabledExtensions);
    }
}


export function wakeUpScreen() {
    if (Main.screenShield._dialog) {
        Main.screenShield._dialog.emit('wake-up-screen');
    }
    else {
        try {
            Main.screenShield._wakeUpScreen();
        }
        catch (error) {
            logWarning(`Error while waking up the screen: ${error}`);
        }
    }
}
