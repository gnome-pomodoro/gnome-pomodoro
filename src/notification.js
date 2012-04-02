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

const Clutter = imports.gi.Clutter;
const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;
const Gtk = imports.gi.Gtk;
const St = imports.gi.St;
const Pango = imports.gi.Pango;

const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const ModalDialog = imports.ui.modalDialog;
const ScreenSaver = imports.misc.screenSaver;
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


const NotificationDialog = new Lang.Class({
    Name: 'PomodoroNotificationDialog',
    Extends: ModalDialog.ModalDialog,

    _init: function() {
        this.parent();
        
        this._title = '';
        this._description = '';
        
        this._timeoutSource = 0;
        this._notification = null;
        this._notificationButtons = [];
        this._notificationSource = null;
        this._eventCaptureSource = 0;
        this._eventCaptureId = 0;
        this._screenSaver = null;
        this._screenSaverChangedId = 0;
        
        this.style_class = 'prompt-dialog';
        
        let mainLayout = new St.BoxLayout({ style_class: 'prompt-dialog-main-layout',
                                            vertical: false });
        
        // let icon = new St.Icon(
        //                   { icon_name: 'timer',
        //                     icon_type: St.IconType.SYMBOLIC,
        //                     icon_size: this.ICON_SIZE });
        // mainLayout.add(icon,
        //                   { x_fill:  true,
        //                     y_fill:  false,
        //                     x_align: St.Align.END,
        //                     y_align: St.Align.START });
        
        let messageBox = new St.BoxLayout({ style_class: 'prompt-dialog-message-layout',
                                            vertical: true });
        
        this._titleLabel = new St.Label({ style_class: 'prompt-dialog-headline',
                                          text: '' });
        
        this._descriptionLabel = new St.Label({ style_class: 'prompt-dialog-description',
                                                text: '' });
        this._descriptionLabel.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this._descriptionLabel.clutter_text.line_wrap = true;
        
        messageBox.add(this._titleLabel,
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
        
        this.connect('opened', Lang.bind(this, function() {
                // Close notification once dialog successfully opens
                this._closeNotification();
            }));
    },

    open: function(timestamp) {
        if (ModalDialog.ModalDialog.prototype.open.call(this, timestamp)) {
            this._closeNotification();
            this._disconnectInternals();
            this._enableEventCapture();
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
        this._openNotification();
        
        return ModalDialog.ModalDialog.prototype.close.call(this, timestamp);
    },

    _onTimeout: function() {
        this._tries += 1;
        
        if (this.open()) {
            return false; // dialog finally opened
        }
        if (this._tries > FALLBACK_TIME * FALLBACK_RATE) {
            this.close(); // open notification as fallback
            return false;
        }
        return true; 
    },

    _onScreenSaverChanged: function(object, active) {
        if (!active)
            this.open();
    },

    _openNotification: function() {
        if (!this._notification) {
            let source = new NotificationSource();
            this._notification = new MessageTray.Notification(source, this._title,
                    this._description, {});
            this._notification.setResident(true);
            
            // Force to show description along with title,
            // as this is private property API may change
            try {
                this._notification._titleFitsInBannerMode = true;
            }
            catch(e) {
                global.logError('Pomodoro: ' + e.message);
            }
            
            // Create buttons
            for (let i=0; i < this._notificationButtons.length; i++) {
                try {
                    this._notification.addButton(i, this._notificationButtons[i].label);
                }
                catch (e) {
                    global.logError('Pomodoro: ' + e.message);
                }
            }
            
            // Connect actions
            this._notification.connect('action-invoked', Lang.bind(this, function(object, id) {
                    try {
                        this._notificationButtons[id].action();
                    }
                    catch (e) {
                        global.logError('Pomodoro: ' + e.message);
                    }
                }));
            
            Main.messageTray.add(source);
            source.notify(this._notification);
        }
    },

    _closeNotification: function() {
        if (this._notification) {
            this._notification.destroy(MessageTray.NotificationDestroyedReason.SOURCE_CLOSED);
            this._notification = null;
        }
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

    get title() {
        return this._title;
    },

    setTitle: function(text) {
        this._title = text;
        this._titleLabel.text = text;
        
        if (this._notification)
            this._notification.update(this._title, this._description);
    },

    get description() {
        return this._description;
    },

    setDescription: function(text) {
        this._description = text;
        this._descriptionLabel.text = text;
        
        if (this._notification)
            this._notification.update(this._title, this._description);
    },

    setNotificationButtons: function(buttons) {
        this._notificationButtons = buttons;
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
        this._closeNotification();
        this._disconnectInternals();
        
        ModalDialog.ModalDialog.prototype.close.call(this);
        ModalDialog.ModalDialog.prototype.destroy.call(this);
    }
});
