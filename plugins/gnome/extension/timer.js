/*
 * Copyright (c) 2014-2016 gnome-pomodoro contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

const { Clutter, Gio, GObject, St, Pango } = imports.gi;

const Main = imports.ui.main;
const Params = imports.misc.params;
const Signals = imports.misc.signals;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Config = Extension.imports.config;
const DBus = Extension.imports.dbus;
const Utils = Extension.imports.utils;


var State = {
    NULL: 'null',
    POMODORO: 'pomodoro',
    SHORT_BREAK: 'short-break',
    LONG_BREAK: 'long-break',

    label(state) {
        switch (state) {
            case State.POMODORO:
                return _("Pomodoro");

            case State.SHORT_BREAK:
                return _("Short Break");

            case State.LONG_BREAK:
                return _("Long Break");

            default:
                return null;
        }
    }
};


var Timer = class extends Signals.EventEmitter {
    constructor() {
        super();

        this._connected = false;
        this._state = null;
        this._isPaused = null;
        this._stateDuration = 0;
        this._propertiesChangedId = 0;
        this._elapsed = 0.0;

        this._proxy = DBus.Pomodoro(this._onInit.bind(this));

        this._propertiesChangedId = this._proxy.connect(
                                       'g-properties-changed',
                                       this._onPropertiesChanged.bind(this));

        this._nameWatcherId = Gio.DBus.session.watch_name(
                                       'org.gnome.Pomodoro',
                                       Gio.BusNameWatcherFlags.AUTO_START,
                                       this._onNameAppeared.bind(this),
                                       this._onNameVanished.bind(this));
    }

    _onNameAppeared() {
        this._connected = true;

        this.emit('service-connected');
        this.emit('update');
    }

    _onNameVanished() {
        this._connected = false;

        this.emit('update');
        this.emit('service-disconnected');
    }

    _onPropertiesChanged(proxy, properties) {
        const state = proxy.State;
        const stateDuration = proxy.StateDuration;
        const elapsed = proxy.Elapsed;
        const isPaused = proxy.IsPaused;

        if (this._state !== state || this._stateDuration !== stateDuration || this._elapsed > elapsed) {
            this._state = state;
            this._stateDuration = stateDuration;
            this._elapsed = elapsed

            this.emit('state-changed');
        }
        else {
            this._elapsed = elapsed;
        }

        if (this._isPaused !== isPaused) {
            this._isPaused = isPaused;
            this.emit(isPaused ? 'paused' : 'resumed');
        }

        this.emit('update');
    }

    _onInit(proxy, error) {
        if (error) {
            Utils.logWarning(error.message);
            this._notifyServiceNotInstalled();
        }
    }

    _onCallback(result, error) {
        if (error) {
            Utils.logWarning(error.message);

            if (error.matches(Gio.DBusError, Gio.DBusError.SERVICE_UNKNOWN)) {
                this._notifyServiceNotInstalled();
            }
        }
    }

    getState() {
        if (!this._connected || this._proxy.State === null) {
            return State.NULL;
        }

        return this._proxy.State;
    }

    setState(state, timestamp) {
        this._proxy.SetStateRemote(state,
                                   timestamp || 0,
                                   this._onCallback.bind(this));
    }

    getStateDuration() {
        return this._proxy.StateDuration;
    }

    setStateDuration(duration) {
        this._proxy.SetStateDurationRemote(this._proxy.State,
                                           duration,
                                           this._onCallback.bind(this));
    }

    get stateDuration() {
        return this._proxy.StateDuration;
    }

    set stateDuration(value) {
        this._proxy.SetStateDurationRemote(this._proxy.State,
                                           value,
                                           this._onCallback.bind(this));
    }

    getElapsed() {
        return this._proxy.Elapsed;
    }

    getRemaining() {
        let state = this.getState();

        if (state === State.NULL) {
            return 0.0;
        }

        return Math.ceil(this._proxy.StateDuration - this._proxy.Elapsed);
    }

    getProgress() {
        return (this._connected && this._proxy.StateDuration > 0)
                ? this._proxy.Elapsed / this._proxy.StateDuration
                : 0.0;
    }

    isPaused() {
        return this._connected && this._proxy.IsPaused;
    }

    start() {
        this._proxy.StartRemote(this._onCallback.bind(this));
    }

    stop() {
        this._proxy.StopRemote(this._onCallback.bind(this));
    }

    pause() {
        this._proxy.PauseRemote(this._onCallback.bind(this));
    }

    resume() {
        this._proxy.ResumeRemote(this._onCallback.bind(this));
    }

    skip() {
        this._proxy.SkipRemote(this._onCallback.bind(this));
    }

    reset() {
        this._proxy.ResetRemote(this._onCallback.bind(this));
    }

    toggle() {
        if (this.getState() === State.NULL) {
            this.start();
        }
        else {
            this.stop();
        }
    }

    isBreak() {
        let state = this.getState();

        return state === State.SHORT_BREAK || state === State.LONG_BREAK;
    }

    showMainWindow(mode, timestamp) {
        this._proxy.ShowMainWindowRemote(mode, timestamp, this._onCallback.bind(this));
    }

    showPreferences(timestamp) {
        this._proxy.ShowPreferencesRemote(timestamp, this._onCallback.bind(this));
    }

    quit() {
        this._proxy.QuitRemote((result, error) => {
            Utils.disableExtension(Config.EXTENSION_UUID);
        });
    }

    _notifyServiceNotInstalled() {
        Extension.extension.notifyIssue(_("Failed to run <i>%s</i> service").format(Config.PACKAGE_NAME));
    }

    destroy() {
        if (this._propertiesChangedId != 0) {
            this._proxy.disconnect(this._propertiesChangedId);
            this._propertiesChangedId = 0;
        }

        if (this._nameWatcherId) {
            Gio.DBus.session.unwatch_name(this._nameWatcherId);
            this._nameWatcherId = 0;
        }
    }
};


var TimerLabel = GObject.registerClass({
}, class PomodoroTimerLabel extends St.BoxLayout {
    _init(timer, params) {
        params = Params.parse(params, {
            style_class: 'extension-pomodoro-timer-label',
            vertical: false,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            x_expand: false,
            y_expand: false,
            reactive: false,
            can_focus: false,
            track_hover: false,
        }, true);

        super._init(params);

        this._timer = timer;
        this._digitWidth = 0.0;
        this._minHPadding = 0.0;
        this._natHPadding = 0.0;
        this._destroyed = false;

        this._minutesLabel = new St.Label({
            text: "0",
            x_expand: true,
            x_align: Clutter.ActorAlign.END,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._minutesLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this.add_actor(this._minutesLabel);

        this._separatorLabel = new St.Label({
            text: ":",
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._separatorLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this.add_actor(this._separatorLabel);

        this._secondsLabel = new St.Label({
            text: "00",
            x_expand: true,
            x_align: Clutter.ActorAlign.START,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._secondsLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this.add_actor(this._secondsLabel);

        this._timerUpdateId = 0;
        this._styleChangedId = 0;

        this._updateAlignment();

        this.connect('notify::x_align', () => this._updateAlignment());
        this.connect('notify::y_align', () => this._updateAlignment());
        this.connect('destroy', this._onDestroy.bind(this));
    }

    freeze() {
        this._frozen = true;
    }

    unfreeze() {
        this._frozen = false;
    }

    vfunc_get_preferred_width(_forHeight) {
        const [, minutesWidth]   = this._minutesLabel.get_preferred_width(-1);
        const [, separatorWidth] = this._separatorLabel.get_preferred_width(-1);
        const [, secondsWidth]   = this._secondsLabel.get_preferred_width(-1);

        const naturalSize = 2 * Math.max(minutesWidth, secondsWidth, 2 * this._digitWidth) +
                            2 * this._natHPadding +
                            separatorWidth;
        const minimumSize = naturalSize;

        return [minimumSize, naturalSize];
    }

    vfunc_get_preferred_height(_forWidth) {
        const child = this.get_first_child();

        if (child) {
            return child.get_preferred_height(-1);
        }

        return [0, 0];
    }

    vfunc_map() {
        if (!this._styleChangedId) {
            this._styleChangedId = this.connect('style-changed', this._onStyleChanged.bind(this));
            this._onStyleChanged(this);
        }

        if (!this._timerUpdateId) {
            this._timerUpdateId = this._timer.connect('update', this._onTimerUpdate.bind(this));
        }

        this._updateLabels();

        super.vfunc_map();
    }

    vfunc_unmap() {
        if (this._styleChangedId) {
            this.disconnect(this._styleChangedId);
            this._styleChangedId = 0;
        }

        if (this._timerUpdateId) {
            this._timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }

        super.vfunc_unmap();
    }

    _updateAlignment() {
        this._minutesLabel.y_align = this.y_align;
        this._separatorLabel.y_align = this.y_align;
        this._secondsLabel.y_align = this.y_align;

        switch (this.x_align)
        {
            case Clutter.ActorAlign.CENTER:
                this._minutesLabel.x_expand = true;
                this._secondsLabel.x_expand = true;
                break;

            case Clutter.ActorAlign.START:
                this._minutesLabel.x_expand = false;
                this._secondsLabel.x_expand = true;
                break;

            case Clutter.ActorAlign.END:
                this._minutesLabel.x_expand = true;
                this._secondsLabel.x_expand = false;
                break;
        }
    }

    _updateLabels() {
        if (this._destroyed || this._frozen) {
            return;
        }

        const remaining = Math.max(this._timer.getRemaining(), 0.0);
        const minutes   = Math.floor(remaining / 60);
        const seconds   = Math.floor(remaining % 60);

        if (this._minutesLabel.clutter_text) {
            this._minutesLabel.clutter_text.set_text('%d'.format(minutes));
        }

        if (this._secondsLabel.clutter_text) {
            this._secondsLabel.clutter_text.set_text('%02d'.format(seconds));
        }
    }

    _onTimerUpdate() {
        this._updateLabels();
    }

    _onStyleChanged(actor) {
        const themeNode = actor.get_theme_node();
        const font      = themeNode.get_font();
        const context   = actor.get_pango_context();
        const metrics   = context.get_metrics(font, context.get_language());

        this._digitWidth = metrics.get_approximate_digit_width() / Pango.SCALE;
        this._minHPadding = themeNode.get_length('-minimum-hpadding');
        this._natHPadding = themeNode.get_length('-natural-hpadding');
    }

    _onDestroy() {
        this._destroyed = true;
    }
});
