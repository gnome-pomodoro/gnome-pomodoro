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

const Clutter = imports.gi.Clutter;
const Gio = imports.gi.Gio;
const Gtk = imports.gi.Gtk;
const Meta = imports.gi.Meta;
const Pango = imports.gi.Pango;
const Shell = imports.gi.Shell;
const St = imports.gi.St;

const Main = imports.ui.main;
const PanelMenu = imports.ui.panelMenu;
const PopupMenu = imports.ui.popupMenu;
const Slider = imports.ui.slider;
const Tweener = imports.ui.tweener;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const PomodoroUtil = Extension.imports.util;
const PomodoroTimer = Extension.imports.timer;
const PomodoroDBus = Extension.imports.dbus;

const Gettext = imports.gettext.domain('gnome-shell-pomodoro');
const _ = Gettext.gettext;
const ngettext = Gettext.ngettext;


// Time in seconds to fade timer label when pause starts or ends
const FADE_ANIMATION_TIME = 0.25;
const FADE_OPACITY = 120;

// Slider helper functions
const SLIDER_UPPER = 2700;
const SLIDER_LOWER = 60;

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
        
        this._timer = new PomodoroTimer.PomodoroTimer();
        this._timer.connect('state-changed', Lang.bind(this, this._onTimerStateChanged));
        this._timer.connect('elapsed-changed', Lang.bind(this, this._onTimerElapsedChanged));
        
        this._dbus = new PomodoroDBus.PomodoroTimer(this._timer);
        
        this._settings = PomodoroUtil.getSettings();

        this.menu.actor.add_style_class_name('extension-pomodoro-menu');
        
        // Timer label
        this.label = new St.Label({ style_class: 'extension-pomodoro-label',
                                    y_align: Clutter.ActorAlign.CENTER });
        this.label.clutter_text.set_line_wrap(false);
        this.label.clutter_text.set_ellipsize(Pango.EllipsizeMode.NONE);
        
        this.actor.add_actor(this.label);
        
        // Toggle timer state button
        this._timerToggle = new PopupMenu.PopupSwitchMenuItem(_("Pomodoro Timer"), false, { style_class: 'popup-subtitle-menu-item' });
        this._timerToggle.connect('toggled', Lang.bind(this, this._onToggled));
        this.menu.addMenuItem(this._timerToggle);
        
        // Session count
        let sessionCountItem = new PopupMenu.PopupMenuItem('', { reactive: false });
        this._sessionCountLabel = sessionCountItem.label;
        this.menu.addMenuItem(sessionCountItem);
        
        // Separator
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        
        // Options SubMenu
        this._optionsMenu = new PopupMenu.PopupSubMenuMenuItem(_("Options"));
        this._buildOptionsMenu();
        this.menu.addMenuItem(this._optionsMenu);
        
        
        // Register keybindings to toggle
        Main.wm.addKeybinding('toggle-pomodoro-timer',
                                      this._settings,
                                      Meta.KeyBindingFlags.NONE,
                                      Shell.KeyBindingMode.ALL,
                                      Lang.bind(this, this._onKeyPressed));

        this.connect('destroy', Lang.bind(this, this._onDestroy));
        
        // Initialize
        this._timer.restore();

        this._updateLabel();
        this._updateSessionCount();
        
        this._settingsChangedId = this._settings.connect('changed', Lang.bind(this, this._onSettingsChanged));
        this._onSettingsChanged();
    },

    _buildOptionsMenu: function() {
        var item;
        var bin;

        // Reset counters
        this._resetCountButton =  new PopupMenu.PopupMenuItem(_("Reset Counts and Timer"));
        this._resetCountButton.connect('activate', Lang.bind(this, this._onReset));
        this._optionsMenu.menu.addMenuItem(this._resetCountButton);
        
        // Away from desk toggle
        this._awayFromDeskToggle = new PopupMenu.PopupSwitchMenuItem(_("Away From Desk"));
        this._awayFromDeskToggle.connect('toggled', Lang.bind(this, function(item) {
            this._settings.set_boolean('away-from-desk', item.state);
        }));
        this._optionsMenu.menu.addMenuItem(this._awayFromDeskToggle);
        
        // Presence status toggle
        this._changePresenceStatusToggle = new PopupMenu.PopupSwitchMenuItem(_("Control Presence Status"));
        this._changePresenceStatusToggle.connect('toggled', Lang.bind(this, function(item) {
            this._settings.set_boolean('change-presence-status', item.state);
        }));
        this._optionsMenu.menu.addMenuItem(this._changePresenceStatusToggle);
        
        // Notification dialog toggle
        this._showDialogsToggle = new PopupMenu.PopupSwitchMenuItem(_("Screen Notifications"));
        this._showDialogsToggle.connect('toggled', Lang.bind(this, function(item) {
            this._settings.set_boolean('show-notification-dialogs', item.state);
        }));
        this._optionsMenu.menu.addMenuItem(this._showDialogsToggle);
        
        // Notify with a sound toggle
        this._playSoundsToggle = new PopupMenu.PopupSwitchMenuItem(_("Sound Notifications"));
        this._playSoundsToggle.connect('toggled', Lang.bind(this, function(item) {
            this._settings.set_boolean('play-sounds', item.state);
        }));
        this._optionsMenu.menu.addMenuItem(this._playSoundsToggle);
        
        // Pomodoro duration
        item = new PopupMenu.PopupMenuItem(_("Pomodoro Duration"), { reactive: false });
        this._pomodoroTimeLabel = new St.Label({ text: '' });
        bin = new St.Bin({ x_align: St.Align.END });
        bin.child = this._pomodoroTimeLabel;
        item.actor.add(bin, { expand: true, x_align: St.Align.END });
        this._optionsMenu.menu.addMenuItem(item);

        item = new PopupMenu.PopupBaseMenuItem({ activate: false });
        this._pomodoroTimeSlider = new Slider.Slider(0);
        this._pomodoroTimeSlider.connect('value-changed', Lang.bind(this, function(item) {
            this._pomodoroTimeLabel.set_text(_formatTime(_valueToSeconds(item.value)));
        }));
        this._pomodoroTimeSlider.connect('drag-end', Lang.bind(this, this._onPomodoroTimeChanged));
        this._pomodoroTimeSlider.actor.connect('scroll-event', Lang.bind(this, this._onPomodoroTimeChanged));
        item.actor.add(this._pomodoroTimeSlider.actor, { expand: true });
        this._optionsMenu.menu.addMenuItem(item);

        // Short pause duration
        item = new PopupMenu.PopupMenuItem(_("Short Break Duration"), { reactive: false });
        this._shortPauseTimeLabel = new St.Label({ text: '' });
        bin = new St.Bin({ x_align: St.Align.END });
        bin.child = this._shortPauseTimeLabel;
        item.actor.add(bin, { expand: true, x_align: St.Align.END });
        this._optionsMenu.menu.addMenuItem(item);

        item = new PopupMenu.PopupBaseMenuItem({ activate: false });
        this._shortPauseTimeSlider = new Slider.Slider(0);
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
        item.actor.add(this._shortPauseTimeSlider.actor, { expand: true });
        this._optionsMenu.menu.addMenuItem(item);

        // Long pause duration
        item = new PopupMenu.PopupMenuItem(_("Long Break Duration"), { reactive: false });
        this._longPauseTimeLabel = new St.Label({ text: '' });
        bin = new St.Bin({ x_align: St.Align.END });
        bin.child = this._longPauseTimeLabel;
        item.actor.add(bin, { expand: true, x_align: St.Align.END });
        this._optionsMenu.menu.addMenuItem(item);

        item = new PopupMenu.PopupBaseMenuItem({ activate: false });
        this._longPauseTimeSlider = new Slider.Slider(0);
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
        item.actor.add(this._longPauseTimeSlider.actor, { expand: true });
        this._optionsMenu.menu.addMenuItem(item);
    },

    _onSettingsChanged: function() {
        this._awayFromDeskToggle.setToggleState(
                                this._settings.get_boolean('away-from-desk'));
        this._showDialogsToggle.setToggleState(
                                this._settings.get_boolean('show-notification-dialogs'));
        this._changePresenceStatusToggle.setToggleState(
                                this._settings.get_boolean('change-presence-status'));
        this._playSoundsToggle.setToggleState(
                                this._settings.get_boolean('play-sounds'));
        
        this._pomodoroTimeSlider.setValue(_secondsToValue(this._settings.get_int('pomodoro-time')));
        this._pomodoroTimeLabel.set_text(_formatTime(_valueToSeconds(this._pomodoroTimeSlider.value)));
        
        this._shortPauseTimeSlider.setValue(_secondsToValue(this._settings.get_int('short-pause-time')));
        this._shortPauseTimeLabel.set_text(_formatTime(_valueToSeconds(this._shortPauseTimeSlider.value)));
        
        this._longPauseTimeSlider.setValue(_secondsToValue(this._settings.get_int('long-pause-time')));
        this._longPauseTimeLabel.set_text(_formatTime(_valueToSeconds(this._longPauseTimeSlider.value)));
        
        this._shortPauseTimeValue = this._shortPauseTimeSlider.value;
        this._shortPauseTimeText  = this._shortPauseTimeLabel.text;
        this._longPauseTimeValue  = this._longPauseTimeSlider.value;
        this._longPauseTimeText   = this._longPauseTimeLabel.text;
    },

    _onPomodoroTimeChanged: function() {
        this._settings.set_int('pomodoro-time', _valueToSeconds(this._pomodoroTimeSlider.value));
    },

    _onShortPauseTimeChanged: function() {
        let seconds = _valueToSeconds(this._shortPauseTimeSlider.value);
        
        if (this._shortPauseTimeSlider.value > this._longPauseTimeValue) {
            this._longPauseTimeLabel.set_text(this._shortPauseTimeLabel.text);
            this._longPauseTimeSlider.setValue(this._shortPauseTimeSlider.value);
            this._settings.set_int('long-pause-time', seconds);
        }
        this._settings.set_int('short-pause-time', seconds);
    },

    _onLongPauseTimeChanged: function() {
        let seconds = _valueToSeconds(this._longPauseTimeSlider.value);
        
        if (this._shortPauseTimeValue > this._longPauseTimeSlider.value) {
            this._shortPauseTimeLabel.set_text(this._longPauseTimeLabel.text);
            this._shortPauseTimeSlider.setValue(this._longPauseTimeSlider.value);
            this._settings.set_int('short-pause-time', seconds);
        }
        this._settings.set_int('long-pause-time', seconds);
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

    _updateLabel: function() {
        if (this._timer.state != PomodoroTimer.State.NULL) {
            let secondsLeft = Math.max(this._timer.remaining, 0);
            
            if (this._timer.state == PomodoroTimer.State.IDLE)
                secondsLeft = this._settings.get_int('pomodoro-time');
            
            let minutes = parseInt(secondsLeft / 60);
            let seconds = parseInt(secondsLeft % 60);
            
            this.label.set_text('%02d:%02d'.format(minutes, seconds));
        }
        else {
            this.label.set_text('00:00');
        }
    },

    _updateSessionCount: function() {
        let sessionCount = this._timer.sessionCount;
        let text;
        
        if (sessionCount == 0)
            text = _("No Completed Sessions");
        else
            text = ngettext("%d Completed Session", "%d Completed Sessions", sessionCount).format(sessionCount);
        
        this._sessionCountLabel.set_text(text);
    },

    _onToggled: function(item) {
        if (item.state)
            this._timer.start();
        else
            this._timer.stop();
    },

    _onReset: function() {
        this._timer.reset();
    },

    _onTimerElapsedChanged: function(object, elapsed) {
        this._updateLabel();
    },

    _onTimerStateChanged: function(object, state) {
        this._updateLabel();
        this._updateSessionCount();
        
        if (state == PomodoroTimer.State.PAUSE || state == PomodoroTimer.State.NULL)
            Tweener.addTween(this.label,
                             { opacity: FADE_OPACITY,
                               transition: 'easeOutQuad',
                               time: FADE_ANIMATION_TIME });
        else
            Tweener.addTween(this.label,
                             { opacity: 255,
                               transition: 'easeOutQuad',
                               time: FADE_ANIMATION_TIME });
        
        this._timerToggle.setToggleState(this._timer.state != PomodoroTimer.State.NULL);
    },

    _onKeyPressed: function() {
        this._timerToggle.toggle();
    },
    
    _onDestroy: function() {
        if (this._settingsChangedId != 0) {
            this._settings.disconnect(this._settingsChangedId);
            this._settingsChangedId = 0;
        }

        Main.wm.removeKeybinding('toggle-pomodoro-timer');

        this._dbus.destroy();
        this._timer.destroy();
    }
});


let indicator;

function init(metadata) {
    PomodoroUtil.initTranslations('gnome-shell-pomodoro');

    let iconTheme = Gtk.IconTheme.get_default();

    if (!iconTheme.has_icon('timer-symbolic'))
        iconTheme.append_search_path (PomodoroUtil.getExtensionPath());
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
