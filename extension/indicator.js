/*
 * Copyright (c) 2011-2014 gnome-pomodoro contributors
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
const GObject = imports.gi.GObject;
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

const ICON_SIZE = 0.8;
const ICON_STEPS = 360;

const IndicatorType = {
    TEXT: 'text',
    TEXT_SMALL: 'text-small',
    ICON: 'icon'
};


const IndicatorMenu = new Lang.Class({
    Name: 'PomodoroIndicatorMenu',
    Extends: PopupMenu.PopupMenu,

    _init: function(indicator) {
        this.parent(indicator.actor, St.Align.START, St.Side.TOP);

        this.actor.add_style_class_name('extension-pomodoro-indicator-menu');

        this.indicator = indicator;
        this.indicator.timer.connect('state-changed', Lang.bind(this, this._onTimerStateChanged));

        /* Toggle timer state button */
        this._timerToggle = new PopupMenu.PopupSwitchMenuItem(_("Pomodoro Timer"), false);
        this._timerToggle.connect('toggled', Lang.bind(this,
            function() {
                this.indicator.timer.toggle();
            }));
        this.addMenuItem(this._timerToggle);

        /* Task list */
        // this.entry = new Tasklist.TaskEntry();
        // this.entry.connect('task-entered', Lang.bind(this, this._onTaskEntered));

        /* TODO: Lock focus on the entry once active */
        /* TODO: Add history manager, just as in runDialog */
        /* TODO: More items could be added to context menu */

        // this.tasklist = new Tasklist.TaskList();
        // this.tasklist.connect('task-selected', Lang.bind(this, this._onTaskSelected));

        this.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this.addAction(_("Manage Tasks"), Lang.bind(this, this._showMainWindow));
        this.addAction(_("Preferences"), Lang.bind(this, this._showPreferences));
        // this.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        // this.addMenuItem(this.tasklist);
        // this.addMenuItem(this.entry);
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


const TextIndicator = new Lang.Class({
    Name: 'PomodoroTextIndicator',

    _init : function(timer) {
        this._initialized     = false;
        this._actorDestroyed  = false;
        this._state           = Timer.State.NULL;
        this._minHPadding     = 0;
        this._natHPadding     = 0;
        this._digitWidth      = 0;
        this._charWidth       = 0;
        this._onTimerUpdateId = 0;

        this.timer = timer;

        this.actor = new Shell.GenericContainer({ reactive: true });
        this.actor._delegate = this;

        this.label = new St.Label({ style_class: 'system-status-label',
                                    x_align: Clutter.ActorAlign.CENTER,
                                    y_align: Clutter.ActorAlign.CENTER });
        this.label.clutter_text.line_wrap = false;
        this.label.clutter_text.ellipsize = false;
        this.label.connect('destroy', Lang.bind(this, function() {
            this.timer.disconnect(this._onTimerUpdateId);
            this._actorDestroyed = true;
        }));
        this.actor.add_child(this.label);

        this.actor.connect('get-preferred-width', Lang.bind(this, this._getPreferredWidth));
        this.actor.connect('get-preferred-height', Lang.bind(this, this._getPreferredHeight));
        this.actor.connect('allocate', Lang.bind(this, this._allocate));
        this.actor.connect('style-changed', Lang.bind(this, this._onStyleChanged));

        this._onTimerUpdateId = this.timer.connect('update', Lang.bind(this, this._onTimerUpdate));

        this._onTimerUpdate();

        this._state = this.timer.getState();
        this._initialized = true;

        if (this._state == Timer.State.POMODORO ||
            this._state == Timer.State.IDLE)
        {
            this.actor.set_opacity(FADE_IN_OPACITY * 255);
        }
        else {
            this.actor.set_opacity(FADE_OUT_OPACITY * 255);
        }
    },

    _onStyleChanged: function(actor) {
        let themeNode = actor.get_theme_node();
        let font      = themeNode.get_font();
        let context   = actor.get_pango_context();
        let metrics   = context.get_metrics(font, context.get_language());

        this._minHPadding = themeNode.get_length('-minimum-hpadding');
        this._natHPadding = themeNode.get_length('-natural-hpadding');
        this._digitWidth  = metrics.get_approximate_digit_width() / Pango.SCALE;
        this._charWidth   = metrics.get_approximate_char_width() / Pango.SCALE;
    },

    _getWidth: function() {
        return Math.ceil(4 * this._digitWidth + 0.5 * this._charWidth);
    },

    _getPreferredWidth: function(actor, forHeight, alloc) {
        let child        = actor.get_first_child();
        let minWidth     = this._getWidth();
        let naturalWidth = minWidth;

        minWidth     += 2 * this._minHPadding;
        naturalWidth += 2 * this._natHPadding;

        if (child) {
            [alloc.min_size, alloc.natural_size] = child.get_preferred_width(-1);
        } else {
            alloc.min_size = alloc.natural_size = 0;
        }

        if (alloc.min_size < minWidth) {
            alloc.min_size = minWidth;
        }

        if (alloc.natural_size < naturalWidth) {
            alloc.natural_size = naturalWidth;
        }
    },

    _getPreferredHeight: function(actor, forWidth, alloc) {
        let child = actor.get_first_child();

        if (child) {
            [alloc.min_size, alloc.natural_size] = child.get_preferred_height(-1);
        } else {
            alloc.min_size = alloc.natural_size = 0;
        }
    },

    _getText: function(state, remaining) {
        let minutes = Math.floor(remaining / 60);
        let seconds = Math.floor(remaining % 60);

        return '%02d:%02d'.format(minutes, seconds);
    },

    _onTimerUpdate: function() {
        if (this._actorDestroyed) {
            return;
        }

        let state = this.timer.getState();

        if (this._state != state && this._initialized)
        {
            this._state = state;

            if (state == Timer.State.POMODORO || state == Timer.State.IDLE) {
                Tweener.addTween(this.actor,
                                 { opacity: FADE_IN_OPACITY * 255,
                                   time: FADE_IN_TIME / 1000,
                                   transition: 'easeOutQuad' });
            }
            else {
                Tweener.addTween(this.actor,
                                 { opacity: FADE_OUT_OPACITY * 255,
                                   time: FADE_OUT_TIME / 1000,
                                   transition: 'easeOutQuad' });
            }
        }

        let remaining = this.timer.getRemaining();

        this.label.set_text(this._getText(state, remaining));
    },

    _allocate: function(actor, box, flags) {
        let child = actor.get_first_child();
        if (!child)
            return;

        let [minWidth, natWidth] = child.get_preferred_width(-1);

        let availWidth  = box.x2 - box.x1;
        let availHeight = box.y2 - box.y1;

        let childBox = new Clutter.ActorBox();
        childBox.y1 = 0;
        childBox.y2 = availHeight;

        if (natWidth + 2 * this._natHPadding <= availWidth) {
            childBox.x1 = this._natHPadding;
            childBox.x2 = availWidth - this._natHPadding;
        } else {
            childBox.x1 = this._minHPadding;
            childBox.x2 = availWidth - this._minHPadding;
        }

        child.allocate(childBox, flags);
    },

    destroy: function() {
        this.actor.destroy();

        this.emit('destroy');
    }
});


