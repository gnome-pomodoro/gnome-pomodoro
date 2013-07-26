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

const Gio = imports.gi.Gio;
const GLib = imports.gi.GLib;
const Meta = imports.gi.Meta;
const Pango = imports.gi.Pango;
const Shell = imports.gi.Shell;
const St = imports.gi.St;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const PanelMenu = imports.ui.panelMenu;
const PopupMenu = imports.ui.popupMenu;
const Tweener = imports.ui.tweener;

const DBus = Extension.imports.dbus;
const Notifications = Extension.imports.notifications;
const Utils = Extension.imports.utils;

const Gettext = imports.gettext.domain('gnome-pomodoro');
const _ = Gettext.gettext;
const ngettext = Gettext.ngettext;


// Time in seconds to fade timer label when pause starts or ends
const FADE_ANIMATION_TIME = 0.25;
const FADE_OPACITY = 150;

// Slider helper functions
const SLIDER_UPPER = 2700;
const SLIDER_LOWER = 60;

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

        this._initialized = false;
        this._propertiesChangedId = 0;
        this._notifyPomodoroStartId = 0;
        this._notifyPomodoroEndId = 0;
        this._notificationDialog = null;
        this._notification = null;
        this._settings = null;
        this._state = State.NULL;
        this._proxy = null;

        // Timer label
        this.label = new St.Label({ opacity: FADE_OPACITY,
                                    style_class: 'extension-pomodoro-label' });
        this.label.clutter_text.set_line_wrap(false);
        this.label.clutter_text.set_ellipsize(Pango.EllipsizeMode.NONE);
        this.actor.add_actor(this.label);

        // Toggle timer state button
        this._timerToggle = new PopupMenu.PopupSwitchMenuItem(_("Pomodoro Timer"), false, { style_class: 'extension-pomodoro-toggle' });
        this._timerToggle.connect('toggled', Lang.bind(this, this.toggle));
        this.menu.addMenuItem(this._timerToggle);

        // Separator
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

//        // Options SubMenu
//        this._optionsMenu = new PopupMenu.PopupSubMenuMenuItem(_("Options"));
//        this._buildOptionsMenu();
//        this.menu.addMenuItem(this._optionsMenu);

        // Settings
        this._settingsButton = new PopupMenu.PopupMenuItem(_("Preferences"));
        this._settingsButton.connect('activate', Lang.bind(this, this._showPreferences));
        this.menu.addMenuItem(this._settingsButton);

        this.menu.actor.connect('notify::visible', Lang.bind(this, this.refresh));

        // We can init most of the stuff later
        //Mainloop.idle_add(Lang.bind(this, this._doInit));
        //this.refresh();
        this._doInit();
    },

    _doInit: function() {
        this._settings = new Gio.Settings({ schema: 'org.gnome.pomodoro.preferences' });

        let children = ['timer', 'sounds', 'presence', 'notifications'];
        for (childId in children) {
            this._settings.get_child(children[childId]).connect('changed', Lang.bind(this, this._onSettingsChanged));
        }

        // Register keybindings to toggle
        Main.wm.addKeybinding('toggle-timer',
                              this._settings.get_child('keybindings'),
                              Meta.KeyBindingFlags.NONE,
                              Shell.KeyBindingMode.ALL,
                              Lang.bind(this, this.toggle));

        this._nameWatcherId = Gio.DBus.session.watch_name(
                                    DBus.SERVICE_NAME,
                                    Gio.BusNameWatcherFlags.AUTO_START,
                                    Lang.bind(this, this._onNameAppeared),
                                    Lang.bind(this, this._onNameVanished));

        this._onSettingsChanged();
        this._ensureProxy();

        this._initialized = true;

        this.refresh();

        return false;
    },

    _showPreferences: function() {
        this._ensureActionsProxy(Lang.bind(this, function() {
            this._actionsProxy.ActivateRemote('preferences', [GLib.Variant.new_string('timer')], null);
        }));
    },

