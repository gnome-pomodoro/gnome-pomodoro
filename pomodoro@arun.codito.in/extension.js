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
const MessageTray = imports.ui.messageTray;

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
        this._pomodoroTime = 15;
        this._minutes = 0;
        this._seconds = 0;
        this._stopTimer = true;
        this._isPause = false;
        this._shortPauseTime = 6;
        this._longPauseTime = 10;
        this._pauseTime = this._shortPauseTime;
        this._pauseCount = 0;
        this._sessionCount = 1;

        this._timer.set_text("[0] --:--");
        this.actor.add_actor(this._timer);

        // Toggle timer state button
        let widget = new PopupMenu.PopupSwitchMenuItem(_("Toggle timer"), false);
        widget.connect("toggled", Lang.bind(this, this._toggleTimerState));
        this.menu.addMenuItem(widget);

        // Start the timer
        this._refreshTimer();
    },

    // Notify user of changes
    _notifyUser: function(text) {
        global.log("_notifyUser called: " + text);

        let source = new MessageTray.SystemNotificationSource();
        Main.messageTray.add(source);
        let notification = new MessageTray.Notification(source, text, null);
        notification.setTransient(true);
        source.notify(notification);
    },
    
    _toggleTimerState: function(item) {
        this._stopTimer = item.state;
        if (this._stopTimer == false) {
            this._notifyUser('Pomodoro stopped!');
            this._stopTimer = true;
            this._isPause = false;
            this._sessionCount = 1;
            this._timer.set_text("[0] --:--");
        }
        else {
            this._notifyUser('Pomodoro started!');
            this._timeSpent = -1;
            this._minutes = 0;
            this._seconds = 0;
            this._stopTimer = false;
            this._isPause = false;
            this._refreshTimer();
        }
    },
    
    _refreshTimer: function() {
        if (this._stopTimer == false) {
            this._timeSpent += 1;
            let _timerLabel = 'Session ' + this._sessionCount;
            
            // Check if a pause is running..
            if (this._isPause == true) {
                // Check if the pause is over
                if (this._timeSpent > this._pauseTime) {
                    this._notifyUser('Pause finished, a new pomodoro is starting!');
                    this._timeSpent = 0;
                    this._isPause = false;
                    this._pauseTime = this._shortPauseTime;
                }
                else {
                    if (this._pauseCount == 0)
                        _timerLabel = 'Long pause';
                    else
                        _timerLabel = 'Pause ' + this._pauseCount;
                }
            }
            // ..or if a pomodoro is running and a pause is needed :)
            else if (this._timeSpent > this._pomodoroTime) {
                this._pauseCount += 1;
                
                // Check if it's time of a longer pause
                if (this._pauseCount == 4) {
                    this._pauseCount = 0;
                    this._sessionCount = 0;
                    this._pauseTime = this._longPauseTime;
                    this._notifyUser('4th pomodoro finished, starting a long pause...');
                    _timerLabel = 'Long pause';
                }
                else {
                    this._notifyUser('Pomodoro finished, starting pause...');
                    _timerLabel = 'Pause ' + this._pauseCount;
                }
                    
                this._timeSpent = 0;
                this._minutes = 0;
                this._seconds = 0;
                this._sessionCount += 1;
                this._isPause = true;
            }

            this._minutes = parseInt(this._timeSpent / 60);
            this._seconds = this._timeSpent - (this._minutes*60);

            // Weird way to show 2-digit number, but js doesn't have a native padding function
            if (this._minutes < 10)
                this._minutes = "0" + this._minutes.toString();
            else
                this._minutes = this._minutes.toString();

            if (this._seconds < 10) 
                this._seconds = "0" + this._seconds.toString();
            else
                this._seconds = this._seconds.toString();
                
            this._timer.set_text("[" + _timerLabel + "] " + this._minutes + ":" + this._seconds);

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
