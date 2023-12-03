import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {EventEmitter} from 'resource:///org/gnome/shell/misc/signals.js';
import {gettext as _} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {extension} from './extension.js';
import {State} from './timer.js';
import {formatRemainingTime} from './notifications.js';
import * as Utils from './utils.js';


// Time in seconds to annouce next timer state.
const ANNOUCEMENT_TIME = 10.0;

const FADE_IN_OPACITY = 1.0;
const FADE_OUT_TIME = 1250;
const FADE_OUT_OPACITY = 0.38;


const ScreenShieldWidget = GObject.registerClass(
class PomodoroScreenShieldWidget extends St.Widget {
    _init(timer) {
        super._init({
            style_class: 'extension-pomodoro-widget',
            layout_manager: new Clutter.BinLayout(),
            can_focus: true,
            x_expand: true,
            y_expand: false,
        });

        this._timer = timer;
        this._isPaused = null;
        this._timerState = null;
        this._timerStateChangedId = 0;
        this._timerPausedId = 0;
        this._timerResumedId = 0;
        this._icons = {};
        this._blinking = false;

        const vbox = new St.BoxLayout({
            vertical: true,
            x_expand: true,
        });
        this.add_actor(vbox);

        const hbox = new St.BoxLayout();
        vbox.add_actor(hbox);

        const contentBox = new St.BoxLayout({
            style_class: 'extension-pomodoro-widget-content',
            vertical: true,
            x_expand: true,
        });
        hbox.add_actor(contentBox);

        const blinkingGroup = new Utils.TransitionGroup();

        const titleLabel = new St.Label({style_class: 'extension-pomodoro-widget-title'});
        contentBox.add_actor(titleLabel);

        const messageLabel = new St.Label({style_class: 'extension-pomodoro-widget-message', text: '15 minutes remaining'});
        contentBox.add_actor(messageLabel);
        blinkingGroup.addActor(messageLabel);

        const buttonsBox = new St.BoxLayout();
        hbox.add_actor(buttonsBox);

        const pauseResumeButton = this._createIconButton('gnome-pomodoro-pause-symbolic', _('Pause Timer'));
        pauseResumeButton.connect('clicked',
            () => {
                if (!this._isPaused)
                    this._timer.pause();

                else
                    this._timer.resume();
            });
        buttonsBox.add_actor(pauseResumeButton);
        blinkingGroup.addActor(pauseResumeButton);

        const skipStopButton = this._createIconButton('gnome-pomodoro-stop-symbolic', _('Stop Timer'));
        skipStopButton.connect('clicked',
            () => {
                if (!this._isPaused)
                    this._timer.skip();
                else
                    this._timer.stop();
            });
        buttonsBox.add_actor(skipStopButton);

        this._blinkingGroup = blinkingGroup;
        this._titleLabel = titleLabel;
        this._messageLabel = messageLabel;
        this._pauseResumeButton = pauseResumeButton;
        this._skipStopButton = skipStopButton;

        this.connect('destroy', this._onDestroy.bind(this));
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
        const icon = new St.Icon({gicon: this._loadIcon(iconName)});
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

    _shouldBlink() {
        if (!this.mapped)
            return false;

        if (this._timerState === State.POMODORO && this._timer.getElapsed() === 0.0)
            return false;

        return this._isPaused;
    }

    _updateTitleLabel() {
        let title;

        if (this._timerState === State.POMODORO &&
            this._isPaused &&
            this._timer.getElapsed() === 0.0)
            title = _('Break is over');
        else
            title = State.label(this._timerState);

        this._titleLabel.text = title;
    }

    _updateMessageLabel() {
        let message;

        if (this._timerState === State.POMODORO &&
            this._isPaused &&
            this._timer.getElapsed() === 0.0)
            message = _('Get ready…');
        else
            message = formatRemainingTime(this._timer.getRemaining());

        this._messageLabel.text = message;
    }

    _updateButtons() {
        const isBreak = this._timerState === State.SHORT_BREAK ||
                        this._timerState === State.LONG_BREAK;

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

    vfunc_map() {
        if (!this._timerStateChangedId) {
            this._timerStateChangedId = this._timer.connect('state-changed', this._onTimerStateChanged.bind(this));
            this._onTimerStateChanged();
        }

        if (!this._timerPausedId)
            this._timerPausedId = this._timer.connect('paused', this._onTimerPaused.bind(this));


        if (!this._timerResumedId)
            this._timerResumedId = this._timer.connect('resumed', this._onTimerResumed.bind(this));


        if (!this._timerUpdateId) {
            this._timerUpdateId = this._timer.connect('update', this._onTimerUpdate.bind(this));
            this._onTimerUpdate();
        }

        super.vfunc_map();

        if (this._shouldBlink())
            this._blink();
    }

    vfunc_unmap() {
        super.vfunc_unmap();

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

        if (this._timerUpdateId) {
            this._timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }
    }

    _onTimerStateChanged() {
        const timerState = this._timer.getState();
        const isPaused = this._timer.isPaused();

        if (this._isPaused !== isPaused ||
            this._timerState !== timerState) {
            this._isPaused = isPaused;
            this._timerState = timerState;

            this._updateButtons();
            this._updateTitleLabel();
            this._updateMessageLabel();
        }

        if (this._shouldBlink()) {
            this._blink();
        } else if (this._blinking) {
            this._blinkingGroup.easeProperty('opacity', FADE_IN_OPACITY * 255, {
                duration: 200,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                onComplete: this._onBlinked.bind(this),
            });
        }
    }

    _onTimerPaused() {
        this._onTimerStateChanged();
    }

    _onTimerResumed() {
        this._onTimerStateChanged();
    }

    _onTimerUpdate() {
        this._updateMessageLabel();
    }

    _onBlinked() {
        this._blinking = false;

        if (!this.mapped) {
            this._blinkingGroup.removeAllTransitions();
            this._blinkingGroup.setProperty('opacity', 255);
        }

        if (this._isPaused)
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

    _onDestroy() {
        if (this._blinkingGroup) {
            this._blinkingGroup.destroy();
            this._blinkingGroup = null;
        }

        this._icons = {};
    }
});


export class ScreenShieldManager extends EventEmitter {
    constructor(timer) {
        super();

        this._timer = timer;
        this._timerState = null;
        this._widget = null;
        this._destroying = false;

        this._annoucementTimeoutId = 0;
        this._timerStateChangedId = this._timer.connect('state-changed', this._onTimerStateChanged.bind(this));
        this._timerPausedId = this._timer.connect('paused', this._onTimerPaused.bind(this));
        this._timerResumedId = this._timer.connect('resumed', this._onTimerResumed.bind(this));

        this._refresh();
    }

    get timer() {
        return this._timer;
    }

    get widget() {
        return this._widget;
    }

    _createWidget() {
        const widget = new ScreenShieldWidget(this._timer);
        widget.connect('destroy',
            () => {
                if (this._widget === widget)
                    this._widget = null;
            });

        return widget;
    }

    _ensureWidget() {
        if (!this._widget) {
            const widget = this._createWidget();

            try {
                const clock = Main.screenShield._dialog._clock;
                clock.add_child(widget);
                clock.set_child_above_sibling(widget, clock._date);  // place after `date`
            } catch (error) {
                Utils.logError(error);
            } finally {
                this._widget = widget;
            }
        }
    }

    _onAnnoucementTimeout() {
        this._annoucementTimeoutId = 0;

        Utils.wakeUpScreen();

        return GLib.SOURCE_REMOVE;
    }

    // TODO: move annoucements to a helper class
    _scheduleAnnoucement() {
        const timeout = Math.round(this._timer.getRemaining() - ANNOUCEMENT_TIME);

        this._unscheduleAnnoucement();

        if (timeout <= 0) {
            this._onAnnoucementTimeout();
            return;
        }

        this._annoucementTimeoutId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT,
            timeout,
            this._onAnnoucementTimeout.bind(this));
        GLib.Source.set_name_by_id(this._annoucementTimeoutId,
            '[gnome-pomodoro] ScreenShieldManager._annoucementTimeoutId');
    }

    _unscheduleAnnoucement() {
        if (this._annoucementTimeoutId) {
            GLib.source_remove(this._annoucementTimeoutId);
            this._annoucementTimeoutId = 0;
        }
    }

    _refresh() {
        const timerState = this._timer.getState();
        const isPaused = this._timer.isPaused();

        this._unscheduleAnnoucement();

        if (!isPaused)
            this._scheduleAnnoucement();

        if (timerState !== State.NULL) {
            this._ensureWidget();
        } else if (this._widget) {
            this._widget.destroy();
            this._widget = null;
        }
    }

    _onTimerStateChanged() {
        const timerState = this._timer.getState();

        // skip waking up if previous state was unknown
        if (timerState !== this._timerState && this._timerState !== null)
            Utils.wakeUpScreen();

        this._refresh();

        this._timerState = timerState;
    }

    _onTimerPaused() {
        this._onTimerStateChanged();
    }

    _onTimerResumed() {
        this._onTimerStateChanged();
    }

    destroy() {
        this._destroying = true;
        this._unscheduleAnnoucement();

        if (this._widget) {
            this._widget.destroy();
            this._widget = null;
        }

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

        this.emit('destroy');
    }
}