//    _buildOptionsMenu: function() {
//        // Reset counters
//        this._resetCountButton =  new PopupMenu.PopupMenuItem(_("Reset Counts and Timer"));
//        this._resetCountButton.connect('activate', Lang.bind(this, this.reset));
//        this._optionsMenu.menu.addMenuItem(this._resetCountButton);
//
//        // Presence status toggle
//        this._changePresenceStatusToggle = new PopupMenu.PopupSwitchMenuItem(_("Control Presence Status"));
//        this._changePresenceStatusToggle.connect('toggled', Lang.bind(this, function(item) {
//            this._settings.get_child('presence').set_boolean('enabled', item.state);
//        }));
//        this._optionsMenu.menu.addMenuItem(this._changePresenceStatusToggle);
//
//        // Notification dialog toggle
//        this._showDialogsToggle = new PopupMenu.PopupSwitchMenuItem(_("Fullscreen Notifications"));
//        this._showDialogsToggle.connect('toggled', Lang.bind(this, function(item) {
//            this._settings.get_child('notifications').set_boolean('screen-notifications', item.state);
//            if (this._notificationDialog)
//                this._notificationDialog.setOpenWhenIdle(item.state);
//        }));
//        this._optionsMenu.menu.addMenuItem(this._showDialogsToggle);
//
//        // Notify with a sound toggle
//        this._playSoundsToggle = new PopupMenu.PopupSwitchMenuItem(_("Sound Notifications"));
//        this._playSoundsToggle.connect('toggled', Lang.bind(this, function(item) {
//            this._settings.get_child('sounds').set_boolean('enabled', item.state);
//        }));
//        this._optionsMenu.menu.addMenuItem(this._playSoundsToggle);
//
//        // Pomodoro duration
//        this._pomodoroTimeTitle = new PopupMenu.PopupMenuItem(_("Pomodoro Duration"), { reactive: false });
//        this._pomodoroTimeLabel = new St.Label({ text: '' });
//        this._pomodoroTimeSlider = new PopupMenu.PopupSliderMenuItem(0);
//        this._pomodoroTimeSlider.connect('value-changed', Lang.bind(this, function(item) {
//            this._pomodoroTimeLabel.set_text(_formatTime(_valueToSeconds(item.value)));
//        }));
//        this._pomodoroTimeSlider.connect('drag-end', Lang.bind(this, this._onPomodoroTimeChanged));
//        this._pomodoroTimeSlider.actor.connect('scroll-event', Lang.bind(this, this._onPomodoroTimeChanged));
//        this._pomodoroTimeTitle.addActor(this._pomodoroTimeLabel, { align: St.Align.END });
//        this._optionsMenu.menu.addMenuItem(this._pomodoroTimeTitle);
//        this._optionsMenu.menu.addMenuItem(this._pomodoroTimeSlider);
//
//        // Short pause duration
//        this._shortPauseTimeTitle = new PopupMenu.PopupMenuItem(_("Short Break Duration"), { reactive: false });
//        this._shortPauseTimeLabel = new St.Label({ text: '' });
//        this._shortPauseTimeSlider = new PopupMenu.PopupSliderMenuItem(0);
//        this._shortPauseTimeSlider.connect('value-changed', Lang.bind(this, function(item) {
//            this._shortPauseTimeLabel.set_text(_formatTime(_valueToSeconds(item.value)));
//            if (item.value > this._longPauseTimeValue) {
//                this._longPauseTimeLabel.set_text(this._shortPauseTimeLabel.text);
//                this._longPauseTimeSlider.setValue(this._shortPauseTimeSlider.value);
//            }
//            else if (this._longPauseTimeSlider.value != this._longPauseTimeValue) {
//                this._longPauseTimeLabel.set_text(this._longPauseTimeText);
//                this._longPauseTimeSlider.setValue(this._longPauseTimeValue);
//            }
//        }));
//        this._shortPauseTimeSlider.connect('drag-end', Lang.bind(this, this._onShortPauseTimeChanged));
//        this._shortPauseTimeSlider.actor.connect('scroll-event', Lang.bind(this, this._onShortPauseTimeChanged));
//        this._shortPauseTimeTitle.addActor(this._shortPauseTimeLabel, { align: St.Align.END });
//        this._optionsMenu.menu.addMenuItem(this._shortPauseTimeTitle);
//        this._optionsMenu.menu.addMenuItem(this._shortPauseTimeSlider);
//
//        // Long pause duration
//        this._longPauseTimeTitle = new PopupMenu.PopupMenuItem(_("Long Break Duration"), { reactive: false });
//        this._longPauseTimeLabel = new St.Label({ text: '' });
//        this._longPauseTimeSlider = new PopupMenu.PopupSliderMenuItem(0);
//        this._longPauseTimeSlider.connect('value-changed', Lang.bind(this, function(item) {
//            this._longPauseTimeLabel.set_text(_formatTime(_valueToSeconds(item.value)));
//            if (this._shortPauseTimeValue > item.value) {
//                this._shortPauseTimeLabel.set_text(this._longPauseTimeLabel.text);
//                this._shortPauseTimeSlider.setValue(this._longPauseTimeSlider.value);
//            }
//            else if (this._shortPauseTimeSlider.value != this._shortPauseTimeValue) {
//                this._shortPauseTimeLabel.set_text(this._shortPauseTimeText);
//                this._shortPauseTimeSlider.setValue(this._shortPauseTimeValue);
//            }
//        }));
//        this._longPauseTimeSlider.connect('drag-end', Lang.bind(this, this._onLongPauseTimeChanged));
//        this._longPauseTimeSlider.actor.connect('scroll-event', Lang.bind(this, this._onLongPauseTimeChanged));
//        this._longPauseTimeTitle.addActor(this._longPauseTimeLabel, { align: St.Align.END });
//        this._optionsMenu.menu.addMenuItem(this._longPauseTimeTitle);
//        this._optionsMenu.menu.addMenuItem(this._longPauseTimeSlider);
//    },

    _onSettingsChanged: function() {
//        this._showDialogsToggle.setToggleState(
//                                this._settings.get_child('notifications').get_boolean('screen-notifications'));
//        this._changePresenceStatusToggle.setToggleState(
//                                this._settings.get_child('presence').get_boolean('enabled'));
//        this._playSoundsToggle.setToggleState(
//                                this._settings.get_child('sounds').get_boolean('enabled'));

//        this._pomodoroTimeSlider.setValue(_secondsToValue(this._settings.get_child('timer').get_uint('pomodoro-time')));
//        this._pomodoroTimeLabel.set_text(_formatTime(_valueToSeconds(this._pomodoroTimeSlider.value)));

//        this._shortPauseTimeSlider.setValue(_secondsToValue(this._settings.get_child('timer').get_uint('short-pause-time')));
//        this._shortPauseTimeLabel.set_text(_formatTime(_valueToSeconds(this._shortPauseTimeSlider.value)));

//        this._longPauseTimeSlider.setValue(_secondsToValue(this._settings.get_child('timer').get_uint('long-pause-time')));
//        this._longPauseTimeLabel.set_text(_formatTime(_valueToSeconds(this._longPauseTimeSlider.value)));

//        this._shortPauseTimeValue = this._shortPauseTimeSlider.value;
//        this._shortPauseTimeText  = this._shortPauseTimeLabel.text;
//        this._longPauseTimeValue  = this._longPauseTimeSlider.value;
//        this._longPauseTimeText   = this._longPauseTimeLabel.text;

        if (this._reminder && !this._settings.get_child('notifications').get_boolean('reminders'))
            this._reminder.destroy();

        if (this._notificationDialog && !this._settings.get_child('notifications').get_boolean('screen-notifications')) {
            this._notificationDialog.close();
            this._notificationDialog.setOpenWhenIdle(false);
        }
    },

