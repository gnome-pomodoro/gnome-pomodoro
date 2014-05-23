/*
 * Copyright (c) 2011-2013 gnome-pomodoro contributors
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

const Clutter = imports.gi.Clutter;
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
const Tasklist = Extension.imports.tasklist;
const Config = Extension.imports.config;
const Settings = Extension.imports.settings;

const Gettext = imports.gettext.domain(Config.GETTEXT_PACKAGE);
const _ = Gettext.gettext;


const FADE_IN_TIME = 250;
const FADE_IN_OPACITY = 1.0;

const FADE_OUT_TIME = 250;
const FADE_OUT_OPACITY = 0.47;

const FOCUS_WINDOW_TIMEOUT = 3;

const State = {
    NULL: 'null',
    POMODORO: 'pomodoro',
    PAUSE: 'pause',
    IDLE: 'idle'
};


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
        this._settingsChangedId = 0;
        this._state = State.NULL;
        this._proxy = null;

        this.label = new St.Label({ opacity: FADE_OUT_OPACITY * 255,
                                    style_class: 'extension-pomodoro-label',
                                    y_align: Clutter.ActorAlign.CENTER });
        this.label.clutter_text.set_line_wrap(false);
        this.label.clutter_text.set_ellipsize(Pango.EllipsizeMode.NONE);
        this.actor.add_actor(this.label);

        this.menu.actor.add_style_class_name('extension-pomodoro-indicator');

        /* Toggle timer state button */
        this._timerToggle = new PopupMenu.PopupSwitchMenuItem(_("Pomodoro Timer"), false, { style_class: 'extension-pomodoro-toggle' });
        this._timerToggle.connect('toggled', Lang.bind(this, this.toggle));
        this.menu.addMenuItem(this._timerToggle);

        /* Task list */
        this.entry = new Tasklist.TaskEntry();
        this.entry.connect('task-entered', Lang.bind(this, this._onTaskEntered));

        /* TODO: Lock focus on the entry once active */
        /* TODO: Add history manager, just as in runDialog */
        /* TODO: More items could be added to context menu */

        this.tasklist = new Tasklist.TaskList();
        this.tasklist.connect('task-selected', Lang.bind(this, this._onTaskSelected));

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this.menu.addAction(_("Manage Tasks"), Lang.bind(this, function() {}));
        this.menu.addAction(_("Preferences"), Lang.bind(this, this._showPreferences));
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this.menu.addMenuItem(this.tasklist);
        this.menu.addMenuItem(this.entry);

        this.menu.connect('open-state-changed',
                          Lang.bind(this, this._onMenuOpenStateChanged));

        try {
            this._settings = Settings.getSettings('org.gnome.pomodoro.preferences');
            this._settingsChangedId = this._settings.connect('changed', Lang.bind(this, this._onSettingsChanged));
        }
        catch (error) {
            log('Pomodoro: ' + error);
        }

        /* Register keybindings to toggle the timer */
        Main.wm.addKeybinding('toggle-timer-key',
                              this._settings,
                              Meta.KeyBindingFlags.NONE,
                              Shell.KeyBindingMode.ALL,
                              Lang.bind(this, this.toggle));

        this._nameWatcherId = Gio.DBus.session.watch_name(
                                       DBus.SERVICE_NAME,
                                       Gio.BusNameWatcherFlags.AUTO_START,
                                       Lang.bind(this, this._onNameAppeared),
                                       Lang.bind(this, this._onNameVanished));

        this._onSettingsChanged();

        if (this._isRunning()) {
            this._ensureProxy();
        }
        else {
            this.refresh();
        }
    },

    _isRunning: function() {
        let settings;
        let state;

        try {
            settings = Settings.getSettings('org.gnome.pomodoro.state');
            state = settings.get_string('state');
        }
        catch (error) {
            log('Pomodoro: ' + error);
        }

        return state && state != State.NULL;
    },

    _showPreferences: function() {
        this._ensureActionsProxy(Lang.bind(this,
            function() {
                let mode = 'timer';
                let timestamp = global.get_current_time();

                this._actionsProxy.ActivateRemote('preferences', [
                        GLib.Variant.new('(su)', [mode, timestamp])
                    ], null);
            }));
    },

    _onSettingsChanged: function() {
        if (this._reminder && !this._settings.get_boolean('show-reminders')) {
            this._reminder.close();
            this._reminder = null;
        }

        if (this._notificationDialog && !this._settings.get_boolean('show-screen-notifications')) {
            this._notificationDialog.close();
        }
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

        let predicted_width        = Math.floor(digit_width * 4 + 0.5 * char_width);
        let predicted_min_size     = predicted_width + 2 * min_hpadding;
        let predicted_natural_size = predicted_width + 2 * natural_hpadding;

        PanelMenu.Button.prototype._getPreferredWidth.call(this, actor, forHeight, alloc); // output stored in alloc

        if (alloc.min_size < predicted_min_size) {
            alloc.min_size = predicted_min_size;
        }

        if (alloc.natural_size < predicted_natural_size) {
            alloc.natural_size = predicted_natural_size;
        }
    },

    _onMenuOpenStateChanged: function(menu, open) {
        if (open) {
            this.refresh();
        }
    },

    refresh: function() {
        let remaining, minutes, seconds;

        let state = this._proxy ? this._proxy.State : null;
        let toggled = state !== null && state !== State.NULL;

        if (this._state !== state && this._initialized)
        {
            this._state = state;

            if (state == State.POMODORO || state == State.IDLE) {
                Tweener.addTween(this.label,
                                 { opacity: FADE_IN_OPACITY * 255,
                                   time: FADE_IN_TIME / 1000,
                                   transition: 'easeOutQuad' });
            }
            else {
                Tweener.addTween(this.label,
                                 { opacity: FADE_OUT_OPACITY * 255,
                                   time: FADE_OUT_TIME / 1000,
                                   transition: 'easeOutQuad' });
            }

            if (state != State.PAUSE && this._notificationDialog) {
                this._notificationDialog.close();
            }

            if (this._timerToggle.toggled !== toggled) {
                this._timerToggle.setToggleState(toggled);
            }
        }

        if (toggled) {
            remaining = Math.max(state != State.IDLE
                    ? Math.ceil(this._proxy.StateDuration - this._proxy.Elapsed)
                    : this._settings.get_double('pomodoro-duration'), 0);

            minutes = Math.floor(remaining / 60);
            seconds = Math.floor(remaining % 60);

            if (this._notification instanceof Notifications.PomodoroEnd) {
                this._notification.setElapsedTime(this._proxy.Elapsed, this._proxy.StateDuration);
                this._notificationDialog.setElapsedTime(this._proxy.Elapsed, this._proxy.StateDuration);
            }
        }
        else {
            minutes = 0;
            seconds = 0;

            if (this._notification instanceof Notifications.PomodoroStart ||
                this._notification instanceof Notifications.PomodoroEnd)
            {
                this._notification.close();
                this._notification = null;
            }

            if (this._notificationDialog) {
                this._notificationDialog.close();
            }
        }

        this.label.set_text('%02d:%02d'.format(minutes, seconds));
    },

    start: function() {
        this._ensureProxy(Lang.bind(this,
            function() {
                this._proxy.StartRemote(Lang.bind(this, this._onDBusCallback));
            }));
    },

    stop: function() {
        this._ensureProxy(Lang.bind(this,
            function() {
                this._proxy.StopRemote(Lang.bind(this, this._onDBusCallback));
            }));
    },

    reset: function() {
        this._ensureProxy(Lang.bind(this,
            function() {
                this._proxy.ResetRemote(Lang.bind(this, this._onDBusCallback));
            }));
    },

    toggle: function() {
        if (this._state === null || this._state === State.NULL) {
            this.start();
        }
        else {
            this.stop();
        }
    },

    _ensureProxy: function(callback) {
        if (this._proxy) {
            if (callback) {
                callback.call(this);

                this.refresh();
            }
            return;
        }

        this._proxy = DBus.Pomodoro(Lang.bind(this, function(proxy, error) {
            if (error) {
                global.log('Pomodoro: ' + error.message);

                this._destroyProxy();
                this._notifyIssue();
                return;
            }

            if (proxy !== this._proxy) {
                return;
            }

            /* Keep in mind that signals won't be called right after initialization
             * when gnome-pomodoro comes back and gets restored
             */
            if (this._propertiesChangedId == 0) {
                this._propertiesChangedId = this._proxy.connect(
                                           'g-properties-changed',
                                           Lang.bind(this, this._onPropertiesChanged));
            }

            if (this._notifyPomodoroStartId == 0) {
                this._notifyPomodoroStartId = this._proxy.connectSignal(
                                           'NotifyPomodoroStart',
                                           Lang.bind(this, this._onNotifyPomodoroStart));
            }

            if (this._notifyPomodoroEndId == 0) {
                this._notifyPomodoroEndId = this._proxy.connectSignal(
                                           'NotifyPomodoroEnd',
                                           Lang.bind(this, this._onNotifyPomodoroEnd));
            }

            if (callback) {
                callback.call(this);
            }

            if (this._proxy.State == State.POMODORO ||
                this._proxy.State == State.IDLE)
            {
                this._onNotifyPomodoroStart(this._proxy, null, [false]);
            }

            if (this._proxy.State == State.PAUSE) {
                this._onNotifyPomodoroEnd(this._proxy, null, [true]);
            }

            this._initialized = true;
            this.refresh();
        }));
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

            /* TODO: not sure whether proxy gets destroyed by garbage collector
             *       there is no destroy method
             */
//            this._proxy.destroy();
            this._proxy = null;
        }

        if (this._actionsProxy) {
            this._actionsProxy = null;
        }
    },

    _ensureActionsProxy: function(callback) {
        if (this._actionsProxy) {
            if (callback) {
                callback.call(this);
            }
            return;
        }
        else {
            this._actionsProxy = new DBus.GtkActions(Lang.bind(this,
                function(proxy, error)
                {
                    if (!error) {
                        if (callback) {
                            callback.call(this);
                        }
                    }
                    else {
                        global.log('Pomodoro: ' + error.message);

                        this._actionsProxy = null;
                        this._notifyIssue();
                    }
                }));
        }
    },

    _onNameAppeared: function() {
        this._ensureProxy();
    },

    _onNameVanished: function() {
        this._destroyProxy();
        this.refresh();
    },

    _onDBusCallback: function(result, error) {
        if (error) {
            global.log('Pomodoro: ' + error.message)
        }
    },

    _onPropertiesChanged: function(proxy, properties) {
        /* TODO: DBus implementation in gjs enforces properties to be cached,
         *       but does not update them properly...
         *       This walkaround may not bee needed in the future
         */
        properties = properties.deep_unpack();

        for (var name in properties) {
            proxy.set_cached_property(name, properties[name]);
        }

        this.refresh();
    },

    _onTaskEntered: function(entry, text) {
        this.tasklist.addTask(new Tasklist.Task(text), {
            animate: true
        });
    },

    _onTaskSelected: function(tasklist, task) {
        global.log("Selected task: " + (task ? task.name : '-'));
    },

    _onNotifyPomodoroStart: function(proxy, senderName, [is_requested]) {

        if (this._notification instanceof Notifications.PomodoroStart) {
            this._notification.show();
            return;
        }

        if (this._notification)
        {
            if (Main.messageTray._trayState == MessageTray.State.SHOWN) {
                this._notification.close();
            }
            else {
                this._notification.destroy();
            }
        }

        this._notification = new Notifications.PomodoroStart();
        this._notification.connect('destroy', Lang.bind(this,
            function(notification) {
                if (this._notification === notification) {
                    this._notification = null;
                }
            }));

        this._notification.show();
    },

    _onNotifyPomodoroEnd: function(proxy, senderName, [is_completed]) {

        if (this._notification instanceof Notifications.PomodoroEnd) {
            this._notification.show();
            return;
        }

        if (this._notification) {
            if (Main.messageTray._trayState == MessageTray.State.SHOWN) {
                this._notification.close();
            }
            else {
                this._notification.destroy();
            }
        }

        let screenNotifications = this._settings.get_boolean('show-screen-notifications');

        this._notification = new Notifications.PomodoroEnd();
        this._notification.connect('action-invoked', Lang.bind(this,
            function(notification, action)
            {
                /* Get current action of a pause switch button */
                if (action == Notifications.Action.SWITCH_TO_PAUSE) {
                    action = notification._pause_switch_button._actionId;
                }

                switch (action)
                {
                    case Notifications.Action.SWITCH_TO_POMODORO:
                        this._proxy.SetStateRemote (State.POMODORO, 0);
                        break;

                    case Notifications.Action.SWITCH_TO_PAUSE:
                        this._proxy.SetStateRemote (State.PAUSE, 0);
                        break;

                    case Notifications.Action.SWITCH_TO_SHORT_PAUSE:
                        this._proxy.SetStateRemote (State.PAUSE, this._settings.get_double('short-break-duration'));
                        break;

                    case Notifications.Action.SWITCH_TO_LONG_PAUSE:
                        this._proxy.SetStateRemote (State.PAUSE, this._settings.get_double('long-break-duration'));
                        break;

                    default:
                        notification.destroy();
                        break;
                }
            }));
        this._notification.connect('clicked', Lang.bind(this,
            function(notification) {
                if (this._notificationDialog) {
                    this._notificationDialog.open();
                    this._notificationDialog.pushModal();
                }
                notification.hide(true);
            }));
        this._notification.connect('destroy', Lang.bind(this,
            function(notification) {
                if (this._notification === notification) {
                    this._notification = null;
                }

                if (this._notificationDialog) {
                    this._notificationDialog.close();
                }

                if (this._reminder) {
                    this._reminder.close();
                    this._reminder = null;
                }
            }));

        if (!this._notificationDialog) {
            this._notificationDialog = new Notifications.PomodoroEndDialog();
            this._notificationDialog.connect('opening', Lang.bind(this,
                function() {
                    if (this._reminder) {
                        this._reminder.close();
                        this._reminder = null;
                    }
                }));
            this._notificationDialog.connect('closing', Lang.bind(this,
                function() {
                    if (this._notification) {
                        this._notification.show();
                    }
                    this._notificationDialog.openWhenIdle();
                }));
            this._notificationDialog.connect('closed', Lang.bind(this,
                function() {
                    this._schedulePomodoroEndReminder();
                }));
            this._notificationDialog.connect('destroy', Lang.bind(this,
                function() {
                    this._notificationDialog = null;
                }));
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
        if (!this._settings.get_boolean('show-reminders')) {
            return;
        }

        if (this._reminder) {
            return;
        }

        this._reminder = new Notifications.PomodoroEndReminder();
        this._reminder.connect('show', Lang.bind(this,
            function(notification) {
                if (!this._proxy || this._proxy.State != State.PAUSE) {
                    notification.close();
                }
                else {
                    /* Don't show reminder if only 90 seconds remain to
                     * next pomodoro
                     */
                    if (this._proxy.StateDuration - this._proxy.Elapsed < 90)
                        notification.close();
                }
            }));
        this._reminder.connect('clicked', Lang.bind(this,
            function() {
                if (this._notificationDialog) {
                    this._notificationDialog.open();
                    this._notificationDialog.pushModal();
                }
            }));
        this._reminder.connect('destroy', Lang.bind(this,
            function(notification) {
                if (this._reminder === notification) {
                    this._reminder = null;
                }
            }));

        this._reminder.schedule();
    },

    _notifyIssue: function() {
        if (this._notification instanceof Notifications.Issue) {
            return;
        }

        this._notification = new Notifications.Issue(_("Looks like gnome-pomodoro is not installed"));
        this._notification.connect('destroy', Lang.bind(this,
            function(notification) {
                if (this._notification === notification)
                    this._notification = null;
            }));
        this._notification.show();
    },

    destroy: function() {
        Main.wm.removeKeybinding('toggle-timer-key');

        if (this._settingsChangedId) {
            this._settings.disconnect(this._settingsChangedId);
        }

        if (this._nameWatcherId) {
            Gio.DBus.session.unwatch_name(this._nameWatcherId);
        }

        if (this._proxy) {
            this._destroyProxy();
        }

        if (this._notificationDialog) {
            this._notificationDialog.destroy();
        }

        if (this._notification) {
            this._notification.destroy();
        }

        this.parent();
    }
});
