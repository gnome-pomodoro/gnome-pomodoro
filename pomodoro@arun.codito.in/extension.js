// A simple pomodoro timer for Gnome-shell
// Copyright (C) 2011 Arun Mahapatra
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

const Lang = imports.lang;
const Mainloop = imports.mainloop;
const St = imports.gi.St;
const Main = imports.ui.main;

const PanelMenu = imports.ui.panelMenu;
const PopupMenu = imports.ui.popupMenu;

const Gettext = imports.gettext.domain('gnome-shell');
const _ = Gettext.gettext;

let _pomodoroInit = false;

function Indicator() {
    this._init.apply(this, arguments);
}

Indicator.prototype = {
    __proto__: PanelMenu.SystemStatusButton.prototype,

    _init: function() {
        PanelMenu.SystemStatusButton.prototype._init.call(this, 'text-x-generic-symbol');

        this._timer = new St.Label();
        this._timeSpent = -1;
        this._minutes = 0;
        this._seconds = 0;
        this._stopTimer = true;
        this._sessionCount = 0;

        this._timer.set_text("[0] --:--");
        this.actor.add_actor(this._timer);

        // Toggle timer state button
        let widget = new PopupMenu.PopupSwitchMenuItem(_("Toggle timer"), false);
        widget.connect("toggled", Lang.bind(this, this._toggleTimerState));
        this.menu.addMenuItem(widget);

        // Register keybindings to toggle
        //let shellwm = global.window_manager;
        //shellwm.takeover_keybinding('something_new');
        //shellwm.connect('keybinding::something_new', function () {
            //Main.runDialog.open();
        //});

        // Bind to system events - like lock or away

        // Start the timer
        this._refreshTimer();
    },

    _toggleTimerState: function(item) {
        this._stopTimer = item.state;
        if (this._stopTimer == false) {
            this._stopTimer = true;
            this._timer.set_text("[" + this._sessionCount + "] --:--");
        }
        else {
            this._timeSpent = -1;
            this._minutes = 0;
            this._seconds = 0;
            this._stopTimer = false;
            this._refreshTimer();
        }
    },

    _refreshTimer: function() {
        if (this._stopTimer == false) {
            this._timeSpent += 1;
            if (this._timeSpent > 1500) {
                this._timeSpent = 0;
                this._minutes = 0;
                this._seconds = 0;
                this._sessionCount += 1;
            }

            this._minutes = parseInt(this._timeSpent / 60);
            this._seconds = this._timeSpent - (this._minutes*60);

            if (this._minutes < 10)
                this._minutes = "0" + this._minutes.toString();
            else
                this._minutes = this._minutes.toString();

            if (this._seconds < 10) 
                this._seconds = "0" + this._seconds.toString();
            else
                this._seconds = this._seconds.toString();

            this._timer.set_text("[" + this._sessionCount + "] " + this._minutes + ":" + this._seconds);

            Mainloop.timeout_add_seconds(1, Lang.bind(this, this._refreshTimer));
        }

        return false;
    }
};

// Put your extension initialization code here
function main() {
    if (!_pomodoroInit) {
        Main.StatusIconDispatcher.STANDARD_TRAY_ICON_IMPLEMENTATIONS['pomodoro'] = 'pomodoro';
        Main.Panel.STANDARD_TRAY_ICON_ORDER.unshift('pomodoro');
        Main.Panel.STANDARD_TRAY_ICON_SHELL_IMPLEMENTATION['pomodoro'] = Indicator;
        _pomodoroInit = true;
    }
}