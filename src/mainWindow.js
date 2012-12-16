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
const _ = imports.gettext.gettext;

const Gdk = imports.gi.Gdk;
const GLib = imports.gi.GLib;
const Gtk = imports.gi.Gtk;

const Config = imports.config;

const MainWindow = new Lang.Class({
    Name: 'MainWindow',

    _init: function(app) {
        this.window = new Gtk.ApplicationWindow({
                              application: app,
                              window_position: Gtk.WindowPosition.CENTER,
                              icon_name: 'application-x-executable',
                              hide_titlebar_when_maximized: true,
                              title: _("Pomodoro") });
        this.window.set_size_request(600, 400);

        this._vbox = new Gtk.VBox();

        this.window.connect('delete-event',
                            Lang.bind(this, this._quit));
        this.window.connect('key-press-event',
                            Lang.bind(this, this._onKeyPressEvent));

        this.window.add(this._vbox);
        this.window.show_all();
    },

    _onKeyPressEvent: function(widget, event) {
        return false;
    },

    _quit: function() {
        return false;
    },

    showAboutDialog: function() {
        let aboutDialog = new Gtk.AboutDialog();

        aboutDialog.authors = [ 'Arun Mahapatra <pratikarun@gmail.com>',
                                'Kamil Prusko <kamilprusko@gmail.com>' ];
        aboutDialog.translator_credits = _("translator-credits");
        aboutDialog.program_name = _("Pomodoro");
        aboutDialog.version = Config.PACKAGE_VERSION;
        aboutDialog.comments = _("A simple time management utility.");
        aboutDialog.copyright = 'Copyright \u00A9 2012 Arun Mahapatra, Kamil Prusko';
        aboutDialog.logo_icon_name = 'timer-symbolic';
        aboutDialog.license = _("This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.\n\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.\n\nYou should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA");
        aboutDialog.wrap_license = true;

        aboutDialog.modal = true;
        aboutDialog.transient_for = this.window;

        aboutDialog.show();
        aboutDialog.connect('response', function() {
            aboutDialog.destroy();
        });
    }
});
