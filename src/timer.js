/*
 * Copyright (c) 2011-2013 gnome-shell-pomodoro contributors
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

const Lang = imports.lang;
const Mainloop = imports.mainloop;
const Signals = imports.signals;

const Gio = imports.gi.Gio;
const GLib = imports.gi.GLib;
const UPowerGlib = imports.gi.UPowerGlib;


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

const State = {
    NULL: 'null',
    POMODORO: 'pomodoro',
    PAUSE: 'pause',
    IDLE: 'idle'
};


const Timer = new Lang.Class({
    Name: 'PomodoroTimer',

    _init: function() {
        this._elapsed = 0;
        this._elapsed_limit = 0;
        this._session_count = 0;
        this._state = State.NULL;
        this._state_timestamp = 0;
        this._timeout_source = 0;

        this._power = new UPowerGlib.Client();
        this._power.connect('notify-resume', Lang.bind(this, this.restore));

        this._settings = new Gio.Settings({ schema: 'org.gnome.pomodoro.preferences.timer' });
        this._settings.connect('changed', Lang.bind(this, this._onSettingsChanged));

        this._state_settings = new Gio.Settings({ schema: 'org.gnome.pomodoro.state' });

        this._state_notified = this._state;

        this.connect('state-changed', Lang.bind(this, function() {
            switch (this._state) {
                case State.IDLE:
                case State.POMODORO:
                    if (this._state_notified == State.PAUSE)
                        this.emit('notify-pomodoro-start');
                    break;
            }

            this._state_notified = this._state;
        }));

        this.connect('pomodoro-end', Lang.bind(this, function(timer, completed) {
            if (this._state == State.PAUSE)
                this.emit('notify-pomodoro-end', completed);
        }));
    },

    _onSettingsChanged: function (settings, key) {
        let elapsed = this._elapsed;
        let elapsed_limit = this._elapsed_limit;

        switch(key) {
            case 'pomodoro-time':
                if (this._state == State.POMODORO)
                    this._elapsed_limit = settings.get_uint('pomodoro-time');

                this._elapsed = Math.min(this._elapsed, this._elapsed_limit);
                break;

            case 'short-pause-time':
                if (this._state == State.PAUSE && this._session_count < 4)
                    this._elapsed_limit = settings.get_uint('short-pause-time');

                this._elapsed = Math.min(this._elapsed, this._elapsed_limit);
                break;

            case 'long-pause-time':
                if (this._state == State.PAUSE && this._session_count >= 4)
                    this._elapsed_limit = settings.get_uint('long-pause-time');

                this._elapsed = Math.min(this._elapsed, this._elapsed_limit);
                break;
        }

        if (this._elapsed != elapsed || this._elapsed_limit != elapsed_limit)
            this.emit('elapsed-changed');
    },

    start: function() {
        if (this._state == State.NULL || this._state == State.IDLE)
            this.set_state(State.POMODORO);
    },

    stop: function() {
        this.set_state(State.NULL);
    },

    reset: function() {
        let is_running = (this._state != State.NULL);

        this._session_count = 0;
        this.set_state(State.NULL);

        if (is_running)
            this.set_state(State.POMODORO);
    },

    get state() {
        return this._state;
    },

    set_state: function(new_state) {
        let state = this._state;
        let elapsed = this._elapsed;
        let elapsed_limit = this._elapsed_limit;
        let session_count = this._session_count;

        this._do_set_state(new_state);

        this._state_settings.set_double('timer-session-count', this._session_count);
        this._state_settings.set_string('timer-state', this._state);
        this._state_settings.set_string('timer-state-changed-date', new Date(this._state_timestamp).toString());

        if (this._state != state) {
            let completed = this._session_count != session_count;

            this.emit('state-changed');

            if (this._state == State.POMODORO)
                this.emit('pomodoro-start');

            if (state == State.POMODORO)
                this.emit('pomodoro-end', completed);
        }

        if (this._elapsed != elapsed || this._elapsed_limit != elapsed_limit)
            this.emit('elapsed-changed');
    },

    _do_set_state: function(new_state, timestamp) {
        if (!timestamp)
            timestamp = new Date().getTime();

        if (this._timeout_source == 0 && new_state != State.NULL)
            this._timeout_source = Mainloop.timeout_add_seconds(1, Lang.bind(this, this._on_timeout));

        if (this._state == new_state)
            return;

        if (this._state == State.POMODORO) {
            if (this._elapsed >= POMODORO_ACCEPTANCE * this._settings.get_uint('pomodoro-time')) {
                this._session_count += 1;
            }
            else {
                // Pomodoro not completed, sorry
            }
        }

        switch (new_state) {
            case State.IDLE:
                break;

            case State.POMODORO:
                let long_pause_acceptance_time = (1.0 - SHORT_LONG_PAUSE_ACCEPTANCE) * this._settings.get_uint('short-pause-time')
                                                     + (SHORT_LONG_PAUSE_ACCEPTANCE) * this._settings.get_uint('long-pause-time');

                if (this._state == State.PAUSE || this._state == State.IDLE) {
                    // If skipped a break make long break sooner
                    if (this._elapsed < SHORT_PAUSE_ACCEPTANCE * this._settings.get_uint('short-pause-time'))
                        this._session_count += 1;

                    // Reset work cycle when finished long break or was too lazy on a short one,
                    // and if skipped a long break try again next time.
                    if (this._elapsed >= long_pause_acceptance_time)
                        this._session_count = 0;
                }
                if (this._state == State.NULL) {
                    // Reset work cycle when disabled for some time
                    let idle_time = (timestamp - this._state_timestamp) / 1000;

                    if (this._state_timestamp > 0 && idle_time >= long_pause_acceptance_time)
                        this._session_count = 0;
                }

                this._elapsed = 0;
                this._elapsed_limit = this._settings.get_uint('pomodoro-time');
                break;

            case State.PAUSE:
                // Wrap time to pause
                if (this._state == State.POMODORO && this._elapsed > this._elapsed_limit)
                    this._elapsed = this._elapsed - this._elapsed_limit;
                else
                    this._elapsed = 0;

                // Determine which pause type user should have
                if (this._session_count >= 4)
                    this._elapsed_limit = this._settings.get_uint('long-pause-time');
                else
                    this._elapsed_limit = this._settings.get_uint('short-pause-time');

                break;

            case State.NULL:
                if (this._timeout_source != 0) {
                    GLib.source_remove(this._timeout_source);
                    this._timeout_source = 0;
                }

                this._elapsed = 0;
                this._elapsed_limit = 0;
                break;
        }

        this._state_timestamp = timestamp;
        this._state = new_state;
    },

    restore: function() {
        let session_count = this._state_settings.get_double('timer-session-count');
        let state = this._state_settings.get_string('timer-state');
        let state_timestamp = Date.parse(this._state_settings.get_string('timer-state-changed-date'));

        if (isNaN(state_timestamp)) {
            log('Pomodoro: Failed to restore timer state, date string is funny.');
            return;
        }

        this._session_count = session_count;
        this._state_timestamp = state_timestamp;

        this._do_set_state(state, state_timestamp);

        if (this._state != State.NULL) {
            this._elapsed = parseInt((new Date().getTime() - this._state_timestamp) / 1000);

            // Skip through states silently to avoid unnecessary notifications
            // and signal emits stacking up
            while (this._elapsed >= this._elapsed_limit) {
                if (this._state == State.POMODORO)
                    this._do_set_state(State.PAUSE);
                else
                    if (this._state == State.PAUSE)
                        this._do_set_state(State.IDLE);
                    else
                        break;
            }
        }

        this._state_settings.set_double('timer-session-count', this._session_count);
        this._state_settings.set_string('timer-state', this._state);
        this._state_settings.set_string('timer-state-changed-date', new Date(this._state_timestamp).toString());

        this.emit('state-changed');
        this.emit('elapsed-changed');

        if (this._state != State.NULL) {
            let completed = this._session_count != session_count;

            if (this._state == State.POMODORO)
                this.emit('pomodoro-start');

            if (this._state == State.PAUSE)
                this.emit('pomodoro-end', completed);
        }
    },

    get elapsed() {
        return this._elapsed;
    },

    set_elapsed: function(value) {
        if (this._elapsed == value)
            return;

        let state = this._state;

        this._elapsed = value;

        switch (this._state) {
            case State.IDLE:
                break;

            case State.PAUSE:
                // Pause is over
                if (this._elapsed >= this._elapsed_limit)
                    // TODO: Enable IDLE state
                    this.set_state(State.POMODORO);

                break;

            case State.POMODORO:
                // Pomodoro is over, a pause is needed :)
                if (this._elapsed >= this._elapsed_limit)
                    this.set_state(State.PAUSE);

                break;
        }

        if (state == this._state)
            this.emit('elapsed-changed');
    },

    get elapsed_limit() {
        return this._elapsed_limit;
    },

    get remaining() {
        return this._elapsed_limit - this._elapsed;
    },

    get session_count() {
        return this._session_count;
    },

    _on_timeout: function() {
        if (this._state != State.NULL)
            this.set_elapsed(this._elapsed + 1);

        return true;
    },

    destroy: function() {
        this.disconnectAll();

        if (this._timeout_source != 0) {
            GLib.source_remove(this._timeout_source);
            this._timeout_source = 0;
        }
    }
});

Signals.addSignalMethods(Timer.prototype);
