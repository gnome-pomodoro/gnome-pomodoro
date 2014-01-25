/*
 * Copyright (c) 2014 gnome-pomodoro contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

const Lang = imports.lang;
const Mainloop = imports.mainloop;
const Signals = imports.signals;

const Clutter = imports.gi.Clutter;
const Gio = imports.gi.Gio;
const Gtk = imports.gi.Gtk;
const GLib = imports.gi.GLib;
const Meta = imports.gi.Meta;
const Pango = imports.gi.Pango;
const Shell = imports.gi.Shell;
const St = imports.gi.St;

const BoxPointer = imports.ui.boxpointer;
const GrabHelper = imports.ui.grabHelper;
const Separator = imports.ui.separator;

const Animation = imports.ui.animation;
const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const PanelMenu = imports.ui.panelMenu;
const Params = imports.misc.params;
const PopupMenu = imports.ui.popupMenu;
const ShellEntry = imports.ui.shellEntry;
const Tweener = imports.ui.tweener;

const DBus = Extension.imports.dbus;

const Gettext = imports.gettext.domain('gnome-pomodoro');
const _ = Gettext.gettext;


const MENU_POPUP_TIMEOUT = 600;
const SCROLL_ANIMATION_TIME = 0.5;


const TaskEntry = new Lang.Class({
    Name: 'PomodoroTaskEntry',
    Extends: PopupMenu.PopupMenuSection,

    _init: function() {
        this.parent();

        this.actor.add_style_class_name('extension-pomodoro-task-entry');
        this.actor._delegate = this;

        this.entry = new St.Entry({
                can_focus: true,
                hint_text: _("Enter new task")
            });
        this.entry.clutter_text.set_max_length(200);
        this.entry.clutter_text.connect('activate', Lang.bind(this, this._onEntryActivated));

        ShellEntry.addContextMenu(this.entry);

        this.actor.add(this.entry, { expand: true });

// TODO: Grab mouse events
//        this.actor.connect('notify::mapped', Lang.bind(this,
//            function() {
//                if (this.actor.mapped) {
//                    this._keyPressEventId =
//                        global.stage.connect('key-press-event',
//                                             Lang.bind(this, this._onKeyPressEvent));
//                } else {
//                    if (this._keyPressEventId)
//                        global.stage.disconnect(this._keyPressEventId);
//                    this._keyPressEventId = 0;
//                }
//            }));
    },

    _onEntryActivated: function(entry) {
        let text = entry.get_text();
        if (text != '') {
            this.emit('task-entered', text);

            entry.set_text('');
        }
    },
});


const Task = new Lang.Class({
    Name: 'PomodoroTask',

    id: 0,

    _init: function (name) {
        if (!Task.prototype.id) {
            Task.prototype.id = 0;
        }

        Task.prototype.id += 1;
        this.id = Task.prototype.id;

        this.name = name;
    }
});


const TaskListItemMenu = new Lang.Class({
    Name: 'PomodoroTaskListItemMenu',
    Extends: PopupMenu.PopupMenu,

    _init: function(source) {
        this.parent(source.actor, 0.5, St.Side.TOP);

        // We want to keep the item hovered while the menu is up
        this.blockSourceEvents = true;

        this._source = source;

        // Chain our visibility and lifecycle to that of the source
        source.actor.connect('notify::mapped', Lang.bind(this, function () {
            if (!source.actor.mapped) {
                this.close();
            }
        }));
        source.actor.connect('destroy', Lang.bind(this, function () {
            this.actor.destroy();
        }));

        Main.uiGroup.add_actor(this.actor);
    },
});
Signals.addSignalMethods(TaskListItemMenu.prototype);


const TaskListItem = new Lang.Class({
    Name: 'PomodoroTaskListItem',
    Extends: PopupMenu.PopupBaseMenuItem,

    _init: function (task, params) {
        this.parent(params);

        this.actor.add_style_class_name('task-list-item');

        this.task = task;
        this.selected = false;

//        if (Clutter.get_default_text_direction() == Clutter.TextDirection.RTL) {
//            this.actor.set_pack_start(false);
//        }

        this.label = new St.Label({ text: task.name });
        this.label.add_style_class_name('name-label');

        this.actor.add_actor(this.label, { expand: true });

        this._menu = null;
        this._menuManager = new PopupMenu.PopupMenuManager(this);

        this.actor.connect('button-press-event', Lang.bind(this, this._onButtonPressEvent));
        this.actor.connect('button-release-event', Lang.bind(this, this._onButtonReleaseEvent));
        this.actor.connect('popup-menu', Lang.bind(this, this._onKeyboardPopupMenu));
    },

    setSelected: function(selected) {
        let selectedChanged = selected != this.selected;
        if (selectedChanged) {
            this.selected = selected;
            if (selected) {
                this.actor.add_style_pseudo_class('selected');
                this.setOrnament(PopupMenu.Ornament.DOT);
            } else {
                this.actor.remove_style_pseudo_class('selected');
                this.setOrnament(PopupMenu.Ornament.NONE);
            }
            this.emit('selected-changed', selected);
        }
    },

    _removeMenuTimeout: function() {
        if (this._menuTimeoutId > 0) {
            Mainloop.source_remove(this._menuTimeoutId);
            this._menuTimeoutId = 0;
        }
    },

    _onDestroy: function() {
        this._removeMenuTimeout();
    },

    _onButtonPressEvent: function(actor, event) {
        let button = event.get_button();
        if (button == 1) {
            this._removeMenuTimeout();
            this._menuTimeoutId = Mainloop.timeout_add(MENU_POPUP_TIMEOUT,
                Lang.bind(this, function() {
                    this.popupMenu();
                }));
        } else if (button == 3) {
            this.popupMenu();
            return true;
        }
        return false;
    },

    /* override PopupBaseMenuItem._onButtonReleaseEvent */
    _onButtonReleaseEvent: function (actor, event) {
        this._removeMenuTimeout();

        if (!this._menu || !this._menu.isOpen) {
            this.activate(event);
        }

        return true;
    },

    _onKeyboardPopupMenu: function() {
        this.popupMenu();
        this._menu.actor.navigate_focus(null, Gtk.DirectionType.TAB_FORWARD, false);
    },

    popupMenu: function() {
        this._removeMenuTimeout();

        if (!this._menu) {
            this._menu = new TaskListItemMenu(this);
            this._menu.connect('open-state-changed', Lang.bind(this, function (menu, isPoppedUp) {
                if (!isPoppedUp) {
                    this._onMenuPoppedDown();
                }
            }));
            Main.overview.connect('hiding', Lang.bind(this, function () {
                this._menu.close();
            }));

            this._menuManager.addMenu(this._menu);

            let item = new PopupMenu.PopupMenuItem(_("Mark as done"));
            this._menu.addMenuItem(item);

            this._menuManager.addMenu(this._menu);
        }

        this.emit('menu-state-changed', true);

        this.actor.set_hover(true);
        this._menu.open();
        this._menuManager.ignoreRelease();

        return false;
    },

    _onMenuPoppedDown: function() {
        this.actor.sync_hover();
        this.emit('menu-state-changed', false);
    },

    _onKeyFocusIn: function(actor) {
        this.setActive(true);
        this.emit('focus-in', Clutter.get_current_event());
    }
});


