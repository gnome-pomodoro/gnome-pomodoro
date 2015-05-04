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

const GLib = imports.gi.GLib;
const Meta = imports.gi.Meta;
const St = imports.gi.St;

const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const Util = imports.misc.util;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Config = Extension.imports.config;
const Timer = Extension.imports.timer;
const Utils = Extension.imports.utils;

const Gettext = imports.gettext.domain(Config.GETTEXT_PACKAGE);
const _ = Gettext.gettext;
const ngettext = Gettext.ngettext;


const IDLE_TIME_TO_ACKNOWLEDGE_REMINDER = 45;

const REMINDER_TIMEOUT = 75;

const REMINDER_MIN_REMAINING_TIME = 60;


function getDefaultSource()
{
    let extension = Extension.extension;
    let source = extension.notificationSource;

    /* a walkaround for ScreenShield requiring new source for each
       music notification */
    if (source && Main.sessionMode.isLocked) {
        source.destroy();
        source = null;
    }

    if (!source || source._destroying) {
        source = new Source();
        source.connect('destroy', Lang.bind(source,
            function(source) {
                if (extension.notificationSource === source) {
                    extension.notificationSource = null;
                }
            }));
    }

    extension.notificationSource = source;

    return source;
}


const Source = new Lang.Class({
    Name: 'PomodoroNotificationSource',
    Extends: MessageTray.Source,

    ICON_NAME: 'gnome-pomodoro',

    _init: function() {
        this.parent(_("Pomodoro"), this.ICON_NAME);
    },

    /* override parent method */
    _createPolicy: function() {
        return new MessageTray.NotificationPolicy({ showInLockScreen: true,
                                                    detailsInLockScreen: true });
    },

    /* override parent method */
    get isClearable() {
        return false;
    },

    destroyNotifications: function(notifications) {
        for (let i = notifications.length - 1; i >= 0; i--) {
            if (notifications[i]) {
                notifications[i].destroy();
            }
        }
    },

    destroyAllNotifications: function() {
        this.destroyNotifications(this.notifications);
    },

    close: function() {
        this.destroy();
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

        this._restoreForFeedback = false;
        this._showing            = false;
        this._bodyLabel          = this.addBody(description);

        this._actorMappedId = this.actor.connect('notify::mapped', Lang.bind(this, this._onActorMappedChanged));

        this.connect('destroy', Lang.bind(this,
            function() {
                if (this._actorMappedId) {
                    this.actor.disconnect(this._actorMappedId);
                    this._actorMappedId = 0;
                }
            }));

        this.source.connect('destroy', Lang.bind(this,
            function() {
                this.source = null;
            }));
    },

    _onActorMappedChanged: function(actor) {
        if (this._restoreForFeedback) {
            this._restoreForFeedback = false;
            this.setForFeedback(false);
        }

        if (actor.mapped) {
            this.emit('mapped');
        }
        else {
            this.emit('unmapped');
        }
    },

    addBody: function(text, style) {
        let actor = new St.Label({ text: text || '',
                                   reactive: true });

        this.addActor(actor, style);
        return actor;
    },

    setShowInLockScreen: function(enabled) {
        this.isMusic = enabled;
    },

    show: function() {
        if (!this.source) {
            this.source = getDefaultSource();
        }

        if (this.source) {
            /* Popup notification regardless of session busy status */
            if (!this.forFeedback) {
                this.setForFeedback(true);
                this._restoreForFeedback = true;
            }

            /* Add notification to source before "source-added"
               signal gets emitted */
            this.source.pushNotification(this);

            if (!Main.messageTray.contains(this.source)) {
                Main.messageTray.add(this.source);
            }

            this.source.notify(this);
        }
        else {
            Extension.extension.logError('Called Notification.show() after destroy()');
        }
    },

    hide: function() {
        this.emit('done-displaying');

        if (!this.resident) {
            this.destroy();
        }
    },

    _updateBody: function(text) {
        try {
            if (this._bodyLabel.clutter_text) {
                this._bodyLabel.clutter_text.set_text(text || '');
                this._bodyLabel.queue_relayout();
            }
        }
        catch (error) {
            Extension.extension.logError(error.message);
        }
    },

    _updateBanner: function(text) {
        try {
            if (this._bannerLabel.clutter_text) {
                this._bannerLabel.clutter_text.set_text(text || '');
                this._bannerLabel.queue_relayout();
            }
        }
        catch (error) {
            Extension.extension.logError(error.message);
        }
    },

    close: function() {
        this.emit('done-displaying');
        this.destroy();
    }
});


const PomodoroStartNotification = new Lang.Class({
    Name: 'PomodoroStartNotification',
    Extends: Notification,

    _init: function(timer) {
        this.parent(_("Pomodoro"), null, null);

        this.setResident(true);
        this.setShowInLockScreen(true);

        this.timer = timer;

        this._timerUpdateId = 0;

        this.addAction(_("Take a break"), Lang.bind(this,
            function() {
                this.timer.setState(Timer.State.PAUSE);
            }));

        this.connect('mapped', Lang.bind(this, this._onActorMapped));
        this.connect('unmapped', Lang.bind(this, this._onActorUnmapped));
        this.connect('destroy', Lang.bind(this, this._onActorUnmapped)); // XXX

        this._updateBanner(_("Focus on your task"));
    },

    _onActorMapped: function() {
        if (!this._timerUpdateId) {
            this._timerUpdateId = this.timer.connect('update', Lang.bind(this, this._onTimerUpdate));
            this._onTimerUpdate();
        }
    },

    _onActorUnmapped: function() {
        if (this._timerUpdateId) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }
    },

    _onTimerUpdate: function() {
        let state = this.timer.getState();

        if (state == Timer.State.POMODORO || state == Timer.State.IDLE) {
            let elapsed       = this.timer.getElapsed();
            let stateDuration = this.timer.getStateDuration();
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
    }
});


