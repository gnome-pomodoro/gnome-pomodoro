/*
 * Copyright (c) 2022-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;


namespace Ft.Database
{
    private const uint VERSION = 3;
    private const string MIGRATIONS_URI = "resource:///io/github/focustimerhq/FocusTimer/migrations";
    private const string DATE_FORMAT = "%Y-%m-%d";  // TODO: make functions to convert date

    private Gom.Adapter? adapter = null;
    private Gom.Repository? repository = null;

    public unowned Gom.Repository? get_repository ()
    {
        return Ft.Database.repository;
    }

    private void make_directory_with_parents (GLib.File directory)
    {
        if (!directory.query_exists ())
        {
            try {
                directory.make_directory_with_parents ();
            }
            catch (GLib.Error error) {
                GLib.warning ("Failed to create directory: %s", error.message);
            }
        }
    }

    /**
     * Convenience function to execute multiline SQL.
     *
     * `Gom.Adapter.execute_sql` is limited to single line queries.
     *
     * This MUST be called from within a write transaction using
     * Gom.Adapter.queue_write().
     */
    private void execute_sql (Gom.Adapter adapter,
                              string      sql)
                              throws GLib.Error
    {
        unowned var database = adapter.get_handle ();
        string error_message;

        if (database.exec (sql, null, out error_message) != Sqlite.OK) {
            throw new Gom.Error.COMMAND_SQLITE (error_message);
        }
    }

    private bool is_migration_applied (Gom.Repository repository,
                                       Gom.Adapter    adapter,
                                       uint           version)
    {
        try {
            Gom.Cursor? cursor = null;
            var check_command = (Gom.Command) GLib.Object.@new (typeof (Gom.Command),
                                                                adapter: adapter);
            check_command.set_sql ("SELECT 1 FROM _gom_version WHERE version = ? LIMIT 1;");
            check_command.set_param_uint (0U, version);

            check_command.execute (out cursor);

            if (cursor != null && cursor.next ()) {
                return true;
            }
        }
        catch (GLib.Error error) {
        }

        return false;
    }

    // public because it's used in tests
    public bool migrate_repository (Gom.Repository repository,
                                    Gom.Adapter    adapter,
                                    uint           version)
                                    throws GLib.Error
    {
        var is_test = Ft.is_test ();

        // Gom tries to re-apply last migration (bug in Gom?).
        if (is_migration_applied (repository, adapter, version))
        {
            if (!is_test) {
                GLib.info ("Migration version %u already applied, skipping", version);
            }

            return true;
        }

        uint8[] file_contents;

        var file = File.new_for_uri (@"$(MIGRATIONS_URI)/version-$(version).sql");
        file.load_contents (null, out file_contents, null);

        try {
            if (!is_test) {
                GLib.info ("Migrating database to version %u", version);
            }

            Ft.Database.execute_sql (adapter, (string) file_contents);
        }
        catch (GLib.Error error) {
            throw error;
        }

        return true;
    }

    private Gom.Repository? open_repository (Gom.Adapter adapter,
                                             GLib.File?  file)
    {
        Gom.Repository? repository = null;

        try {
            if (file != null) {
                make_directory_with_parents (file.get_parent ());
                adapter.open_sync (file.get_uri ());
            }
            else {
                adapter.open_sync (":memory:");
            }
        }
        catch (GLib.Error error) {
            GLib.critical ("Failed to open database '%s': %s", file?.get_uri (), error.message);
            return null;
        }

        adapter.queue_write (
            () => {
                try {
                    adapter.execute_sql ("PRAGMA foreign_keys = ON;");
                }
                catch (GLib.Error error) {
                    GLib.warning ("Failed to enable 'foreign_keys': %s", error.message);
                }
            });

        try {
            repository = new Gom.Repository (adapter);

            // TODO: back-up before migrating

            repository.migrate_sync (Ft.Database.VERSION,
                                     Ft.Database.migrate_repository);
        }
        catch (GLib.Error error) {
            GLib.error ("Failed to migrate database: %s", error.message);

            // TODO: backup and create a new database
        }

        return repository;
    }

    private void close_repository (Gom.Repository repository)
    {
        var adapter = repository.adapter;

        try {
            adapter.close_sync ();
        }
        catch (GLib.Error error) {
            GLib.warning ("Error while closing database: %s", error.message);
        }
    }

    public void open ()
    {
        GLib.File? file = null;

        if (Ft.Database.repository != null) {
            return;
        }

        if (!Ft.is_test ())
        {
            var directory_path = GLib.Path.build_filename (GLib.Environment.get_user_data_dir (),
                                                           Config.PACKAGE_NAME);
            var directory_file = GLib.File.new_for_path (directory_path);

            if (!directory_file.query_exists ()) {
                make_directory_with_parents (directory_file);
            }

            var file_path = GLib.Path.build_filename (directory_path, "database.sqlite");
            file = GLib.File.new_for_path (file_path);

            var old_file_path = GLib.Path.build_filename (GLib.Environment.get_user_data_dir (),
                                                          "gnome-pomodoro",
                                                          "database.sqlite");
            if (Ft.is_flatpak ()) {
                old_file_path = GLib.Path.build_filename (GLib.Environment.get_home_dir (),
                                                          ".local",
                                                          "share",
                                                          "gnome-pomodoro",
                                                          "database.sqlite");
            }

            var old_file = GLib.File.new_for_path (old_file_path);

            if (!file.query_exists () && old_file.query_exists ())
            {
                try {
                    old_file.copy (file, GLib.FileCopyFlags.NONE, null, null);
                    GLib.info ("Imported database from %s to %s", old_file_path, file_path);
                }
                catch (GLib.Error error) {
                    GLib.warning ("Failed to import database: %s", error.message);
                }
            }
        }

        Ft.Database.adapter = new Gom.Adapter ();
        Ft.Database.repository = open_repository (Ft.Database.adapter, file);
    }

    public void close ()
    {
        if (Ft.Database.repository == null) {
            return;
        }

        close_repository (Ft.Database.repository);

        Ft.Database.repository = null;
        Ft.Database.adapter = null;
    }

    public string serialize_date (GLib.Date date)
    {
        return date.valid ()
                ? Ft.DateUtils.format_date (date, DATE_FORMAT)
                : "";  // TODO: is this acceptable by SQLite?
    }

    /**
     * Remove leading zeros from a string
     */
    private inline string chug_zeros (string str)
    {
        var index = 0;

        while (str.@get (index) == '0') {
            index++;
        }

        return index > 0
                ? str.substring (index)
                : str;
    }

    public GLib.Date parse_date (string date_string)
    {
        var parts = date_string.split ("-");
        var date = GLib.Date ();

        if (parts.length == 3)
        {
            var year  = uint.parse (chug_zeros (parts[0]));
            var month = uint.parse (chug_zeros (parts[1]));
            var day   = uint.parse (chug_zeros (parts[2]));

            date.set_dmy ((GLib.DateDay) day,
                          (GLib.DateMonth) month,
                          (GLib.DateYear) year);
        }

        return date;
    }
}
