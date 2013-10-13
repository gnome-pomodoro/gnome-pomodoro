/*
 * A simple pomodoro timer for GNOME Shell
 *
 * Copyright (c) 2011-2013 gnome-pomodoro contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * Authors: Arun Mahapatra <pratikarun@gmail.com>
 *          Kamil Prusko <kamilprusko@gmail.com>
 */

const Gettext = imports.gettext;

const Main = imports.ui.main;
const Config = imports.misc.config;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Indicator = Extension.imports.indicator;


let indicator = null;


function init(metadata) {
    Gettext.bindtextdomain('gnome-pomodoro', Config.LOCALEDIR);
}


function enable() {
    if (!indicator) {
        indicator = new Indicator.Indicator();
        Main.panel.addToStatusArea('pomodoro', indicator);
    }
}


function disable() {
    if (indicator) {
        indicator.destroy();
        indicator = null;
    }
}
