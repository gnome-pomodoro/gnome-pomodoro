// A simple pomodoro timer for Gnome-shell
// Copyright (C) 2011,2012 Gnome-shell pomodoro extension contributors
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

const Lightbox = imports.ui.lightbox;
const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const ScreenSaver = imports.misc.screenSaver;
const Tweener = imports.ui.tweener;
const ExtensionUtils = imports.misc.extensionUtils;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const PomodoroUtil = Extension.imports.util;

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
const MIN_DISPLAY_TIME = 1000;
// Time to fade-in or fade-out notification in seconds
const OPEN_AND_CLOSE_TIME = 0.15;

const State = {
    OPENED: 0,
    CLOSED: 1,
    OPENING: 2,
    CLOSING: 3
};


const NotificationSource = new Lang.Class({
    Name: 'PomodoroNotificationSource',
    Extends: MessageTray.Source,

    _init: function() {
        this.parent(_("Pomodoro Timer"));
        
        this._setSummaryIcon(this.createNotificationIcon());
    },

    createNotificationIcon: function() {
        let iconTheme = Gtk.IconTheme.get_default();

        if (!iconTheme.has_icon('timer'))
            iconTheme.append_search_path (PomodoroUtil.getExtensionPath());

        return new St.Icon({ icon_name: 'timer',
                             icon_type: St.IconType.SYMBOLIC,
                             icon_size: this.ICON_SIZE });
    },

    open: function(notification) {
        this.destroyNonResidentNotifications();
    }
});

// ModalDialog class is based on ModalDialog from GNOME Shell. We need our own thing to have
// more event signals, different fade in/out times, and different event blocking behavior
const ModalDialog = new Lang.Class({
    Name: 'PomodoroModalDialog',

    _init: function() {
        this.state = State.CLOSED;
        this._hasModal = false;

        this._group = new St.Widget({ visible: false,
                                      x: 0,
                                      y: 0,
                                      accessible_role: Atk.Role.DIALOG });
        Main.uiGroup.add_actor(this._group);

        let constraint = new Clutter.BindConstraint({ source: global.stage,
                                                      coordinate: Clutter.BindCoordinate.ALL });
        this._group.add_constraint(constraint);
        this._group.connect('destroy', Lang.bind(this, this._onGroupDestroy));

        this._backgroundBin = new St.Bin();
        this._group.add_actor(this._backgroundBin);

        this._dialogLayout = new St.BoxLayout({ style_class: 'extension-pomodoro-dialog',
                                                vertical:    true });

        this._lightbox = new Lightbox.Lightbox(this._group,
                                               { inhibitEvents: true });
        this._lightbox.highlight(this._backgroundBin);
        this._lightbox.actor.style_class = 'extension-pomodoro-lightbox';

        let stack = new Shell.Stack();
        this._backgroundBin.child = stack;

        this._eventBlocker = new Clutter.Group({ reactive: true });
        stack.add_actor(this._eventBlocker);
        stack.add_actor(this._dialogLayout);

        this.contentLayout = new St.BoxLayout({ vertical: true });
        this._dialogLayout.add(this.contentLayout,
                               { x_fill:  true,
                                 y_fill:  true,
                                 x_align: St.Align.MIDDLE,
                                 y_align: St.Align.START });

        global.focus_manager.add_group(this._dialogLayout);
//        this._initialKeyFocus = this._dialogLayout;
//        this._initialKeyFocusDestroyId = 0;
        this._savedKeyFocus = null;
    },

    destroy: function() {
        this.popModal();
        this._group.clear_constraints();
        this._lightbox.destroy();

        // FIXME: As in ModalDialog class, destroy method is broken. If we attempt to destroy
        //        this._group GNOME Shell crashes each time, so we at least destroy as much
        //        as we can
        Main.uiGroup.remove_actor(this._group);
        // this._group.destroy();
    },

    _onGroupDestroy: function() {
        this.emit('destroy');
    },

    _fadeOpen: function() {
        let monitor = Main.layoutManager.focusMonitor;

        this._backgroundBin.set_position(monitor.x, monitor.y);
        this._backgroundBin.set_size(monitor.width, monitor.height);

        this.state = State.OPENING;

        this._dialogLayout.opacity = 255;
        if (this._lightbox)
            this._lightbox.show();
        this._group.opacity = 0;
        this._group.show();
        Tweener.addTween(this._group,
                         { opacity: 255,
                           time: OPEN_AND_CLOSE_TIME,
                           transition: 'easeOutQuad',
                           onComplete: Lang.bind(this,
                               function() {
                                   this.state = State.OPENED;
                                   this.emit('opened');
                               })
                         });
    },

    open: function(timestamp) {
        if (this.state == State.OPENED || this.state == State.OPENING)
            return true;

        if (!this.pushModal(timestamp))
            return false;

        this._fadeOpen();
        this.emit('opening');
        return true;
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
                                   this.state = State.CLOSED;
                                   this._group.hide();
                                   this.emit('closed');
                               })
                         });
        this.emit('closing');
    },

    // Drop modal status without closing the dialog; this makes the
    // dialog insensitive as well, so it needs to be followed shortly
    // by either a close() or a pushModal()
    popModal: function(timestamp) {
        if (!this._hasModal)
            return;

        let focus = global.stage.key_focus;
        if (focus && this._group.contains(focus))
            this._savedKeyFocus = focus;
        else
            this._savedKeyFocus = null;

        Main.popModal(this._group, timestamp);
        global.gdk_screen.get_display().sync();
        this._hasModal = false;

        this._eventBlocker.raise_top();
    },

    pushModal: function (timestamp) {
        if (this._hasModal)
            return true;
        if (!Main.pushModal(this._group, timestamp))
            return false;

        this._hasModal = true;
        if (this._savedKeyFocus) {
            this._savedKeyFocus.grab_key_focus();
            this._savedKeyFocus = null;
        } //else
//            this._initialKeyFocus.grab_key_focus();

        this._eventBlocker.lower_bottom();
        return true;
    }
});
Signals.addSignalMethods(ModalDialog.prototype);


