/*
 * Copyright (c) 2011-2013 gnome-pomodoro contributors
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
 * Authors: Arun Mahapatra <pratikarun@gmail.com>
 *          Kamil Prusko <kamilprusko@gmail.com>
 */

const Lang = imports.lang;
const Mainloop = imports.mainloop;
const Cairo = imports.cairo;

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
const FADE_OUT_OPACITY = 0.38;

const FOCUS_WINDOW_TIMEOUT = 3;

const ICON_SIZE = 0.8;
const ICON_STEPS = 720;

const State = {
    NULL: 'null',
    POMODORO: 'pomodoro',
    PAUSE: 'pause',
    IDLE: 'idle'
};

const IndicatorType = {
    TEXT: 'text',
    ICON: 'icon'
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

        this.box = new St.Bin({ style_class: 'extension-pomodoro-indicator-box',
                                x_align: St.Align.START,
                                y_align: St.Align.START,
                                x_fill: true,
                                y_fill: true,
                                opacity: FADE_OUT_OPACITY * 255 });  /* FIXME: Icon is faded-in during "null" state */
        this.actor.add_actor(this.box);

        this.icon = new St.DrawingArea({ style_class: 'extension-pomodoro-icon' });
        this.icon.connect('repaint', Lang.bind(this, this._iconRepaint));
        this._iconProgress = -1.0;

        this.label = new St.Label({ style_class: 'extension-pomodoro-label',
                                    y_align: Clutter.ActorAlign.CENTER });
        this.label.clutter_text.set_line_wrap(false);
        this.label.clutter_text.set_ellipsize(Pango.EllipsizeMode.NONE);

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
        this.menu.addAction(_("Manage Tasks"), Lang.bind(this, this._showMainWindow));
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

    _showMainWindow: function() {
        this._ensureProxy(Lang.bind(this,
            function() {
                let timestamp = global.get_current_time();

                this._proxy.ShowMainWindowRemote(timestamp);
            }));
    },

    _showPreferences: function() {
        this._ensureProxy(Lang.bind(this,
            function() {
                let view = 'timer';
                let timestamp = global.get_current_time();

                this._proxy.ShowPreferencesRemote(view, timestamp);
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

        let indicatorType = this._settings.get_string('indicator-type');
        if (this._type != indicatorType) {
            this._type = indicatorType;

            for (let child = this.box.get_first_child();
                 child;
                 child = child.get_next_sibling()) {
                 child.unparent();
            }

            if (this._type == IndicatorType.ICON) {
                this.box.add_actor(this.icon);
            }
            else {
                this.box.add_actor(this.label);
            }

            this.refresh();
        }
    },

    _getPreferredWidth: function(actor, forHeight, alloc) {
        let min_width, natural_width;

        let theme_node = actor.get_theme_node();
        let min_hpadding = theme_node.get_length('-minimum-hpadding');
        let natural_hpadding = theme_node.get_length('-natural-hpadding');

        if (this._type == IndicatorType.ICON) {
            min_width = forHeight - 2 * theme_node.get_length('-minimum-vpadding');
            natural_width = forHeight - 2 * theme_node.get_length('-natural-vpadding');
        }
        else {
            let context     = actor.get_pango_context();
            let font        = theme_node.get_font();
            let metrics     = context.get_metrics(font, context.get_language());
            let digit_width = metrics.get_approximate_digit_width() / Pango.SCALE;
            let char_width  = metrics.get_approximate_char_width() / Pango.SCALE;

            min_width = Math.floor(digit_width * 4 + 0.5 * char_width);
            natural_width = min_width;
        }

        let predicted_min_size     = min_width + 2 * min_hpadding;
        let predicted_natural_size = natural_width + 2 * natural_hpadding;

        this.parent(actor, forHeight, alloc);  /* output stored in alloc */

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

    _iconRepaint: function(area) {
        let cr = area.get_context();
        let themeNode = area.get_theme_node();
        let [width, height] = area.get_surface_size();

        let radius = Math.min(width, height) * 0.85 * ICON_SIZE / 2;
        let progress = Math.max(this._iconProgress, 0.001);

        let color = themeNode.get_foreground_color();
        let supplementColor = new Clutter.Color({
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha * FADE_OUT_OPACITY
        });

        cr.translate(width / 2,
                     height / 2);

        cr.setOperator(Cairo.Operator.SOURCE);
        cr.setLineCap(Cairo.LineCap.ROUND);

        if (this._state && this._state != State.NULL)
        {
            let angle1 = - 0.5 * Math.PI;
            let angle2 = 2.0 * Math.PI * progress - 0.5 * Math.PI;
            let negative = (this._state == State.PAUSE);

            /* background pie */
            if (!negative)
            {
                Clutter.cairo_set_source_color(cr, supplementColor);
                cr.setLineWidth(2.1);

                cr.arc(0, 0, radius, 0.0, 2.0 * Math.PI);
                cr.stroke();
            }

            /* foreground pie */
            Clutter.cairo_set_source_color(cr, color);
            if (!negative) {
                cr.arc(0, 0, radius, angle1, angle2);
            }
            else {
                cr.arcNegative(0, 0, radius, angle1, angle2);
            }

            cr.setOperator(Cairo.Operator.CLEAR);
            cr.setLineWidth(3.5);
            cr.strokePreserve();

            cr.setOperator(Cairo.Operator.SOURCE);
            cr.setLineWidth(2.2);
            cr.stroke();
        }
        else {
            Clutter.cairo_set_source_color(cr, supplementColor);
            cr.setLineWidth(2.1);
            cr.arc(0, 0, radius, 0.0, 2.0 * Math.PI);
            cr.stroke();
        }

        cr.$dispose();
    },

    _getProgress: function() {
        if (this._proxy && this._proxy.StateDuration > 0) {
            return this._proxy.Elapsed / this._proxy.StateDuration;
        }

        return 0.0;
    },

    refresh: function() {
        let remaining, minutes, seconds, label_text;

        let state = this._proxy ? this._proxy.State : null;
        let toggled = state !== null && state !== State.NULL;

        if (this._state !== state && this._initialized)
        {
            this._state = state;

            if (state == State.POMODORO || state == State.IDLE || (state != State.PAUSE && this._type == IndicatorType.ICON)) {
                Tweener.addTween(this.box,
                                 { opacity: FADE_IN_OPACITY * 255,
                                   time: FADE_IN_TIME / 1000,
                                   transition: 'easeOutQuad' });
            }
            else {
                Tweener.addTween(this.box,
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

            this._iconProgress = -1.0;  /* force refresh */
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

        if (this._type == IndicatorType.ICON) {
            let progress = (state != State.IDLE)
                    ? Math.floor(this._getProgress() * ICON_STEPS) / ICON_STEPS
                    : 0.0;

            if (progress != this._iconProgress) {
                this._iconProgress = progress;
                this.icon.queue_repaint();
            }
        }
        else {
            if (this._type == 'short') {
                label_text = minutes > 0
                        ? '%2dm'.format(minutes)
                        : '%2ds'.format(seconds);
            }
            else {
                label_text = '%02d:%02d'.format(minutes, seconds);
            }

            this.label.set_text(label_text);
        }
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


        if (this._notificationDialog) {
            this._notificationDialog.destroy();
        }

        this.label.destroy();
        this.icon.destroy();

        this.parent();
    }
});
