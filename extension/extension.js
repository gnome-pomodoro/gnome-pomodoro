/*
 * A simple pomodoro timer for GNOME Shell
 *
 * Copyright (c) 2011-2013 gnome-pomodoro contributors
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
 * Authors: Arun Mahapatra <pratikarun@gmail.com>
 *          Kamil Prusko <kamilprusko@gmail.com>
 */

const Gettext = imports.gettext;

const Main = imports.ui.main;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Indicator = Extension.imports.indicator;
const Config = Extension.imports.config;


let indicator = null;


function init(metadata) {
    Gettext.bindtextdomain(Config.GETTEXT_PACKAGE,
                           Config.LOCALE_DIR);
}


function enable() {
    if (!indicator) {
        indicator = new Indicator.Indicator();
        Main.panel.addToStatusArea(Config.PACKAGE_NAME, indicator);
    }
}


function disable() {
    if (indicator) {
        indicator.destroy();
        indicator = null;
    }
}
