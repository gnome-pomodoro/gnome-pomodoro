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
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */

const Lang = imports.lang;
const Mainloop = imports.mainloop;
const Signals = imports.signals;

const Atk = imports.gi.Atk;
const Clutter = imports.gi.Clutter;
const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;
const Meta = imports.gi.Meta;
const Shell = imports.gi.Shell;
const St = imports.gi.St;
const Pango = imports.gi.Pango;

const GrabHelper = imports.ui.grabHelper;
const Layout = imports.ui.layout;
const Lightbox = imports.ui.lightbox;
const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const Tweener = imports.ui.tweener;
const Util = imports.misc.util;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Config = Extension.imports.config;
const Settings = Extension.imports.settings;
const Timer = Extension.imports.timer;

const Gettext = imports.gettext.domain(Config.GETTEXT_PACKAGE);
const _ = Gettext.gettext;
const ngettext = Gettext.ngettext;


/* Time between user input events before making dialog modal.
 * Value is a little higher than:
 *   - slow typing speed of 23 words per minute which translates
 *     to 523 miliseconds between key presses
 *   - moderate typing speed of 35 words per minute, 343 miliseconds.
 */
const IDLE_TIME_TO_PUSH_MODAL = 600;
const PUSH_MODAL_TIME_LIMIT = 1000;
const PUSH_MODAL_RATE = Clutter.get_default_frame_rate();

const IDLE_TIME_TO_OPEN = 60000;
const IDLE_TIME_TO_CLOSE = 600;
const MIN_DISPLAY_TIME = 300;

const FADE_IN_TIME = 180;
const FADE_IN_OPACITY = 0.55;

const FADE_OUT_TIME = 180;

/* Remind about ongoing break in given delays */
const REMINDER_INTERVALS = [75000];

/* Ratio between user idle time and time between reminders to determine
 * whether user is away
 */
const REMINDER_ACCEPTANCE = 0.66;

const State = {
    OPENED: 0,
    CLOSED: 1,
    OPENING: 2,
    CLOSING: 3
};


let source = null;


function getDefaultSource() {
    if (!source || !source.policy) {
        source = new Source();
        source.connect('destroy', Lang.bind(this,
            function() {
                source = null;
            }));
    }
    return source;
}


const NotificationPolicy = new Lang.Class({
    Name: 'PomodoroNotificationPolicy',
    Extends: MessageTray.NotificationGenericPolicy,

    /* override parent method */
    get detailsInLockScreen() {
        return true;
    }
});


const Source = new Lang.Class({
    Name: 'PomodoroNotificationSource',
    Extends: MessageTray.Source,

    ICON_NAME: 'gnome-pomodoro',

    _init: function() {
        this.parent(_("Pomodoro"), this.ICON_NAME);
    },

    /* override parent method */
    _createPolicy: function() {
        return new NotificationPolicy();
    },

    clear: function() {
        let notifications = this.notifications;
        this.notifications = [];

        for (let i = 0; i < notifications.length; i++) {
            notifications[i].destroy();
        }
    },

    close: function() {
        this.destroy();
        this.emit('done-displaying-content', false);
    }
});