const ShortTextIndicator = new Lang.Class({
    Name: 'PomodoroShortTextIndicator',
    Extends: TextIndicator,

    _init: function(timer) {
        this.parent(timer);

        this.label.set_x_align(Clutter.ActorAlign.END);
    },

    _getWidth: function() {
        return Math.ceil(2 * this._digitWidth +
                         1 * this._charWidth);
    },

    _getText: function(state, remaining) {
        let minutes = Math.round(remaining / 60);
        let seconds = Math.round(remaining % 60);

        if (remaining > 15) {
            seconds = Math.ceil(seconds / 15) * 15;
        }

        return (remaining <= 45)
                ? _("%ds").format(seconds, remaining)
                : _("%dm").format(minutes, remaining);
    }
});


const IconIndicator = new Lang.Class({
    Name: 'PomodoroIconIndicator',

    _init : function(timer) {
        this._initialized     = false;
        this._actorDestroyed  = false;
        this._state           = Timer.State.NULL;
        this._progress        = -1.0;
        this._minHPadding     = 0;
        this._natHPadding     = 0;
        this._minVPadding     = 0;
        this._natVPadding     = 0;
        this._primaryColor    = null;
        this._secondaryColor  = null;
        this._onTimerUpdateId = 0;

        this.timer = timer;

        this.actor = new Shell.GenericContainer({ reactive: true });
        this.actor._delegate = this;

        this.icon = new St.DrawingArea({ style_class: 'system-status-icon' });
        this.icon.connect('repaint', Lang.bind(this, this._repaint));
        this.icon.connect('destroy', Lang.bind(this, function() {
            this.timer.disconnect(this._onTimerUpdateId);
            this._actorDestroyed = true;
        }));
        this.actor.add_child(this.icon);

        this.actor.connect('get-preferred-width', Lang.bind(this, this._getPreferredWidth));
        this.actor.connect('get-preferred-height', Lang.bind(this, this._getPreferredHeight));
        this.actor.connect('allocate', Lang.bind(this, this._allocate));
        this.actor.connect('style-changed', Lang.bind(this, this._onStyleChanged));

        this._onTimerUpdateId = this.timer.connect('update', Lang.bind(this, this._onTimerUpdate));

        this._onTimerUpdate();

        this._state = this.timer.getState();
        this._initialized = true;
    },

    _onStyleChanged: function(actor) {
        let themeNode = actor.get_theme_node();

        this._minHPadding = themeNode.get_length('-minimum-hpadding');
        this._natHPadding = themeNode.get_length('-natural-hpadding');
        this._minVPadding = themeNode.get_length('-minimum-vpadding');
        this._natVPadding = themeNode.get_length('-natural-vpadding');

        let color = themeNode.get_foreground_color()
        this._primaryColor = color;
        this._secondaryColor = new Clutter.Color({
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha * FADE_OUT_OPACITY
        });
    },

    _getPreferredWidth: function(actor, forHeight, alloc) {
        let minWidth     = forHeight - 2 * this._minVPadding;
        let naturalWidth = forHeight - 2 * this._natVPadding;
        let child        = actor.get_first_child();

        minWidth     += 2 * this._minHPadding;
        naturalWidth += 2 * this._natHPadding;

        if (child) {
            [alloc.min_size, alloc.natural_size] = child.get_preferred_width(-1);
        } else {
            alloc.min_size = alloc.natural_size = 0;
        }

        if (alloc.min_size < minWidth) {
            alloc.min_size = minWidth;
        }

        if (alloc.natural_size < naturalWidth) {
            alloc.natural_size = naturalWidth;
        }
    },

    _getPreferredHeight: function(actor, forWidth, alloc) {
        let child = actor.get_first_child();

        if (child) {
            [alloc.min_size, alloc.natural_size] = child.get_preferred_height(-1);
        } else {
            alloc.min_size = alloc.natural_size = 0;
        }
    },

    _onTimerUpdate: function() {
        if (this._actorDestroyed) {
            return;
        }

        let state = this.timer.getState();
        let progress = this.timer.getProgress();

        if (this._state != state && this._initialized)
        {
            this._state = state;
            this._progress = -1.0;  /* force refresh */
        }

        if (this._progress != progress)
        {
            this._progress = progress;
            this.icon.queue_repaint();
        }
    },

    _allocate: function(actor, box, flags) {
        let child = actor.get_first_child();
        if (!child)
            return;

        let [minWidth, natWidth] = child.get_preferred_width(-1);

        let availWidth  = box.x2 - box.x1;
        let availHeight = box.y2 - box.y1;

        let childBox = new Clutter.ActorBox();
        childBox.y1 = 0;
        childBox.y2 = availHeight;

        if (natWidth + 2 * this._natHPadding <= availWidth) {
            childBox.x1 = this._natHPadding;
            childBox.x2 = availWidth - this._natHPadding;
        } else {
            childBox.x1 = this._minHPadding;
            childBox.x2 = availWidth - this._minHPadding;
        }

        child.allocate(childBox, flags);
    },

    _repaint: function(area) {
        let cr = area.get_context();
        let [width, height] = area.get_surface_size();

        let radius   = Math.min(width, height) * 0.85 * ICON_SIZE / 2;
        let progress = Math.max(this._progress, 0.001);

        cr.translate(0.5 * width, 0.5 * height);
        cr.setOperator(Cairo.Operator.SOURCE);
        cr.setLineCap(Cairo.LineCap.ROUND);

        if (this._state && this._state != Timer.State.NULL)
        {
            let angle1   = - 0.5 * Math.PI;
            let angle2   = - 0.5 * Math.PI + 2.0 * Math.PI * progress;
            let negative = (this._state == Timer.State.PAUSE);

            /* background pie */
            if (!negative)
            {
                Clutter.cairo_set_source_color(cr, this._secondaryColor);
                cr.setLineWidth(2.1);

                cr.arc(0, 0, radius, 0.0, 2.0 * Math.PI);
                cr.stroke();
            }

            /* foreground pie */
            Clutter.cairo_set_source_color(cr, this._primaryColor);
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
            Clutter.cairo_set_source_color(cr, this._secondaryColor);
            cr.setLineWidth(2.1);
            cr.arc(0, 0, radius, 0.0, 2.0 * Math.PI);
            cr.stroke();
        }

        cr.$dispose();
    },

    destroy: function() {
        this.actor.destroy();

        this.emit('destroy');
    }
});