const NotificationDialog = new Lang.Class({
    Name: 'PomodoroNotificationDialog',
    Extends: ModalDialog,

    _init: function() {
        this.parent();
        
        this._timer = '';
        this._description = '';
        
        this._timeoutSource = 0;
        this._eventCaptureSource = 0;
        this._eventCaptureId = 0;
        this._screenSaver = null;
        this._screenSaverChangedId = 0;
        
        this._idleMonitor = new Shell.IdleMonitor();
        this._openWhenIdle = false;
        this._openWhenIdleWatchId = 0;
        this._closeWhenActive = false;
        this._closeWhenActiveWatchId = 0;
        
        let mainLayout = new St.BoxLayout({ style_class: 'extension-pomodoro-dialog-main-layout',
                                            vertical: false });
        
        let messageBox = new St.BoxLayout({ style_class: 'extension-pomodoro-dialog-message-layout',
                                            vertical: true });
        
        this._timerLabel = new St.Label({ style_class: 'extension-pomodoro-dialog-timer',
                                          text: '' });
        
        this._descriptionLabel = new St.Label({ style_class: 'extension-pomodoro-dialog-description',
                                                text: '' });
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
    },

    open: function(timestamp) {
        if (ModalDialog.prototype.open.call(this, timestamp)) {
            this._disconnectInternals();
            
            Mainloop.timeout_add(MIN_DISPLAY_TIME, Lang.bind(this, function() {
                    if (this.state == State.OPENED || this.state == State.OPENING)
                        this.setCloseWhenActive(true);
                    return false;
                }));
            
            return true; // dialog already opened
        }
        
        if (!this._screenSaver)
            this._screenSaver = new ScreenSaver.ScreenSaverProxy();
        
        if (this._screenSaver.screenSaverActive) {
            if (this._screenSaverChangedId == 0)
                this._screenSaverChangedId = this._screenSaver.connectSignal(
                                                           'ActiveChanged',
                                                           Lang.bind(this, this._onScreenSaverChanged));
        }
        else {
            if (this._timeoutSource == 0) {
                this._tries = 1;
                this._timeoutSource = Mainloop.timeout_add(parseInt(1000/FALLBACK_RATE),
                                                           Lang.bind(this, this._onTimeout));
            }
        }
        return false;
    },

    close: function(timestamp) {
        this._disconnectInternals();
        this.setCloseWhenActive(false);

        ModalDialog.prototype.close.call(this, timestamp);
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

    _onTimeout: function() {
        this._tries += 1;
        
        if (this.open()) {
            return false; // dialog finally opened
        }
        if (this._tries > FALLBACK_TIME * FALLBACK_RATE) {
            this.close(); // dialog can't be opened
            return false;
        }
        return true; 
    },

    _onScreenSaverChanged: function(object, active) {
        if (!active)
            this.open();
    },

    _enableEventCapture: function() {
        this._disableEventCapture();
        this._eventCaptureId = global.stage.connect('captured-event', Lang.bind(this, this._onEventCapture));
        this._eventCaptureSource = Mainloop.timeout_add(BLOCK_EVENTS_TIME, Lang.bind(this, this._onEventCaptureTimeout));
    },

    _disableEventCapture: function() {
        if (this._eventCaptureSource != 0) {
            GLib.source_remove(this._eventCaptureSource);
            this._eventCaptureSource = 0;
        }
        if (this._eventCaptureId != 0) {
            global.stage.disconnect(this._eventCaptureId);
            this._eventCaptureId = 0;
        }
    },

    _onEventCapture: function(actor, event) {
        switch(event.type()) {
            case Clutter.EventType.KEY_PRESS:
                let keysym = event.get_key_symbol();
                if (keysym == Clutter.Escape)
                    return false;
                // User might be looking at the keyboard while typing, so continue typing to the app.
                // TODO: pass typed letters to a focused object without blocking them
                this._enableEventCapture();
                return true;
            
            case Clutter.EventType.BUTTON_PRESS:
            case Clutter.EventType.BUTTON_RELEASE:
                return true;
        }
        return false;
    },

    _onEventCaptureTimeout: function() {
        this._disableEventCapture();
        return false;
    },

    setTimer: function(text) {
        this._timer = text;
        this._timerLabel.text = text;
    },

    setDescription: function(text) {
        this._description = text;
        this._descriptionLabel.text = text;
    },

    _disconnectInternals: function() {
        this._disableEventCapture();
        
        if (this._timeoutSource != 0) {
            GLib.source_remove(this._timeoutSource);
            this._timeoutSource = 0;
        }
        if (this._screenSaverChangedId != 0) {
            this._screenSaver.disconnect(this._screenSaverChangedId);
            this._screenSaverChangedId = 0;
        }
    },

    destroy: function() {
        this.setOpenWhenIdle(false);
        this.setCloseWhenActive(false);

        this._disconnectInternals();
        ModalDialog.prototype.destroy.call(this);
    }
});
