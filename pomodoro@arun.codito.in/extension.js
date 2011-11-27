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

const Clutter = imports.gi.Clutter;
const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;
const Pango = imports.gi.Pango;
const St = imports.gi.St;
const Util = imports.misc.util;
const ExtensionSystem = imports.ui.extensionSystem;

const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const ModalDialog = imports.ui.modalDialog;
const PanelMenu = imports.ui.panelMenu;
const PopupMenu = imports.ui.popupMenu;

const Gettext = imports.gettext.domain('gnome-shell-pomodoro');
const _ = Gettext.gettext;

let _useKeybinder = true;
try { const Keybinder = imports.gi.Keybinder; } catch (error) { _useKeybinder = false; }

let _configVersion = "0.1";
let _configOptions = [ // [ <variable>, <config_category>, <actual_option>, <default_value> ]
    ["_pomodoroTime", "timer", "pomodoro_duration", 1500],
    ["_shortPauseTime", "timer", "short_pause_duration", 300],
    ["_longPauseTime", "timer", "long_pause_duration", 900],
    ["_showMessages", "ui", "show_messages", true],
    ["_showElapsed", "ui", "show_elapsed_time", true],
    ["_persistentBreakMessage", "ui", "show_persistent_break_message", false],
    ["_keyToggleTimer", "ui", "key_toggle_timer", "<Ctrl><Alt>P"]
];

function Indicator() {
    this._init.apply(this, arguments);
}

