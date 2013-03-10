// A simple pomodoro timer for Gnome-shell
// Copyright (C) 2011-2013 Gnome-shell pomodoro extension contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

const Lang = imports.lang;
const Mainloop = imports.mainloop;
const Signals = imports.signals;

const Atk = imports.gi.Atk;
const Clutter = imports.gi.Clutter;
const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;
const Gtk = imports.gi.Gtk;
const Shell = imports.gi.Shell;
const St = imports.gi.St;
const Pango = imports.gi.Pango;

const Layout = imports.ui.layout;
const Lightbox = imports.ui.lightbox;
const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const Tweener = imports.ui.tweener;
const ExtensionUtils = imports.misc.extensionUtils;
const Util = imports.misc.util;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Utils = Extension.imports.utils;

const Gettext = imports.gettext.domain('gnome-shell-pomodoro');
const _ = Gettext.gettext;
const ngettext = Gettext.ngettext;


// Notification dialog blocks user input for a time corresponding to slow typing speed
// of 23 words per minute which translates to 523 miliseconds between key presses,
// and moderate typing speed of 35 words per minute / 343 miliseconds.
// Pressing Enter key takes longer, so more time needed.
const BLOCK_EVENTS_TIME = 600;
// Time after which stop trying to open a dialog and open a notification
const FALLBACK_TIME = 1000;
// Rate per second at which try opening a dialog
const FALLBACK_RATE = Clutter.get_default_frame_rate();

// Time to open notification dialog
const IDLE_TIME_TO_OPEN = 60000;
// Time to determine activity after which notification dialog is closed
const IDLE_TIME_TO_CLOSE = 600;
// Time before user activity is being monitored
const MIN_DISPLAY_TIME = 200;
// Time to fade-in or fade-out notification in seconds
const OPEN_AND_CLOSE_TIME = 0.15;

const NOTIFICATION_DIALOG_OPACITY = 0.55;

const ICON_NAME = 'timer-symbolic';

const State = {
    OPENED: 0,
    CLOSED: 1,
    OPENING: 2,
    CLOSING: 3
};

const Action = {
    START_POMODORO: 1,
    REPORT_BUG: 2,
};


