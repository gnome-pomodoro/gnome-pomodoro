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

const Lang = imports.lang;
const Mainloop = imports.mainloop;
const Signals = imports.signals;

const Clutter = imports.gi.Clutter;
const Gio = imports.gi.Gio;
const GLib = imports.gi.GLib;
const Meta = imports.gi.Meta;
const St = imports.gi.St;
const UPowerGlib = imports.gi.UPowerGlib;

const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const GnomeSession = imports.misc.gnomeSession;
const ScreenSaver = imports.misc.screenSaver;
const Util = imports.misc.util;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const PomodoroUtil = Extension.imports.util;
const Notification = Extension.imports.notification;

const Gettext = imports.gettext.domain('gnome-shell-pomodoro');
const _ = Gettext.gettext;
const ngettext = Gettext.ngettext;

try {
    const Gst = imports.gi.Gst;
    Gst.init(null);
} catch(e) {
    global.logError('Pomodoro: '+ e.message);
}


// Pomodoro acceptance factor is useful in cases of disabling the timer,
// accepted pomodoros increases session count and narrows time to long pause.
const POMODORO_ACCEPTANCE = 20.0 / 25.0;
// Short pause acceptance is used to catch quick "Start a new pomodoro" clicks,
// declining short pause narrows time to long pause.
const SHORT_PAUSE_ACCEPTANCE = 1.0 / 5.0;
// Long pause acceptance is used to determine if user made or finished a long 
// pause. If long pause hasn't finished, it's repeated next time. If user made 
// a long pause during short one, it's treated as long one. Acceptance value here 
// is a factor between short pause time and long pause time.
const SHORT_LONG_PAUSE_ACCEPTANCE = 0.5;

// Path to sound file in case GSettings value is empty
const DEFAULT_SOUND_FILE = 'bell.wav';

// Command to wake up or power on the screen
const SCREENSAVER_DEACTIVATE_COMMAND = 'xdg-screensaver reset';


const State = {
    NULL: 0,
    POMODORO: 1,
    PAUSE: 2,
    IDLE: 3
};


