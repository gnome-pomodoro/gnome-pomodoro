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

import Cairo from 'gi://cairo';
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Pango from 'gi://Pango';
import St from 'gi://St';

import {PopupAnimation} from 'resource:///org/gnome/shell/ui/boxpointer.js';
import {EventEmitter} from 'resource:///org/gnome/shell/misc/signals.js';
import {gettext as _} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

import {extension} from './extension.js';
import {State, TimerLabel} from './timer.js';
import * as Utils from './utils.js';


const FADE_IN_TIME = 1250;
const FADE_IN_OPACITY = 1.0;

const FADE_OUT_TIME = 1250;
const FADE_OUT_OPACITY = 0.38;

const STEPS = 120;
const X_ALIGNMENT = 0.5;


const IndicatorType = {
    TEXT: 'text',
    SHORT_TEXT: 'short-text',
    ICON: 'icon',
};


const IndicatorMenu = class extends PopupMenu.PopupMenu {
    constructor(indicator) {
        super(indicator, X_ALIGNMENT, St.Side.TOP);

        this._indicator = indicator;
        this._timer = indicator.timer;
        this._isPaused = null;
        this._timerState = null;
        this._timerStateChangedId = 0;
        this._timerPausedId = 0;
        this._timerResumedId = 0;
        this._icons = {};

        this.actor.add_style_class_name('extension-pomodoro-indicator-menu');

        this._actorMappedId = this.actor.connect('notify::mapped', this._onNotifyMapped.bind(this));

        this.addMenuItem(this._createToggleMenuItem());
        this.addMenuItem(this._createTimerMenuItem());

        this.addStateMenuItem('pomodoro', _('Pomodoro'));
        this.addStateMenuItem('short-break', _('Short Break'));
        this.addStateMenuItem('long-break', _('Long Break'));

        this.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        this.addAction(_('Preferences'), this._activatePreferences.bind(this));
        this.addAction(_('Stats'), this._activateStats.bind(this));
        this.addAction(_('Quit'), this._activateQuit.bind(this));
    }

    get indicator() {
        return this._indicator;
    }

    // TODO: move to utils
    _loadIcon(iconName) {
        let icon = this._icons[iconName];

        if (!icon) {
            const iconUri = '%s/icons/hicolor/scalable/actions/%s.svg'.format(extension.dir.get_uri(), iconName);
            icon = new Gio.FileIcon({
                file: Gio.File.new_for_uri(iconUri),
            });

            this._icons[iconName] = icon;
        }

        return icon;
    }

    _createIconButton(iconName, accessibleName) {
        const icon = new St.Icon({
            gicon: this._loadIcon(iconName),
            style_class: 'popup-menu-icon',
        });
        const iconButton = new St.Button({
            reactive: true,
            can_focus: true,
            track_hover: true,
            accessible_name: accessibleName,
            style_class: 'icon-button',
        });
        iconButton.add_style_class_name('flat');
        iconButton.set_child(icon);

        return iconButton;
    }

    _createToggleMenuItem() {
        const menuItem = new PopupMenu.PopupMenuItem(_('Pomodoro Timer'),
            {
                style_class: 'extension-pomodoro-toggle-menu-item',
                reactive: false,
                can_focus: false,
            });
        menuItem.label.y_align = Clutter.ActorAlign.CENTER;

        const startButton = this._createIconButton('gnome-pomodoro-start-symbolic', _('Start Timer'));
        startButton.connect('clicked', this._onStartClicked.bind(this));
        menuItem.add_child(startButton);

        this._toggleMenuItem = menuItem;

        return menuItem;
    }

    _createTimerMenuItem() {
        const menuItem = new PopupMenu.PopupMenuItem('',
            {
                style_class: 'extension-pomodoro-timer-menu-item',
                reactive: false,
                can_focus: false,
            });
        menuItem.label.visible = false;

        const timerButton = new St.Button({
            style_class: 'extension-pomodoro-timer-button',
            reactive: true,
            can_focus: true,
            track_hover: true,
        });
        timerButton.add_style_class_name('button');
        timerButton.add_style_class_name('flat');
        timerButton.connect('clicked', this._onTimerButtonClicked.bind(this));
        menuItem.add_child(timerButton);

        const timerLabel = new TimerLabel(this._timer, {x_align: Clutter.ActorAlign.START});
        timerButton.set_child(timerLabel);

        const buttonsBox = new St.BoxLayout({
            style_class: 'extension-pomodoro-timer-buttons-box',
            x_align: Clutter.ActorAlign.END,
            x_expand: true,
        });
        menuItem.add_child(buttonsBox);

        const pauseResumeButton = this._createIconButton('gnome-pomodoro-pause-symbolic', _('Pause Timer'));
        pauseResumeButton.connect('clicked',
            () => {
                if (!this._isPaused)
                    this._onPauseClicked();

                else
                    this._onResumeClicked();
            });
        buttonsBox.add_child(pauseResumeButton);

        const skipStopButton = this._createIconButton('gnome-pomodoro-stop-symbolic', _('Stop Timer'));
        skipStopButton.connect('clicked',
            () => {
                if (!this._isPaused)
                    this._onSkipClicked();
                else
                    this._onStopClicked();
            });
        buttonsBox.add_child(skipStopButton);

        const blinkingGroup = this._indicator.blinkingGroup;
        blinkingGroup.addActor(timerLabel);
        blinkingGroup.addActor(pauseResumeButton);

        this._timerMenuItem = menuItem;
        this._timerButton = timerButton;
        this._pauseResumeButton = pauseResumeButton;
        this._skipStopButton = skipStopButton;

        return menuItem;
    }

    _updateTimerButtons() {
        const visible = this._timerState !== State.NULL;
        const isBreak = this._timerState === State.SHORT_BREAK ||
                        this._timerState === State.LONG_BREAK;

        this._toggleMenuItem.visible = !visible;
        this._timerMenuItem.visible = visible;

        this._timerButton.reactive = isBreak && !this._isPaused;
        this._timerButton.can_focus = this._timerButton.reactive;

        if (!this._isPaused) {
            this._pauseResumeButton.child.gicon = this._loadIcon('gnome-pomodoro-pause-symbolic');
            this._pauseResumeButton.accessible_name = isBreak ? _('Pause break') : _('Pause Pomodoro');

            this._skipStopButton.child.gicon = this._loadIcon('gnome-pomodoro-skip-symbolic');
            this._skipStopButton.accessible_name = isBreak ? _('Start Pomodoro') : _('Take a break');
        } else {
            this._pauseResumeButton.child.gicon = this._loadIcon('gnome-pomodoro-start-symbolic');
            this._pauseResumeButton.accessible_name = isBreak ? _('Resume break') : _('Resume Pomodoro');

            this._skipStopButton.child.gicon = this._loadIcon('gnome-pomodoro-stop-symbolic');
            this._skipStopButton.accessible_name = _('Stop');
        }
    }

    _updateStateItems() {
        const visible = this._timerState !== State.NULL;

        for (const [stateName, menuItem] of Object.entries(this._stateItems)) {
            menuItem.visible = visible;

            if (stateName === this._timerState) {
                menuItem.setOrnament(PopupMenu.Ornament.DOT);
                menuItem.add_style_class_name('active');
            } else {
                menuItem.setOrnament(PopupMenu.Ornament.NONE);
                menuItem.remove_style_class_name('active');
            }
        }
    }

    _onNotifyMapped(actor) {
        if (actor.mapped) {
            this._connectTimerSignals();

            this._onTimerStateChanged();
        } else {
            this._disconnectTimerSignals();
        }
    }

    _onTimerStateChanged() {
        const timerState = this._timer.getState();
        const isPaused = this._timer.isPaused();

        if (this._isPaused !== isPaused ||
            this._timerState !== timerState) {
            this._isPaused = isPaused;
            this._timerState = timerState;

            this._updateTimerButtons();
            this._updateStateItems();
        }
    }

    _onTimerPaused() {
        this._onTimerStateChanged();
    }

    _onTimerResumed() {
        this._onTimerStateChanged();
    }

    _onTimerButtonClicked() {
        const notificationManager = extension.notificationManager;

        this.itemActivated(PopupAnimation.NONE);

        if (notificationManager)
            notificationManager.openDialog();
    }

    _onStartClicked() {
        this.itemActivated(PopupAnimation.NONE);

        this._timer.start();
    }

    _onSkipClicked() {
        this.itemActivated(PopupAnimation.NONE);

        this._timer.skip();
    }

    _onStopClicked() {
        const idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
            this._timer.stop();

            return GLib.SOURCE_REMOVE;
        });
        GLib.Source.set_name_by_id(idleId, '[gnome-pomodoro] this._timer.stop()');

        // Closing menu leads to GrabHelper complaing about accessing deallocated St.Button,
        // while doing savedFocus.grab_key_focus().
        // As a walkaround we call timer.stop() with delay. Seems that these calls interfere
        // with each other.
        this.itemActivated(PopupAnimation.NONE);
    }

    _onPauseClicked() {
        this._timer.pause();
    }

    _onResumeClicked() {
        this.itemActivated(PopupAnimation.NONE);

        this._timer.resume();
    }

    addAction(label, callback, icon) {
        const menuItem = super.addAction(label, callback, icon);

        menuItem.connect('leave-event', actor => {
            if (actor.has_key_focus())
                global.stage.set_key_focus(actor.get_parent());
        });

        return menuItem;
    }

    addStateMenuItem(name, label) {
        if (!this._stateItems)
            this._stateItems = {};

        let menuItem = this.addAction(label, (_menuItem, event) => {  // eslint-disable-line no-unused-vars
            this._activateState(name);
        });

        menuItem.add_style_class_name('state-item');

        this._stateItems[name] = menuItem;

        return menuItem;
    }

    _activateState(stateName) {
        this.itemActivated(PopupAnimation.NONE);

        this._timer.setState(stateName);
    }

    _activateStats() {
        const timestamp = global.get_current_time();

        this.itemActivated(PopupAnimation.NONE);
        Main.overview.hide();

        this._timer.showMainWindow('stats', timestamp);
    }

    _activatePreferences() {
        const timestamp = global.get_current_time();

        this.itemActivated(PopupAnimation.NONE);
        Main.overview.hide();

        this._timer.showPreferences(timestamp);
    }

    _activateQuit() {
        this._timer.quit();
    }

    _connectTimerSignals() {
        if (!this._timerStateChangedId) {
            this._timerStateChangedId = this._timer.connect('state-changed', this._onTimerStateChanged.bind(this));
            this._onTimerStateChanged();
        }

        if (!this._timerPausedId)
            this._timerPausedId = this._timer.connect('paused', this._onTimerPaused.bind(this));


        if (!this._timerResumedId)
            this._timerResumedId = this._timer.connect('resumed', this._onTimerResumed.bind(this));
    }

    _disconnectTimerSignals() {
        if (this._timerStateChangedId) {
            this._timer.disconnect(this._timerStateChangedId);
            this._timerStateChangedId = 0;
        }

        if (this._timerPausedId) {
            this._timer.disconnect(this._timerPausedId);
            this._timerPausedId = 0;
        }

        if (this._timerResumedId) {
            this._timer.disconnect(this._timerResumedId);
            this._timerResumedId = 0;
        }
    }

    close(animate) {
        this._disconnectTimerSignals();

        super.close(animate);
    }

    destroy() {
        this._disconnectTimerSignals();

        if (this._actorMappedId) {
            this.actor.disconnect(this._actorMappedId);
            this._actorMappedId = 0;
        }

        this._indicator = null;
        this._timer = null;
        this._icons = null;

        super.destroy();
    }
};