Indicator.prototype = {
    __proto__: PanelMenu.Button.prototype,

    _init: function() {
        PanelMenu.Button.prototype._init.call(this, St.Align.START);

        // Set default values of options, and then override from config file
        this._parseConfig();

        this._timer = new St.Label({ style_class: 'extension-pomodoro-label' });
        this._timeSpent = -1;
        this._minutes = 0;
        this._seconds = 0;
        this._stopTimer = true;
        this._isPause = false;
        this._pauseTime = 0;
        this._pauseCount = 0;                                   // Number of short pauses so far. Reset every 4 pauses.
        this._sessionCount = 0;                                 // Number of pomodoro sessions completed so far!
        this._labelMsg = new St.Label({ text: 'Stopped'});
        this._timerLabel = this.sessionCount;
        this._persistentMessageDialog = new ModalDialog.ModalDialog();
        this._persistentMessageTimer = new St.Label({ style_class: 'persistent-message-label'  }),

        // Set default menu
        this._timer.set_text("[0] --:--");
        this.actor.add_actor(this._timer);
        let item = new PopupMenu.PopupMenuItem("Status:", { reactive: false });
        item.addActor(this._labelMsg);
        this.menu.addMenuItem(item);

        // Set initial width of the timer label
        this._timer.connect('realize', Lang.bind(this, this._onTimerRealize));

        // Toggle timer state button
        this._widget = new PopupMenu.PopupSwitchMenuItem(_("Toggle timer"), false);
        this._widget.connect("toggled", Lang.bind(this, this._toggleTimerState));
        this.menu.addMenuItem(this._widget);

        // Separator
        let item = new PopupMenu.PopupSeparatorMenuItem();
        this.menu.addMenuItem(item);

        // Options SubMenu
        this._optionsMenu = new PopupMenu.PopupSubMenuMenuItem('Options');
        this.menu.addMenuItem(this._optionsMenu);
        // Add options to submenu
        this._buildOptionsMenu();

        // Register keybindings to toggle
        if (_useKeybinder) {
            Keybinder.init();
            Keybinder.bind(this._keyToggleTimer, Lang.bind(this, this._keyHandler), null);
        }

        // Create persistent message modal dialog
        this._persistentMessageDialog.contentLayout.add(new St.Label({ style_class: 'persistent-message-label',
            text: 'Take a break!' }), { x_fill: true, y_fill: true });
        this._persistentMessageDialog.contentLayout.add(this._persistentMessageTimer,
                { x_fill: true, y_fill: true });
        this._persistentMessageDialog.setButtons([ 
            { label: _("Skip Break"), 
              action: Lang.bind(this, function(param) { this._timeSpent = 99999;
              this._checkTimerState();
              }), 
            },
            { label: _("Hide"),
              action: Lang.bind(this, function(param) { this._persistentMessageDialog.close(); }),
              key:    Clutter.Escape 
            },]);

        // Start the timer
        this._refreshTimer();
    },


    // Add whatever options the timer needs to this submenu
    _buildOptionsMenu: function() {

        // Timer format Menu
        if (this._showElapsed == true)
            this._timerTypeMenu = new PopupMenu.PopupMenuItem(_("Show Remaining Time"));
        else
            this._timerTypeMenu = new PopupMenu.PopupMenuItem(_("Show Elapsed Time"));

        this._optionsMenu.menu.addMenuItem(this._timerTypeMenu);
        this._timerTypeMenu.connect('activate', Lang.bind(this, this._toggleTimerType));

        // Reset Counters Menu
        this._resetMenu =  new PopupMenu.PopupMenuItem(_('Reset Counts and Timer'));
        this._optionsMenu.menu.addMenuItem(this._resetMenu);
        this._resetMenu.connect('activate', Lang.bind(this, this._resetCount));

        // ShowMessages option toggle
        this._showMessagesSwitch = new PopupMenu.PopupSwitchMenuItem(_("Show Notification Messages"), this._showMessages);
        this._showMessagesSwitch.connect("toggled", Lang.bind(this, function() {
            this._showMessages = !(this._showMessages);
            this._onConfigUpdate(false);
        }));
        this._optionsMenu.menu.addMenuItem(this._showMessagesSwitch);

        //Persistent Break Message toggle
        let breakMessageToggle = new PopupMenu.PopupSwitchMenuItem
            (_("Show Persistent Break Messages"), this._persistentBreakMessage);
        breakMessageToggle.connect("toggled", Lang.bind(this, function() {
            this._persistentBreakMessage = !(this._persistentBreakMessage);
            this._onConfigUpdate(false);
        }));
        // Uncomment and replace tooltip, if label does not describe use clearly
        // breakMessageToggle.actor.tooltip_text = "Show a persistent message at the end of pomodoro session"; 
        this._optionsMenu.menu.addMenuItem(breakMessageToggle);  

        // Pomodoro Duration menu
        let timerLengthMenu = new PopupMenu.PopupSubMenuMenuItem(_('Timer Durations'));
        this._optionsMenu.menu.addMenuItem(timerLengthMenu);

        let item = new PopupMenu.PopupMenuItem(_("Pomodoro Duration"), { reactive: false });
        this._pomodoroTimeLabel = new St.Label({ text: this._formatTime(this._pomodoroTime) });
        item.addActor(this._pomodoroTimeLabel);
        timerLengthMenu.menu.addMenuItem(item);

        this._pomodoroTimeSlider = new PopupMenu.PopupSliderMenuItem(this._pomodoroTime/3600);
        this._pomodoroTimeSlider.connect('value-changed', Lang.bind(this, function() {
            this._pomodoroTime = Math.ceil(Math.ceil(this._pomodoroTimeSlider._value * 3600)/10)*10;
            this._pomodoroTimeLabel.set_text(this._formatTime(this._pomodoroTime));
            this._onConfigUpdate(true);
        } ));
        timerLengthMenu.menu.addMenuItem(this._pomodoroTimeSlider);

        // Short Break Duration menu
        item = new PopupMenu.PopupMenuItem(_("Short Break Duration"), { reactive: false });
        this._sBreakTimeLabel = new St.Label({ text: this._formatTime(this._shortPauseTime) });
        item.addActor(this._sBreakTimeLabel);
        timerLengthMenu.menu.addMenuItem(item);

        this._sBreakTimeSlider = new PopupMenu.PopupSliderMenuItem(this._shortPauseTime/720);
        this._sBreakTimeSlider.connect('value-changed', Lang.bind(this, function() {
            this._shortPauseTime = Math.ceil(Math.ceil(this._sBreakTimeSlider._value * 720)/10)*10;
            this._sBreakTimeLabel.set_text(this._formatTime(this._shortPauseTime));
            this._onConfigUpdate(true);
        } ));
        timerLengthMenu.menu.addMenuItem(this._sBreakTimeSlider);

        // Long Break Duration menu
        item = new PopupMenu.PopupMenuItem(_("Long Break Duration"), { reactive: false });
        this._lBreakTimeLabel = new St.Label({ text: this._formatTime(this._longPauseTime) });
        item.addActor(this._lBreakTimeLabel);
        timerLengthMenu.menu.addMenuItem(item);

        this._lBreakTimeSlider = new PopupMenu.PopupSliderMenuItem(this._longPauseTime/2160);
        this._lBreakTimeSlider.connect('value-changed', Lang.bind(this, function() {
            this._longPauseTime = Math.ceil(Math.ceil(this._lBreakTimeSlider._value * 2160)/10)*10;
            this._lBreakTimeLabel.set_text(this._formatTime(this._longPauseTime));
            this._onConfigUpdate(true);
        } ));
        timerLengthMenu.menu.addMenuItem(this._lBreakTimeSlider);
    },

    // Handle the style related properties in the timer label. These properties are dependent on
    // font size/theme used by user, we need to calculate them during runtime
    _onTimerRealize: function(actor) {
        let context = actor.get_pango_context();
        let themeNode = actor.get_theme_node();
        let font = themeNode.get_font();
        let metrics = context.get_metrics(font, context.get_language());
        let digit_width = metrics.get_approximate_digit_width() / Pango.SCALE;
        let char_width = metrics.get_approximate_char_width() / Pango.SCALE;

        // 3, 5 are the number of characters and digits we have in the label
        actor.width = char_width * 3 + digit_width * 5;
        global.log("Pomodoro: label width = " + char_width + ", " + digit_width);
    },

    // Handles option changes in the UI, saves the configuration
    // Set _validateTimer_ to true in case internal timer states and related options are changed
    _onConfigUpdate: function(validateTimer) {
        if (validateTimer == true) {
            this._checkTimerState();
            this._updateTimer();
        }

        this._saveConfig();
    },

    // Toggle how timeSpent is displayed on ui_timer
    _toggleTimerType: function() {
        if (this._showElapsed == true) {
            this._showElapsed = false;
            this._timerTypeMenu.label.set_text(_("Show Elapsed Time"));
        } else {
            this._showElapsed = true;
            this._timerTypeMenu.label.set_text(_("Show Remaining Time"));
        }

        this._onConfigUpdate(true);
        return false;
    },


    // Reset all counters and timers
    _resetCount: function() {
        this._sessionCount = 0;
        this._pauseCount = 0;
        if (this._stopTimer == false) {
            this._stopTimer = true;
            this._isPause = false;
        }
        this._timer.set_text("[" + this._sessionCount + "] --:--");
        this._widget.setToggleState(false);
        return false;
    },

    // Notify user of changes
    _notifyUser: function(text, label_msg) {
        if (this._showMessages) {
            let source = new MessageTray.SystemNotificationSource();
            Main.messageTray.add(source);
            let notification = new MessageTray.Notification(source, text, null);
            notification.setTransient(true);
            source.notify(notification);
        }        
        // Change the label inside the popup menu
        this._labelMsg.set_text(label_msg);
    },

    // Show a persistent message at the end of pomodoro session
    _showMessageAtPomodoroCompletion: function() {
        if (this._persistentBreakMessage) {
            this._persistentMessageDialog.open();
        }
    },

    // Plays a notification sound
    _playNotificationSound: function() {
        let extension = ExtensionSystem.extensionMeta["pomodoro@arun.codito.in"];
        let uri = GLib.filename_to_uri(extension.path + "/bell.wav", null);
        
        try {
            Util.trySpawnCommandLine("gst-launch --quiet playbin2 uri="+ GLib.shell_quote(uri));
        } catch (err) {
            global.logError("Pomodoro: Error playing a sound: " + err.message);
        }
    },

    // Toggle timer state
    _toggleTimerState: function(item) {
        if (item != null) {
            this._stopTimer = item.state;
        }

        if (this._stopTimer == false) {
            this._stopTimer = true;
            this._isPause = false;
            this._timer.set_text("[" + this._sessionCount + "] --:--");
            this._labelMsg.set_text('Stopped');
        }
        else {
            this._timeSpent = -1;
            this._minutes = 0;
            this._seconds = 0;
            this._stopTimer = false;
            this._isPause = false;
            this._refreshTimer();
            this._labelMsg.set_text('Running');
        }
    },


    // Increment timeSpent and call functions to check timer states and update ui_timer    
    _refreshTimer: function() {
        if (this._stopTimer == false) {
            this._timeSpent += 1;
            this._checkTimerState();
            this._updateTimer();
            Mainloop.timeout_add_seconds(1, Lang.bind(this, this._refreshTimer));
        }

        this._updateTimer();
        return false;
    },


    // Checks if timer needs to change state
    _checkTimerState: function() {
        if (this._stopTimer == false) {
            this._timerLabel = this._sessionCount;

            // Check if a pause is running..
            if (this._isPause == true) {
                // Check if the pause is over
                if (this._timeSpent >= this._pauseTime) {
                    this._timeSpent = 0;
                    this._isPause = false;
                    this._notifyUser('Pause finished, a new pomodoro is starting!', 'Running');
                    this._persistentMessageDialog.close();
                    this._playNotificationSound();
                }
                else {
                    if (this._pauseCount == 0) {
                        this._pauseTime = this._longPauseTime;
                        this._timerLabel = 'L';
                    } else {
                        this._pauseTime = this._shortPauseTime;
                        this._timerLabel = 'S';
                    }
                }
            }
            // ..or if a pomodoro is running and a pause is needed :)
            else if (this._timeSpent >= this._pomodoroTime) {
                this._pauseCount += 1;
                this._pauseTime = this._shortPauseTime;

                // Check if it's time of a longer pause
                if (this._pauseCount == 4) {
                    this._pauseCount = 0;
                    this._pauseTime = this._longPauseTime;
                    this._notifyUser('4th pomodoro in a row finished, starting a long pause...', 'Long pause');
                    this._timerLabel = 'L';
                }
                else {
                    this._notifyUser('Pomodoro finished, starting pause...', 'Short pause');
                    this._timerLabel = 'S';
                }

                this._showMessageAtPomodoroCompletion();
                this._timeSpent = 0;
                this._minutes = 0;
                this._seconds = 0;
                this._sessionCount += 1;
                this._isPause = true;
            }
        }
    },


    // Update timer_ui
    _updateTimer: function() {
        if (this._stopTimer == false) {
            let displaytime = this._timeSpent;
            if (this._showElapsed == false) {
                if (this._isPause == false) 
                    displaytime = this._pomodoroTime - this._timeSpent;
                else
                    displaytime = this._pauseTime - this._timeSpent;
            }                            

            this._minutes = parseInt(displaytime / 60);
            this._seconds = displaytime - (this._minutes * 60);

            timer_text = "%02d:%02d".format(this._minutes, this._seconds)
            this._timer.set_text("[" + this._timerLabel + "] " + timer_text);

            if (this._isPause && this._persistentBreakMessage)
                this._persistentMessageTimer.set_text(timer_text + "\n");
        }
    },


    // Format absolute time in seconds as "Xm Ys"
    _formatTime: function(abs) {
        let minutes = Math.floor(abs/60);
        let seconds = abs - minutes*60;
        let str = "";
        if (minutes != 0) {
            str = str + minutes.toString() + " m ";
        }
        if (seconds != 0) {
            str = str + seconds.toString() + " s";
        }
        if (abs == 0) {
            str = "0 s";
        }
        return str;
    },

    _keyHandler: function(keystring, data) {
        if (keystring == this._keyToggleTimer) {
            this._toggleTimerState(null);
        }
    },
    
    _parseConfig: function() {
        let _configFile = GLib.get_user_config_dir() + "/gnome-shell-pomodoro/gnome_shell_pomodoro.json";
        // Set the default values
        for (let i = 0; i < _configOptions.length; i++)
            this[_configOptions[i][0]] = _configOptions[i][3];

        if (GLib.file_test(_configFile, GLib.FileTest.EXISTS)) {
            let filedata = null;

            try {
                filedata = GLib.file_get_contents(_configFile, null, 0);
                global.log("Pomodoro: Using config file = " + _configFile);

                let jsondata = JSON.parse(filedata[1]);
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
    },


    _saveConfig: function() {
        let _configDir = GLib.get_user_config_dir() + "/gnome-shell-pomodoro";
        let _configFile = _configDir + "/gnome_shell_pomodoro.json";
        let filedata = null;
        let jsondata = {};

        if (GLib.file_test(_configDir, GLib.FileTest.EXISTS | GLib.FileTest.IS_DIR) == false &&
                GLib.mkdir_with_parents(_configDir, 0x2141) != 0) { // 0755 base 8 = 0x2141 base 6
                    global.logError("Pomodoro: Failed to create configuration directory. Path = " +
                            _configDir + ". Configuration will not be saved.");
                }

        try {
            jsondata["version"] = _configVersion;
            for (let i = 0; i < _configOptions.length; i++) {
                let option = _configOptions[i];
                // Insert the option "category", if it's undefined
                if (jsondata.hasOwnProperty(option[1]) == false) {
                    jsondata[option[1]] = {};
                }

                // Update the option key/value pairs
                jsondata[option[1]][option[2]] = this[option[0]];
            }
            filedata = JSON.stringify(jsondata, null, "  ");
            GLib.file_set_contents(_configFile, filedata, filedata.length);
        }
        catch (e) {
            global.logError("Pomodoro: Error writing config file = " + e);
        }
        finally {
            jsondata = null;
            filedata = null;
        }
        global.log("Pomodoro: Updated config file = " + _configFile);
    }
};

// Extension initialization code
function init(metadata) {
    //imports.gettext.bindtextdomain('gnome-shell-pomodoro', metadata.localedir);
}

let _indicator;

function enable() {
    if (_indicator == null) {
        _indicator = new Indicator;
        Main.panel.addToStatusArea('pomodoro', _indicator);
    }
}

function disable() {
    if (_indicator != null) {
        _indicator.destroy();
        _indicator = null;
    }
}
