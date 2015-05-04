/*
 * Based on 'convenience.js'
 *
 * Copyright (c) 2014 gnome-pomodoro contributors
 *               2012 GNOME Shell Extensions developers
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
 */

const Gettext = imports.gettext;
const Gio = imports.gi.Gio;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Config = Extension.imports.config;


function getSettings(schemaId) {
    let schemaDir = Gio.File.new_for_path(Config.GSETTINGS_SCHEMA_DIR);
    let schemaSource;
    if (schemaDir.query_exists(null)) {
        schemaSource = Gio.SettingsSchemaSource.new_from_directory(schemaDir.get_path(),
                                                                   Gio.SettingsSchemaSource.get_default(),
                                                                   false);
    }
    else {
        schemaSource = Gio.SettingsSchemaSource.get_default();
    }

    let schema = schemaSource.lookup(schemaId, true);
    if (!schema) {
        throw new Error('Schema ' + schemaId + ' could not be found for extension '
                        + Extension.metadata.uuid + '. Please check your installation.');
    }

    return new Gio.Settings({ settings_schema: schema });
}
