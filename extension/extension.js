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

const Gio = imports.gi.Gio;
const Meta = imports.gi.Meta;
const Pango = imports.gi.Pango;
const St = imports.gi.St;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const PanelMenu = imports.ui.panelMenu;
const PopupMenu = imports.ui.popupMenu;
const Tweener = imports.ui.tweener;

const DBus = Extension.imports.dbus;
const Notification = Extension.imports.notification;
const Utils = Extension.imports.utils;

const Gettext = imports.gettext.domain('gnome-shell-pomodoro');
const _ = Gettext.gettext;
const ngettext = Gettext.ngettext;


// Time in seconds to fade timer label when pause starts or ends
const FADE_ANIMATION_TIME = 0.25;
const FADE_OPACITY = 150;

// Slider helper functions
const SLIDER_UPPER = 2700;
const SLIDER_LOWER = 60;

const POMODORO_SERVICE_NAME = 'org.gnome.Pomodoro';

const State = {
    NULL: 'null',
    POMODORO: 'pomodoro',
    PAUSE: 'pause',
    IDLE: 'idle'
};


function _valueToSeconds(value) {
    return Math.floor(value * (SLIDER_UPPER - SLIDER_LOWER) / 60) * 60 + SLIDER_LOWER;
}

function _secondsToValue(seconds) {
    return (seconds - SLIDER_LOWER) / (SLIDER_UPPER - SLIDER_LOWER);
}

function _formatTime(seconds) {
    let minutes = Math.floor(seconds / 60);
    return ngettext("%d minute", "%d minutes", minutes).format(minutes);
}