const MessagesIndicator = new Lang.Class({
    Name: 'PomodoroMessagesIndicator',

    _init: function() {
        this._count = 0;
        this._sources = [];

        this._container = new St.BoxLayout({ style_class: 'messages-indicator-contents',
                                             reactive: true,
                                             track_hover: true,
                                             x_expand: true,
                                             y_expand: true,
                                             x_align: Clutter.ActorAlign.CENTER });

        this._icon = new St.Icon({ icon_name: 'user-idle-symbolic',
                                   icon_size: 16 });
        this._container.add_actor(this._icon);

        this._label = new St.Label();
        this._container.add_actor(this._label);

        this._highlight = new St.Widget({ style_class: 'messages-indicator-highlight',
                                          x_expand: true,
                                          y_expand: true,
                                          y_align: Clutter.ActorAlign.END,
                                          visible: false });

        this._container.connect('notify::hover', Lang.bind(this,
            function() {
                this._highlight.visible = this._container.hover;
            }));

        let clickAction = new Clutter.ClickAction();
        this._container.add_action(clickAction);
        clickAction.connect('clicked', Lang.bind(this,
            function() {
                Main.messageTray.openTray();
            }));

        Main.messageTray.connect('showing', Lang.bind(this,
            function() {
                this._highlight.visible = false;
                this._container.hover = false;
            }));

        let layout = new Clutter.BinLayout();
        this.actor = new St.Widget({ layout_manager: layout,
                                     style_class: 'messages-indicator',
                                     y_expand: true,
                                     y_align: Clutter.ActorAlign.END,
                                     visible: false });
        this.actor.add_actor(this._container);
        this.actor.add_actor(this._highlight);

        Main.messageTray.connect('source-added', Lang.bind(this, this._onSourceAdded));
        Main.messageTray.connect('source-removed', Lang.bind(this, this._onSourceRemoved));

        let sources = Main.messageTray.getSources();
        sources.forEach(Lang.bind(this, function(source) { this._onSourceAdded(null, source); }));

        Main.overview.connect('showing', Lang.bind(this, this._updateVisibility));
    },

    _onSourceAdded: function(tray, source) {
        if (source.trayIcon)
            return;

        source.connect('count-updated', Lang.bind(this, this._updateCount));
        this._sources.push(source);
        this._updateCount();
    },

    _onSourceRemoved: function(tray, source) {
        this._sources.splice(this._sources.indexOf(source), 1);
        this._updateCount();
    },

    _updateCount: function() {
        let count = 0;
        let hasChats = false;
        this._sources.forEach(Lang.bind(this,
            function(source) {
                count += source.indicatorCount;
                hasChats |= source.isChat;
            }));

        this._count = count;
        this._label.text = ngettext("%d new message",
                                    "%d new messages",
                                   count).format(count);

        this._icon.visible = hasChats;
        this._updateVisibility();
    },

    _updateVisibility: function() {
        let visible = (this._count > 0);

        this.actor.visible = visible;
    }
});


/**
 * ModalDialog class based on ModalDialog from GNOME Shell. We need our own
 * class to have more event signals, different fade in/out times, and different
 * event blocking behavior.
 */
