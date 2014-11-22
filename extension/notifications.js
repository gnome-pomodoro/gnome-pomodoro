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

const GLib = imports.gi.GLib;

const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const Util = imports.misc.util;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Config = Extension.imports.config;
const Timer = Extension.imports.timer;

const Gettext = imports.gettext.domain(Config.GETTEXT_PACKAGE);
const _ = Gettext.gettext;
const ngettext = Gettext.ngettext;


/* Remind about ongoing break in given delays */
const REMINDER_INTERVALS = [75000];

/* Ratio between user idle time and time between reminders to determine
 * whether user is away
 */
const REMINDER_ACCEPTANCE = 0.66;


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

    setShowInLockScreen: function(enabled) {
        this.isMusic = enabled;
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


const PomodoroEndReminderNotification = new Lang.Class({
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


const IssueNotification = new Lang.Class({
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