// ModalDialog class is based on ModalDialog from GNOME Shell. We need our own
// class to have more event signals, different fade in/out times, and different
// event blocking behavior
const ModalDialog = new Lang.Class({
    Name: 'PomodoroModalDialog',

    _init: function() {
        this.state = State.CLOSED;
        this._hasModal = false;

        this._idleMonitor = Shell.IdleMonitor.get();
        this._pushModalWatchId = 0;
        this._pushModalSource = 0;
        this._pushModalTries = 0;
        this._capturedEventId = 0;

        this._group = new St.Widget({ visible: false,
                                      x: 0,
                                      y: 0,
                                      accessible_role: Atk.Role.DIALOG });
        Main.uiGroup.add_actor(this._group);

        let constraint = new Clutter.BindConstraint({ source: global.stage,
                                                      coordinate: Clutter.BindCoordinate.ALL });
        this._group.add_constraint(constraint);
        this._group.opacity = 0;
        this._group.connect('destroy', Lang.bind(this, this._onGroupDestroy));

        this._backgroundBin = new St.Bin();
        this._monitorConstraint = new Layout.MonitorConstraint();
        this._backgroundBin.add_constraint(this._monitorConstraint);
        this._group.add_actor(this._backgroundBin);

        this._dialogLayout = new St.BoxLayout({ style_class: 'extension-pomodoro-dialog',
                                                vertical:    true });

        this._lightbox = new Lightbox.Lightbox(this._group,
                                               { fadeFactor: NOTIFICATION_DIALOG_OPACITY,
                                                 inhibitEvents: false });
        this._lightbox.highlight(this._backgroundBin);
        this._lightbox.actor.style_class = 'extension-pomodoro-lightbox';

        this._backgroundBin.child = this._dialogLayout;

        this.contentLayout = new St.BoxLayout({ vertical: true });
        this._dialogLayout.add(this.contentLayout,
                               { x_fill:  true,
                                 y_fill:  true,
                                 x_align: St.Align.MIDDLE,
                                 y_align: St.Align.START });

        global.focus_manager.add_group(this._dialogLayout);
        this._savedKeyFocus = null;
    },

    destroy: function() {
        this._group.destroy();
    },

    _onGroupDestroy: function() {
        this.emit('destroy');
    },

    _fadeOpen: function() {
        this._monitorConstraint.index = global.screen.get_current_monitor();

        this.state = State.OPENING;

        if (this._lightbox)
            this._lightbox.show();

        this._group.show();
        Tweener.addTween(this._group,
                         { opacity: 255,
                           time: OPEN_AND_CLOSE_TIME,
                           transition: 'easeOutQuad',
                           onComplete: Lang.bind(this, this._onFadeOpenComplete)
                         });
    },

    _onFadeOpenComplete: function() {
        if (this.statue == State.OPENING) {
            this.state = State.OPENED;
            this.emit('opened');

            if (this._capturedEventId == 0)
                this._capturedEventId = global.stage.connect('captured-event', Lang.bind(this, this._onCapturedEvent));
        }
    },

    open: function(timestamp) {
        if (this.state == State.OPENED || this.state == State.OPENING)
            return;

        // Don't become modal and block events just yet, monitor when user becomes idle.
        if (this._pushModalWatchId == 0)
            this._pushModalWatchId = this._idleMonitor.add_watch(BLOCK_EVENTS_TIME,
                                                                 Lang.bind(this, this._onPushModalWatch));

        this._fadeOpen();
        this.emit('opening');
    },

    close: function(timestamp) {
        if (this.state == State.CLOSED || this.state == State.CLOSING)
            return;

        this.state = State.CLOSING;
        this.popModal(timestamp);
        this._savedKeyFocus = null;

        Tweener.addTween(this._group,
                         { opacity: 0,
                           time: OPEN_AND_CLOSE_TIME,
                           transition: 'easeOutQuad',
                           onComplete: Lang.bind(this,
                               function() {
                                    if (this.state == State.CLOSING) {
                                        this.state = State.CLOSED;
                                        this._group.hide();
                                        this.emit('closed');
                                    }
                               })
                         });
        this.emit('closing');
    },

    _onPushModalWatch: function(monitor, id, userBecameIdle) {
        if (userBecameIdle) {
            this._idleMonitor.remove_watch(this._pushModalWatchId);
            this._pushModalWatchId = 0;

            if (this.pushModal(global.get_current_time())) {
                // dialog became modal
            }
            else
                if (this._timeoutSource == 0) {
                    this._pushModalTries = 1;
                    this._pushModalSource = Mainloop.timeout_add(parseInt(1000/FALLBACK_RATE),
                                                                 Lang.bind(this, this._onPushModalTimeout));
                }
        }
    },

    _onPushModalTimeout: function() {
        this._pushModalTries += 1;

        if (this.pushModal(global.get_current_time())) {
            return false; // dialog finally opened
        }
        else
            if (this._pushModalTries > FALLBACK_TIME * FALLBACK_RATE) {
                this.close(); // dialog can't become modal
                return false;
            }
        return true;
    },

    _onCapturedEvent: function(actor, event) {
        switch (event.type()) {
            case Clutter.EventType.KEY_PRESS:
                let symbol = event.get_key_symbol();
                if (symbol == Clutter.Escape) {
                    this.close();
                    return true;
                }
                break;
        }
        return false;
    },

    // Drop modal status without closing the dialog; this makes the
    // dialog insensitive as well, so it needs to be followed shortly
    // by either a close() or a pushModal()
    popModal: function(timestamp) {
        this._disconnectInternals();

        if (!this._hasModal)
            return;

        try {
            Main.popModal(this._group, timestamp);
            global.gdk_screen.get_display().sync();
        }
        catch (error) {
            // For some reason modal might have been popped externally
        }

        let focus = global.stage.key_focus;
        if (focus && this._group.contains(focus))
            this._savedKeyFocus = focus;
        else
            this._savedKeyFocus = null;

        this._hasModal = false;
        this._lightbox.actor.reactive = false;
    },

    pushModal: function (timestamp) {
        if (this._hasModal)
            return true;
        if (!Main.pushModal(this._group, timestamp))
            return false;

        this._hasModal = true;
        this._lightbox.actor.reactive = true;

        if (this._savedKeyFocus) {
            this._savedKeyFocus.grab_key_focus();
            this._savedKeyFocus = null;
        }

        return true;
    },

    _disconnectInternals: function() {
        if (this._pushModalWatchId != 0) {
            this._idleMonitor.remove_watch(this._pushModalWatchId);
            this._pushModalWatchId = 0;
        }
        if (this._pushModalSource != 0) {
            GLib.source_remove(this._pushModalSource);
            this._pushModalSource = 0;
        }
        if (this._capturedEventId != 0) {
            global.stage.disconnect(this._capturedEventId);
            this._capturedEventId = 0;
        }
    }
});
Signals.addSignalMethods(ModalDialog.prototype);


