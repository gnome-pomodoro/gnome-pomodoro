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
const Meta = imports.gi.Meta;
const Gtk = imports.gi.Gtk;

const Main = imports.ui.main;
const ExtensionSystem = imports.ui.extensionSystem;
const MessageTray = imports.ui.messageTray;
const ModalDialog = imports.ui.modalDialog;
const PanelMenu = imports.ui.panelMenu;
const PopupMenu = imports.ui.popupMenu;
const Tweener = imports.ui.tweener;

const Util = imports.misc.util;
const Params = imports.misc.params;
const GnomeSession = imports.misc.gnomeSession;
const ScreenSaver = imports.misc.screenSaver;

const Gettext = imports.gettext.domain('gnome-shell-pomodoro');
const _ = Gettext.gettext;

let _useKeybinder = true;
try { const Keybinder = imports.gi.Keybinder; } catch (error) { _useKeybinder = false; }

try {
    const Gst = imports.gi.Gst;
    Gst.init(null);
} catch(e) {
}


let _configVersion = '0.1';
let _configOptions = [ // [ <variable>, <config_category>, <actual_option>, <default_value> ]
    ['_pomodoroTime', 'timer', 'pomodoro_duration', 1500],
    ['_shortPauseTime', 'timer', 'short_pause_duration', 300],
    ['_longPauseTime', 'timer', 'long_pause_duration', 900],
    ['_awayFromDesk', 'ui', 'away_from_desk', false],
    ['_showDialogMessages', 'ui', 'show_dialog_messages', true],
    ['_playSound', 'ui', 'play_sound', true],
    ['_keyToggleTimer', 'ui', 'key_toggle_timer', '<Ctrl><Alt>P'],
];


function NotificationSource() {
    this._init();
}

NotificationSource.prototype = {
    __proto__:  MessageTray.Source.prototype,
    
    _init: function() {
        MessageTray.Source.prototype._init.call(this, _("Pomodoro Timer"));
        
        this._setSummaryIcon(this.createNotificationIcon());
        
        // Add ourselves as a source.
        Main.messageTray.add(this);
    },

    createNotificationIcon: function() {
        return new St.Icon({ icon_name: 'timer',
                             icon_type: St.IconType.SYMBOLIC,
                             icon_size: this.ICON_SIZE });
    },

    open: function(notification) {
        this.destroyNonResidentNotifications();
    }
}


// Message dialog blocks user input for a time corresponding to slow typing speed
// of 23 words per minute which translates to 523 miliseconds between key presses,
// and moderate typing speed of 35 words per minute / 343 miliseconds.
// Pressing Enter key takes longer, so more time needed.
const MESSAGE_DIALOG_BLOCK_EVENTS_TIME = 600;

function MessageDialog() {
    this._init();
}

