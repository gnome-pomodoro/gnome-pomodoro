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

const Config = Extension.imports.config;
const Timer = Extension.imports.timer;

const Gettext = imports.gettext.domain(Config.GETTEXT_PACKAGE);
const _ = Gettext.gettext;


const FADE_IN_TIME = 1250;
const FADE_IN_OPACITY = 1.0;

const FADE_OUT_TIME = 1250;
const FADE_OUT_OPACITY = 0.38;

const STEPS = 120;


var IndicatorType = {
    TEXT: 'text',
    SHORT_TEXT: 'short-text',
    ICON: 'icon'
};


var IndicatorMenu = class extends PopupMenu.PopupMenu {
    constructor(indicator) {
        super(indicator, St.Align.START, St.Side.TOP);

        this._isPaused = null;
        this._timerState = null;
        this._timerUpdateId = 0;

        this.actor.add_style_class_name('extension-pomodoro-indicator-menu');

        this._actorMappedId = this.actor.connect('notify::mapped', this._onActorMapped.bind(this));

        this.indicator = indicator;

        this._populate();
    }

    _createActionButton(iconName, accessibleName) {
        let button = new St.Button({ reactive: true,
                                     can_focus: true,
                                     track_hover: true,
                                     accessible_name: accessibleName,
                                     style_class: 'system-menu-action extension-pomodoro-indicator-menu-action' });
        button.child = new St.Icon({ icon_name: iconName });
        return button;
    }

    _onTimerClicked() {
        this.close();

        if (Extension.extension && Extension.extension.dialog) {
            Extension.extension.dialog.open(true);
            Extension.extension.dialog.pushModal();
        }
    }

    _onStartClicked() {
        this.indicator.timer.start();

        this.close();
    }

    _onStopClicked() {
        this.indicator.timer.stop();

        this.close();
    }

    _onPauseClicked() {
        if (!this.indicator.timer.isPaused ()) {
            this.indicator.timer.pause();
        }
        else {
            this.indicator.timer.resume();

            this.close();
        }
    }

    _populate() {
        let toggleItem = new PopupMenu.PopupMenuItem(_("Pomodoro Timer"),
                                           { style_class: 'extension-pomodoro-indicator-menu-toggle',
                                             reactive: false,
                                             can_focus: false });
        toggleItem.label.y_align = Clutter.ActorAlign.CENTER;
        this.addMenuItem(toggleItem);

        let startAction = this._createActionButton('media-playback-start-symbolic', _("Start Timer"));
        startAction.add_style_class_name('extension-pomodoro-indicator-menu-action-border');
        startAction.connect('clicked', this._onStartClicked.bind(this));
        toggleItem.add_child(startAction);

        let timerItem = new PopupMenu.PopupMenuItem("",
                                           { style_class: 'extension-pomodoro-indicator-menu-timer',
                                             reactive: false,
                                             can_focus: false });
        timerItem.label.visible = false;
        this.addMenuItem(timerItem);

        let timerLabel = new St.Label({ style_class: 'extension-pomodoro-indicator-menu-timer-label',
                                        y_align: Clutter.ActorAlign.CENTER });
        let timerLabelButton = new St.Button({ reactive: false,
                                               can_focus: false,
                                               track_hover: false,
                                               style_class: 'extension-pomodoro-indicator-menu-timer-label-button' });
        timerLabelButton.child = timerLabel;
        timerLabelButton.connect('clicked', this._onTimerClicked.bind(this));
        timerItem.add_child(timerLabelButton);

        let hbox = new St.BoxLayout({ x_align: Clutter.ActorAlign.END,
                                      x_expand: true });
        timerItem.add_child(hbox);

        let pauseAction = this._createActionButton('media-playback-pause-symbolic', _("Pause Timer"));
        pauseAction.connect('clicked', this._onPauseClicked.bind(this));
        hbox.add_actor(pauseAction);

        let stopAction = this._createActionButton('media-playback-stop-symbolic', _("Stop Timer"));
        stopAction.connect('clicked', this._onStopClicked.bind(this));
        hbox.add_actor(stopAction);

        this._toggleMenuItem = toggleItem;
        this._timerMenuItem = timerItem;
        this._timerLabelButton = timerLabelButton;

        this.timerLabel = timerLabel;
        this.pauseAction = pauseAction;

        this.addStateMenuItem('pomodoro', _("Pomodoro"));
        this.addStateMenuItem('short-break', _("Short Break"));
        this.addStateMenuItem('long-break', _("Long Break"));

        this.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        this.addAction(_("Preferences"), this._activatePreferences.bind(this));
        this.addAction(_("Stats"), this._activateStats.bind(this));
        this.addAction(_("Quit"), this._activateQuit.bind(this));
    }

    addStateMenuItem(name, label) {
        if (!this._stateItems) {
            this._stateItems = {};
        }

        let menuItem = this.addAction(label, (menuItem, event) => {
                this._activateState(name);
            });

        menuItem.add_style_class_name('state-item');

        this._stateItems[name] = menuItem;

        return menuItem;
    }

    _onActorMapped(actor) {
        if (actor.mapped && this._timerUpdateId == 0) {
            this._timerUpdateId = this.indicator.timer.connect('update', this._onTimerUpdate.bind(this));
            this._onTimerUpdate();
        }

        if (!actor.mapped && this._timerUpdateId != 0) {
            this.indicator.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }
    }

    _onTimerUpdate() {
        let timer = this.indicator.timer;
        let timerState = timer.getState();
        let remaining = timer.getRemaining();
        let isPaused = timer.isPaused();
        let isRunning = timerState != Timer.State.NULL;

        if (this._isPaused != isPaused ||
            this._timerState != timerState)
        {
            this._isPaused = isPaused;
            this._timerState = timerState;

            this._toggleMenuItem.visible = !isRunning;
            this._timerMenuItem.visible = isRunning;

            this._timerLabelButton.reactive = isRunning && !isPaused && timerState != Timer.State.POMODORO;
            this.pauseAction.child.icon_name = isPaused
                                               ? 'media-playback-start-symbolic'
                                               : 'media-playback-pause-symbolic';
            this.pauseAction.accessible_name = isPaused
                                               ? _("Resume Timer")
                                               : _("Pause Timer");

            for (let key in this._stateItems) {
                let stateItem = this._stateItems[key];

                stateItem.visible = isRunning;

                if (key == timerState) {
                    stateItem.setOrnament(PopupMenu.Ornament.DOT);
                    stateItem.add_style_class_name('active');
                }
                else {
                    stateItem.setOrnament(PopupMenu.Ornament.NONE);
                    stateItem.remove_style_class_name('active');
                }
            }
        }

        this.timerLabel.set_text(this._formatTime(remaining));
    }

    _formatTime(remaining) {
        if (remaining < 0.0) {
            remaining = 0.0;
        }

        let minutes = Math.floor(remaining / 60);
        let seconds = Math.floor(remaining % 60);

        return '%02d:%02d'.format(minutes, seconds);
    }

    _activateStats() {
        let timestamp = global.get_current_time();

        this.indicator.timer.showMainWindow('stats', timestamp);
    }

    _activatePreferences() {
        let timestamp = global.get_current_time();

        this.indicator.timer.showPreferences(timestamp);
    }

    _activateQuit() {
        this.indicator.timer.quit();
    }

    _activateState(stateName) {
        this.indicator.timer.setState(stateName);
    }

    destroy() {
        if (this._timerUpdateId) {
            this.indicator.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }

        if (this._actorMappedId) {
            this.actor.disconnect(this._actorMappedId);
            this._actorMappedId = 0;
        }

        this.indicator = null;
        this.timerLabel = null;
        this.pauseAction = null;

        super.destroy();
    }
};