const PomodoroEndNotification = new Lang.Class({
    Name: 'PomodoroEndNotification',
    Extends: Notification,

    _init: function(timer) {
        this.parent(_("Take a break!"), null, null);

        this.setResident(true);
        this.setShowInLockScreen(true);

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

        this.connect('mapped', Lang.bind(this, this._onActorMapped));
        this.connect('unmapped', Lang.bind(this, this._onActorUnmapped));
        this.connect('destroy', Lang.bind(this,
            function() {
                this._onActorUnmapped();

                if (this._settingsChangedId) {
                    Extension.extension.settings.disconnect(this._settingsChangedId);
                    this._settingsChangedId = 0;
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

    _onActorMapped: function() {
        if (!this._timerUpdateId) {
            this._timerUpdateId = this.timer.connect('update', Lang.bind(this, this._onTimerUpdate));
            this._onTimerUpdate();
        }
    },

    _onActorUnmapped: function() {
        if (this._timerUpdateId) {
            this.timer.disconnect(this._timerUpdateId);
            this._timerUpdateId = 0;
        }
    },

    _onTimerUpdate: function() {
        let state = this.timer.getState();

        if (state == Timer.State.PAUSE) {
            let elapsed       = this.timer.getElapsed();
            let stateDuration = this.timer.getStateDuration();
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
    }
});


const ReminderManager = new Lang.Class({
    Name: 'PomodoroReminderManager',

    _init: function(timer) {
        this.timer = timer;
        this.acknowledged = false;

        this._idleMonitor = Meta.IdleMonitor.get_core();
        this._idleWatchId = 0;
        this._timeoutSource = 0;
        this._blockCount = 0;
        this._isScheduled = false;
    },

    get isScheduled() {
        return this._isScheduled;
    },

    get isBlocked() {
        return this._blockCount != 0;
    },

    block: function() {
        this._blockCount += 1;

        if (this._timeoutSource) {
            Mainloop.source_remove(this._timeoutSource);
            this._timeoutSource = 0;
        }
    },

    unblock: function() {
        this._blockCount -= 1;

        if (this._blockCount < 0) {
            Extension.extension.logError('Spurious call for reminder unblock');
        }

        if (!this.isBlocked && this.isScheduled) {
            this.schedule();
        }
    },

    _onIdleTimeout: function(monitor) {
        if (this._idleWatchId) {
            this._idleMonitor.remove_watch(this._idleWatchId);
            this._idleWatchId = 0;
        }

        this.acknowledged = true;
    },

    _onTimeout: function() {
        this._isScheduled = false;
        this._timeoutSource = 0;

        if (this._idleWatchId) {
            this._idleMonitor.remove_watch(this._idleWatchId);
            this._idleWatchId = 0;
        }

        /* acknowledge break if playing a video or playing a game */
        let info = Utils.getFocusedWindowInfo();

        if (info.isPlayer && info.isFullscreen) {
            this.acknowledged = true;
        }

        if (!this.acknowledged && this.timer.getRemaining() > REMINDER_MIN_REMAINING_TIME) {
            this.emit('notify');
        }

        return GLib.SOURCE_REMOVE;
    },

    schedule: function() {
        let seconds = REMINDER_TIMEOUT;

        this._isScheduled = true;

        if (this._timeoutSource) {
            Mainloop.source_remove(this._timeoutSource);
            this._timeoutSource = 0;
        }

        if (!this.isBlocked) {
            this._timeoutSource = Mainloop.timeout_add_seconds(
                                       seconds,
                                       Lang.bind(this, this._onTimeout));
        }

        if (this._idleWatchId == 0) {
            this._idleWatchId = this._idleMonitor.add_idle_watch(IDLE_TIME_TO_ACKNOWLEDGE_REMINDER * 1000, Lang.bind(this, this._onIdleTimeout));
        }
    },

    unschedule: function() {
        this._isScheduled = false;

        if (this._timeoutSource) {
            Mainloop.source_remove(this._timeoutSource);
            this._timeoutSource = 0;
        }

        if (this._idleWatchId) {
            this._idleMonitor.remove_watch(this._idleWatchId);
            this._idleWatchId = 0;
        }
    },

    destroy: function() {
        this.unschedule();

        this.emit('destroy');
    }
});
Signals.addSignalMethods(ReminderManager.prototype);


const PomodoroEndReminderNotification = new Lang.Class({
    Name: 'PomodoroEndReminderNotification',
    Extends: Notification,

    _init: function() {
        let title = _("Hey!");
        let description = _("You're missing out on a break");

        this.parent(title, null, null);

        this.setTransient(true);
        this.setUrgency(MessageTray.Urgency.LOW);

        this._updateBanner(description);
        this._updateBody(description);
    }
});


const IssueNotification = new Lang.Class({
    Name: 'PomodoroIssueNotification',
    Extends: MessageTray.Notification,

    _init: function(message) {
        let source = getDefaultSource();
        let title  = _("Pomodoro");
        let url    = Config.PACKAGE_BUGREPORT;

        this.parent(source, title, message, { bannerMarkup: true });

        this.setTransient(true);
        this.setUrgency(MessageTray.Urgency.HIGH);

        this.addAction(_("Report issue"), Lang.bind(this,
            function() {
                Util.trySpawnCommandLine('xdg-open ' + GLib.shell_quote(url));
                Main.messageTray.close();
            }));
    },

    show: function() {
        if (!Main.messageTray.contains(this.source)) {
            Main.messageTray.add(this.source);
        }

        this.source.notify(this);
    },

    close: function() {
        this.emit('done-displaying');
        this.destroy();
    }
});
