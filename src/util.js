// A simple pomodoro timer for Gnome-shell
//
// Based on 'convenience.js'
//
// Copyright (C) 2012 Arun Mahapatra, Gnome-shell pomodoro extension contributors
//               2012 GNOME Shell Extensions developers
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

const Gettext = imports.gettext;
const Gio = imports.gi.Gio;

const Config = imports.misc.config;
const ExtensionUtils = imports.misc.extensionUtils;


function initTranslations(domain) {
    let extension = ExtensionUtils.getCurrentExtension();

    domain = domain || extension.metadata['gettext-domain'];

    // check if this extension is installed locally,
    // otherwise assume that extension has been installed in the
    // same prefix as gnome-shell
    let localeDir = extension.dir.get_child('locale');
    if (localeDir.query_exists(null))
        Gettext.bindtextdomain(domain, localeDir.get_path());
    else
        Gettext.bindtextdomain(domain, Config.LOCALEDIR);
}

function getExtensionPath() {
    let extension = ExtensionUtils.getCurrentExtension();
    return extension.dir.get_path();
}

function getSettings(schema) {
    let extension = ExtensionUtils.getCurrentExtension();

    schema = schema || extension.metadata['settings-schema'];

    // check if this extension is installed locally, in that case it has the
    // schema files in a subfolder otherwise assume that extension has been
    // installed in the same prefix as gnome-shell (and therefore schemas are
    // available in the standard folders)
    let schemaDir = extension.dir.get_child('schemas');
    let schemaSource;
    if (schemaDir.query_exists(null))
        schemaSource = Gio.SettingsSchemaSource.new_from_directory(schemaDir.get_path(),
                                                                   Gio.SettingsSchemaSource.get_default(),
                                                                   false);
    else
        schemaSource = Gio.SettingsSchemaSource.get_default();

    let schemaObj = schemaSource.lookup(schema, true);
    if (!schemaObj)
        throw new Error('Schema ' + schema + ' could not be found for extension '
                        + extension.metadata.uuid + '. Please check your installation.');

    return new Gio.Settings({ settings_schema: schemaObj });
}