const Indicator = new Lang.Class({
    Name: 'PomodoroIndicator',
    Extends: PanelMenu.Button,

    _init: function() {
        this.parent(St.Align.START);

        this._state = State.NULL;
        this._proxy = null;

        this._nameWatcherId = Gio.DBus.session.watch_name(
                                    POMODORO_SERVICE_NAME,
                                    Gio.BusNameWatcherFlags.NONE,
                                    Lang.bind(this, this._onNameAppeared),
                                    Lang.bind(this, this._onNameVanished));
        this._propertiesChangedId = 0;

        this._settings = new Gio.Settings({ schema: 'org.gnome.pomodoro.preferences' });
        this._settings.connect('changed', Lang.bind(this, this._onSettingsChanged));

        // Timer label
        this.label = new St.Label({ style_class: 'extension-pomodoro-label' });
        this.label.clutter_text.set_line_wrap(false);
        this.label.clutter_text.set_ellipsize(Pango.EllipsizeMode.NONE);

        this.actor.add_actor(this.label);

        // Toggle timer state button
        this._timerToggle = new PopupMenu.PopupSwitchMenuItem(_("Pomodoro Timer"), false, { style_class: 'popup-subtitle-menu-item' });
        this._timerToggle.connect('toggled', Lang.bind(this, this.toggle));
        this.menu.addMenuItem(this._timerToggle);

        // Separator
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Options SubMenu
        this._optionsMenu = new PopupMenu.PopupSubMenuMenuItem(_("Options"));
        this._buildOptionsMenu();
        this.menu.addMenuItem(this._optionsMenu);

        // Register keybindings to toggle
        global.display.add_keybinding('toggle-timer',
                                      this._settings.get_child('keybindings'),
                                      Meta.KeyBindingFlags.NONE,
                                      Lang.bind(this, this.toggle));

        this.menu.actor.connect('notify::visible', Lang.bind(this, this.refresh));

        this.refresh();

        this._onSettingsChanged();
        this._ensureProxy();
    },

    _buildOptionsMenu: function() {
        // Reset counters
        this._resetCountButton =  new PopupMenu.PopupMenuItem(_("Reset Counts and Timer"));
        this._resetCountButton.connect('activate', Lang.bind(this, this.reset));
        this._optionsMenu.menu.addMenuItem(this._resetCountButton);

        // Presence status toggle
        this._changePresenceStatusToggle = new PopupMenu.PopupSwitchMenuItem(_("Control Presence Status"));
        this._changePresenceStatusToggle.connect('toggled', Lang.bind(this, function(item) {
            this._settings.get_child('presence').set_boolean('enabled', item.state);
        }));
        this._optionsMenu.menu.addMenuItem(this._changePresenceStatusToggle);

        // Notification dialog toggle
        this._showDialogsToggle = new PopupMenu.PopupSwitchMenuItem(_("Fullscreen Notifications"));
        this._showDialogsToggle.connect('toggled', Lang.bind(this, function(item) {
            this._settings.get_child('notifications').set_boolean('screen-notifications', item.state);
        }));
        this._optionsMenu.menu.addMenuItem(this._showDialogsToggle);

        // Notify with a sound toggle
        this._playSoundsToggle = new PopupMenu.PopupSwitchMenuItem(_("Sound Notifications"));
        this._playSoundsToggle.connect('toggled', Lang.bind(this, function(item) {
            this._settings.get_child('sounds').set_boolean('enabled', item.state);
        }));
        this._optionsMenu.menu.addMenuItem(this._playSoundsToggle);

        // Pomodoro duration
        this._pomodoroTimeTitle = new PopupMenu.PopupMenuItem(_("Pomodoro Duration"), { reactive: false });
        this._pomodoroTimeLabel = new St.Label({ text: '' });
        this._pomodoroTimeSlider = new PopupMenu.PopupSliderMenuItem(0);
        this._pomodoroTimeSlider.connect('value-changed', Lang.bind(this, function(item) {
            this._pomodoroTimeLabel.set_text(_formatTime(_valueToSeconds(item.value)));
        }));
        this._pomodoroTimeSlider.connect('drag-end', Lang.bind(this, this._onPomodoroTimeChanged));
        this._pomodoroTimeSlider.actor.connect('scroll-event', Lang.bind(this, this._onPomodoroTimeChanged));
        this._pomodoroTimeTitle.addActor(this._pomodoroTimeLabel, { align: St.Align.END });
        this._optionsMenu.menu.addMenuItem(this._pomodoroTimeTitle);
        this._optionsMenu.menu.addMenuItem(this._pomodoroTimeSlider);

        // Short pause duration
        this._shortPauseTimeTitle = new PopupMenu.PopupMenuItem(_("Short Break Duration"), { reactive: false });
        this._shortPauseTimeLabel = new St.Label({ text: '' });
        this._shortPauseTimeSlider = new PopupMenu.PopupSliderMenuItem(0);
        this._shortPauseTimeSlider.connect('value-changed', Lang.bind(this, function(item) {
            this._shortPauseTimeLabel.set_text(_formatTime(_valueToSeconds(item.value)));
            if (item.value > this._longPauseTimeValue) {
                this._longPauseTimeLabel.set_text(this._shortPauseTimeLabel.text);
                this._longPauseTimeSlider.setValue(this._shortPauseTimeSlider.value);
            }
            else if (this._longPauseTimeSlider.value != this._longPauseTimeValue) {
                this._longPauseTimeLabel.set_text(this._longPauseTimeText);
                this._longPauseTimeSlider.setValue(this._longPauseTimeValue);
            }
        }));
        this._shortPauseTimeSlider.connect('drag-end', Lang.bind(this, this._onShortPauseTimeChanged));
        this._shortPauseTimeSlider.actor.connect('scroll-event', Lang.bind(this, this._onShortPauseTimeChanged));
        this._shortPauseTimeTitle.addActor(this._shortPauseTimeLabel, { align: St.Align.END });
        this._optionsMenu.menu.addMenuItem(this._shortPauseTimeTitle);
        this._optionsMenu.menu.addMenuItem(this._shortPauseTimeSlider);

        // Long pause duration
        this._longPauseTimeTitle = new PopupMenu.PopupMenuItem(_("Long Break Duration"), { reactive: false });
        this._longPauseTimeLabel = new St.Label({ text: '' });
        this._longPauseTimeSlider = new PopupMenu.PopupSliderMenuItem(0);
        this._longPauseTimeSlider.connect('value-changed', Lang.bind(this, function(item) {
            this._longPauseTimeLabel.set_text(_formatTime(_valueToSeconds(item.value)));
            if (this._shortPauseTimeValue > item.value) {
                this._shortPauseTimeLabel.set_text(this._longPauseTimeLabel.text);
                this._shortPauseTimeSlider.setValue(this._longPauseTimeSlider.value);
            }
            else if (this._shortPauseTimeSlider.value != this._shortPauseTimeValue) {
                this._shortPauseTimeLabel.set_text(this._shortPauseTimeText);
                this._shortPauseTimeSlider.setValue(this._shortPauseTimeValue);
            }
        }));
        this._longPauseTimeSlider.connect('drag-end', Lang.bind(this, this._onLongPauseTimeChanged));
        this._longPauseTimeSlider.actor.connect('scroll-event', Lang.bind(this, this._onLongPauseTimeChanged));
        this._longPauseTimeTitle.addActor(this._longPauseTimeLabel, { align: St.Align.END });
        this._optionsMenu.menu.addMenuItem(this._longPauseTimeTitle);
        this._optionsMenu.menu.addMenuItem(this._longPauseTimeSlider);
    },

    _onSettingsChanged: function() {
        this._showDialogsToggle.setToggleState(
                                this._settings.get_child('notifications').get_boolean('screen-notifications'));
        this._changePresenceStatusToggle.setToggleState(
                                this._settings.get_child('presence').get_boolean('enabled'));
        this._playSoundsToggle.setToggleState(
                                this._settings.get_child('sounds').get_boolean('enabled'));

        this._pomodoroTimeSlider.setValue(_secondsToValue(this._settings.get_child('timer').get_uint('pomodoro-time')));
        this._pomodoroTimeLabel.set_text(_formatTime(_valueToSeconds(this._pomodoroTimeSlider.value)));

        this._shortPauseTimeSlider.setValue(_secondsToValue(this._settings.get_child('timer').get_uint('short-pause-time')));
        this._shortPauseTimeLabel.set_text(_formatTime(_valueToSeconds(this._shortPauseTimeSlider.value)));

        this._longPauseTimeSlider.setValue(_secondsToValue(this._settings.get_child('timer').get_uint('long-pause-time')));
        this._longPauseTimeLabel.set_text(_formatTime(_valueToSeconds(this._longPauseTimeSlider.value)));

        this._shortPauseTimeValue = this._shortPauseTimeSlider.value;
        this._shortPauseTimeText  = this._shortPauseTimeLabel.text;
        this._longPauseTimeValue  = this._longPauseTimeSlider.value;
        this._longPauseTimeText   = this._longPauseTimeLabel.text;
    },

    _onPomodoroTimeChanged: function() {
        this._settings.get_child('timer').set_uint('pomodoro-time', _valueToSeconds(this._pomodoroTimeSlider.value));
    },

    _onShortPauseTimeChanged: function() {
        let seconds = _valueToSeconds(this._shortPauseTimeSlider.value);

        if (this._shortPauseTimeSlider.value > this._longPauseTimeValue) {
            this._longPauseTimeLabel.set_text(this._shortPauseTimeLabel.text);
            this._longPauseTimeSlider.setValue(this._shortPauseTimeSlider.value);
            this._settings.get_child('timer').set_uint('long-pause-time', seconds);
        }
        this._settings.get_child('timer').set_uint('short-pause-time', seconds);
    },

    _onLongPauseTimeChanged: function() {
        let seconds = _valueToSeconds(this._longPauseTimeSlider.value);

        if (this._shortPauseTimeValue > this._longPauseTimeSlider.value) {
            this._shortPauseTimeLabel.set_text(this._longPauseTimeLabel.text);
            this._shortPauseTimeSlider.setValue(this._longPauseTimeSlider.value);
            this._settings.get_child('timer').set_uint('short-pause-time', seconds);
        }
        this._settings.get_child('timer').set_uint('long-pause-time', seconds);
    },

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

    refresh: function() {
        let state = this._proxy ? this._proxy.State : null;
        let toggled = state !== null && state !== State.NULL;

        if (this._state !== state) {
            if (state == State.POMODORO || state == State.IDLE)
                Tweener.addTween(this.label,
                                 { opacity: 255,
                                   transition: 'easeOutQuad',
                                   time: FADE_ANIMATION_TIME });
            else
                Tweener.addTween(this.label,
                                 { opacity: FADE_OPACITY,
                                   transition: 'easeOutQuad',
                                   time: FADE_ANIMATION_TIME });
            this._state = state;
        }

        if (toggled) {
            let secondsLeft = Math.max(this._proxy.ElapsedLimit - this._proxy.Elapsed, 0);

            if (state == State.IDLE)
                secondsLeft = this._proxy.ElapsedLimit;

            let minutes = parseInt(secondsLeft / 60);
            let seconds = parseInt(secondsLeft % 60);

            this.label.set_text('%02d:%02d'.format(minutes, seconds));
        }
        else
            this.label.set_text('00:00');

        if (this._timerToggle.toggled !== toggled)
            this._timerToggle.setToggleState(toggled);
    },

    start: function() {
        this._ensureProxy(Lang.bind(this, function() {
            this._proxy.StartRemote(Lang.bind(this, this._onDBusCallback));
        }));
    },

    stop: function() {
        this._ensureProxy(Lang.bind(this, function() {
            this._proxy.StopRemote(Lang.bind(this, this._onDBusCallback));
        }));
    },

    reset: function() {
        this._ensureProxy(Lang.bind(this, function() {
            this._proxy.ResetRemote(Lang.bind(this, this._onDBusCallback));
        }));
    },

    toggle: function() {
        if (this._state === null || this._state === State.NULL)
            this.start();
        else
            this.stop();
    },

    _ensureProxy: function(callback) {
        if (!this._proxy)
        {
            this._proxy = DBus.Pomodoro(Lang.bind(this, function(proxy, error)
            {
                if (!error) {
                    global.log('Pomodoro: created a proxy');
                    this._propertiesChangedId = this._proxy.connect('g-properties-changed',
                                                                    Lang.bind(this, this.refresh));
                    this.refresh();

                    if (callback)
                        callback.call(this);
                }
                else {
                    this._notifyError(_("Could not run pomodoro timer"));
                    global.log('Pomodoro: ' + error.message);
                }
            }));
        }
        else {
            if (callback)
                callback.call(this);
        }
    },

    _onNameAppeared: function() {
        this._ensureProxy();
    },

    _onNameVanished: function() {
        if (this._proxy && this._propertiesChangedId) {
            this._proxy.disconnect(this._propertiesChangedId);
            this._propertiesChangedId = 0;
        }

        if (this._proxy) {
            this._proxy = null;
        }

        this.refresh();
    },

    _onDBusCallback: function(result, error) {
        if (error)
            global.log('Pomodoro: ' + error.message)
    },

    _getNotificationSource: function() {
        let source = this._notificationSource;
        if (!source) {
            source = new Notification.NotificationSource();
            source.connect('destroy', Lang.bind(this, function() {
                this._notificationSource = null;
            }));
            Main.messageTray.add(source);
        }
        return source;
    },

    _notifyError: function(title, text, urgency) {
        let source = this._getNotificationSource();

        let notification = new MessageTray.Notification(source, title, text);
        notification.setTransient(true);
        notification.setUrgency(urgency !== undefined ? urgency : MessageTray.Urgency.HIGH);

        source.notify(notification);
    },

    destroy: function() {
        global.display.remove_keybinding('toggle-timer');

        if (this._nameWatcherId) {
            Gio.DBus.session.unwatch_name(this._nameWatcherId);
            this._nameWatcherId = 0;
        }

        if (this._notificationSource) {
            this._notificationSource.destroy();
            this._notificationSource = null;
        }

        this.parent();
    }
});


let indicator;

function init(metadata) {
    Utils.initTranslations('gnome-shell-pomodoro');
}

function enable() {
    if (!indicator) {
        indicator = new Indicator();
        Main.panel.addToStatusArea('pomodoro', indicator);
    }
}

function disable() {
    if (indicator) {
        indicator.destroy();
        indicator = null;
    }
}