const PomodoroEndDialog = new Lang.Class({
    Name: 'PomodoroEndDialog',
    Extends: ModalDialog,

    _init: function() {
        this.parent();

        this._description = _("It's time to take a break!");

        this._openWhenIdle = false;
        this._openWhenIdleWatchId = 0;
        this._closeWhenActive = false;
        this._closeWhenActiveWatchId = 0;

        let mainLayout = new St.BoxLayout({ style_class: 'extension-pomodoro-dialog-main-layout',
                                            vertical: false });

        let messageBox = new St.BoxLayout({ style_class: 'extension-pomodoro-dialog-message-layout',
                                            vertical: true });

        this._timerLabel = new St.Label({ style_class: 'extension-pomodoro-dialog-timer' });

        this._descriptionLabel = new St.Label({ style_class: 'extension-pomodoro-dialog-description',
                                                text: this._description });
        this._descriptionLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this._descriptionLabel.clutter_text.line_wrap = true;

        messageBox.add(this._timerLabel,
                            { y_fill:  false,
                              y_align: St.Align.START });
        messageBox.add(this._descriptionLabel,
                            { y_fill:  true,
                              y_align: St.Align.START });
        mainLayout.add(messageBox,
                            { x_fill: true,
                              y_align: St.Align.START });
        this.contentLayout.add(mainLayout,
                            { x_fill: true,
                              y_fill: true });

        this.setRemainingTime(0);
    },

    open: function(timestamp) {
        this.parent(timestamp);

        Mainloop.timeout_add(MIN_DISPLAY_TIME, Lang.bind(this, function() {
                if (this.state == State.OPENED || this.state == State.OPENING)
                    this.setCloseWhenActive(true);
                return false;
            }));
    },

    close: function(timestamp) {
        this.setCloseWhenActive(false);

        this.parent(timestamp);
    },

    setOpenWhenIdle: function(enabled) {
        this._openWhenIdle = enabled;

        if (this._openWhenIdleWatchId != 0) {
            this._idleMonitor.remove_watch(this._openWhenIdleWatchId);
            this._openWhenIdleWatchId = 0;
        }
        if (enabled) {
            this._openWhenIdleWatchId = this._idleMonitor.add_watch(IDLE_TIME_TO_OPEN,
                                            Lang.bind(this, function(monitor, id, userBecameIdle) {
                if (userBecameIdle)
                    this.open();
            }));
        }
    },

    setCloseWhenActive: function(enabled) {
        this._closeWhenActive = enabled;

        if (this._closeWhenActiveWatchId != 0) {
            this._idleMonitor.remove_watch(this._closeWhenActiveWatchId);
            this._closeWhenActiveWatchId = 0;
        }
        if (enabled) {
            this._closeWhenActiveWatchId = this._idleMonitor.add_watch(IDLE_TIME_TO_CLOSE,
                                           Lang.bind(this, function(monitor, id, userBecameIdle) {
                if (!userBecameIdle)
                    this.close();
            }));
        }
    },

    setRemainingTime: function(remaining) {
        let minutes = parseInt(remaining / 60);
        let seconds = parseInt(remaining % 60);

        this._timerLabel.set_text('%02d:%02d'.format(minutes, seconds));
    },

    setDescription: function(text) {
        this._description = text;
        this._descriptionLabel.text = text;
    },

    destroy: function() {
        this.setOpenWhenIdle(false);
        this.setCloseWhenActive(false);

        this.parent();
    }
});