const Indicator = new Lang.Class({
    Name: 'PomodoroIndicator',
    Extends: PanelMenu.Button,

    _init: function(timer) {
        this.parent(St.Align.START, _("Pomodoro"), true);

        this.timer  = timer;
        this.widget = null;

        this.actor.add_style_class_name('extension-pomodoro-indicator');

        this._arrow = PopupMenu.arrowIcon(St.Side.BOTTOM);

        this._hbox = new St.BoxLayout({ style_class: 'panel-status-menu-box' });
        this._hbox.pack_start = true;
        this._hbox.add_child(this._arrow, { expand: false,
                                            x_fill: false,
                                            x_align: St.Align.END });
        this.actor.add_child(this._hbox);

        this.setMenu(new IndicatorMenu(this));

        this._settingsChangedId = Extension.extension.settings.connect('changed::indicator-type', Lang.bind(this, this._onSettingsChanged));

        this._onSettingsChanged();
    },

    _onSettingsChanged: function() {
        let indicatorType = Extension.extension.settings.get_string('indicator-type');

        if (this.widget) {
            this.widget.destroy();
        }

        switch(indicatorType)
        {
            case IndicatorType.ICON:
                this.widget = new IconIndicator(this.timer);
                break;

            case IndicatorType.TEXT_SMALL:
                this.widget = new ShortTextIndicator(this.timer);
                break;

            default:
                this.widget = new TextIndicator(this.timer);
        }

        this.widget.actor.bind_property('opacity',
                                        this._arrow,
                                        'opacity',
                                        GObject.BindingFlags.SYNC_CREATE);

        this._hbox.add_child(this.widget.actor, { expand: false,
                                                  x_fill: false,
                                                  x_align: St.Align.START });
    }
});
