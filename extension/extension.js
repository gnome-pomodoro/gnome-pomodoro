// A simple pomodoro timer for Gnome-shell
// Copyright (C) 2011,2012 Arun Mahapatra, Gnome-shell pomodoro extension contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

const Main = imports.ui.main;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Indicator = Extension.imports.indicator;
const Utils = Extension.imports.utils;


let indicator;

function init(metadata) {
    Utils.initTranslations('gnome-shell-pomodoro');
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