const PomodoroTimer = new Lang.Class({
    Name: 'PomodoroTimer',

    _init: function() {
        this._elapsed = 0;
        this._elapsedLimit = 0;
        this._sessionPartCount = 0;
        this._sessionCount = 0;
        this._state = State.NULL;
        this._stateTimestamp = 0;
        
        this._timeoutSource = 0;
        this._eventCaptureId = 0;
        this._eventCaptureSource = 0;
        this._eventCapturePointer = null;
        
        this._notification = null;
        this._notificationDialog = null;
        this._playbin = null;
        this._power = null;
        this._presence = null;
        this._presenceChangeEnabled = false;
        this._screenSaver = null;
        
        this._settings = PomodoroUtil.getSettings();
        this._settings.connect('changed', Lang.bind(this, this._onSettingsChanged));
    },

    _onSettingsChanged: function (settings, key) {
        switch(key) {
            case 'pomodoro-time':
                if (this._state == State.POMODORO)
                    this._elapsedLimit = settings.get_int('pomodoro-time');
                    this._elapsed = Math.min(this._elapsed, this._elapsedLimit);
                break;
            case 'short-pause-time':
                if (this._state == State.PAUSE && this._sessionPartCount < 4)
                    this._elapsedLimit = settings.get_int('short-pause-time');
                    this._elapsed = Math.min(this._elapsed, this._elapsedLimit);
                break;
            case 'long-pause-time':
                if (this._state == State.PAUSE && this._sessionPartCount >= 4)
                    this._elapsedLimit = settings.get_int('long-pause-time');
                    this._elapsed = Math.min(this._elapsed, this._elapsedLimit);
                break;
            case 'change-presence-status':
                this._updatePresenceStatus();
                break;
        }
        this.emit('elapsed-changed');
    },

    start: function() {
        if (this._state == State.NULL || this._state == State.IDLE) {
            this.setState(State.POMODORO);
        }
    },

    stop: function() {
        this.setState(State.NULL);
    },

    reset: function() {
        this._sessionCount = 0;
        this._sessionPartCount = 0;
        
        let isRunning = (this._state != State.NULL);
        this.setState(State.NULL);
        
        if (isRunning)
            this.setState(State.POMODORO);
    },

    startPomodoro: function() {
        this._closeNotification();
        if (this._state == State.PAUSE || this._state == State.IDLE)
            this._playNotificationSound();
        
        if (this._timeoutSource != 0) {
            GLib.source_remove(this._timeoutSource);
            this._timeoutSource = 0;
        }
        
        this.setState(State.POMODORO);
    },

    get state() {
        return this._state;
    },

    setState: function(newState) {
        this._setState(newState);
        
        this._updatePresenceStatus();
        
        this.emit('state-changed', this._state);
        this.emit('elapsed-changed', this._elapsed);
    },

    _setState: function(newState, timestamp) {        
        this._closeNotification();
        this._disableEventCapture();

        if (!timestamp)
            timestamp = new Date().getTime()
        
        if (newState != State.NULL) {
            this._load();
            
            if (this._timeoutSource == 0) {
                this._timeoutSource = Mainloop.timeout_add_seconds(1, Lang.bind(this, this._onTimeout));
            }
        }
        
        if (this._state == newState) {
            return;
        }
        
        if (this._state == State.POMODORO) {
            if (this._elapsed >= POMODORO_ACCEPTANCE * this._settings.get_int('pomodoro-time')) {
                this._sessionCount += 1;
                this._sessionPartCount += 1;
            }
            else {
                // Pomodoro not completed, sorry
            }
        }
        
        switch (newState) {
            case State.IDLE:
                this._enableEventCapture();
                break;
            
            case State.POMODORO:
                let longPauseAcceptanceTime = (1.0 - SHORT_LONG_PAUSE_ACCEPTANCE) * this._settings.get_int('short-pause-time')
                                                  + (SHORT_LONG_PAUSE_ACCEPTANCE) * this._settings.get_int('long-pause-time');
                
                if (this._state == State.PAUSE || this._state == State.IDLE) {
                    // If skipped a break make long break sooner
                    if (this._elapsed < SHORT_PAUSE_ACCEPTANCE * this._settings.get_int('short-pause-time'))
                        this._sessionPartCount += 1;
                    
                    // Reset work cycle when finished long break or was too lazy on a short one,
                    // and if skipped a long break try again next time.
                    if (this._elapsed >= longPauseAcceptanceTime)
                        this._sessionPartCount = 0;
                }
                if (this._state == State.NULL) {
                    // Reset work cycle when disabled for some time
                    let idleTime = (timestamp - this._stateTimestamp) / 1000;
                    
                    if (this._stateTimestamp > 0 && idleTime >= longPauseAcceptanceTime)
                        this._sessionPartCount = 0;
                }
                
                this._elapsed = 0;
                this._elapsedLimit = this._settings.get_int('pomodoro-time');
                break;
            
            case State.PAUSE:
                // Wrap time to pause
                if (this._state == State.POMODORO && this._elapsed > this._elapsedLimit)
                    this._elapsed = this._elapsed - this._elapsedLimit;
                else
                    this._elapsed = 0;
                
                // Determine which pause type user should have
                if (this._sessionPartCount >= 4)
                    this._elapsedLimit = this._settings.get_int('long-pause-time');
                else
                    this._elapsedLimit = this._settings.get_int('short-pause-time');
                
                break;
            
            case State.NULL:
                if (this._timeoutSource != 0) {
                    GLib.source_remove(this._timeoutSource);
                    this._timeoutSource = 0;
                }
                
                this._elapsed = 0;
                this._elapsedLimit = 0;
                this._unload();
                break;
        }
        
        this._stateTimestamp = timestamp;
        this._state = newState;
        
        this._settings.set_int('saved-session-count', this._sessionCount);
        this._settings.set_int('saved-session-part-count', this._sessionPartCount);
        this._settings.set_enum('saved-state', this._state);
        this._settings.set_string('saved-state-date', new Date(timestamp).toString());
    },

    restore: function() {
        let sessionCount     = this._settings.get_int('saved-session-count');
        let sessionPartCount = this._settings.get_int('saved-session-part-count');
        let state            = this._settings.get_enum('saved-state');
        let stateTimestamp   = Date.parse(this._settings.get_string('saved-state-date'));
        
        if (isNaN(stateTimestamp)) {
            global.logError('Pomodoro: Failed to restore timer state, date string is funny.');
            return;
        }
        
        this._sessionCount = sessionCount;
        this._sessionPartCount = sessionPartCount;        
        this._stateTimestamp = stateTimestamp;
        
        this._setState(state, stateTimestamp);
        
        if (this._state != State.NULL) {
            this._elapsed = parseInt((new Date().getTime() - this._stateTimestamp) / 1000);
            
            // Skip through states silently to avoid unnecessary notifications
            // and signal emits stacking up
            while (this._elapsed >= this._elapsedLimit) {
                if (this._state == State.POMODORO)
                    this._setState(State.PAUSE);
                else
                    if (this._state == State.PAUSE)
                        this._setState(State.IDLE);
                    else
                        break;
            }
            
            if (!this._notification || !this._notificationDialog) {
                if (this._state == State.PAUSE)
                    this._notifyPomodoroEnd();
                
                // TODO: Notify about pomodoro start once the lock screen is off
                // if (this._state == State.IDLE)
                //    this._notifyPomodoroStart();
            }            
        }
        
        this._updatePresenceStatus();
        
        this.emit('state-changed', this._state);
        this.emit('elapsed-changed', this._elapsed);
    },

    get elapsed() {
        return this._elapsed;
    },

    setElapsed: function(value) {
        if (this._elapsed == value)
            return;
        
        this._elapsed = value;
        this.emit('elapsed-changed', value);
    },

    get remaining() {
        return this._elapsedLimit - this._elapsed;
    },

    get sessionCount() {
        return this._sessionCount;
    },

    _onTimeout: function() {
        if (this._state == State.NULL)
            return true;
        
        this.setElapsed(this._elapsed + 1);
        
        switch (this._state) {
            case State.IDLE:
                break;
            
            case State.PAUSE:
                // Pause is over
                if (this._elapsed >= this._elapsedLimit) {
                    this.setState(this._settings.get_boolean('away-from-desk') ? State.POMODORO : State.IDLE);
                    this._notifyPomodoroStart();
                }
                this._updateNotification();
                break;
            
            case State.POMODORO:
                // Pomodoro over and a pause is needed :)
                if (this._elapsed >= this._elapsedLimit) {
                    this.setState(State.PAUSE);
                    this._notifyPomodoroEnd();
                }
                break;
        }
        
        return true;
    },

    _onEventCapture: function(actor, event) {
        // When notification dialog fades out, can trigger an event.
        // To avoid that we need to capture just these event types:
        switch(event.type()) {
            case Clutter.EventType.KEY_PRESS:
            case Clutter.EventType.BUTTON_PRESS:
            case Clutter.EventType.MOTION:
            case Clutter.EventType.SCROLL:
                this.setState(State.POMODORO);
                break;
        }
        return false;
    },

    _onX11EventCapture: function() {
        let display = global.screen.get_display();
        let pointer = global.get_pointer();
        let idleTime = parseInt((display.get_current_time_roundtrip() - display.get_last_user_time()) / 1000);
        
        if (idleTime < 1 || (this._eventCapturePointer && (
            pointer[0] != this._eventCapturePointer[0] || pointer[1] != this._eventCapturePointer[1]))) {
            this.setState(State.POMODORO);
            
            // Treat last non-idle second as if timer was running.
            this._onTimeout();
            return false;
        }
        this._eventCapturePointer = pointer;
        return true;
    },

    _notifyPomodoroStart: function() {
        this._closeNotification();
        this._playNotificationSound();
        
        // if (!this._settings.get_boolean('away-from-desk'))
        //     this._deactivateScreenSaver();
        
        let source = new Notification.NotificationSource();
        this._notification = new MessageTray.Notification(source, _("Pause finished, a new pomodoro is starting!"), null);
        this._notification.setTransient(true);
        this._notification.connect('collapsed', Lang.bind(this, function() {
                this._notification.destroy(MessageTray.NotificationDestroyedReason.SOURCE_CLOSED);
            }));
        this._notification.connect('destroy', Lang.bind(this, function() {
                this._notification = null;
            }));
        source.notify(this._notification);
        
        this.emit('notify-pomodoro-start');
    },

    _notifyPomodoroEnd: function() {
        this._closeNotification();
        
        if (this._settings.get_boolean('away-from-desk') && this._elapsed == 0) {
            this._deactivateScreenSaver();
            this._playNotificationSound();
        }
        
        this._notificationDialog = new Notification.NotificationDialog();
        this._notificationDialog.setTitle(_("Pomodoro Finished!")); 
        this._notificationDialog.setButtons([
                { label: _("Hide"),
                  action: Lang.bind(this, function() {
                        this._notificationDialog.close();
                    }),
                  key: Clutter.Escape
                },
                { label: _("Start a new pomodoro"),
                  action: Lang.bind(this, this.startPomodoro)
                }
            ]);
        this._notificationDialog.setNotificationButtons([
                { label: _("Show dialog"),
                  action: Lang.bind(this, function() {
                        this._notificationDialog.open();
                    })
                },
                { label: _("Start a new pomodoro"),
                  action: Lang.bind(this, this.startPomodoro)
                }
            ]);
        this._notificationDialog.connect('destroy', Lang.bind(this, function() {
                this._notificationDialog = null;
            }));
        
        this._updateNotification();
        
        if (this._settings.get_boolean('show-notification-dialogs'))
            this._notificationDialog.open();
        else
            this._notificationDialog.close();
        
        this.emit('notify-pomodoro-end');
    },

    _closeNotification: function() {
        if (this._notification && !this._notification.expanded) {
            this._notification.destroy(MessageTray.NotificationDestroyedReason.SOURCE_CLOSED);
            this._notification = null;
        }
        if (this._notificationDialog) {
            this._notificationDialog.destroy();
            this._notificationDialog = null;
        }
    },

    _playNotificationSound: function() {
        if (this._settings.get_boolean('play-sounds')) {
            let uri = this._settings.get_string('sound-uri');
            
            try {
                if (!uri) {
                    let path = GLib.path_is_absolute(DEFAULT_SOUND_FILE)
                                        ? DEFAULT_SOUND_FILE
                                        : GLib.build_filenamev([ PomodoroUtil.getExtensionPath(), DEFAULT_SOUND_FILE ]);
                    uri = GLib.filename_to_uri(path, null);
                }
                
                let playbin = Gst.ElementFactory.make('playbin2', null);
                playbin.uri = uri;
                playbin.set_state(Gst.State.PLAYING);
            }
            catch (e) {
                global.logError('Pomodoro: Error playing sound file "'+ uri +'": ' + e.message);
            }
        }
    },

    _updateNotification: function() {
        if (!this._notificationDialog || this._state != State.PAUSE)
            return;
        
        let seconds = Math.max(this._elapsedLimit - this._elapsed, 0);
        let minutes = Math.round(seconds / 60);
        
        seconds = Math.ceil(seconds / 5) * 5;
        
        try {
            this._notificationDialog.setDescription((seconds <= 45)
                                    ? ngettext("Take a break, you have %d second\n",
                                               "Take a break, you have %d seconds\n", seconds).format(seconds)
                                    : ngettext("Take a break, you have %d minute\n",
                                               "Take a break, you have %d minutes\n", minutes).format(minutes));
        }
        catch (e) {
            // Notification might be closed before we knew it
        }
    },

    _updatePresenceStatus: function() {
        let enabled = this._settings.get_boolean('change-presence-status');
        
        if (this._presence && (enabled || this._presenceChangeEnabled)) {
            let status;
            if (enabled)
                status = (this._state == State.POMODORO || this._state == State.IDLE)
                                    ? GnomeSession.PresenceStatus.BUSY
                                    : GnomeSession.PresenceStatus.AVAILABLE;
            else
                status = GnomeSession.PresenceStatus.AVAILABLE;
            
            this._presence.status = status;
        }
        
        this._presenceChangeEnabled = enabled;
    },

    _enableEventCapture: function() {
        // We use meta_display_get_last_user_time() which determines any user interaction 
        // with X11/Mutter windows but not with GNOME Shell UI, for that we handle 'captured-event'.
        if (this._eventCaptureId == 0) {
            this._eventCaptureId = global.stage.connect('captured-event', Lang.bind(this, this._onEventCapture));
        }
        if (this._eventCaptureSource == 0) {
            this._eventCapturePointer = global.get_pointer();
            this._eventCaptureSource = Mainloop.timeout_add_seconds(1, Lang.bind(this, this._onX11EventCapture));
        }
    },

    _disableEventCapture: function() {
        if (this._eventCaptureId != 0) {
            global.stage.disconnect(this._eventCaptureId);
            this._eventCaptureId = 0;
        }
        if (this._eventCaptureSource != 0) {
            GLib.source_remove(this._eventCaptureSource);
            this._eventCaptureSource = 0;
        }
    },

    _deactivateScreenSaver: function() {
        if (this._screenSaver && this._screenSaver.screenSaverActive)
            this._screenSaver.SetActive(false);
        
        try {
            Util.trySpawnCommandLine(SCREENSAVER_DEACTIVATE_COMMAND);
        }
        catch (e) {
            global.logError('Pomodoro: Error waking up the screen: ' + e.message);
        }
    },

    _load: function() {
        if (!this._screenSaver) {
            this._screenSaver = new ScreenSaver.ScreenSaverProxy();
        }
        if (!this._power) {
            this._power = new UPowerGlib.Client();
            this._power.connect('notify-resume', Lang.bind(this, this.restore));
        }
        if (!this._presence) {
            this._presence = new GnomeSession.Presence();
            this._presenceChangeEnabled = this._settings.get_boolean('change-presence-status');
        }
        if (!this._playbin && Gst) {
            // Load some GStreamer modules to memory to (hopefully) reduce first-use lag
            this._playbin = Gst.ElementFactory.make('playbin2', null);
            this._playbin.set_state(Gst.State.READY);
        }
    },

    _unload: function() {
        if (this._screenSaver) {
            this._screenSaver = null;
        }
        if (this._playbin && Gst) {
            this._playbin.set_state(Gst.State.NULL);
            this._playbin = null;
        }
    },

    destroy: function() {
        this.stop();
        this.disconnectAll();
    }
});

Signals.addSignalMethods(PomodoroTimer.prototype);
