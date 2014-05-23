/*
 * Based on 'convenience.js'
 *
 * Copyright (c) 2014 gnome-pomodoro contributors
 *               2012 GNOME Shell Extensions developers
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
 */

const Gettext = imports.gettext;
const Gio = imports.gi.Gio;

const Extension = imports.misc.extensionUtils.getCurrentExtension();
const Config = Extension.imports.config;


function getSettings(schema) {
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

    let schemaObj = schemaSource.lookup(schema, true);
    if (!schemaObj) {
        let extension = ExtensionUtils.getCurrentExtension();

        throw new Error('Schema ' + schema + ' could not be found for extension '
                        + extension.metadata.uuid + '. Please check your installation.');
    }

    return new Gio.Settings({ settings_schema: schemaObj });
}
