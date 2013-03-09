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

const Gio = imports.gi.Gio;
const GLib = imports.gi.GLib;

const Config = imports.config;
const Utils = imports.utils;


const Sounds = new Lang.Class({
    Name: 'PomodoroSounds',

    _init: function(timer) {
        this._timer = timer;
        this._settings = new Gio.Settings({ schema: 'org.gnome.pomodoro.preferences.sounds' });

        this._notifyPomodoroStartId = timer.connect(
                    'notify-pomodoro-start', Lang.bind(this, this.notify_pomodoro_start));

        this._notifyPomodoroEndId = timer.connect(
                    'notify-pomodoro-end', Lang.bind(this, this.notify_pomodoro_end));
    },

    play_sound_path: function(path) {
        let file;

        if (path && this._settings.get_boolean('enabled'))
        {
            if (!GLib.path_is_absolute(path))
                path = GLib.build_filenamev([ Config.PACKAGE_DATADIR, 'sounds', path ]);

            file = Gio.file_new_for_path(path);

            if (file.query_exists(null)) {
                try {
                    Utils.try_spawn_command_line('canberra-gtk-play --file='+ GLib.shell_quote(path));
                }
                catch (error) {
                    log('Error playing sound file "'+ path +'": ' + error.message);
                }
            }
            else {
                log('Sound file "'+ path +'" does not exist');
            }
        }
    },

    play_sound_uri: function(uri) {
        this.play_sound_path(GLib.uri_parse_scheme(uri)
                             ? GLib.filename_from_uri(uri, null) : uri);
    },

    notify_pomodoro_start: function() {
        this.play_sound_uri(this._settings.get_string('pomodoro-start-sound'));
    },

    notify_pomodoro_end: function() {
        this.play_sound_uri(this._settings.get_string('pomodoro-end-sound'));
    },

    destroy: function() {
        if (this._timer) {
            this._timer.disconnect(this._notifyPomodoroStartId);
            this._timer.disconnect(this._notifyPomodoroEndId);
        }
    },
});
