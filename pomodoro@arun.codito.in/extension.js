// A simple pomodoro timer for Gnome-shell
// Copyright (C) 2011 Arun Mahapatra, Gnome-shell pomodoro extension contributors
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

const GLib = imports.gi.GLib;
const Pango = imports.gi.Pango;
const St = imports.gi.St;

const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const PanelMenu = imports.ui.panelMenu;
const PopupMenu = imports.ui.popupMenu;

const Gettext = imports.gettext.domain('gnome-shell');
const _ = Gettext.gettext;

let _pomodoroInit = false;
let _configOptions = [ // [ <variable>, <config_category>, <actual_option>, <default_value> ]
    ["_pomodoroTime", "timer", "pomodoro_duration", 1500],
    ["_shortPauseTime", "timer", "short_pause_duration", 300],
    ["_longPauseTime", "timer", "long_pause_duration", 900],
    ["_keyToggleTimer", "ui", "key_toggle_timer", "<Ctrl><Alt>P"]
];

function Indicator() {
    this._init.apply(this, arguments);
}

Indicator.prototype = {
    __proto__: PanelMenu.SystemStatusButton.prototype,

    _init: function() {
        PanelMenu.SystemStatusButton.prototype._init.call(this, 'text-x-generic-symbol');

        // Set default values of options, and then override from config file
        this._parseConfig();

        this._timer = new St.Label({ style_class: 'extension-pomodoro-label' });
        this._timeSpent = -1;
        this._minutes = 0;
        this._seconds = 0;
        this._stopTimer = true;
        this._isPause = false;
        this._pauseTime = this._shortPauseTime;
        this._pauseCount = 0;                                   // Number of short pauses so far. Reset every 4 pauses.
        this._sessionCount = 0;                                 // Number of pomodoro sessions completed so far!
        this._labelMsg = new St.Label({ text: 'Stopped'});

        // Set default menu
        this._timer.set_text("[0] --:--");
        this.actor.add_actor(this._timer);
        let item = new PopupMenu.PopupMenuItem("Status:");
        item.addActor(this._labelMsg);
        this.menu.addMenuItem(item);

        // Set initial width of the timer label
        this._timer.connect('realize', Lang.bind(this, this._onRealize));

        // Toggle timer state button
        let widget = new PopupMenu.PopupSwitchMenuItem(_("Toggle timer"), false);
        widget.connect("toggled", Lang.bind(this, this._toggleTimerState));
        this.menu.addMenuItem(widget);

        // Start the timer
        this._refreshTimer();
    },

    // Handle the style related properties in the timer label. These properties are dependent on
    // font size/theme used by user, we need to calculate them during runtime
    _onRealize: function(actor) {
        let context = actor.get_pango_context();
        let themeNode = actor.get_theme_node();
        let font = themeNode.get_font();
        let metrics = context.get_metrics(font, context.get_language());
        let digit_width = metrics.get_approximate_digit_width() / Pango.SCALE;
        let char_width = metrics.get_approximate_digit_width() / Pango.SCALE;

        // 3, 5 are the number of characters and digits we have in the label
        actor.width = char_width * 3 + digit_width * 5;
        global.log("Pomodoro: label width = " + char_width + ", " + digit_width);
    },

    // Notify user of changes
    _notifyUser: function(text, label_msg) {
        let source = new MessageTray.SystemNotificationSource();
        Main.messageTray.add(source);
        let notification = new MessageTray.Notification(source, text, null);
        notification.setTransient(true);
        source.notify(notification);
        
        // Change the label inside the popup menu
        this._labelMsg.set_text(label_msg);
    },
    
    _toggleTimerState: function(item) {
        this._stopTimer = item.state;
        if (this._stopTimer == false) {
            this._notifyUser('Pomodoro stopped!', 'Stopped');
            this._stopTimer = true;
            this._isPause = false;
            this._timer.set_text("[" + this._sessionCount + "] --:--");
        }
        else {
            this._notifyUser('Pomodoro started!', 'Running');
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
            let _timerLabel = this._sessionCount;
            
            // Check if a pause is running..
            if (this._isPause == true) {
                // Check if the pause is over
                if (this._timeSpent > this._pauseTime) {
                    this._notifyUser('Pause finished, a new pomodoro is starting!', 'Running');
                    this._timeSpent = 0;
                    this._isPause = false;
                    this._pauseTime = this._shortPauseTime;
                }
                else {
                    if (this._pauseCount == 0)
                        _timerLabel = 'L';
                    else
                        _timerLabel = 'S';
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
                    this._notifyUser('4th pomodoro in a row finished, starting a long pause...', 'Long pause');
                    _timerLabel = 'L';
                }
                else {
                    this._notifyUser('Pomodoro finished, starting pause...', 'Short pause');
                    _timerLabel = 'S';
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
    },

    _parseConfig: function() {
        let _configFile = GLib.get_home_dir() + "/.gnome_shell_pomodoro.json";

        // Set the default values
        for (let i = 0; i < _configOptions.length; i++)
            this[_configOptions[i][0]] = _configOptions[i][3];

        if (GLib.file_test(_configFile, GLib.FileTest.EXISTS)) {
            let filedata = null;

            try {
                filedata = GLib.file_get_contents(_configFile, null, 0);
                global.log("Pomodoro: Using config file = " + _configFile);

                let jsondata = eval("(" + filedata[1] + ")");
                let parserVersion = null;
                if (jsondata.hasOwnProperty("version"))
                    parserVersion = jsondata.version;
                else
                    throw "Parser version not defined";

                for (let i = 0; i < _configOptions.length; i++) {
                    let option = _configOptions[i];
                    if (jsondata.hasOwnProperty(option[1]) && jsondata[option[1]].hasOwnProperty(option[2])) {
                        // The option "category" and the actual option is defined in config file,
                        // override it!
                        this[option[0]] = jsondata[option[1]][option[2]];
                    }
                }
            }
            catch (e) {
                global.logError("Pomodoro: Error reading config file = " + e);
            }
            finally {
                filedata = null;
            }
        }
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

