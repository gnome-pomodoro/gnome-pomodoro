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
const Gtk = imports.gi.Gtk;
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

const Config = Extension.imports.config;
const Timer = Extension.imports.timer;

const Gettext = imports.gettext.domain(Config.GETTEXT_PACKAGE);
const _ = Gettext.gettext;


const FADE_IN_TIME = 1250;
const FADE_IN_OPACITY = 1.0;

const FADE_OUT_TIME = 1250;
const FADE_OUT_OPACITY = 0.38;

const STEPS = 120;

const IndicatorType = {
    TEXT: 'text',
    SHORT_TEXT: 'short-text',
    ICON: 'icon'
};


const IndicatorMenu = new Lang.Class({
    Name: 'PomodoroIndicatorMenu',
    Extends: PopupMenu.PopupMenu,

    _init: function(indicator) {
        this.parent(indicator.actor, St.Align.START, St.Side.TOP);

        this._timerUpdateId = 0;

        this.actor.add_style_class_name('extension-pomodoro-indicator-menu');

        this._actorMappedId = this.actor.connect('notify::mapped', Lang.bind(this, this._onActorMapped));

        this.indicator = indicator;

        this._createTimerMenuItem();

        this.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this.addAction(_("Preferences"), Lang.bind(this, this._activatePreferences));
        this.addAction(_("Quit"), Lang.bind(this, this._activateQuit));
    },

    _createActionButton: function(iconName, accessibleName) {
        let button = new St.Button({ reactive: true,
                                     can_focus: true,
                                     track_hover: true,
                                     accessible_name: accessibleName,
                                     style_class: 'system-menu-action extension-pomodoro-menu-action' });
        button.child = new St.Icon({ icon_name: iconName });
        return button;
    },

    _onTimerClicked: function() {
        this.close();

        if (Extension.extension && Extension.extension.dialog) {
            Extension.extension.dialog.open(true);
            Extension.extension.dialog.pushModal();
        }
    },

    _onStartClicked: function() {
        this.indicator.timer.start();

        this.close();
    },

    _onStopClicked: function() {
        this.indicator.timer.stop();

        this.close();
    },

    _onPauseClicked: function() {
        if (!this.indicator.timer.isPaused ()) {
            this.indicator.timer.pause();
        }
        else {
            this.indicator.timer.resume();

            this.close();
        }
    },

    _createTimerMenuItem: function() {
        let item;
        let hbox;

        item = new PopupMenu.PopupMenuItem(_("Pomodoro Timer"),
                                           { style_class: 'extension-pomodoro-menu-timer',
                                            reactive: false,
                                            can_focus: false });
        item.label.y_align = Clutter.ActorAlign.CENTER;

        this._timerMenuItem = item;
        this._timerLabel = new St.Label({ style_class: 'extension-pomodoro-menu-timer-label',
                                          y_align: Clutter.ActorAlign.CENTER });
        this._timerLabelButton = new St.Button({ reactive: false,
                                                 can_focus: false,
                                                 track_hover: false,
                                                 style_class: 'extension-pomodoro-menu-timer-label-button' });
        this._timerLabelButton.child = this._timerLabel;
        this._timerLabelButton.connect('clicked', Lang.bind(this, this._onTimerClicked));

        hbox = new St.BoxLayout();

        this._startAction = this._createActionButton('media-playback-start-symbolic', _("Start Timer"));
        this._startAction.add_style_class_name('extension-pomodoro-menu-action-border');
        this._startAction.connect('clicked', Lang.bind(this, this._onStartClicked));
        hbox.add_actor(this._startAction);

        this._pauseAction = this._createActionButton('media-playback-pause-symbolic', _("Pause Timer"));
        this._pauseAction.connect('clicked', Lang.bind(this, this._onPauseClicked));
        hbox.add_actor(this._pauseAction);

        this._stopAction = this._createActionButton('media-playback-stop-symbolic', _("Stop Timer"));
        this._stopAction.connect('clicked', Lang.bind(this, this._onStopClicked));
        hbox.add_actor(this._stopAction);

        item.actor.add(this._timerLabelButton, { expand: true });
        item.actor.add(hbox);

        this.addMenuItem(item);

        this.timerLabel = this._timerLabel;
        this.pauseAction = this._pauseAction;

        this.addStateMenuItem('pomodoro', _("Pomodoro"));
        this.addStateMenuItem('short-break', _("Short Break"));
        this.addStateMenuItem('long-break', _("Long Break"));
    },

    addStateMenuItem: function(name, label) {
        if (!this._stateItems) {
            this._stateItems = {};
        }

        let menuItem = this.addAction(label, Lang.bind(this,
            function(menuItem, event) {
                this._activateState(name);
            }));

        menuItem.actor.add_style_class_name('state-item');

        this._stateItems[name] = menuItem;

        return menuItem;
    },

    _onActorMapped: function(actor) {
        if (actor.mapped && this._timerUpdateId == 0) {
            this._timerUpdateId = this.indicator.timer.connect('update', Lang.bind(this, this._onTimerUpdate));
            this._onTimerUpdate();
        }

        if (!actor.mapped && this._timerUpdateId != 0) {
            this.indicator.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }
    },

    _onTimerUpdate: function() {
        let timer = this.indicator.timer;
        let timerState = timer.getState();
        let remaining = timer.getRemaining();
        let isRunning = timerState != Timer.State.NULL;
        let isPaused = timer.isPaused();

        if (this._isRunning !== isRunning ||
            this._isPaused !== isPaused ||
            this._timerState !== timerState)
        {
            this._isRunning = isRunning;
            this._isPaused = isPaused;
            this._timerState = timerState;

            this._timerMenuItem.label.visible = !isRunning;
            this._timerLabel.visible = isRunning;
            this._timerLabelButton.reactive = isRunning && !isPaused && timerState != Timer.State.POMODORO;
            this._startAction.visible = !isRunning;
            this._stopAction.visible = isRunning;
            this._pauseAction.visible = isRunning;
            this._pauseAction.child.icon_name = isPaused
                                                ? 'media-playback-start-symbolic'
                                                : 'media-playback-pause-symbolic';
            this._pauseAction.accessible_name = isPaused
                                                ? _("Resume Timer")
                                                : _("Pause Timer");

            if (isRunning) {
                this._timerMenuItem.actor.add_style_class_name('extension-pomodoro-menu-timer-running');
            }
            else {
                this._timerMenuItem.actor.remove_style_class_name('extension-pomodoro-menu-timer-running');
            }

            for (let key in this._stateItems) {
                let stateItem = this._stateItems[key];

                stateItem.actor.visible = isRunning;

                if (key == timerState) {
                    stateItem.setOrnament(PopupMenu.Ornament.DOT);
                    stateItem.actor.add_style_class_name('active');
                }
                else {
                    stateItem.setOrnament(PopupMenu.Ornament.NONE);
                    stateItem.actor.remove_style_class_name('active');
                }
            }
        }

        this.timerLabel.set_text(this._formatTime(remaining));
    },

    _formatTime: function(remaining) {
        if (remaining < 0.0) {
            remaining = 0.0;
        }

        let minutes = Math.floor(remaining / 60);
        let seconds = Math.floor(remaining % 60);

        return '%02d:%02d'.format(minutes, seconds);
    },

    _activatePreferences: function() {
        let timestamp = global.get_current_time();

        this.indicator.timer.showPreferences(timestamp);
    },

    _activateQuit: function() {
        this.indicator.timer.quit();
    },

    _activateState: function(stateName) {
        this.indicator.timer.setState(stateName);
    },

    destroy: function() {
        if (this._timerUpdateId) {
            this.indicator.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }

        if (this._actorMappedId) {
            this.actor.disconnect(this._actorMappedId);
            this._actorMappedId = 0;
        }

        this.indicator = null;

        this.parent();
    }
});