const ModalDialog = new Lang.Class({
    Name: 'PomodoroModalDialog',

    _init: function() {
        this.state = State.CLOSED;

        this._idleMonitor          = Meta.IdleMonitor.get_core();
        this._pushModalDelaySource = 0;
        this._pushModalWatchId     = 0;
        this._pushModalSource      = 0;
        this._pushModalTries       = 0;

        this._monitorConstraint = new Layout.MonitorConstraint();
        this._stageConstraint   = new Clutter.BindConstraint({
                                       source: global.stage,
                                       coordinate: Clutter.BindCoordinate.ALL });

        this._layout = new St.BoxLayout({ vertical: true });

        /* Modal dialogs are fixed width and grow vertically; set the request
         * mode accordingly so wrapped labels are handled correctly during
         * size requests.
         */
        this._layout.request_mode = Clutter.RequestMode.HEIGHT_FOR_WIDTH;

        this._backgroundStack = new St.Widget({ layout_manager: new Clutter.BinLayout() });
        this._backgroundStack.add_actor(this._layout);


        let backgroundBin = new St.Bin({ child: this._backgroundStack,
                                         x_fill: true,
                                         y_fill: true });
        backgroundBin.add_constraint(this._monitorConstraint);

        this.actor = new St.Widget({ accessible_role: Atk.Role.DIALOG,
                                     visible: false,
                                     opacity: 0.0,
                                     x: 0,
                                     y: 0 });
        this.actor.add_constraint(this._stageConstraint);
        this.actor.add_style_class_name('extension-pomodoro-dialog');
        this.actor.add_actor(backgroundBin);
        this.actor.connect('destroy', Lang.bind(this, this._onActorDestroy));
        Main.layoutManager.modalDialogGroup.add_actor(this.actor);

        this._lightbox = new Lightbox.Lightbox(this.actor,
                                               { fadeFactor: FADE_IN_OPACITY,
                                                 inhibitEvents: false });
        this._lightbox.highlight(backgroundBin);
        this._lightbox.actor.add_style_class_name('extension-pomodoro-lightbox');
        this._lightbox.show();

        this._grabHelper = new GrabHelper.GrabHelper(this.actor);
        this._grabHelper.addActor(this._lightbox.actor);

        global.focus_manager.add_group(this.actor);
    },

    open: function(timestamp) {
        if (this.state == State.OPENED || this.state == State.OPENING) {
            return;
        }

        this.state = State.OPENING;

        if (this._pushModalDelaySource == 0) {
            this._pushModalDelaySource = Mainloop.timeout_add(
                        Math.max(MIN_DISPLAY_TIME - IDLE_TIME_TO_PUSH_MODAL, 0),
                        Lang.bind(this, this._onPushModalDelayTimeout));
        }

        this._monitorConstraint.index = global.screen.get_current_monitor();
        this.actor.show();

        Tweener.addTween(this.actor,
                         { opacity: 255,
                           time: FADE_IN_TIME / 1000,
                           transition: 'easeOutQuad',
                           onComplete: Lang.bind(this,
                                function() {
                                    if (this.state == State.OPENING) {
                                        this.state = State.OPENED;
                                        this.emit('opened');
                                    }
                                })
                         });
        this.emit('opening');

        Main.messageTray.close();
    },

    close: function(timestamp) {
        if (this.state == State.CLOSED || this.state == State.CLOSING) {
            return;
        }

        this.popModal(timestamp);
        this.state = State.CLOSING;

        Tweener.addTween(this.actor,
                         { opacity: 0,
                           time: FADE_OUT_TIME / 1000,
                           transition: 'easeOutQuad',
                           onComplete: Lang.bind(this,
                               function() {
                                    if (this.state == State.CLOSING) {
                                        this.state = State.CLOSED;
                                        this.actor.hide();
                                        this.emit('closed');
                                    }
                               })
                         });
        this.emit('closing');
    },

    _onPushModalDelayTimeout: function() {
        /* Don't become modal and block events just yet,
         * wait until user becomes idle.
         */
        if (this._pushModalWatchId == 0) {
            this._pushModalWatchId = this._idleMonitor.add_idle_watch(IDLE_TIME_TO_PUSH_MODAL, Lang.bind(this,
                function(monitor) {
                    if (this._pushModalWatchId) {
                        this._idleMonitor.remove_watch(this._pushModalWatchId);
                        this._pushModalWatchId = 0;
                    }
                    this.pushModal(global.get_current_time());
                }
            ));
        }

        this._pushModalDelaySource = 0;
        return false;
    },

    _pushModal: function(timestamp) {
        if (this.state == State.CLOSED || this.state == State.CLOSING) {
            return false;
        }

        this._lightbox.actor.reactive = true;

        this._grabHelper.ignoreRelease();

        return this._grabHelper.grab({
            actor: this._lightbox.actor,
            onUngrab: Lang.bind(this, this._onUngrab)
        });
    },

    _onPushModalTimeout: function() {
        if (this.state == State.CLOSED || this.state == State.CLOSING) {
            this._pushModalSource = 0;
            return false;
        }

        this._pushModalTries += 1;

        if (this._pushModal(global.get_current_time())) {
            this._pushModalSource = 0;
            return false; /* dialog finally opened */
        }

        if (this._pushModalTries > PUSH_MODAL_TIME_LIMIT * PUSH_MODAL_RATE) {
            this.close();
            this._pushModalSource = 0;
            return false; /* dialog can't become modal */
        }

        return true;
    },

    pushModal: function(timestamp) {
        if (this.state == State.CLOSED || this.state == State.CLOSING) {
            return;
        }

        this._disconnectInternals();

        /* delay pushModal to ignore current events */
        Mainloop.idle_add(Lang.bind(this,
            function() {
                this._pushModalTries = 1;

                if (this._pushModal(global.get_current_time())) {
                    /* dialog became modal */
                }
                else {
                    this._pushModalSource = Mainloop.timeout_add(Math.floor(1000 / PUSH_MODAL_RATE),
                                                                 Lang.bind(this, this._onPushModalTimeout));
                }

                return false;
            }
        ));
    },

    /**
     * Drop modal status without closing the dialog; this makes the
     * dialog insensitive as well, so it needs to be followed shortly
     * by either a close() or a pushModal()
     */
    popModal: function(timestamp) {
        this._disconnectInternals();

        this._grabHelper.ungrab({
            actor: this._lightbox.actor
        });

        this._lightbox.actor.reactive = false;
    },

    _disconnectInternals: function() {
        if (this._pushModalDelaySource) {
            GLib.source_remove(this._pushModalDelaySource);
            this._pushModalDelaySource = 0;
        }
        if (this._pushModalSource) {
            GLib.source_remove(this._pushModalSource);
            this._pushModalSource = 0;
        }
        if (this._pushModalWatchId) {
            this._idleMonitor.remove_watch(this._pushModalWatchId);
            this._pushModalWatchId = 0;
        }
    },

    _onActorDestroy: function() {
        this.close();
        this.emit('destroy');
    },

    _onUngrab: function() {
        this.close();
    },

    destroy: function() {
        this.actor.destroy();
    }
});
Signals.addSignalMethods(ModalDialog.prototype);


