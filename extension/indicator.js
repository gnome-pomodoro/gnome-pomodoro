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
const Signals = imports.signals;

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
//const Notifications = Extension.imports.notifications;
const Config = Extension.imports.config;
const Settings = Extension.imports.settings;
const Tasklist = Extension.imports.tasklist;
const Timer = Extension.imports.timer;

const Gettext = imports.gettext.domain(Config.GETTEXT_PACKAGE);
const _ = Gettext.gettext;


const FADE_IN_TIME = 250;
const FADE_IN_OPACITY = 1.0;

const FADE_OUT_TIME = 250;
const FADE_OUT_OPACITY = 0.38;

const FOCUS_WINDOW_TIMEOUT = 3;

const ICON_SIZE = 0.8;
const ICON_STEPS = 360;

const IndicatorType = {
    TEXT: 'text',
    ICON: 'icon'
};


const IndicatorMenu = new Lang.Class({
    Name: 'PomodoroIndicatorMenu',
    Extends: PopupMenu.PopupMenu,

    _init: function(indicator) {
        this.parent(indicator.actor, St.Align.START, St.Side.TOP);

        this.actor.add_style_class_name('extension-pomodoro-indicator');

        this.indicator = indicator;
        this.indicator.timer.connect('state-changed', Lang.bind(this, this._onTimerStateChanged));

        /* Toggle timer state button */
        this._timerToggle = new PopupMenu.PopupSwitchMenuItem(_("Pomodoro Timer"), false, { style_class: 'extension-pomodoro-toggle' });
        this._timerToggle.connect('toggled', Lang.bind(this,
            function() {
                this.indicator.timer.toggle();
            }));
        this.addMenuItem(this._timerToggle);

        /* Task list */
        this.entry = new Tasklist.TaskEntry();
        this.entry.connect('task-entered', Lang.bind(this, this._onTaskEntered));

        /* TODO: Lock focus on the entry once active */
        /* TODO: Add history manager, just as in runDialog */
        /* TODO: More items could be added to context menu */

        this.tasklist = new Tasklist.TaskList();
        this.tasklist.connect('task-selected', Lang.bind(this, this._onTaskSelected));

        this.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this.addAction(_("Manage Tasks"), Lang.bind(this, this._showMainWindow));
        this.addAction(_("Preferences"), Lang.bind(this, this._showPreferences));
        this.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this.addMenuItem(this.tasklist);
        this.addMenuItem(this.entry);
    },

    _onTimerStateChanged: function() {
        let toggled = this.indicator.timer.getState() != Timer.State.NULL;

        if (this._timerToggle.toggled !== toggled) {
            this._timerToggle.setToggleState(toggled);
        }
    },

    _showMainWindow: function() {
        let timestamp = global.get_current_time();

        this.indicator.timer.showMainWindow(timestamp);
    },

    _showPreferences: function() {
        let view = 'timer';
        let timestamp = global.get_current_time();

        this.indicator.timer.showPreferences(view, timestamp);
    },

    _onTaskEntered: function(entry, text) {
        this.tasklist.addTask(new Tasklist.Task(text), {
            animate: true
        });
    },

    _onTaskSelected: function(tasklist, task) {
        global.log("Selected task: " + (task ? task.name : '-'));
    }

});


const Indicator = new Lang.Class({
    Name: 'PomodoroIndicator',
    Extends: PanelMenu.Button,

    _init: function(timer) {
        this.parent(St.Align.START, _("Pomodoro Indicator"), true);

        this.timer = timer;

        this._initialized = false;
        this._settingsChangedId = 0;
        this._state = Timer.State.NULL;
        this._iconProgress = -1.0;

        this.box = new St.Bin({ style_class: 'extension-pomodoro-indicator-box',
                                x_align: St.Align.START,
                                y_align: St.Align.START,
                                x_fill: true,
                                y_fill: true,
                                opacity: FADE_OUT_OPACITY * 255 });  /* FIXME: Icon is faded-in during "null" state */
        this.actor.add_actor(this.box);

        this.icon = new St.DrawingArea({ style_class: 'extension-pomodoro-icon' });
        this.icon.connect('repaint', Lang.bind(this, this._iconRepaint));

        this.label = new St.Label({ style_class: 'extension-pomodoro-label',
                                    y_align: Clutter.ActorAlign.CENTER });
        this.label.clutter_text.set_line_wrap(false);
        this.label.clutter_text.set_ellipsize(Pango.EllipsizeMode.NONE);

        let menu = new IndicatorMenu(this);
        this.setMenu(menu);

        this.menu.connect('open-state-changed',
                          Lang.bind(this, this._onMenuOpenStateChanged));

        try {
            this._settingsChangedId = Extension.extension.settings.connect('changed', Lang.bind(this, this._onSettingsChanged));
        }
        catch (error) {
            Extension.extension.logError(error);
        }

        this._onSettingsChanged();

        this._initialized = true;

        this.timer.connect('update', Lang.bind(this, this._onTimerUpdate));
        this._onTimerUpdate();
    },

    _onSettingsChanged: function() {
        let indicatorType = Extension.extension.settings.get_string('indicator-type');
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

            this._onTimerUpdate();
        }
    },

//    _onPropertiesChanged: function(proxy, properties) {
//        /* TODO: DBus implementation in gjs enforces properties to be cached,
//         *       but does not update them properly...
//         *       This walkaround may not bee needed in the future
//         */
//        properties = properties.deep_unpack();
//
//        for (var name in properties) {
//            proxy.set_cached_property(name, properties[name]);
//        }
//
//        this.refresh();
//    },

    _onMenuOpenStateChanged: function(menu, open) {
        if (open) {
            this._onTimerUpdate();
        }
    },

    _onTimerUpdate: function() {
        let remaining, minutes, seconds, progress, label_text;

        let state = this.timer.getState();
        let toggled = state != Timer.State.NULL;

        if (this._state != state && this._initialized)
        {
            this._state = state;

            if (state == Timer.State.POMODORO || state == Timer.State.IDLE || (state != Timer.State.PAUSE && this._type == IndicatorType.ICON)) {
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

            this._iconProgress = -1.0;  /* force refresh */
        }

        if (toggled) {
            remaining = this.timer.getRemaining();

            minutes = Math.floor(remaining / 60);
            seconds = Math.floor(remaining % 60);
        }
        else {
            minutes = 0;
            seconds = 0;
        }

        if (this._type == IndicatorType.ICON) {
            progress = (state != Timer.State.IDLE)
                    ? Math.floor(this.timer.getProgress() * ICON_STEPS) / ICON_STEPS
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

        if (this._state && this._state != Timer.State.NULL)
        {
            let angle1 = - 0.5 * Math.PI;
            let angle2 = 2.0 * Math.PI * progress - 0.5 * Math.PI;
            let negative = (this._state == Timer.State.PAUSE);

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

    destroy: function() {
        if (this._settingsChangedId) {
            Extension.extension.settings.disconnect(this._settingsChangedId);
        }

        this.label.destroy();
        this.icon.destroy();

        this.parent();
    }
});
