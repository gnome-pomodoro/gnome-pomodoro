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

import {EventEmitter} from 'resource:///org/gnome/shell/misc/signals.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import * as Config from './config.js';
import {extension} from './extension.js';


const ENABLED_EXTENSIONS_KEY = 'enabled-extensions';

const icons = {};


export const Patch = class extends EventEmitter {
    constructor(object, overrides) {
        super();

        this.object = object;
        this.overrides = overrides;
        this.initial = {};
        this.applied = false;

        for (let name in this.overrides) {
            this.initial[name] = this.object[name];

            if (typeof this.initial[name] == 'undefined')
                logWarning(`Property "${name}" for ${this.object} is not defined`);
        }
    }

    apply() {
        if (!this.applied) {
            for (let name in this.overrides)
                this.object[name] = this.overrides[name];

            this.applied = true;

            this.emit('applied');
        }
    }

    revert() {
        if (this.applied) {
            for (let name in this.overrides)
                this.object[name] = this.initial[name];

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
            if (this._actors[index].actor === actor)
                return index;
        }

        return -1;
    }

    addActor(actor) {
        let index = this._findActor(actor);

        if (!actor || index >= 0)
            return;

        const meta = {
            actor,
            destroyId: actor.connect('destroy', () => {
                this.removeActor(actor);
                meta.destroyId = 0;
            }),
        };
        this._actors.push(meta);

        if (!this._referenceActor)
            this._setReferenceActor(actor);
    }

    removeActor(actor) {
        let index = this._findActor(actor);
        if (index >= 0) {
            const meta = this._actors.splice(index, 1);
            if (meta.destroyId)
                actor.disconnect(meta.destroyId);
        }

        if (this._referenceActor === actor)
            this._setReferenceActor(this._actors.length > 0 ? this._actors[0].actor : null);
    }

    easeProperty(name, target, params) {
        let onStopped = params.onStopped;
        let onComplete = params.onComplete;

        this._actors.forEach(meta => {
            let localParams = Object.assign({
                onStopped: isFinished => {
                    if (onStopped && meta.actor === this._referenceActor)
                        onStopped(isFinished);
                },
                onComplete: () => {
                    if (onComplete && meta.actor === this._referenceActor)
                        onComplete();
                },
            }, params);

            meta.actor.ease_property(name, target, localParams);
        });
    }

    setProperty(name, target) {
        let properties = {};
        properties[name] = target;

        this._actors.forEach(meta => {
            meta.actor.set(properties);
        });
    }

    removeAllTransitions() {
        this._actors.forEach(meta => {
            meta.actor.remove_all_transitions();
        });
    }

    destroy() {
        this._actors.slice().forEach(meta => {
            this.removeActor(meta.actor);
        });
    }
};


/**
 *
 * @param {Error} error - error
 */
export function logError(error) {
    Main.extensionManager.logExtensionError(Config.EXTENSION_UUID, error);
}


/**
 *
 * @param {string} message - error
 */
export function logWarning(message) {
    console.warn(`Pomodoro: ${message}`);
}


/**
 *
 * @param {string} required - version required
 */
export function isVersionAtLeast(required) {
    const current = Config.PACKAGE_VERSION;
    const currentArray = current.split('.');
    const requiredArray = required.split('.');

    if (requiredArray[0] <= currentArray[0] &&
        requiredArray[1] <= currentArray[1] &&
        (requiredArray[2] <= currentArray[2] || requiredArray[2] === undefined))
        return true;

    return false;
}


/**
 *
 * @param {string} uuid - extension uuid
 */
export function disableExtension(uuid) {
    const enabledExtensions = global.settings.get_strv(ENABLED_EXTENSIONS_KEY);
    const extensionIndex = enabledExtensions.indexOf(uuid);

    if (extensionIndex >= 0) {
        enabledExtensions.splice(extensionIndex, 1);
        global.settings.set_strv(ENABLED_EXTENSIONS_KEY, enabledExtensions);
    }
}


/**
 *
 */
export function wakeUpScreen() {
    if (Main.screenShield._dialog) {
        Main.screenShield._dialog.emit('wake-up-screen');
    } else {
        try {
            Main.screenShield._wakeUpScreen();
        } catch (error) {
            logWarning(`Error while waking up the screen: ${error}`);
        }
    }
}


/**
 * @param {string} iconName - icon name
 */
export function loadIcon(iconName) {
    let icon = icons[iconName];

    if (!icon) {
        const iconUri = '%s/icons/hicolor/scalable/actions/%s.svg'.format(extension.dir.get_uri(), iconName);
        icon = new Gio.FileIcon({
            file: Gio.File.new_for_uri(iconUri),
        });

        icons[iconName] = icon;
    }

    return icon;
}