const PomodoroEndDialog = new Lang.Class({
    Name: 'PomodoroEndDialog',
    Extends: ModalDialog,

    _init: function(timer) {
        this.parent();

        this.timer = timer;
        this.description = _("It's time to take a break");

        this._openIdleWatchId        = 0;
        this._openWhenIdleWatchId    = 0;
        this._closeWhenActiveWatchId = 0;
        this._actorMappedId          = 0;
        this._timerUpdateId          = 0;

        this._timerLabel = new St.Label({ style_class: 'extension-pomodoro-dialog-timer' });

        this._descriptionLabel = new St.Label({
                                       style_class: 'extension-pomodoro-dialog-description',
                                       text: this.description });
        this._descriptionLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this._descriptionLabel.clutter_text.line_wrap = true;

        let box = new St.BoxLayout({ style_class: 'extension-pomodoro-dialog-box',
                                     vertical: true });
        box.add(this._timerLabel,
                { y_fill: false,
                  y_align: St.Align.START });
        box.add(this._descriptionLabel,
                { y_fill: false,
                  y_align: St.Align.START });
        this._layout.add(box,
                         { expand: true,
                           x_fill: false,
                           y_fill: false,
                           x_align: St.Align.MIDDLE,
                           y_align: St.Align.MIDDLE });

        let messagesIndicator = new MessagesIndicator();
        this._backgroundStack.add_actor(messagesIndicator.actor);

        this._actorMappedId = this.actor.connect('notify::mapped', Lang.bind(this, this._onActorMappedChanged));
    },

    _onActorMappedChanged: function(actor) {
        if (actor.mapped && !this._timerUpdateId) {
            this._timerUpdateId = this.timer.connect('update', Lang.bind(this, this._onTimerUpdate));
            this._onTimerUpdate();
        }

        if (!actor.mapped && this._timerUpdateId) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }
    },

    _onTimerUpdate: function() {
        if (this.timer.getState() == Timer.State.PAUSE) {
            let remaining = this.timer.getRemaining();
            let minutes   = Math.floor(remaining / 60);
            let seconds   = Math.floor(remaining % 60);

            this._timerLabel.set_text('%02d:%02d'.format(minutes, seconds));
        }
    },

    /**
     * Open the dialog and setup closing by user activity.
     */
    open: function(timestamp) {
        this.parent(timestamp);

        if (this._openTimeoutSource) {
            return;
        }

        /* Delay scheduling of closing the dialog by activity
         * until user has chance to see it.
         */
        this._openTimeoutSource = Mainloop.timeout_add(MIN_DISPLAY_TIME, Lang.bind(this,
            function() {
                /* Wait until user becomes slightly idle */
                if (this._idleMonitor.get_idletime() < IDLE_TIME_TO_CLOSE) {
                    this._openIdleWatchId = this._idleMonitor.add_idle_watch(IDLE_TIME_TO_CLOSE, Lang.bind(this,
                        function(monitor) {
                            this.closeWhenActive();
                        }
                    ));
                }
                else {
                    this.closeWhenActive();
                }

                this._openTimeoutSource = 0;
                return false;
            }));
    },

    close: function(timestamp) {
        this._cancelCloseWhenActive();
        this._cancelOpenWhenIdle();

        this.parent(timestamp);
    },

    _cancelOpenWhenIdle: function() {
        if (this._openWhenIdleWatchId) {
            this._idleMonitor.remove_watch(this._openWhenIdleWatchId);
            this._openWhenIdleWatchId = 0;
        }
    },

    openWhenIdle: function() {
        if (this.state == State.OPEN || this.state == State.OPENING) {
            return;
        }

        if (this._openWhenIdleWatchId == 0) {
            this._openWhenIdleWatchId = this._idleMonitor.add_idle_watch(IDLE_TIME_TO_OPEN, Lang.bind(this,
                function(monitor) {
                    this.open();
                }
            ));
        }
    },

    _cancelCloseWhenActive: function() {
        if (this._closeWhenActiveWatchId) {
            this._idleMonitor.remove_watch(this._closeWhenActiveWatchId);
            this._closeWhenActiveWatchId = 0;
        }
    },

    closeWhenActive: function() {
        if (this.state == State.CLOSED || this.state == State.CLOSING) {
            return;
        }

        if (this._closeWhenActiveWatchId == 0) {
            this._closeWhenActiveWatchId = this._idleMonitor.add_user_active_watch(Lang.bind(this,
                function(monitor) {
                    this.close();
                }
            ));
        }
    },

    setDescription: function(text) {
        this.description = text;
        this._descriptionLabel.set_text(this.description);
    },

    destroy: function() {
        this._cancelOpenWhenIdle();
        this._cancelCloseWhenActive();

        if (this._openIdleWatchId) {
            this._idleMonitor.remove_watch(this._openIdleWatchId);
            this._openIdleWatchId = 0;
        }
        if (this._actorMappedId) {
            this.actor.disconnect(this._actorMappedId);
            this._actorMappedId = 0;
        }
        if (this._timerUpdateId) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }

        this.parent();
    }
});