var TextIndicator = class {
    constructor(timer) {
        this._initialized     = false;
        this._state           = Timer.State.NULL;
        this._minHPadding     = 0;
        this._natHPadding     = 0;
        this._digitWidth      = 0;
        this._charWidth       = 0;
        this._onTimerUpdateId = 0;

        this.timer = timer;

        this.actor = new St.Widget({ reactive: true });
        this.actor._delegate = this;

        this.label = new St.Label({ style_class: 'system-status-label',
                                    x_align: Clutter.ActorAlign.CENTER,
                                    y_align: Clutter.ActorAlign.CENTER });
        this.label.clutter_text.line_wrap = false;
        this.label.clutter_text.ellipsize = false;
        this.label.connect('destroy',
            () => {
                if (this._onTimerUpdateId) {
                    this.timer.disconnect(this._onTimerUpdateId);
                    this._onTimerUpdateId = 0;
                }
            });
        this.actor.add_child(this.label);

        this.actor.connect('style-changed', this._onStyleChanged.bind(this));
        this.actor.connect('destroy', this._onActorDestroy.bind(this));

        this._onTimerUpdateId = this.timer.connect('update', this._onTimerUpdate.bind(this));

        this._onTimerUpdate();

        this._state = this.timer.getState();
        this._initialized = true;

        if (this._state == Timer.State.POMODORO) {
            this.actor.set_opacity(FADE_IN_OPACITY * 255);
        }
        else {
            this.actor.set_opacity(FADE_OUT_OPACITY * 255);
        }
    }

    _onStyleChanged(actor) {
        let themeNode = actor.get_theme_node();
        let font      = themeNode.get_font();
        let context   = actor.get_pango_context();
        let metrics   = context.get_metrics(font, context.get_language());

        this._minHPadding = themeNode.get_length('-minimum-hpadding');
        this._natHPadding = themeNode.get_length('-natural-hpadding');
        this._digitWidth  = metrics.get_approximate_digit_width() / Pango.SCALE;
        this._charWidth   = metrics.get_approximate_char_width() / Pango.SCALE;
    }

    _getWidth() {
        return Math.ceil(4 * this._digitWidth + 0.5 * this._charWidth);
    }

    _getText(state, remaining) {
        if (remaining < 0.0) {
            remaining = 0.0;
        }

        let minutes = Math.floor(remaining / 60);
        let seconds = Math.floor(remaining % 60);

        return '%02d:%02d'.format(minutes, seconds);
    }

    _onTimerUpdate() {
        let state = this.timer.getState();
        let remaining = this.timer.getRemaining();

        if (this._state != state && this._initialized) {
            this._state = state;

            if (state == Timer.State.POMODORO) {
                this.actor.ease({
                    opacity: FADE_IN_OPACITY * 255,
                    duration: FADE_IN_TIME,
                    mode: Clutter.AnimationMode.EASE_OUT_QUAD
                });
            }
            else {
               this.actor.ease({
                    opacity: FADE_OUT_OPACITY * 255,
                    duration: FADE_OUT_TIME,
                    mode: Clutter.AnimationMode.EASE_OUT_QUAD
               });
            }
        }

        this.label.set_text(this._getText(state, remaining));
    }

    _onActorDestroy() {
        if (this._onTimerUpdateId) {
            this.timer.disconnect(this._onTimerUpdateId);
            this._onTimerUpdateId = 0;
        }

        this.actor._delegate = null;

        this.emit('destroy');
    }

    destroy() {
        this.actor.destroy();
    }
};
Signals.addSignalMethods(TextIndicator.prototype);