const TextIndicator = class extends EventEmitter {
    constructor(timer) {
        super();

        this._initialized     = false;
        this._state           = State.NULL;
        this._digitWidth      = 0;
        this._charWidth       = 0;
        this._onTimerUpdateId = 0;

        this.timer = timer;

        this.actor = new St.Widget({reactive: true});
        this.actor._delegate = this;

        this.label = new St.Label({
            style_class: 'system-status-label',
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
        });
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

        if (this._state === State.POMODORO)
            this.actor.set_opacity(FADE_IN_OPACITY * 255);
        else
            this.actor.set_opacity(FADE_OUT_OPACITY * 255);
    }

    _onStyleChanged(actor) {
        const themeNode    = actor.get_theme_node();
        const font         = themeNode.get_font();
        const context      = actor.get_pango_context();
        const metrics      = context.get_metrics(font, context.get_language());

        this._digitWidth  = metrics.get_approximate_digit_width() / Pango.SCALE;
        this._charWidth   = metrics.get_approximate_char_width() / Pango.SCALE;
    }

    _getWidth() {
        return Math.ceil(4 * this._digitWidth + 0.5 * this._charWidth);
    }

    _getText(state, remaining) {
        if (remaining < 0.0)
            remaining = 0.0;

        const minutes = Math.floor(remaining / 60);
        const seconds = Math.floor(remaining % 60);

        return '%02d:%02d'.format(minutes, seconds);
    }

    _onTimerUpdate() {
        const state = this.timer.getState();
        const remaining = this.timer.getRemaining();

        if (this._state !== state && this._initialized) {
            this._state = state;

            if (state === State.POMODORO) {
                this.actor.ease({
                    opacity: FADE_IN_OPACITY * 255,
                    duration: FADE_IN_TIME,
                    mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                });
            } else {
                this.actor.ease({
                    opacity: FADE_OUT_OPACITY * 255,
                    duration: FADE_OUT_TIME,
                    mode: Clutter.AnimationMode.EASE_OUT_QUAD,
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


const ShortTextIndicator = class extends TextIndicator {
    constructor(timer) {
        super(timer);

        this.label.set_x_align(Clutter.ActorAlign.END);
    }

    _getWidth() {
        return Math.ceil(2 * this._digitWidth +
                         Number(this._charWidth));
    }

    _getText(state, remaining) {
        if (remaining < 0.0)
            remaining = 0.0;

        let minutes = Math.round(remaining / 60);
        let seconds = Math.round(remaining % 60);

        if (remaining > 15)
            seconds = Math.ceil(seconds / 15) * 15;

        return remaining > 45
            ? '%d′'.format(minutes)
            : '%d″'.format(seconds);
    }
};


const IconIndicator = class extends EventEmitter {
    constructor(timer) {
        super();

        this._state           = State.NULL;
        this._progress        = 0.0;
        this._primaryColor    = null;
        this._secondaryColor  = null;
        this._timerUpdateId = 0;

        this.timer = timer;

        this.actor = new St.Widget({reactive: true});
        this.actor._delegate = this;

        this.icon = new St.DrawingArea({style_class: 'system-status-icon'});
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
        let [found, size] = themeNode.lookup_length('icon-size', false);

        if (!found)
            return;

        [actor.min_width, actor.natural_width] = themeNode.adjust_preferred_width(size, size);
        [actor.min_height, actor.natural_height] = themeNode.adjust_preferred_height(size, size);

        this._iconSize = size;
    }

    _onIconRepaint(area) {
        const cr = area.get_context();
        const [width, height] = area.get_surface_size();
        const scaleFactor = St.ThemeContext.get_for_stage(global.stage).scale_factor;

        const radius    = 0.5 * this._iconSize - 2.0;
        const progress  = this._progress;
        const isRunning = this._state !== State.NULL;
        const isBreak   = this._state === State.SHORT_BREAK ||
                          this._state === State.LONG_BREAK;

        cr.translate(0.5 * width, 0.5 * height);
        cr.setOperator(Cairo.Operator.SOURCE);
        cr.setLineCap(Cairo.LineCap.ROUND);

        const angle1 = -0.5 * Math.PI - 2.0 * Math.PI * Math.min(Math.max(progress, 0.000001), 1.0);
        const angle2 = -0.5 * Math.PI;

        /* background pie */
        if (isBreak || !isRunning) {
            cr.setSourceColor(this._secondaryColor);
            cr.arcNegative(0, 0, radius, angle1, angle2);
            cr.setLineWidth(2.2 * scaleFactor);
            cr.stroke();
        } else {
            cr.setSourceColor(this._secondaryColor);
            cr.arc(0, 0, radius, 0.0, 2.0 * Math.PI);
            cr.setLineWidth(2.2 * scaleFactor);
            cr.stroke();

            if (angle2 > angle1) {
                cr.setSourceColor(this._primaryColor);
                cr.arcNegative(0, 0, radius, angle1, angle2);
                cr.setOperator(Cairo.Operator.CLEAR);
                cr.setLineWidth(3.5 * scaleFactor);
                cr.strokePreserve();

                cr.setOperator(Cairo.Operator.SOURCE);
                cr.setLineWidth(2.2 * scaleFactor);
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
        const themeNode = actor.get_theme_node();
        const color = themeNode.get_foreground_color();
        this._primaryColor = color;
        this._secondaryColor = new Clutter.Color({
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha * FADE_OUT_OPACITY,
        });
    }


    _onTimerUpdate() {
        const state = this.timer.getState();
        const progress = Math.floor(this.timer.getProgress() * STEPS) / STEPS;

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


export const Indicator = GObject.registerClass(
class PomodoroIndicator extends PanelMenu.Button {
    _init(timer, type) {
        super._init(X_ALIGNMENT, _('Pomodoro'), true);

        this.timer  = timer;
        this.widget = null;

        this.add_style_class_name('extension-pomodoro-indicator');

        this._iconBox = new St.Bin({
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this.add_child(this._iconBox);

        this._blinking = false;
        this._blinkingGroup = new Utils.TransitionGroup();
        this._blinkingGroup.addActor(this._iconBox);

        this.setMenu(new IndicatorMenu(this));
        Main.panel.menuManager.addMenu(this.menu);

        this.setType(type);

        this._mappedId = this.connect('notify::mapped', this._onMappedChanged.bind(this));

        this.connect('destroy', () => {
            if (this._timerPausedId) {
                this.timer.disconnect(this._timerPausedId);
                this._timerPausedId = 0;
            }

            if (this._timerResumedId) {
                this.timer.disconnect(this._timerResumedId);
                this._timerResumedId = 0;
            }

            if (this._blinkingGroup) {
                this._blinkingGroup.destroy();
                this._blinkingGroup = null;
            }

            if (this.icon) {
                this.icon.destroy();
                this.icon = null;
            }

            if (this._mappedId) {
                this.disconnect(this._mappedId);
                this._mappedId = 0;
            }

            this.timer = null;
        });
    }

    get blinkingGroup() {
        return this._blinkingGroup;
    }

    _onMappedChanged() {
        if (this.mapped) {
            if (!this._timerPausedId)
                this._timerPausedId = this.timer.connect('paused', this._onTimerPaused.bind(this));


            if (!this._timerResumedId)
                this._timerResumedId = this.timer.connect('resumed', this._onTimerResumed.bind(this));
        } else {
            if (this._timerPausedId) {
                this.timer.disconnect(this._timerPausedId);
                this._timerPausedId = 0;
            }

            if (this._timerResumedId) {
                this.timer.disconnect(this._timerResumedId);
                this._timerResumedId = 0;
            }
        }

        this._onBlinked();
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

        this._iconBox.set_child(this.widget.actor);
    }

    _onBlinked() {
        this._blinking = false;

        if (!this.mapped) {
            this._blinkingGroup.removeAllTransitions();
            this._blinkingGroup.setProperty('opacity', 255);
        }

        if (this.timer.isPaused())
            this._blink();
    }

    _blink() {
        if (!this.mapped)
            return;

        if (!this._blinking) {
            let ignoreSignals = false;
            let fadeIn = () => {
                if (this._blinking) {
                    this._blinkingGroup.easeProperty('opacity', FADE_IN_OPACITY * 255, {
                        duration: 1750,
                        mode: Clutter.AnimationMode.EASE_IN_OUT_CUBIC,
                        onComplete: () => {
                            if (!this.mapped)
                                return;

                            if (!ignoreSignals) {
                                ignoreSignals = true;
                                fadeOut();
                                ignoreSignals = false;
                            } else {
                                // stop recursion
                            }
                        },
                    });
                } else {
                    this._onBlinked();
                }
            };
            let fadeOut = () => {
                if (this._blinking) {
                    this._blinkingGroup.easeProperty('opacity', FADE_OUT_OPACITY * 255, {
                        duration: 1750,
                        mode: Clutter.AnimationMode.EASE_IN_OUT_CUBIC,
                        onComplete: () => {
                            if (!ignoreSignals) {
                                ignoreSignals = true;
                                fadeIn();
                                ignoreSignals = false;
                            } else {
                                // stop recursion
                            }
                        },
                    });
                } else {
                    this._onBlinked();
                }
            };

            if (St.Settings.get().enable_animations) {
                this._blinking = true;
                this._blinkingGroup.easeProperty('opacity', FADE_OUT_OPACITY * 255, {
                    duration: FADE_OUT_TIME,
                    mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                    onComplete: fadeIn,
                });
            }
        }
    }

    _onTimerPaused() {
        this._blink();
    }

    _onTimerResumed() {
        if (this._blinking) {
            this._blinkingGroup.easeProperty('opacity', FADE_IN_OPACITY * 255, {
                duration: 200,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                onComplete: this._onBlinked.bind(this),
            });
        }
    }
});