const TextIndicator = new Lang.Class({
    Name: 'PomodoroTextIndicator',

    _init : function(timer) {
        this._initialized     = false;
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
        this.label.connect('destroy', Lang.bind(this,
            function() {
                if (this._onTimerUpdateId) {
                    this.timer.disconnect(this._onTimerUpdateId);
                    this._onTimerUpdateId = 0;
                }
            }));
        this.actor.add_child(this.label);

        this.actor.connect('get-preferred-width', Lang.bind(this, this._getPreferredWidth));
        this.actor.connect('get-preferred-height', Lang.bind(this, this._getPreferredHeight));
        this.actor.connect('allocate', Lang.bind(this, this._allocate));
        this.actor.connect('style-changed', Lang.bind(this, this._onStyleChanged));
        this.actor.connect('destroy', Lang.bind(this, this._onActorDestroy));

        this._onTimerUpdateId = this.timer.connect('update', Lang.bind(this, this._onTimerUpdate));

        this._onTimerUpdate();

        this._state = this.timer.getState();
        this._initialized = true;

        if (this._state == Timer.State.POMODORO) {
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
        }
        else {
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
        }
        else {
            alloc.min_size = alloc.natural_size = 0;
        }
    },

    _getText: function(state, remaining) {
        if (remaining < 0.0) {
            remaining = 0.0;
        }

        let minutes = Math.floor(remaining / 60);
        let seconds = Math.floor(remaining % 60);

        return '%02d:%02d'.format(minutes, seconds);
    },

    _onTimerUpdate: function() {
        let state = this.timer.getState();
        let remaining = this.timer.getRemaining();

        if (this._state != state && this._initialized) {
            this._state = state;

            if (state == Timer.State.POMODORO) {
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
        }
        else {
            childBox.x1 = this._minHPadding;
            childBox.x2 = availWidth - this._minHPadding;
        }

        child.allocate(childBox, flags);
    },

    _onActorDestroy: function() {
        if (this._onTimerUpdateId) {
            this.timer.disconnect(this._onTimerUpdateId);
            this._onTimerUpdateId = 0;
        }

        this.actor._delegate = null;

        this.emit('destroy');
    },

    destroy: function() {
        this.actor.destroy();
    }
});
Signals.addSignalMethods(TextIndicator.prototype);


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
        if (remaining < 0.0) {
            remaining = 0.0;
        }

        let minutes = Math.round(remaining / 60);
        let seconds = Math.round(remaining % 60);

        if (remaining > 15) {
            seconds = Math.ceil(seconds / 15) * 15;
        }

        return (remaining > 45)
                ? "%d′".format(minutes, remaining)
                : "%d″".format(seconds, remaining);
    }
});