var ShortTextIndicator = class extends TextIndicator {
    constructor(timer) {
        super(timer);

        this.label.set_x_align(Clutter.ActorAlign.END);
    }

    _getWidth() {
        return Math.ceil(2 * this._digitWidth +
                         1 * this._charWidth);
    }

    _getText(state, remaining) {
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
};

var IconIndicator = class {
    constructor(timer) {
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

        this.actor = new St.Widget({ reactive: true });
        this.actor._delegate = this;

        this.icon = new St.DrawingArea({ style_class: 'system-status-icon' });
        this.icon.connect('style-changed', this._onIconStyleChanged.bind(this));
        this.icon.connect('repaint', this._onIconRepaint.bind(this));
        this.icon.connect('destroy', this._onIconDestroy.bind(this));
        this.actor.add_child(this.icon);

        this.actor.connect('style-changed', this._onStyleChanged.bind(this));
        this.actor.connect('destroy', this._onActorDestroy.bind(this));

        this._timerUpdateId = this.timer.connect('update', this._onTimerUpdate.bind(this));

        this._onTimerUpdate();

        this._state = this.timer.getState();
    }

    _onIconStyleChanged(actor) {
        let themeNode = actor.get_theme_node();
        let size = Math.ceil(themeNode.get_length('icon-size'));

        [actor.min_width, actor.natural_width] = themeNode.adjust_preferred_width(size, size);
        [actor.min_height, actor.natural_height] = themeNode.adjust_preferred_height(size, size);

        this._iconSize = size;
    }

    _onIconRepaint(area) {
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
    }

    _onIconDestroy() {
        if (this._timerUpdateId) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }
    }

    _onStyleChanged(actor) {
        let themeNode = actor.get_theme_node();

        this._minHPadding = themeNode.get_length('-minimum-hpadding');
        this._natHPadding = themeNode.get_length('-natural-hpadding');
        this._minVPadding = themeNode.get_length('-minimum-vpadding');
        this._natVPadding = themeNode.get_length('-natural-vpadding');

        let color = themeNode.get_foreground_color();
        this._primaryColor = color;
        this._secondaryColor = new Clutter.Color({
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha * FADE_OUT_OPACITY
        });
    }


    _onTimerUpdate() {
        let state = this.timer.getState();
        let progress = Math.floor(this.timer.getProgress() * STEPS) / STEPS;

        if (this._progress !== progress || this._state !== state) {
            this._state = state;
            this._progress = progress;
            this.icon.queue_repaint();
        }
    }


    _onActorDestroy() {
        if (this._timerUpdateId) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }

        this.timer = null;
        this.icon = null;

        this.actor._delegate = null;

        this.emit('destroy');
    }

    destroy() {
        this.actor.destroy();
    }
};
Signals.addSignalMethods(IconIndicator.prototype);


