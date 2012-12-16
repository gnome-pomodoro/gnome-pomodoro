/*
 * Copyright (c) 2012 gnome-shell-pomodoro contributors
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
 *
 */

const Lang = imports.lang;
const Mainloop = imports.mainloop;
const Gettext = imports.gettext;
const _ = imports.gettext.gettext;

const Gdk = imports.gi.Gdk;
const Gio = imports.gi.Gio;
const Gtk = imports.gi.Gtk;
const GLib = imports.gi.GLib;

const Main = imports.main;
const MainWindow = imports.mainWindow;
const Config = imports.config;

const Application = new Lang.Class({
    Name: 'Application',
    Extends: Gtk.Application,

    instance: null,

    _init: function() {
        Gettext.bindtextdomain(Config.GETTEXT_PACKAGE, Config.PACKAGE_LOCALEDIR);
        Gettext.textdomain(Config.GETTEXT_PACKAGE);
        GLib.set_prgname(Config.PACKAGE_NAME);

        Application.instance = this;

        this.settings = new Gio.Settings({ schema: 'org.gnome.shell.extensions.pomodoro' });

        this.parent({ application_id: 'org.gnome.Pomodoro',
                      flags: Gio.ApplicationFlags.FLAGS_NONE });
    },

    get_default: function() {
        return Application.instance;
    },

    _onActionQuit: function() {
        this._mainWindow.window.destroy();
    },

    _onActionAbout: function() {
        this._mainWindow.showAboutDialog();
    },

    _initActions: function() {
        let actionEntries = [
            { name: 'quit',
              callback: this._onActionQuit,
              accel: '<Primary>q' },
            { name: 'about',
              callback: this._onActionAbout }
        ];

        actionEntries.forEach(Lang.bind(this,
            function(actionEntry) {
                let state = actionEntry.state;
                let parameterType = actionEntry.parameter_type ?
                    GLib.VariantType.new(actionEntry.parameter_type) : null;
                let action;

                if (state)
                    action = Gio.SimpleAction.new_stateful(actionEntry.name,
                        parameterType, actionEntry.state);
                else
                    action = new Gio.SimpleAction({ name: actionEntry.name });

                if (actionEntry.create_hook)
                    actionEntry.create_hook.apply(this, [action]);

                if (actionEntry.callback)
                    action.connect('activate', Lang.bind(this, actionEntry.callback));

                if (actionEntry.accel)
                    this.add_accelerator(actionEntry.accel, 'app.' + actionEntry.name, null);

                this.add_action(action);
            }));
    },

    _initAppMenu: function() {
        let builder = new Gtk.Builder();
        builder.add_from_resource('/org/gnome/pomodoro/app-menu.ui');

        let menu = builder.get_object('app-menu');
        this.set_app_menu(menu);
    },

    vfunc_startup: function() {
        this.parent();

        Gtk.init(null);

        let resource = Gio.Resource.load(Config.PACKAGE_DATADIR + '/gnome-shell-pomodoro.gresource');
        resource._register();

        this._initActions();
        this._initAppMenu();

        this._mainWindow = new MainWindow.MainWindow(this);
    },

    vfunc_activate: function() {
        this._mainWindow.window.present();
    }
});