const IconIndicator = new Lang.Class({
    Name: 'PomodoroIconIndicator',

    _init : function(timer) {
        this._state           = Timer.State.NULL;
        this._progress        = 0.0;
        this._minHPadding     = 0;
        this._natHPadding     = 0;
        this._minVPadding     = 0;
        this._natVPadding     = 0;
        this._primaryColor    = null;
        this._secondaryColor  = null;
        this._timerUpdateId = 0;

        this.timer = timer;

        this.actor = new Shell.GenericContainer({ reactive: true });
        this.actor._delegate = this;

        this.icon = new St.DrawingArea({ style_class: 'system-status-icon' });
        this.icon.connect('style-changed', Lang.bind(this, this._onIconStyleChanged));
        this.icon.connect('repaint', Lang.bind(this, this._onIconRepaint));
        this.icon.connect('destroy', Lang.bind(this, this._onIconDestroy));
        this.actor.add_child(this.icon);

        this.actor.connect('get-preferred-width', Lang.bind(this, this._getPreferredWidth));
        this.actor.connect('get-preferred-height', Lang.bind(this, this._getPreferredHeight));
        this.actor.connect('allocate', Lang.bind(this, this._allocate));
        this.actor.connect('style-changed', Lang.bind(this, this._onStyleChanged));
        this.actor.connect('destroy', Lang.bind(this, this._onActorDestroy));

        this._timerUpdateId = this.timer.connect('update', Lang.bind(this, this._onTimerUpdate));

        this._onTimerUpdate();

        this._state = this.timer.getState();
    },

    _onIconStyleChanged: function(actor) {
        let themeNode = actor.get_theme_node();
        let size = Math.ceil(themeNode.get_length('icon-size'));

        [actor.min_width, actor.natural_width] = themeNode.adjust_preferred_width(size, size);
        [actor.min_height, actor.natural_height] = themeNode.adjust_preferred_height(size, size);

        this._iconSize = size;
    },

    _onIconRepaint: function(area) {
        let cr = area.get_context();
        let [width, height] = area.get_surface_size();

        let radius    = 0.5 * this._iconSize - 2.0;
        let progress  = this._progress;
        let isRunning = this._state != Timer.State.NULL;
        let isBreak   = (this._state == Timer.State.SHORT_BREAK ||
                         this._state == Timer.State.LONG_BREAK);

        cr.translate(0.5 * width, 0.5 * height);
        cr.setOperator(Cairo.Operator.SOURCE);
        cr.setLineCap(Cairo.LineCap.ROUND);

        let angle1 = - 0.5 * Math.PI - 2.0 * Math.PI * Math.min(Math.max(progress, 0.000001), 1.0);
        let angle2 = - 0.5 * Math.PI;

        /* background pie */
        if (isBreak || !isRunning) {
            Clutter.cairo_set_source_color(cr, this._secondaryColor);
            cr.arcNegative(0, 0, radius, angle1, angle2);
            cr.setLineWidth(2.2);
            cr.stroke();
        }
        else {
            Clutter.cairo_set_source_color(cr, this._secondaryColor);
            cr.arc(0, 0, radius, 0.0, 2.0 * Math.PI);
            cr.setLineWidth(2.2);
            cr.stroke();

            if (angle2 > angle1) {
                Clutter.cairo_set_source_color(cr, this._primaryColor);
                cr.arcNegative(0, 0, radius, angle1, angle2);
                cr.setOperator(Cairo.Operator.CLEAR);
                cr.setLineWidth(3.5);
                cr.strokePreserve();

                cr.setOperator(Cairo.Operator.SOURCE);
                cr.setLineWidth(2.2);
                cr.stroke();
            }
        }

        cr.$dispose();
    },

    _onIconDestroy: function() {
        if (this._timerUpdateId) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }
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
        let child = actor.get_first_child();

        if (child) {
            [alloc.min_size, alloc.natural_size] = child.get_preferred_width(-1);
        }
        else {
            alloc.min_size = alloc.natural_size = 0;
        }

        alloc.min_size += 2 * this._minHPadding;
        alloc.natural_size += 2 * this._natHPadding;
    },

    _getPreferredHeight: function(actor, forWidth, alloc) {
        let child = actor.get_first_child();

        if (child) {
            [alloc.min_size, alloc.natural_size] = child.get_preferred_height(-1);
        }
        else {
            alloc.min_size = alloc.natural_size = 0;
        }

        alloc.min_size += 2 * this._minVPadding;
        alloc.natural_size += 2 * this._natVPadding;
    },

    _onTimerUpdate: function() {
        let state = this.timer.getState();
        let progress = Math.floor(this.timer.getProgress() * STEPS) / STEPS;

        if (this._progress !== progress || this._state !== state) {
            this._state = state;
            this._progress = progress;
            this.icon.queue_repaint();
        }
    },

    _allocate: function(actor, box, flags) {
        let child = actor.get_first_child();
        if (!child) {
            return;
        }

        let availWidth  = box.x2 - box.x1;
        let availHeight = box.y2 - box.y1;

        let [minWidth, natWidth] = child.get_preferred_width(availHeight);

        let childBox = new Clutter.ActorBox();
        childBox.y1 = 0;
        childBox.y2 = availHeight;

        if (natWidth + 2 * this._natHPadding <= availWidth) {
            childBox.x1 = this._natHPadding;
            childBox.x2 = availWidth - this._natHPadding;
        }
        else {
            childBox.x1 = this._minHPadding;
            childBox.x2 = availWidth - this._minHPadding;
        }

        child.allocate(childBox, flags);
    },

    _onActorDestroy: function() {
        if (this._timerUpdateId) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }

        this.timer = null;
        this.icon = null;

        this.actor._delegate = null;

        this.emit('destroy');
    },

    destroy: function() {
        this.actor.destroy();
    }
});
Signals.addSignalMethods(IconIndicator.prototype);