//    _onPomodoroTimeChanged: function() {
//        this._settings.get_child('timer').set_uint('pomodoro-time', _valueToSeconds(this._pomodoroTimeSlider.value));
//    },

//    _onShortPauseTimeChanged: function() {
//        let seconds = _valueToSeconds(this._shortPauseTimeSlider.value);
//
//        if (this._shortPauseTimeSlider.value > this._longPauseTimeValue) {
//            this._longPauseTimeLabel.set_text(this._shortPauseTimeLabel.text);
//            this._longPauseTimeSlider.setValue(this._shortPauseTimeSlider.value);
//            this._settings.get_child('timer').set_uint('long-pause-time', seconds);
//        }
//        this._settings.get_child('timer').set_uint('short-pause-time', seconds);
//    },

//    _onLongPauseTimeChanged: function() {
//        let seconds = _valueToSeconds(this._longPauseTimeSlider.value);
//
//        if (this._shortPauseTimeValue > this._longPauseTimeSlider.value) {
//            this._shortPauseTimeLabel.set_text(this._longPauseTimeLabel.text);
//            this._shortPauseTimeSlider.setValue(this._longPauseTimeSlider.value);
//            this._settings.get_child('timer').set_uint('short-pause-time', seconds);
//        }
//        this._settings.get_child('timer').set_uint('long-pause-time', seconds);
//    },

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
        let remaining, minutes, seconds;

        let state = this._proxy ? this._proxy.State : null;
        let toggled = state !== null && state !== State.NULL;

        if (this._state !== state && this._initialized) {
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

            if (this._state == State.IDLE &&
                this._notification instanceof Notifications.PomodoroStart)
            {
                this._notification.hide();
            }

            this._state = state;

            if (this._timerToggle.toggled !== toggled)
                this._timerToggle.setToggleState(toggled);
        }

        if (toggled) {
            remaining = state != State.IDLE
                    ? Math.max(this._proxy.ElapsedLimit - this._proxy.Elapsed, 0)
                    : this._settings.get_child('timer').get_uint('pomodoro-time');

            minutes = parseInt(remaining / 60);
            seconds = parseInt(remaining % 60);

            if (this._notification instanceof Notifications.PomodoroEnd) {
                this._notification.setRemainingTime(remaining);
                this._notificationDialog.setRemainingTime(remaining);
            }
        }
        else {
            minutes = 0;
            seconds = 0;

            if (this._notification instanceof Notifications.PomodoroStart ||
                this._notification instanceof Notifications.PomodoroEnd)
            {
                this._notification.destroy();
                this._notification = null;
            }
        }

        this.label.set_text('%02d:%02d'.format(minutes, seconds));
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
        if (this._proxy) {
            if (callback) {
                callback.call(this);

                this.refresh();
            }
            return;
        }
        else
        {
            this._proxy = DBus.Pomodoro(Lang.bind(this, function(proxy, error) {
                if (error) {
                    global.log('Pomodoro: ' + error.message);

                    this._destroyProxy();
                    this._notifyIssue();
                    return;
                }

                if (!this._proxy) {
                    global.log('Pomodoro: Callback called when proxy has been destroyed');
                    return;
                }

                // Keep in mind that signals won't be called right after initialization
                // when gnome-pomodoro comes back and gets restored
                if (!this._propertiesChangedId)
                    this._propertiesChangedId = this._proxy.connect('g-properties-changed',
                                                                Lang.bind(this, this._onPropertiesChanged));
                if (!this._notifyPomodoroStartId)
                    this._notifyPomodoroStartId = this._proxy.connectSignal('NotifyPomodoroStart',
                                                                Lang.bind(this, this._onNotifyPomodoroStart));
                if (!this._notifyPomodoroEndId)
                    this._notifyPomodoroEndId = this._proxy.connectSignal('NotifyPomodoroEnd',
                                                                Lang.bind(this, this._onNotifyPomodoroEnd));

                if (callback)
                    callback.call(this);

                if (this._proxy.State == State.POMODORO || this._proxy.State == State.IDLE)
                    this._onNotifyPomodoroStart(this._proxy, null, [false]);

                if (this._proxy.State == State.PAUSE)
                    this._onNotifyPomodoroEnd(this._proxy, null, [true]);

                this.refresh();
            }));
        }
    },

    _destroyProxy: function() {
        if (this._proxy) {
            if (this._propertiesChangedId) {
                this._proxy.disconnect(this._propertiesChangedId);
                this._propertiesChangedId = 0;
            }

            if (this._notifyPomodoroStartId) {
                this._proxy.disconnectSignal(this._notifyPomodoroStartId);
                this._notifyPomodoroStartId = 0;
            }

            if (this._notifyPomodoroEndId) {
                this._proxy.disconnectSignal(this._notifyPomodoroEndId);
                this._notifyPomodoroEndId = 0;
            }

            // TODO: not sure whether proxy gets destroyed by garbage collector
            //       there is no destroy method
            // this._proxy.destroy();
            this._proxy = null;
        }

        if (this._actionsProxy) {
            this._actionsProxy = null;
        }
    },

    _ensureActionsProxy: function(callback) {
        if (!this._actionsProxy)
            this._actionsProxy = new DBus.GtkActions(Lang.bind(this, function(proxy, error)
            {
                if (!error) {
                    if (callback)
                        callback.call(this);
                }
                else {
                    global.log('Pomodoro: ' + error.message);

                    this._actionsProxy = null;
                    this._notifyIssue();
                }
            }));
        else
            if (callback)
                callback.call(this);
    },

    _ensureNotificationSource: function() {
        if (!this._notificationSource) {
            this._notificationSource = new Notifications.Source();
            this._notificationSource.connect('destroy', Lang.bind(this, function(reason) {
                this._notificationSource = null;
            }));
        }
        return this._notificationSource;
    },

    _onNameAppeared: function() {
        this._ensureProxy();
    },

    _onNameVanished: function() {
        this._destroyProxy();
        this.refresh();
    },

    _onDBusCallback: function(result, error) {
        if (error)
            global.log('Pomodoro: ' + error.message)
    },

    _onPropertiesChanged: function(proxy, properties) {
        // DBus implementation in gjs enforces properties to be cached,
        // but does not update them properly...
        //
        // TODO: This walkaround may not bee needed in the future
        //
        properties = properties.deep_unpack();

        for (var name in properties) {
            proxy.set_cached_property(name, properties[name]);
        }

        this.refresh();
    },

    _onNotifyPomodoroStart: function(proxy, senderName, [is_requested]) {
        let source = this._ensureNotificationSource();

        if (is_requested) {
            if (this._notification)
                this._notification.destroy();
            return;
        }

        if (this._notification instanceof Notifications.PomodoroStart) {
            this._notification.show();
            return;
        }

        if (this._notification)
            this._notification.destroy();

        this._notification = new Notifications.PomodoroStart(source);
        this._notification.connect('destroy', Lang.bind(this, function(notification) {
            if (this._notification === notification)
                this._notification = null;
        }));

        this._notification.show();
    },

    _onNotifyPomodoroEnd: function(proxy, senderName, [is_completed]) {
        let source = this._ensureNotificationSource();
        let screenNotifications = this._settings.get_child('notifications')
                                                .get_boolean('screen-notifications');

        if (this._notification instanceof Notifications.PomodoroEnd) {
            this._notification.show();
            return;
        }

        if (this._notification)
            this._notification.destroy();

        this._notification = new Notifications.PomodoroEnd(source);
        this._notification.connect('action-invoked', Lang.bind(this, function(notification, action) {
            notification.destroy();
            if (action == Notifications.Action.START_POMODORO && this._proxy)
                this._proxy.State = State.POMODORO;
        }));
        this._notification.connect('clicked', Lang.bind(this, function() {
            if (this._notificationDialog) {
                this._notificationDialog.open();
                this._notificationDialog.pushModal();
            }
        }));
        this._notification.connect('destroy', Lang.bind(this, function(notification) {
            if (this._notification === notification)
                this._notification = null;

            if (this._notificationDialog) {
                this._notificationDialog.close();
                this._notificationDialog.setOpenWhenIdle(false);
            }

            if (this._reminder) {
                this._reminder.destroy();
                this._reminder = null;
            }
        }));

        if (!this._notificationDialog) {
            this._notificationDialog = new Notifications.PomodoroEndDialog();
            this._notificationDialog.connect('opening', Lang.bind(this, function() {
                if (this._reminder)
                    this._reminder.destroy();
            }));
            this._notificationDialog.connect('closing', Lang.bind(this, function() {
                if (this._notification)
                    this._notification.show();
            }));
            this._notificationDialog.connect('closed', Lang.bind(this, function() {
                this._schedulePomodoroEndReminder();
            }));
            this._notificationDialog.connect('destroy', Lang.bind(this, function() {
                this._notificationDialog = null;
            }));

            this._notificationDialog.setOpenWhenIdle(screenNotifications);
        }

        if (screenNotifications) {
            this._notificationDialog.open();
        }
        else {
            this._notification.show();
            this._schedulePomodoroEndReminder();
        }
    },

    _schedulePomodoroEndReminder: function() {
        let source = this._ensureNotificationSource();

        if (!this._settings.get_child('notifications').get_boolean('reminders'))
            return;

        if (this._reminder)
            this._reminder.destroy();

        this._reminder = new Notifications.PomodoroEndReminder(source);
        this._reminder.connect('show', Lang.bind(this, function(notification) {
            if (!this._proxy || this._proxy.State != State.PAUSE)
                notification.destroy();
            else
                // Don't show reminder if only 90 seconds remain to next pomodoro
                if (this._proxy.ElapsedLimit - this._proxy.Elapsed < 90)
                    notification.destroy();
        }));
        this._reminder.connect('clicked', Lang.bind(this, function() {
            if (this._notificationDialog) {
                this._notificationDialog.open();
                this._notificationDialog.pushModal();
            }
        }));
        this._reminder.connect('destroy', Lang.bind(this, function(notification) {
            if (this._reminder === notification)
                this._reminder = null;
        }));

        this._reminder.schedule();
    },

    _notifyIssue: function() {
        let source = this._ensureNotificationSource();

        if (this._notification instanceof Notifications.Issue)
            return;

        if (this._notification)
            this._notification.destroy();

        this._notification = new Notifications.Issue(source);
        this._notification.connect('destroy', Lang.bind(this, function(notification) {
            if (this._notification === notification)
                this._notification = null;
        }));
        this._notification.show();
    },

    destroy: function() {
        Main.wm.removeKeybinding('toggle-timer');

        if (this._nameWatcherId)
            Gio.DBus.session.unwatch_name(this._nameWatcherId);

        if (this._proxy)
            this._destroyProxy();

        if (this._notificationDialog)
            this._notificationDialog.destroy();

        if (this._notification)
            this._notification.destroy();

        if (this._notificationSource)
            this._notificationSource.destroy(MessageTray.NotificationDestroyedReason.SOURCE_CLOSED);

        this.parent();
    }
});