MessageDialog.prototype = {
    __proto__:  ModalDialog.ModalDialog.prototype,
    
    _init: function() {
        ModalDialog.ModalDialog.prototype._init.call(this);
        
        this.style_class = 'polkit-dialog';
        this._timeoutSource = 0;
        this._eventCaptureId = 0;
        this._tryOpenTimeoutSource = 0;

        let mainLayout = new St.BoxLayout({
                                style_class: 'polkit-dialog-main-layout',
                                vertical: false });
        
        // let icon = new St.Icon(
        //                   { icon_name: 'timer',
        //                     icon_type: St.IconType.SYMBOLIC,
        //                     icon_size: this.ICON_SIZE });
        // mainLayout.add(icon,
        //                   { x_fill:  true,
        //                     y_fill:  false,
        //                     x_align: St.Align.END,
        //                     y_align: St.Align.START });

        let messageBox = new St.BoxLayout({
                                style_class: 'polkit-dialog-message-layout',
                                vertical: true });

        this._titleLabel = new St.Label({ style_class: 'polkit-dialog-headline',
                                            text: '' });
                
        this._descriptionLabel = new St.Label({ style_class: 'polkit-dialog-description',
                                                text: '' });
        this._descriptionLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this._descriptionLabel.clutter_text.line_wrap = true;
        
        messageBox.add(this._titleLabel,
                            { y_fill:  false,
                              y_align: St.Align.START });                                              
        messageBox.add(this._descriptionLabel,
                            { y_fill:  true,
                              y_align: St.Align.START });
        mainLayout.add(messageBox,
                            { x_fill: true,
                              y_align: St.Align.START });
        this.contentLayout.add(mainLayout,
                            { x_fill: true,
                              y_fill: true });
    },

    open: function(timestamp) {        
        let success = ModalDialog.ModalDialog.prototype.open.call(this, timestamp);
        if (success) {
            this._disableEventCapture();

            this._eventCaptureId = global.stage.connect('captured-event', Lang.bind(this, this._onEventCapture));
            this._waitUntilIdle();
        }
        return success;
    },
    
    tryOpen: function(params) {
        params = Params.parse(params, { seconds: 1,
                                        onFailure: null });

        if (!this.open()) {
            // Ignore second call
            if (this._tryOpenTimeoutSource != 0)
                return;
            
            // Schedule reopening of the dialog
            let tries = 1;
            let fps = Clutter.get_default_frame_rate();
            this._tryOpenTimeoutSource = Mainloop.timeout_add(parseInt(1000/fps), Lang.bind(this, function(){
                tries++;
                if (this.open()) {
                    return false;
                }
                if (tries > params.seconds*fps) {
                    if (params.onFailure != null)
                        params.onFailure();
                    return false;
                }
                return true;
            }));
        }
    },
    
    close: function(timestamp) {
        this._disableEventCapture();
        if (this._tryOpenTimeoutSource != 0) {
            GLib.source_remove(this._tryOpenTimeoutSource);
            this._tryOpenTimeoutSource = 0;
        }
        return ModalDialog.ModalDialog.prototype.close.call(this, timestamp);
    },
    
    _waitUntilIdle: function() {
        if (this._timeoutSource != 0) {
            GLib.source_remove(this._timeoutSource);
            this._timeoutSource = 0;
        }
        this._timeoutSource = Mainloop.timeout_add(MESSAGE_DIALOG_BLOCK_EVENTS_TIME, Lang.bind(this, function(){
            this._disableEventCapture();
            return false;
        }));
    },

    _onEventCapture: function(actor, event) {
        switch(event.type()) {
            case Clutter.EventType.KEY_PRESS:
                let keysym = event.get_key_symbol();
                if (keysym == Clutter.Escape)
                    return false;
                // User might be looking at the keyboard while typing, so continue typing to the app.
                // TODO: pass typed letters to a focused object without blocking them
                this._waitUntilIdle();
                return true;                
            
            case Clutter.EventType.BUTTON_PRESS:
            case Clutter.EventType.BUTTON_RELEASE:
                return true;
        }
        return false;
    },
    
    _disableEventCapture: function() {
        if (this._timeoutSource != 0) {
            GLib.source_remove(this._timeoutSource);
            this._timeoutSource = 0;
        }
        if (this._eventCaptureId != 0) {
            global.stage.disconnect(this._eventCaptureId);
            this._eventCaptureId = 0;
        }
    },
    
    setTitle: function(text) {
        this._titleLabel.text = text;
    },

    setText: function(text) {
        this._descriptionLabel.text = text;        
    }
}


const TIMER_LABEL_OPACITY_WHEN_PAUSE = 150;
const TIMER_LABEL_FADE_TIME = 0.2; // seconds used to fade in/out

function Indicator() {
    this._init.apply(this, arguments);
}