var Indicator = GObject.registerClass(
class PomodoroIndicator extends PanelMenu.Button {
    _init(timer, type) {
        super._init(St.Align.START, _("Pomodoro"), true);

        this.timer  = timer;
        this.widget = null;

        this.add_style_class_name('extension-pomodoro-indicator');

        this._arrow = PopupMenu.arrowIcon(St.Side.BOTTOM);
        this._blinking = false;
        this._blinkTimeoutSource = 0;

        this._hbox = new St.BoxLayout({ style_class: 'panel-status-menu-box' });
        this._hbox.pack_start = true;
        this._hbox.set_y_align(Clutter.ActorAlign.CENTER);
        this._hbox.add_child(this._arrow);
        this.add_child(this._hbox);

        this.setMenu(new IndicatorMenu(this));
        this.setType(type);

        this._onBlinked();

        this._timerPausedId = this.timer.connect('paused', this._onTimerPaused.bind(this));
        this._timerResumedId = this.timer.connect('resumed', this._onTimerResumed.bind(this));

        let destroyId = this.connect('destroy', () => {
            if (this._blinkTimeoutSource != 0) {
                GLib.source_remove(this._blinkTimeoutSource);
                this._blinkTimeoutSource = 0;
            }

            this.timer.disconnect(this._timerPausedId);
            this.timer.disconnect(this._timerResumedId);
            this.timer = null;

            if (this.icon) {
                this.icon.destroy();
                this.icon = null;
            }

            this.disconnect(destroyId);
        })
    }

    setType(type) {
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

        this._hbox.add_child(this.widget.actor);
    }

    _onBlinked() {
        this._blinking = false;

        if (this.timer.isPaused()) {
            this._blink();
        }
    }

    _blink() {
        if (!this._blinking) {
            this._blinking = true;

            let fadeOutParams = {
                duration: FADE_OUT_TIME,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                opacity: FADE_OUT_OPACITY * 255
            };
            let fadeInParams = {
                duration: FADE_IN_TIME,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                delay: FADE_OUT_TIME,
                opacity: FADE_IN_OPACITY * 255,
                onComplete: this._onBlinked.bind(this)
            };

            if (Gtk.Settings.get_default().gtk_enable_animations) {
                this._hbox.ease(fadeOutParams);
                this._hbox.ease(fadeInParams);
                this.menu.timerLabel.ease(fadeOutParams);
                this.menu.timerLabel.ease(fadeInParams);
                this.menu.pauseAction.child.ease(fadeOutParams);
                this.menu.pauseAction.child.ease(fadeInParams);
            }
            else if (this._blinkTimeoutSource == 0) {
                this._hbox.ease(fadeOutParams);

                this._blinkTimeoutSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT, FADE_OUT_TIME,
                    () => {
                        this._hbox.ease(fadeInParams);

                        this._blinkTimeoutSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT, FADE_IN_TIME, () => {
                            this._blinkTimeoutSource = 0;

                            this._onBlinked ();

                            return GLib.SOURCE_REMOVE;
                        });

                        return GLib.SOURCE_REMOVE;
                    });
            }
        }
    }

    _onTimerPaused() {
        this._blink();
    }

    _onTimerResumed() {
        if (this._blinking) {
            let fadeInParams = {
                duration: 200,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                opacity: FADE_IN_OPACITY * 255,
                onComplete: this._onBlinked.bind(this)
            };

            this._hbox.remove_all_transitions();
            this.menu.timerLabel.remove_all_transitions();
            this.menu.pauseAction.child.remove_all_transitions();

            this._hbox.ease(fadeInParams);
            this.menu.timerLabel.ease(fadeInParams);
            this.menu.pauseAction.child.ease(fadeInParams);

            if (this._blinkTimeoutSource != 0) {
                GLib.source_remove(this._blinkTimeoutSource);
                this._blinkTimeoutSource = 0;
            }
        }
    }
});