const Indicator = new Lang.Class({
    Name: 'PomodoroIndicator',
    Extends: PanelMenu.Button,

    _init: function(timer, type) {
        this.parent(St.Align.START, _("Pomodoro"), true);

        this.timer  = timer;
        this.widget = null;

        this.actor.add_style_class_name('extension-pomodoro-indicator');
        this.actor.connect('destroy', Lang.bind(this, this._onActorDestroy));

        this._arrow = PopupMenu.arrowIcon(St.Side.BOTTOM);
        this._blinking = false;
        this._blinkTimeoutSource = 0;

        this._hbox = new St.BoxLayout({ style_class: 'panel-status-menu-box' });
        this._hbox.pack_start = true;
        this._hbox.add_child(this._arrow, { expand: false,
                                            x_fill: false,
                                            x_align: St.Align.END });
        this.actor.add_child(this._hbox);

        this.setMenu(new IndicatorMenu(this));
        this.setType(type);

        this._onBlinked();

        this._timerPausedId = this.timer.connect('paused', Lang.bind(this, this._onTimerPaused));
        this._timerResumedId = this.timer.connect('resumed', Lang.bind(this, this._onTimerResumed));
    },

    setType: function(type) {
        if (this.widget) {
            this.widget.destroy();
            this.widget = null;
        }

        switch (type) {
            case IndicatorType.TEXT:
                this.widget = new TextIndicator(this.timer);
                break;

            case IndicatorType.SHORT_TEXT:
                this.widget = new ShortTextIndicator(this.timer);
                break;

            default:
                this.widget = new IconIndicator(this.timer);
                break;
        }

        this.widget.actor.bind_property('opacity',
                                        this._arrow,
                                        'opacity',
                                        GObject.BindingFlags.SYNC_CREATE);

        this._hbox.add_child(this.widget.actor, { expand: false,
                                                  x_fill: false,
                                                  x_align: St.Align.START });
    },

    _onBlinked: function() {
        this._blinking = false;

        if (this.timer.isPaused()) {
            this._blink();
        }
    },

    _blink: function() {
        if (!this._blinking) {
            this._blinking = true;

            let fadeOutParams = {
                time: FADE_OUT_TIME / 1000,
                transition: 'easeInOutQuad',
                opacity: FADE_OUT_OPACITY * 255
            };
            let fadeInParams = {
                time: FADE_IN_TIME / 1000,
                transition: 'easeInOutQuad',
                delay: FADE_OUT_TIME / 1000,
                opacity: FADE_IN_OPACITY * 255,
                onComplete: Lang.bind(this, this._onBlinked)
            };

            if (Gtk.Settings.get_default().gtk_enable_animations) {
                Tweener.addTween(this._hbox, fadeOutParams);
                Tweener.addTween(this._hbox, fadeInParams);
                Tweener.addTween(this.menu.timerLabel, fadeOutParams);
                Tweener.addTween(this.menu.timerLabel, fadeInParams);
                Tweener.addTween(this.menu.pauseAction.child, fadeOutParams);
                Tweener.addTween(this.menu.pauseAction.child, fadeInParams);
            }
            else if (this._blinkTimeoutSource == 0) {
                Tweener.addTween(this._hbox, fadeOutParams);

                this._blinkTimeoutSource = Mainloop.timeout_add (FADE_OUT_TIME, Lang.bind(this,
                    function () {
                        Tweener.addTween(this._hbox, fadeInParams);

                        this._blinkTimeoutSource = Mainloop.timeout_add (FADE_IN_TIME, Lang.bind(this, function () {
                            this._blinkTimeoutSource = 0;

                            this._onBlinked ();

                            return GLib.SOURCE_REMOVE;
                        }));

                        return GLib.SOURCE_REMOVE;
                    }));
            }
        }
    },

    _onTimerPaused: function() {
        this._blink();
    },

    _onTimerResumed: function() {
        if (this._blinking) {
            let fadeInParams = {
                time: 200 / 1000,
                transition: 'easeOutQuad',
                opacity: FADE_IN_OPACITY * 255,
                onComplete: Lang.bind(this, this._onBlinked)
            };

            Tweener.removeTweens(this._hbox);
            Tweener.removeTweens(this.menu.timerLabel);
            Tweener.removeTweens(this.menu.pauseAction.child);

            Tweener.addTween(this._hbox, fadeInParams);
            Tweener.addTween(this.menu.timerLabel, fadeInParams);
            Tweener.addTween(this.menu.pauseAction.child, fadeInParams);

            if (this._blinkTimeoutSource != 0) {
                Mainloop.source_remove(this._blinkTimeoutSource);
                this._blinkTimeoutSource = 0;
            }
        }
    },

    _onActorDestroy: function() {
        Tweener.removeTweens(this._hbox);
        Tweener.removeTweens(this.menu.timerLabel);
        Tweener.removeTweens(this.menu.pauseAction.child);

        if (this._blinkTimeoutSource != 0) {
            Mainloop.source_remove(this._blinkTimeoutSource);
            this._blinkTimeoutSource = 0;
        }

        this.timer.disconnect(this._timerPausedId);
        this.timer.disconnect(this._timerResumedId);
        this.timer = null;

        if (this.icon) {
            this.icon.destroy();
            this.icon = null;
        }
    },

    destroy: function() {
        this.parent();
    }
});
