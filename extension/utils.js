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

const Shell = imports.gi.Shell;

const Main = imports.ui.main;


const VIDEO_PLAYER_CATEGORIES = [
    ['Player', 'Video'],
    ['Player', 'AudioVideo'],
    ['Game'],
];


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
    let window = global.display.focus_window;

    let result = {
        app: app,
        window: window,
        isPlayer: false,
        isFullscreen: false
    };

    if (app) {
        let categoriesStr = app.get_app_info().get_categories();
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