const TaskList = new Lang.Class({
    Name: 'PomodoroTaskList',
    Extends: PopupMenu.PopupMenuSection,

    _init: function() {
        this.parent();

        this.actor = new St.ScrollView({ x_expand: true,
                                         y_expand: true,
                                         x_fill: true,
                                         y_fill: false,
                                         reactive: true,
                                         y_align: St.Align.START });
        this.actor.add_style_class_name('extension-pomodoro-task-list');
        // this.actor.set_mouse_scrolling (false);
        this.actor.set_overlay_scrollbars (true);
        this.actor.set_policy(Gtk.PolicyType.NEVER,
                              Gtk.PolicyType.AUTOMATIC);

        // FIXME: why fade effect doesn't work?
        this.actor.update_fade_effect(15, 0);
        this.actor.get_effect('fade').fade_edges = true;

        // we are only using ScrollView for the fade effect, hide scrollbars
        this.actor.vscroll.hide();

        this.actor.add_actor(this.box);

        // TODO: write custom _getPreferredHeight to show exactly 10 items or so
        // this.actor.connect('get-preferred-height', Lang.bind(this, this._getPreferredHeight));

        this._items = {};
        this._selected = null;

        let tasks = [
            new Task("Walk the dog"),
            new Task("Buy milk"),
            new Task("Save the world")
        ];

        for (var i=0; i < tasks.length; i++) {
            this.addTask(tasks[i]);
        }
    },

    _moveFocusToItems: function() {
        let hasItems = Object.keys(this._items).length > 0;

        if (!hasItems) {
            return;
        }

        if (global.stage.get_key_focus() != this.actor) {
            return;
        }

        let focusSet = this.actor.navigate_focus(null, Gtk.DirectionType.TAB_FORWARD, false);
        if (!focusSet) {
            Meta.later_add(Meta.LaterType.BEFORE_REDRAW, Lang.bind(this, function() {
                this._moveFocusToItems();
                return false;
            }));
        }
    },

    scrollToItem: function(item) {
        let box = item.actor.get_allocation_box();

        let adjustment = this.actor.get_vscroll_bar().get_adjustment();

        // TODO: only reveal top or bottom item
        let value = (box.y1 + adjustment.step_increment / 2.0) - (adjustment.page_size / 2.0);
        Tweener.removeTweens(adjustment);
        Tweener.addTween (adjustment,
                          { value: value,
                            time: SCROLL_ANIMATION_TIME,
                            transition: 'easeOutQuad' });
    },

    getItemFromTaskId: function(task_id) {
        let item = this._items[task_id];

        if (!item) {
            return null;
        }

        return item;
    },

    addTask: function(task, params) {
        params = Params.parse (params, { animate: false,
                                         style_class: null });
        if (!task.id) {
            return null;
        }

        if (this._items[task.id])
        {
            // TODO: Move task to top

            return this._items[task.id];
        }

        let position = 0;

        let item = new TaskListItem(task);
        item.connect('activate', Lang.bind(this, this._onItemActivate));
        item.connect('focus-in', Lang.bind(this, this._onItemFocusIn));
        this.addMenuItem(item, position);

        this._items[task.id] = item;

        if (params.animate) {
            let [naturalWidth, naturalHeight] = item.actor.get_size();

            item.actor.set_height(0);
            Tweener.addTween(item.actor,
                             { height: naturalHeight,
                               time: 0.2,
                               transition: 'easeOutQuad',
                               onCompleteScope: item,
                               onComplete: function() {
                                   this.actor.set_height(-1);
                               }
                             });
        }

        return item;
    },

    removeTask: function(task) {
        let id = task.id;

        if (!id) {
            return;
        }

        let item = this._items[id];

        if (!item) {
            return;
        }

        item.actor.destroy();
        delete this._items[id];
    },

    _onItemActivate: function(item, event) {
        if (this._selected) {
            this._selected.setSelected(false);
        }

        if (!this._selected || this._selected != item) {
            this._selected = item;
            this._selected.setSelected(true);
            this.emit('task-selected', item.task);
        }
        else {
            this._selected = null;
            this.emit('task-selected', null);
        }
    },

    _onItemFocusIn: function(item, event) {
        switch (event.type())
        {
            case Clutter.EventType.KEY_PRESS:
            case Clutter.EventType.BUTTON_PRESS:
                this.scrollToItem(item);
                break;
        }
    }
});