const Source = new Lang.Class({
    Name: 'PomodoroNotificationSource',
    Extends: MessageTray.Source,

    _init: function() {
        this.parent(_("Pomodoro"));
    },

    createIcon: function(size) {
        return new St.Icon({ icon_name: ICON_NAME,
                             icon_size: size });
    }
});

const Notification = new Lang.Class({
    Name: 'PomodoroNotification',
    Extends: MessageTray.Notification,

    _init: function(source, title, description, params) {
        this.parent(source, title, description, params);

        // Force to show description along with title,
        // as this is private property, API might change
        try {
            this._titleFitsInBannerMode = true;
        }
        catch (error) {
            global.log('Pomodoro: ' + error.message);
        }
    },

    show: function() {
        if (!Main.messageTray.contains(this.source))
            Main.messageTray.add(this.source);

        if (this.source)
            this.source.notify(this);
    },

    hide: function() {
        this.emit('done-displaying');
    }
});

const PomodoroStart = new Lang.Class({
    Name: 'PomodoroStartNotification',
    Extends: Notification,

    _init: function(source) {
        this.parent(source,
                    _("Pause finished"),
                    _("A new pomodoro is starting"),
                    null);
        this.setTransient(true);
    }
});

const PomodoroEnd = new Lang.Class({
    Name: 'PomodoroEndNotification',
    Extends: Notification,

    _init: function(source) {
        let title = _("Take a break!");
        let description = '';

        this.parent(source, title, description, null);

        this.setResident(true);
        this.addButton(Action.START_POMODORO, _("Start a new pomodoro"));
    },

    setRemainingTime: function(remaining) {
        let seconds = Math.floor(remaining % 60);
        let minutes = Math.round(remaining / 60);
        let message = (remaining <= 45)
                                    ? ngettext("You have %d second left\n",
                                               "You have %d seconds left\n", seconds).format(seconds)
                                    : ngettext("You have %d minute left\n",
                                               "You have %d minutes left\n", minutes).format(minutes);

        this.update(this.title, message, {});
    }
});

const Issue = new Lang.Class({
    Name: 'PomodoroIssueNotification',
    Extends: Notification,

    _init: function(source) {
        let extension = ExtensionUtils.getCurrentExtension();
        let service   = extension.metadata['service'];
        let url       = extension.metadata['url'];
        let installed = Gio.file_new_for_path(service).query_exists(null);

        let title = _("Could not run pomodoro");
        let description = installed
                    ? _("Something went badly wrong...")
                    : _("Looks like the app is not installed");

        this.parent(source, title, description, {});
        this.setUrgency(MessageTray.Urgency.HIGH);
        this.setTransient(true);

        // TODO: Check which distro running, install via package manager

        // FIXME: Gnome Shell crashes due to missing schema file,
        //        so offer to install the app doesn't work right now

        if (installed)
            this.addButton(Action.REPORT_BUG, _("Report issue"));
        else
            this.addButton(Action.VISIT_WEBSITE, _("Install it"));

        this.connect('action-invoked', Lang.bind(this, function(notification, action) {
            notification.hide();
            if (action == Action.REPORT_BUG)
                Util.trySpawnCommandLine('xdg-open ' + GLib.shell_quote(url));
        }));
    }
});