Indicator.prototype = {
    __proto__: PanelMenu.Button.prototype,

    _init: function() {
        PanelMenu.Button.prototype._init.call(this, St.Align.START);

        // Set default values of options, and then override from config file
        this._parseConfig();

        this._timeSpent = 0;
        this._isRunning = false;
        this._isPause = false;
        this._isIdle = false;
        this._pauseTime = this._longPauseTime;
        this._pauseCount = 0;                                   // Number of short pauses so far. Reset every 4 pauses.
        this._sessionCount = 0;                                 // Number of pomodoro sessions completed so far!
        this._notification = null;
        this._dialog = null;
        this._timerSource = 0;
        this._eventCaptureId = 0;
        this._eventCaptureSource = 0;
        this._pointer = null;

        this.label = new St.Label({ style_class: 'extension-pomodoro-label' });
        this.label.clutter_text.set_line_wrap(false);
        this.label.clutter_text.set_ellipsize(Pango.EllipsizeMode.NONE);
        
        // St.Label doesn't support text-align so use a Bin
        let labelBin = new St.Bin({ x_align: St.Align.START });
        labelBin.add_actor(this.label);
        this.actor.add_actor(labelBin);
        
        // Toggle timer state button
        this._timerToggle = new PopupMenu.PopupSwitchMenuItem(_("Pomodoro Timer"), false, { style_class: 'popup-subtitle-menu-item' });
        this._timerToggle.connect('toggled', Lang.bind(this, this._toggleTimerState));
        this.menu.addMenuItem(this._timerToggle);

        // Session count
        let sessionCountItem = new PopupMenu.PopupMenuItem('', { reactive: false });
        this._sessionCountLabel = sessionCountItem.label;
        this.menu.addMenuItem(sessionCountItem);

        // Separator
        let item = new PopupMenu.PopupSeparatorMenuItem();
        this.menu.addMenuItem(item);

        // Options SubMenu
        this._optionsMenu = new PopupMenu.PopupSubMenuMenuItem(_("Options"));        
        this._buildOptionsMenu();
        this.menu.addMenuItem(this._optionsMenu);

        // Register keybindings to toggle
        if (_useKeybinder) {
            Keybinder.init();
            Keybinder.bind(this._keyToggleTimer, Lang.bind(this, this._keyHandler), null);
        }

        // GNOME Session
        this._screenSaver = null;


        this.connect('destroy', Lang.bind(this, this._onDestroy));
        
        // Init timer
        this._resetCount();
    },

    // Add whatever options the timer needs to this submenu
    _buildOptionsMenu: function() {
        // Reset Counters Menu
        this._resetCountButton =  new PopupMenu.PopupMenuItem(_("Reset Counts and Timer"));
        this._resetCountButton.actor.tooltip_text = _("Click to reset session counts to zero");
        this._resetCountButton.connect('activate', Lang.bind(this, this._resetCount));
        this._optionsMenu.menu.addMenuItem(this._resetCountButton);
        
        // Away From Desk toggle
        this._awayFromDeskToggle = new PopupMenu.PopupSwitchMenuItem(_("Away From Desk"), this._awayFromDesk);
        this._awayFromDeskToggle.actor.tooltip_text = _("Set optimal settings for doing paperwork");
        this._awayFromDeskToggle.connect('toggled', Lang.bind(this, function(item) {
            this._awayFromDesk = item.state;
            this._onConfigUpdate(false);
        }));
        this._optionsMenu.menu.addMenuItem(this._awayFromDeskToggle);

        // Dialog Message toggle
        this._breakMessageToggle = new PopupMenu.PopupSwitchMenuItem(_("Show Dialog Messages"), this._showDialogMessages);
        this._breakMessageToggle.actor.tooltip_text = _("Show a dialog message at the end of pomodoro session");
        this._breakMessageToggle.connect('toggled', Lang.bind(this, function() {
            this._showDialogMessages = !(this._showDialogMessages);
            this._onConfigUpdate(false);
        }));
        this._optionsMenu.menu.addMenuItem(this._breakMessageToggle);

        // Notify with a sound
        this._playSoundToggle = new PopupMenu.PopupSwitchMenuItem(_("Sound Notifications"), this._playSound);
        this._playSoundToggle.actor.tooltip_text = _("Play a sound at start of pomodoro session");
        this._playSoundToggle.connect('toggled', Lang.bind(this, function() {
            this._playSound = !(this._playSound);
            this._onConfigUpdate(false);
        }));
        this._optionsMenu.menu.addMenuItem(this._playSoundToggle);

        // Pomodoro Duration section
        let timerLengthSection = new PopupMenu.PopupMenuSection();

        this._pomodoroTimeTitle = new PopupMenu.PopupMenuItem(_("Pomodoro Duration"), { reactive: false });
        this._pomodoroTimeLabel = new St.Label({ text: this._formatTime(this._pomodoroTime) });
        this._pomodoroTimeSlider = new PopupMenu.PopupSliderMenuItem(this._pomodoroTime/3600);
        this._pomodoroTimeSlider.connect('value-changed', Lang.bind(this, function() {
            this._pomodoroTime = Math.ceil(Math.ceil(this._pomodoroTimeSlider._value * 3600)/60)*60;
            this._pomodoroTimeLabel.set_text(this._formatTime(this._pomodoroTime));
            this._onConfigUpdate(true);
        }));
        this._pomodoroTimeTitle.addActor(this._pomodoroTimeLabel, { align: St.Align.END });
        this._optionsMenu.menu.addMenuItem(this._pomodoroTimeTitle);
        this._optionsMenu.menu.addMenuItem(this._pomodoroTimeSlider);

        // Short Break Duration menu
        this._shortBreakTimeTitle = new PopupMenu.PopupMenuItem(_("Short Break Duration"), { reactive: false });
        this._shortBreakTimeLabel = new St.Label({ text: this._formatTime(this._shortPauseTime) });
        this._shortBreakTimeSlider = new PopupMenu.PopupSliderMenuItem(this._shortPauseTime/720);
        this._shortBreakTimeSlider.connect('value-changed', Lang.bind(this, function() {
            this._shortPauseTime = Math.ceil(Math.ceil(this._shortBreakTimeSlider._value * 720)/60)*60;
            this._shortBreakTimeLabel.set_text(this._formatTime(this._shortPauseTime));
            this._onConfigUpdate(true);
        }));
        this._shortBreakTimeTitle.addActor(this._shortBreakTimeLabel, { align: St.Align.END });
        this._optionsMenu.menu.addMenuItem(this._shortBreakTimeTitle);
        this._optionsMenu.menu.addMenuItem(this._shortBreakTimeSlider);

        // Long Break Duration menu
        this._longBreakTimeTitle = new PopupMenu.PopupMenuItem(_("Long Break Duration"), { reactive: false });
        this._longBreakTimeLabel = new St.Label({ text: this._formatTime(this._longPauseTime) });
        this._longBreakTimeSlider = new PopupMenu.PopupSliderMenuItem(this._longPauseTime/2160);
        this._longBreakTimeSlider.connect('value-changed', Lang.bind(this, function() {
            this._longPauseTime = Math.ceil(Math.ceil(this._longBreakTimeSlider._value * 2160)/60)*60;
            this._longBreakTimeLabel.set_text(this._formatTime(this._longPauseTime));
            this._onConfigUpdate(true);
        }));
        this._longBreakTimeTitle.addActor(this._longBreakTimeLabel, { align: St.Align.END });
        this._optionsMenu.menu.addMenuItem(this._longBreakTimeTitle);
        this._optionsMenu.menu.addMenuItem(this._longBreakTimeSlider);
    },

    // Handle the style related properties in the timer label. These properties are dependent on
    // font size/theme used by user, we need to calculate them during runtime
    _getPreferredWidth: function(actor, forHeight, alloc) {
        let theme_node = actor.get_theme_node();
        let min_hpadding = theme_node.get_length('-minimum-hpadding');
        let natural_hpadding = theme_node.get_length('-natural-hpadding');

        let context     = actor.get_pango_context();
        let font        = theme_node.get_font();
        let metrics     = context.get_metrics(font, context.get_language());
        let digit_width = metrics.get_approximate_digit_width() / Pango.SCALE;
        let char_width  = metrics.get_approximate_char_width() / Pango.SCALE;
        
        let predicted_width        = parseInt(digit_width * 4 + 0.5 * char_width);
        let predicted_min_size     = predicted_width + 2 * min_hpadding;
        let predicted_natural_size = predicted_width + 2 * natural_hpadding;        

        PanelMenu.Button.prototype._getPreferredWidth.call(this, actor, forHeight, alloc); // output stored in alloc

        if (alloc.min_size < predicted_min_size)
            alloc.min_size = predicted_min_size;
        
        if (alloc.natural_size < predicted_natural_size)
            alloc.natural_size = predicted_natural_size;
    },

    // Handles option changes in the UI, saves the configuration
    // Set _validateTimer_ to true in case internal timer states and related options are changed
    _onConfigUpdate: function(validateTimer) {
        if (validateTimer)
            this._updateTimer();

        this._saveConfig();
    },
    
    _onDestroy: function() {
        this._stopTimer();
    },
    
    // Skip break or reset current pomodoro
    _startNewPomodoro: function() {
        if (this._isPause)
            this._pauseCount += 0;
        this._timeSpent = 0;
        this._setPauseState(false);
        this._stopTimer();
        this._startTimer();
        
        this._closeNotification();
        this._playNotificationSound();
    },
    
    // Reset all counters and timers
    _resetCount: function() {
        this._timeSpent = 0;
        this._setPauseState(false);
        this._sessionCount = 0;
        this._pauseCount = 0;

        if (this._isRunning) {
            this._stopTimer();
            this._startTimer();
        }else{
            this._updateTimer();
            this._updateSessionCount();
        }
        return false;
    },

    _closeNotification: function() {
        if (this._notification) {
            this._notification.destroy(MessageTray.NotificationDestroyedReason.SOURCE_CLOSED);
            this._notification = null;        
        }
        if (this._dialog) {
            this._dialog.close();
            this._dialog = null;
        }
    },

    // Notify user of changes
    _notifyPomodoroStart: function() {
        this._closeNotification();

        //if (!this._awayFromDesk)
        //    this._deactivateScreenSaver();

        if (true) {
            let source = new NotificationSource();
            this._notification = new MessageTray.Notification(source, _("Pause finished, a new pomodoro is starting!"), null);
            this._notification.setTransient(true);
            
            source.notify(this._notification);
        }        

        this._playNotificationSound();
    },
    
    // Notify user of changes
    _notifyPomodoroEnd: function(hideDialog) {
        let screenSaverActive = this._screenSaver &&
                                this._screenSaver.screenSaverActive;

        this._closeNotification();

        if (this._awayFromDesk && !hideDialog) {
            // Deactivate screensaver before message dialog is created to immediately
            // try open message dialog without waiting for _onScreenSaverActiveChanged()
            this._deactivateScreenSaver();
            this._playNotificationSound();
        }

        if (this._showDialogMessages && !hideDialog) {
            this._dialog = new MessageDialog();
            this._dialog.setTitle(_("Pomodoro Finished!"));
            this._dialog.setButtons([
                    { label: _("Hide"),
                      action: Lang.bind(this, function() {
                            this._notifyPomodoroEnd(true);
                      }),
                      key: Clutter.Escape
                    },
                    { label: _("Start a new Pomodoro"),
                      action: Lang.bind(this, this._startNewPomodoro),
                    }
                ]);

            // Try open message dialog
            if (!this._dialog.open()) {
                if (screenSaverActive) {
                    this._dialog.tryOpen({ onFailure: function() {
                        this._notifyPomodoroEnd(true);
                    }});
                }
                else {
                    // Fallback to a regular notification
                    hideDialog = true;
                }
            }
        }
                
        if (!this._showDialogMessages || hideDialog) {
            let source = new NotificationSource();
            this._notification = new MessageTray.Notification(source, '', '', null);
            this._updateNotification();

            this._notification.setResident(true);
            this._notification.addButton(1, _("Start a new Pomodoro"));
            this._notification.connect('action-invoked', Lang.bind(this, function(param) {
                    this._startNewPomodoro();
                }));
            source.notify(this._notification);
        }
    },

    // Plays a notification sound
    _playNotificationSound: function() {
        if (this._playSound) {
            let extension = ExtensionSystem.extensionMeta['pomodoro@arun.codito.in'];
            let uri = GLib.filename_to_uri(extension.path + '/bell.wav', null);
            
            try {
                // Create a local instance of playbin as sounds may overlap
                let playbin = Gst.ElementFactory.make('playbin2', null);
                playbin.set_property('uri', uri);
                playbin.set_state(Gst.State.PLAYING);
            }
            catch (e) {
                global.logError('Pomodoro: Error playing a sound "'+ uri +'": ' + e.message);
            }
        }
    },

    _deactivateScreenSaver: function() {
        if (this._screenSaver && this._screenSaver.screenSaverActive)
            this._screenSaver.SetActive(false);

        try{
            // Wake up the screen
            Util.trySpawnCommandLine('xdg-screensaver reset');
        }catch (err){
            global.logError('Pomodoro: Error waking up screen: ' + err.message);
        }
    },
    
    // Toggle timer state
    _toggleTimerState: function(item) {
        this._timeSpent = 0;
        this._setPauseState(false);
        
        if (item.state)
            this._startTimer();
        else
            this._stopTimer();        
    },
    
    _startTimer: function() {
        if (this._timerSource == 0)
            this._timerSource = Mainloop.timeout_add_seconds(1, Lang.bind(this, this._refreshTimer));

        if (!this._screenSaver) {
            this._screenSaver = new ScreenSaver.ScreenSaverProxy();
            this._screenSaver.connect('ActiveChanged', Lang.bind(this, this._onScreenSaverActiveChanged));
        }

        if (!this._playbin) {
            // Warm up GStreamer to reduce first-use lag (Can this be done in a cleaner way?)
            this._playbin = Gst.ElementFactory.make('playbin2', null);
        }

        this._isRunning = true;
        this._updateTimer();
        this._updateSessionCount();
    },

    _stopTimer: function() {
        if (this._timerSource != 0) {
            GLib.source_remove(this._timerSource);
            this._timerSource = 0;
        }
        this._isRunning = false;
        this._setIdle(false);
        this._updateTimer();
        this._updateSessionCount();            
        this._closeNotification();            
        
        this._screenSaver = null;
        this._playbin = null;
    },

    _suspendTimer: function() {
        if (this._timerSource != 0) {
            // Stop timer
            GLib.source_remove(this._timerSource);
            this._timerSource = 0;

            this._setIdle(true);
        }
    },

    _setIdle: function(active) {
        this._isIdle = active;
        if (active) {
            // We use meta_display_get_last_user_time() which determines any user interaction 
            // with X11/Mutter windows but not with GNOME Shell UI, for that we handle 'captured-event'.
            if (this._eventCaptureId == 0)
                this._eventCaptureId = global.stage.connect('captured-event', Lang.bind(this, this._onEventCapture));
            
            if (this._eventCaptureSource == 0) {
                this._pointer = null;
                this._eventCaptureSource = Mainloop.timeout_add_seconds(1, Lang.bind(this, this._onX11EventCapture));
            }
        }
        else{
            global.stage.disconnect(this._eventCaptureId);
            this._eventCaptureId = 0;

            GLib.source_remove(this._eventCaptureSource);
            this._eventCaptureSource = 0;
            
            if (this._isRunning)
                this._startTimer();
        }
    },

    _setPauseState: function(active) {
        this._isPause = active;

        if (active && this._isRunning)
            Tweener.addTween(this.label,
                             { opacity: TIMER_LABEL_OPACITY_WHEN_PAUSE,
                               transition: 'easeOutQuad',
                               time: TIMER_LABEL_FADE_TIME });            
        else
            Tweener.addTween(this.label,
                             { opacity: 255,
                               transition: 'easeOutQuad',
                               time: TIMER_LABEL_FADE_TIME });        
    },

    _onEventCapture: function(actor, event) {
        // When notification dialog fades out, can trigger an event.
        // To avoid that we need to capture just these event types:
        switch(event.type()) {
            case Clutter.EventType.KEY_PRESS:
            case Clutter.EventType.BUTTON_PRESS:
            case Clutter.EventType.MOTION:
            case Clutter.EventType.SCROLL:
                this._setIdle(false);
                break;
        }
        return false;
    },

    _onX11EventCapture: function() {
        let display = global.screen.get_display();
        let pointer = global.get_pointer();
        let idleTime = parseInt((display.get_current_time_roundtrip() - display.get_last_user_time()) / 1000);
        
        if (idleTime < 1 || (this._pointer && (pointer[0] != this._pointer[0] || pointer[1] != this._pointer[1]))) {
            this._setIdle(false);
            
            // Treat last non-idle second as if timer was running.
            this._refreshTimer();
            return false;
        }
        
        this._pointer = pointer;
        return true;
    },
    
    _onScreenSaverActiveChanged: function(object, active) {        
        if (!this._isRunning)
            return;
        
        if (active) {
            // this._setIdle(true);
        }
        else{
            if (this._isPause && this._showDialogMessages && this._dialog)
                this._dialog.tryOpen({ onFailure: function() {
                    this._notifyPomodoroEnd(true);
                }});
        }
    },
    
    // Increment timeSpent and call functions to check timer states and update ui_timer    
    _refreshTimer: function() {
        if (this._isRunning) {
            this._timeSpent += 1;
            this._checkTimerState();
            this._updateTimer();
            return true;
        }
        return false;
    },


    // Checks if timer needs to change state
    _checkTimerState: function() {
        if (this._isRunning) {
            // Check if a pause is running..
            if (this._isPause) {
                // Check if the pause is over
                if (this._timeSpent >= this._pauseTime) {
                    this._timeSpent = 0;
                    this._setPauseState(false);
                    this._updateSessionCount();
                    this._notifyPomodoroStart();
                    
                    if (!this._awayFromDesk)
                        this._suspendTimer();
                }
                else{
                    if (this._pauseCount == 0)
                        this._pauseTime = this._longPauseTime;
                    else
                        this._pauseTime = this._shortPauseTime;
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
                }

                this._timeSpent = 0;
                this._sessionCount += 1;
                this._setPauseState(true);
                this._updateSessionCount();
                this._notifyPomodoroEnd();
            }
        }
    },

    _updateSessionCount: function() {
        let text;
        if (this._sessionCount == 0)
            text = _("No Completed Sessions");
        else
            text = ngettext("%d Completed Session", "%d Completed Sessions", this._sessionCount).format(this._sessionCount);

        this._sessionCountLabel.set_text(text);
    },

    // Update timer_ui
    _updateTimer: function() {
        this._checkTimerState();

        if (this._isRunning) {
            let secondsLeft = Math.max((this._isPause ? this._pauseTime : this._pomodoroTime) - this._timeSpent, 0);
            if (this._isPause)
                secondsLeft = Math.ceil(secondsLeft / 5) * 5;
                        
            let minutes = parseInt(secondsLeft / 60);
            let seconds = parseInt(secondsLeft % 60);
            
            this.label.set_text('%02d:%02d'.format(minutes, seconds));
            this._updateNotification();
        }
        else{
            this.label.set_text('00:00');
        }
    },

    _updateNotification: function() {
        if (this._isPause)
        {
            let seconds = Math.max((this._isPause ? this._pauseTime : this._pomodoroTime) - this._timeSpent, 0);
            if (this._isPause)
                seconds = Math.ceil(seconds / 5) * 5;

            let minutes = Math.round(seconds / 60);
            let timestring;

            if (seconds <= 45)
                timestring = ngettext("Take a break, you have %d second\n", "Take a break, you have %d seconds\n", seconds).format(seconds);
            else
                timestring = ngettext("Take a break, you have %d minute\n", "Take a break, you have %d minutes\n", minutes).format(minutes);

            if (this._dialog)
                this._dialog.setText(timestring);
                
            if (this._notification)
                this._notification.update(_("Pomodoro Finished!"), timestring);
        }
    },
    
    _formatTime: function(seconds) {
        let minutes = Math.floor(seconds/60);
        return ngettext("%d minute", "%d minutes", minutes).format(minutes);
    },

    _keyHandler: function(keystring, data) {
        if (keystring == this._keyToggleTimer) {
            this._toggleTimerState(null);
            this._timerToggle.setToggleState(this._isRunning);
        }
    },
    
    _parseConfig: function() {
        // Set the default values
        for (let i = 0; i < _configOptions.length; i++)
            this[_configOptions[i][0]] = _configOptions[i][3];

        // Search for configuration files first in system config dirs and after in the user dir
        let _configDirs = [GLib.get_system_config_dirs(), GLib.get_user_config_dir()];
        for(var i = 0; i < _configDirs.length; i++) {
            let _configFile = _configDirs[i] + '/gnome-shell-pomodoro/gnome_shell_pomodoro.json';

            if (GLib.file_test(_configFile, GLib.FileTest.EXISTS)) {
                let filedata = null;

                try {
                    filedata = GLib.file_get_contents(_configFile, null, 0);
                    global.log('Pomodoro: Using config file = ' + _configFile);

                    let jsondata = JSON.parse(filedata[1]);
                    let parserVersion = null;
                    if (jsondata.hasOwnProperty('version'))
                        parserVersion = jsondata.version;
                    else
                        throw 'Parser version not defined';

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
                    global.logError('Pomodoro: Error reading config file ' + _configFile + ', error = ' + e);
                }
                finally {
                    filedata = null;
                }
            }
        }
    },

    _saveConfig: function() {
        let _configDir = GLib.get_user_config_dir() + '/gnome-shell-pomodoro';
        let _configFile = _configDir + '/gnome_shell_pomodoro.json';
        let filedata = null;
        let jsondata = {};

        if (GLib.file_test(_configDir, GLib.FileTest.EXISTS | GLib.FileTest.IS_DIR) == false &&
                GLib.mkdir_with_parents(_configDir, 0x2141) != 0) { // 0755 base 8 = 0x2141 base 6
                    global.logError('Pomodoro: Failed to create configuration directory. Path = ' +
                            _configDir + '. Configuration will not be saved.');
                }

        try {
            jsondata['version'] = _configVersion;
            for (let i = 0; i < _configOptions.length; i++) {
                let option = _configOptions[i];
                // Insert the option "category", if it's undefined
                if (jsondata.hasOwnProperty(option[1]) == false) {
                    jsondata[option[1]] = {};
                }

                // Update the option key/value pairs
                jsondata[option[1]][option[2]] = this[option[0]];
            }
            filedata = JSON.stringify(jsondata, null, '  ');
            GLib.file_set_contents(_configFile, filedata, filedata.length);
        }
        catch (e) {
            global.logError('Pomodoro: Error writing config file = ' + e);
        }
        finally {
            jsondata = null;
            filedata = null;
        }
        global.log('Pomodoro: Updated config file = ' + _configFile);
    }
};


let _indicator;

// Extension initialization code
function init(metadata) {
    //imports.gettext.bindtextdomain('gnome-shell-pomodoro', metadata.localedir);
    
    // search for icons inside extension directory
    Gtk.IconTheme.get_default().append_search_path (metadata.path);
}

function enable() {
    if (!_indicator) {
        _indicator = new Indicator;
        Main.panel.addToStatusArea('pomodoro', _indicator);
    }
}

function disable() {
    if (_indicator) {
        _indicator.destroy();
        _indicator = null;
    }
}