const Notification = new Lang.Class({
    Name: 'PomodoroNotification',
    Extends: MessageTray.Notification,

    _init: function(title, description, params) {
        this.parent(getDefaultSource(), title, description, params);

        /* We want notifications to be shown right after the action,
         * therefore urgency bump.
         */
        this.setUrgency(MessageTray.Urgency.HIGH);

        this.actor.child.add_style_class_name('extension-pomodoro-notification');

        this._overrideForFeedback = false;
        this._showing             = false;
        this._destroying          = false;
        this._bodyLabel           = this.addBody(description);

        this._actorMappedId = this.actor.connect('notify::mapped', Lang.bind(this, this._onActorMappedChanged));
    },

    _onActorMappedChanged: function(actor) {
        if (this._overrideForFeedback) {
            this._overrideForFeedback = false;
            this.setForFeedback(false);
        }
    },

    show: function(force) {
        if (!this._destroying) {
            /* Popup notification regardless of session busy status */
            if (!this.forFeedback && force) {
                this.setForFeedback(true);
                this._overrideForFeedback = true;
            }

            if (!Main.messageTray.contains(this.source)) {
                Main.messageTray.add(this.source);
            }

            this.source.notify(this);
        }
    },

    hide: function() {
        this.emit('done-displaying');

        if (!this.resident) {
            this.destroy();
        }
    },

    _updateBody: function(text) {
        this._bodyLabel.clutter_text.set_markup(text);
        this._bodyLabel.queue_relayout();
    },

    _updateBanner: function(text) {
        this._bannerLabel.clutter_text.set_markup(text);
        this._bannerLabel.queue_relayout();
    },

    close: function() {
        this.emit('done-displaying');
        this.destroy();
    },

    destroy: function(reason) {
        this._destroying = true;

        if (this._actorMappedId) {
            this.actor.disconnect(this._actorMappedId);
            this._actorMappedId = 0;
        }

        this.parent(reason);
    }
});


