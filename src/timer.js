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
const ScreenShield = imports.ui.screenShield;
const Util = imports.misc.util;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const PomodoroUtil = Extension.imports.util;
const Notification = Extension.imports.notification;

const Gettext = imports.gettext.domain('gnome-shell-pomodoro');
const _ = Gettext.gettext;
const ngettext = Gettext.ngettext;


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

// Default path to sound file
const DEFAULT_SOUND_FILE = 'bell.wav';

// Command to wake up or power on the screen
const SCREENSAVER_DEACTIVATE_COMMAND = 'xdg-screensaver reset';

// Remind about ongoing break in given delays
const PAUSE_REMIND_TIMES = [90];
// Ratio between user idle time and time between reminders to determine if user
// is finally away
const PAUSE_REMINDER_ACCEPTANCE = 0.8

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
        this._reminderSource = 0;
        this._reminderTime = 0;
        this._reminderCount = 0;
        
        this._notification = null;
        this._notificationDialog = null;
        this._playbin = null;
        this._power = null;
        this._presence = null;
        this._presenceChangeEnabled = false;
        this._idleMonitor = Meta.IdleMonitor.get_core();
        this._becameActiveId = 0;
        
        this._settings = PomodoroUtil.getSettings();
        this._settingsChangedId = this._settings.connect('changed', Lang.bind(this, this._onSettingsChanged));
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
        this._closeNotifications();
        this._disableEventCapture();

        if (!timestamp)
            timestamp = new Date().getTime()
        
        if (newState != State.NULL) {
            this._load();
            
            if (this._timeoutSource == 0) {
                this._timeoutSource = Mainloop.timeout_add_seconds(1, Lang.bind(this, this._onTimeout));
            }
            if (this._state == newState) {
                return;
            }
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
            global.log('Pomodoro: Failed to restore timer state, date string is funny.');
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

            if (this._state == State.PAUSE) {
                this._notifyPomodoroEnd();
                if (this._notificationDialog) {
                    this._notificationDialog.open();
                    this._notificationDialog.pushModal();
                }
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

    _notifyPomodoroStart: function() {
        this._closeNotifications();
        this._playNotificationSound();
        
        // if (!this._settings.get_boolean('away-from-desk'))
        //     this._deactivateScreenSaver();

        let notification = new MessageTray.Notification(Notification.get_default_source(),
                                                        _("Pause finished."),
                                                        _("A new pomodoro is starting."),
                                                        null);
        notification.setTransient(true);
        this._openNotification(notification);

        this.emit('notify-pomodoro-start');
    },

    _notifyPomodoroEnd: function() {
        this._closeNotifications();
        
        if (this._settings.get_boolean('away-from-desk') && this._elapsed == 0) {
            this._deactivateScreenSaver();
            this._playNotificationSound();
        }

        if (!this._notificationDialog) {
            this._notificationDialog = new Notification.NotificationDialog();
            this._notificationDialog.setTimer('00:00');
            this._notificationDialog.setDescription(_("It's time to take a break"));

            this._notificationDialog.connect('opening', Lang.bind(this, function() {
                    this._unscheduleReminder();
                }));
            this._notificationDialog.connect('closing', Lang.bind(this, function() {
                    if (this._notification)
                        this._openNotification(this._notification);
                }));
            this._notificationDialog.connect('closed', Lang.bind(this, function() {
                    this._unscheduleReminder(); // reset reminder count
                    this._scheduleReminder();
                }));
            this._notificationDialog.connect('destroy', Lang.bind(this, function() {
                    this._notificationDialog = null;
                }));
        }

        if (this._notification)
            this._notification.destroy(MessageTray.NotificationDestroyedReason.SOURCE_CLOSED);

        this._notification = new MessageTray.Notification(Notification.get_default_source(),
                                                          _("Take a break!"),
                                                          null);
        this._notification.setResident(true);

        this._notification.addButton('start-pomodoro', _("Start a new pomodoro"));

        this._notification._titleFitsInBannerMode = true;

        if (!this._notification._bodyLabel) {
            this._notification._bodyLabel = this._notification.addBody("", null, null);
        }

        this._notification.connect('action-invoked', Lang.bind(this, function(object, id) {
                Main.messageTray.close();

                if (id == 'start-pomodoro')
                    this.startPomodoro();
            }));
        this._notification.connect('clicked', Lang.bind(this, function() {
                if (this._notificationDialog) {
                    this._notificationDialog.open();
                    this._notificationDialog.pushModal();
                }
            }));
        this._notification.connect('destroy', Lang.bind(this, function(reason) {
                this._notification = null;
            }));

        this._updateNotification();

        if (this._settings.get_boolean('show-notification-dialogs'))
            this._notificationDialog.open();
        else
            this._openNotification(this._notification);

        this._notificationDialog.setOpenWhenIdle(true);

        this.emit('notify-pomodoro-end');
    },

    _openNotification: function(notification) {
        if (notification) {
            if (!Main.messageTray.contains(notification.source))
                Main.messageTray.add(notification.source);

            if (notification.source)
                notification.source.notify(notification);
        }
    },

    _closeNotifications: function() {
        if (this._notificationDialog) {
            this._notificationDialog.close();
            this._notificationDialog.setOpenWhenIdle(false);
        }
        if (this._notification) {
            let notification = this._notification;
            if (Main.messageTray._trayState == MessageTray.State.SHOWN)
                notification.emit('done-displaying-content', false);

            notification.destroy();
        }
        this._unscheduleReminder();
    },

    _remindPomodoroEnd: function() {
        if (this._state != State.PAUSE)
            return;
        
        // Don't show reminder if only two minutes remains to next pomodoro
        if (this._elapsedLimit - this._elapsed < 120)
            return;
        
        if (!this._notificationDialog || this._notificationDialog.state == Notification.State.CLOSED) {

            let notification = new MessageTray.Notification(Notification.get_default_source(),
                                                            _("Hey, you're missing out on a break."),
                                                            null);
            notification.setTransient(true);
            notification.connect('clicked', Lang.bind(this, function() {
                    if (this._notificationDialog) {
                        this._notificationDialog.open();
                        this._notificationDialog.pushModal();
                    }
                }));
            this._openNotification(notification);
        }
    },

    _onReminderTimeout: function() {
        let idleTime = this._idleMonitor.get_idletime();
        
        // No need to notify if user seems to be away. We only monitor idle time 
        // based on X11, and not Clutter scene which better reflects to real work
        if (idleTime < this._reminderTime * PAUSE_REMINDER_ACCEPTANCE)
            this._remindPomodoroEnd();
        else
            this._reminderCount = 0;
        
        this._reminderSource = 0;
        this._scheduleReminder();
        return false;
    },

    _onScreenShieldChanged: function() {
        if (!Main.screenShield.locked && this._state == State.PAUSE) {
            if (this._notificationDialog && this._settings.get_boolean('show-notification-dialogs')) {
                this._notificationDialog.open();
                this._notificationDialog.pushModal();
            }
        }
    },

    _scheduleReminder: function() {
        let times = PAUSE_REMIND_TIMES;
        let reschedule = false;
        
        if (this._state != State.PAUSE) {
            this._unscheduleReminder ();
            return;
        }
        
        if (this._reminderSource != 0) {
            GLib.source_remove(this._reminderSource);
            this._reminderSource = 0;
            reschedule = true;
        }
        
        if (this._reminderCount < times.length) {
            this._reminderTime = times[this._reminderCount];
            this._reminderSource = Mainloop.timeout_add_seconds(this._reminderTime,
                                                                Lang.bind(this, this._onReminderTimeout));
        }
        
        if (!reschedule)
            this._reminderCount += 1;
    },

    _unscheduleReminder: function() {
        if (this._reminderSource != 0) {
            GLib.source_remove(this._reminderSource);
            this._reminderSource = 0;
        }
        
        this._reminderTime = 0;
        this._reminderCount = 0;
    },

    _playNotificationSound: function() {
        if (this._settings.get_boolean('play-sounds')) {
            let uri = this._settings.get_string('sound-uri');
            let path = '';

            if (uri)
                path = GLib.filename_from_uri(uri);
            else
                path = GLib.path_is_absolute(DEFAULT_SOUND_FILE)
                                ? DEFAULT_SOUND_FILE
                                : GLib.build_filenamev([ PomodoroUtil.getExtensionPath(), DEFAULT_SOUND_FILE ]);

            let file = Gio.file_new_for_path(path);
            if (file.query_exists(null))
            {
                try {
                    Util.trySpawnCommandLine('canberra-gtk-play --file='+ GLib.shell_quote(path));
                }
                catch (e) {
                    global.log('Pomodoro: Error playing sound file "'+ path +'": ' + e.message);
                }
            }
            else {
                global.log('Pomodoro: Sound file "'+ path +'" does not exist');
            }
        }
    },

    _updateNotification: function() {
        if (this._state != State.PAUSE)
            return;

        let remaining = Math.max(this._elapsedLimit - this._elapsed, 0);

        if (this._notificationDialog) {
            let seconds = Math.floor(remaining % 60);
            let minutes = Math.floor(remaining / 60);

            this._notificationDialog.setTimer('%02d:%02d'.format(minutes, seconds));
        }
        if (this._notification) {
            let seconds = Math.floor(remaining % 60);
            let minutes = Math.round(remaining / 60);
            let message = (remaining <= 45)
                        ? ngettext("You have %d second left.",
                                   "You have %d seconds left.", seconds).format(seconds)
                        : ngettext("You have %d minute left.",
                                   "You have %d minutes left.", minutes).format(minutes);

            this._notification._bannerLabel.set_text(message);
            this._notification._bodyLabel.set_text(message);
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

    _onIdleMonitorBecameActive: function(monitor) {
        this.setState(State.POMODORO);
    },

    _enableEventCapture: function() {
        if (this._becameActiveId == 0)
            this._becameActiveId = this._idleMonitor.add_user_active_watch(Lang.bind(this, this._onIdleMonitorBecameActive));
    },

    _disableEventCapture: function() {
        if (this._becameActiveId != 0) {
            this._idleMonitor.remove_watch(this._becameActiveId);
            this._becameActiveId = 0;
        }
    },

    _deactivateScreenSaver: function() {
        if (Main.screenShield && Main.screenShield.locked)
            Main.screenShield.unlock();
        
        try {
            Util.trySpawnCommandLine(SCREENSAVER_DEACTIVATE_COMMAND);
        }
        catch (e) {
            global.log('Pomodoro: Error waking up the screen: ' + e.message);
        }
    },

    _load: function() {
        if (Main.screenShield) {
            Main.screenShield.connect('lock-status-changed', Lang.bind(this, this._onScreenShieldChanged));
        }
        if (!this._power) {
            this._power = new UPowerGlib.Client();
            this._power.connect('notify-resume', Lang.bind(this, this.restore));
        }
        if (!this._presence) {
            this._presence = new GnomeSession.Presence();
            this._presenceChangeEnabled = this._settings.get_boolean('change-presence-status');
        }
    },

    _unload: function() {
    },

    destroy: function() {
        this.disconnectAll();
        this._closeNotifications();
        this._disableEventCapture();

        if (this._settingsChangedId != 0) {
            this._settings.disconnect(this._settingsChangedId);
            this._settingsChangedId = 0;
        }

        if (this._timeoutSource != 0) {
            GLib.source_remove(this._timeoutSource);
            this._timeoutSource = 0;
        }

        if (this._notification) {
            this._notification.destroy();
            this._notification = null;
        }

        if (this._notificationDialog) {
            this._notificationDialog.destroy();
            this._notificationDialog = null;
        }

        this._unload();
    }
});

Signals.addSignalMethods(PomodoroTimer.prototype);
