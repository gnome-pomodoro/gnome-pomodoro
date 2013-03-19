/*
 * Copyright (c) 2013 gnome-shell-pomodoro contributors
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

const MainWindow = imports.mainWindow;
const Config = imports.config;
const DBus = imports.dbus;
const Sounds = imports.sounds;
const Timer = imports.timer;

// Time in milliseconds after which application should quit
const APPLICATION_INACTIVITY_TIMEOUT = 10000;


const Application = new Lang.Class({
    Name: 'Application',
    Extends: Gtk.Application,

    _init: function() {
        Gettext.bindtextdomain(Config.GETTEXT_PACKAGE, Config.PACKAGE_LOCALEDIR);
        Gettext.textdomain(Config.GETTEXT_PACKAGE);
        GLib.set_prgname(Config.PACKAGE_NAME);

        // Run as a service. In this mode, registration fails if the service
        // is already running, and the application will stay around for a while
        // when the use count falls to zero.
        this.parent({ application_id: 'org.gnome.Pomodoro',
                      flags: Gio.ApplicationFlags.IS_SERVICE | Gio.ApplicationFlags.HANDLES_COMMAND_LINE });

        this.set_inactivity_timeout(APPLICATION_INACTIVITY_TIMEOUT);

        this.settings = new Gio.Settings({ schema: 'org.gnome.pomodoro' });
        this.dbus = null;

        this.timer = new Timer.Timer();

        // Setup Plugins
        this.plugins = [
            new Sounds.Sounds(this.timer),
        ];

        this._window = null;

        // Quit service if not used
        this._has_hold = false;

        this.timer.connect('state-changed', Lang.bind(this, function(timer) {
            let is_running = timer.state != Timer.State.NULL;
            if (is_running != this._has_hold) {
                if (is_running)
                    this.hold();
                else
                    this.release();

                this._has_hold = is_running;
            }
        }));

        this.timer.restore();

        this._setup_actions();
    },

    _action_preferences: function(action) {
        this._create_window();
        if (this._window) {
            this._window.set_view('preferences');
            this._window.window.present();
        }
    },

    _action_about: function() {
        this._create_window();
        if (this._window)
            this._window.showAboutDialog();
    },

    _action_quit: function() {
        this.timer.stop();
        this._destroy_window();
    },

    _setup_actions: function() {
        let preferences_action = new Gio.SimpleAction({ name: 'preferences' });
        preferences_action.connect('activate', Lang.bind(this, this._action_preferences));

        let about_action = new Gio.SimpleAction({ name: 'about' });
        about_action.connect('activate', Lang.bind(this, this._action_about));

        let quit_action = new Gio.SimpleAction({ name: 'quit' });
        quit_action.connect('activate', Lang.bind(this, this._action_quit));

        this.add_accelerator('<Primary>q', 'app.quit', null);

        this.add_action(preferences_action);
        this.add_action(about_action);
        this.add_action(quit_action);
    },

    _setup_menu: function() {
        let builder = new Gtk.Builder();
        builder.add_from_resource('/org/gnome/pomodoro/app-menu.ui');

        let menu = builder.get_object('app-menu');
        this.set_app_menu(menu);
    },

    // Emitted on the primary instance immediately after registration.
    vfunc_startup: function() {
        this.parent();

        let resource = Gio.Resource.load(Config.PACKAGE_DATADIR + '/gnome-shell-pomodoro.gresource');
        resource._register();

        this._setup_menu();
    },

    // Save the state before exit.
    // Emitted only on the registered primary instance instance immediately
    // after the main loop terminates.
    vfunc_shutdown: function() {
        this.timer.destroy();

        this.parent();
    },

    // Emitted on the primary instance when an activation occurs.
    // The application must be registered before calling this function.
    vfunc_activate: function() {
        if (this._window)
            this._window.window.present();
    },

    _create_window: function() {
        if (this._window)
            return;

        this._window = new MainWindow.MainWindow(this);
        this._window.window.connect('destroy', Lang.bind(this, function() {
            this._window = null;
        }));
    },

    _destroy_window: function() {
        if (this._window) {
            this._window.window.destroy();
            this._window = null;
        }
    },

    vfunc_command_line: function(cmdline) {
        let args = cmdline.get_arguments();
        if (args.indexOf('--no-default-window') == -1)
            this._create_window();

        this.activate();
        return 0;
    },

    vfunc_dbus_register: function(connection, object_path) {
        if (!this.parent(connection, object_path))
            return false;

        if (!this.dbus)
            this.dbus = new DBus.Pomodoro(this.timer);

        return true;
    },

    vfunc_dbus_unregister: function(connection, object_path) {
        if (this.dbus) {
            this.dbus.destroy();
            this.dbus = null;
        }

        this.parent(connection, object_path);
    }
});