const PomodoroStart = new Lang.Class({
    Name: 'PomodoroStartNotification',
    Extends: Notification,

    _init: function(timer) {
        this.parent(_("Pomodoro"), null, null);

        this.setResident(true);

        this.timer = timer;

        this._timerUpdateId = 0;

        this.addAction(_("Take a break"), Lang.bind(this,
            function() {
                this.timer.setState(Timer.State.PAUSE);
            }));

        this.connect('destroy', Lang.bind(this,
            function() {
                if (this._timerUpdateId) {
                    this.timer.disconnect(this._timerUpdateId);
                    this._timerUpdateId = 0;
                }
            }));

        this._updateBanner(_("Focus on your task"));
    },

    _onActorMappedChanged: function(actor) {
        this.parent(actor);

        if (actor.mapped && !this._timerUpdateId) {
            this._timerUpdateId = this.timer.connect('update', Lang.bind(this, this._onTimerUpdate));
            this._onTimerUpdate();
        }

        if (!actor.mapped && this._timerUpdateId) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }
    },

    _onTimerUpdate: function() {
        let state = this.timer.getState();

        if (state == Timer.State.POMODORO || state == Timer.State.IDLE) {
            let elapsed       = this.timer.proxy.Elapsed;
            let stateDuration = this.timer.proxy.StateDuration;
            let remaining     = this.timer.getRemaining();
            let minutes       = Math.round(remaining / 60);
            let seconds       = Math.round(remaining % 60);

            if (remaining > 15) {
                seconds = Math.ceil(seconds / 15) * 15;
            }

            let longMessage = (remaining <= 45)
                    ? ngettext("Focus on your task for %d more second.",
                               "Focus on your task for %d more seconds.", seconds).format(seconds)
                    : ngettext("Focus on your task for %d more minute.",
                               "Focus on your task for %d more minutes.", minutes).format(minutes);

            this._updateBody(longMessage);
        }
    },

    show: function() {
        this.parent(true);
    }
});


const PomodoroEnd = new Lang.Class({
    Name: 'PomodoroEndNotification',
    Extends: Notification,

    _init: function(timer) {
        this.parent(_("Take a break!"), null, null);

        this.setResident(true);

        this.timer = timer;

        this._timerUpdateId      = 0;
        this._settingsChangedId  = 0;
        this._shortBreakDuration = 0;
        this._longBreakDuration  = 0;
        this._isLongPause        = null;

        let settings = Extension.extension.settings;
        try {
            this._settingsChangedId  = settings.connect('changed', Lang.bind(this, this._onSettingsChanged));
            this._shortBreakDuration = settings.get_double('short-break-duration');
            this._longBreakDuration  = settings.get_double('long-break-duration');
        }
        catch (error) {
            Extension.extension.logError(error);
        }

        this._switchToPauseButton = this.addAction(null, Lang.bind(this,
            function() {
                let duration = this._isLongPause
                        ? this._shortBreakDuration
                        : this._longBreakDuration;

                this.timer.setState(Timer.State.PAUSE, duration);
            }));

        this.addAction(_("Start pomodoro"), Lang.bind(this,
            function() {
                this.timer.setState(Timer.State.POMODORO);
                this.close();
                Main.messageTray.close();
            }));

        this.connect('destroy', Lang.bind(this,
            function() {
                if (this._settingsChangedId) {
                    Extension.extension.settings.disconnect(this._settingsChangedId);
                    this._settingsChangedId = 0;
                }
                if (this._timerUpdateId) {
                    this.timer.disconnect(this._timerUpdateId);
                    this._timerUpdateId = 0;
                }
            }));
    },

    _onSettingsChanged: function(settings, key) {
        switch (key) {
            case 'short-break-duration':
                this._shortBreakDuration = settings.get_double('short-break-duration');
                break;

            case 'long-break-duration':
                this._longBreakDuration = settings.get_double('long-break-duration');
                break;
        }
    },

    _onActorMappedChanged: function(actor) {
        this.parent(actor);

        if (actor.mapped && !this._timerUpdateId) {
            this._timerUpdateId = this.timer.connect('update', Lang.bind(this, this._onTimerUpdate));
            this._onTimerUpdate();
        }

        if (!actor.mapped && this._timerUpdateId) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }
    },

    _onTimerUpdate: function() {
        let state = this.timer.getState();

        if (state == Timer.State.PAUSE) {
            let elapsed       = this.timer.proxy.Elapsed;
            let stateDuration = this.timer.proxy.StateDuration;
            let remaining     = this.timer.getRemaining();
            let minutes       = Math.round(remaining / 60);
            let seconds       = Math.round(remaining % 60);

            if (remaining > 15) {
                seconds = Math.ceil(seconds / 15) * 15;
            }

            let shortMessage = (remaining <= 45)
                    ? ngettext("You have %d second",
                               "You have %d seconds", seconds).format(seconds)
                    : ngettext("You have %d minute",
                               "You have %d minutes", minutes).format(minutes);

            let longMessage = (remaining <= 45)
                    ? ngettext("You have %d second until next pomodoro.",
                               "You have %d seconds until next pomodoro.", seconds).format(seconds)
                    : ngettext("You have %d minute until next pomodoro.",
                               "You have %d minutes until next pomodoro.", minutes).format(minutes);

            let isLongPause = stateDuration > this._shortBreakDuration;
            let canSwitchPause =
                    (elapsed < this._shortBreakDuration) &&
                    (this._shortBreakDuration < this._longBreakDuration);

            this._updateBanner(shortMessage);
            this._updateBody(longMessage);
            this._updateButtons(isLongPause, canSwitchPause);
        }
    },

    _updateButtons: function(isLongPause, canSwitchPause) {
        if (this._switchToPauseButton.reactive != canSwitchPause) {
            this._switchToPauseButton.reactive  = canSwitchPause;
            this._switchToPauseButton.can_focus = canSwitchPause;
        }

        if (this._isLongPause !== isLongPause) {
            this._isLongPause = isLongPause;
            this._switchToPauseButton.set_label(
                isLongPause ? _("Shorten it") : _("Lengthen it"));
        }
    },

    show: function() {
        this.parent(true);
    }
});


const PomodoroEndReminder = new Lang.Class({
    Name: 'PomodoroEndReminderNotification',
    Extends: Notification,

    _init: function() {
        this.parent(_("Hey, you're missing out on a break"), null, null);

        this.setTransient(true);
        this.setUrgency(MessageTray.Urgency.LOW);

        this._timeoutSource = 0;
        this._interval      = 0;
        this._timeout       = 0;

        this.connect('destroy', Lang.bind(this,
            function() {
                this.unschedule();
            }));
    },

    _onTimeout: function() {
        let display  = global.screen.get_display();
        let idleTime = (display.get_current_time_roundtrip() - display.get_last_user_time()) / 1000;

        /* No need to notify if user seems to be away. We only monitor idle
         * time based on X11, and not Clutter scene which should better reflect
         * to real work.
         */
        if (idleTime < this._timeout * REMINDER_ACCEPTANCE) {
            this.show();
        }
        else {
            this.unschedule();
        }

        this.schedule();

        return false;
    },

    show: function() {
        this.parent(true);
    },

    schedule: function() {
        let intervals  = REMINDER_INTERVALS;
        let reschedule = this._timeoutSource != 0;

        if (this._timeoutSource) {
            GLib.source_remove(this._timeoutSource);
            this._timeoutSource = 0;
        }

        if (this._interval < intervals.length) {
            let interval = Math.ceil(intervals[this._interval] / 1000);

            this._timeout = interval;
            this._timeoutSource = Mainloop.timeout_add_seconds(
                                       interval,
                                       Lang.bind(this, this._onTimeout));
        }

        if (!reschedule) {
            this._interval += 1;
        }
    },

    unschedule: function() {
        if (this._timeoutSource) {
            GLib.source_remove(this._timeoutSource);
            this._timeoutSource = 0;
        }

        this._interval = 0;
        this._timeout  = 0;
    }
});


const Issue = new Lang.Class({
    Name: 'PomodoroIssueNotification',
    Extends: Notification,

    _init: function(message) {
        let title = _("Problem with gnome-pomodoro");
        let url   = Config.PACKAGE_BUGREPORT;

        this.parent(title, message, {});

        this.setTransient(true);

        /* TODO: Check which distro running, check for updates via package manager */

        this.addAction(_("Report issue"), Lang.bind(this,
            function() {
                Util.trySpawnCommandLine('xdg-open ' + GLib.shell_quote(url));
                this.hide();
            }));
    }
});
