using GLib;


namespace Pomodoro.Database
{
    private const uint VERSION = 3;
    private const string MIGRATIONS_URI = "resource:///org/gnomepomodoro/Pomodoro/migrations";
    private const string DATE_FORMAT = "%Y-%m-%d";  // TODO: make functions to convert date

    private Gom.Adapter? adapter = null;
    private Gom.Repository? repository = null;

    public unowned Gom.Repository? get_repository ()
    {
        return Pomodoro.Database.repository;
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
        // Gom tries to re-apply last migration (bug in Gom?).
        if (is_migration_applied (repository, adapter, version)) {
            GLib.info ("Migration version %u already applied, skipping", version);
            return true;
        }

        uint8[] file_contents;

        var file = File.new_for_uri (@"$(MIGRATIONS_URI)/version-$(version).sql");
        file.load_contents (null, out file_contents, null);

        try {
            GLib.info ("Migrating database to version %u", version);
            Pomodoro.Database.execute_sql (adapter, (string) file_contents);
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

            repository.migrate_sync (Pomodoro.Database.VERSION,
                                     Pomodoro.Database.migrate_repository);
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

        if (Pomodoro.Database.repository != null) {
            return;
        }

        if (!Pomodoro.is_test ())
        {
            if (Pomodoro.is_flatpak ())
            {
                var host_db_path = GLib.Path.build_filename (GLib.Environment.get_home_dir (),
                                                             ".local",
                                                             "share",
                                                             Config.PACKAGE_NAME,
                                                             "database.sqlite");
                var sandbox_data_dir = GLib.Path.build_filename (GLib.Environment.get_user_data_dir (),
                                                                 Config.PACKAGE_NAME);
                var sandbox_db_path = GLib.Path.build_filename (sandbox_data_dir, "database.sqlite");

                var host_file = GLib.File.new_for_path (host_db_path);
                var sandbox_dir_file = GLib.File.new_for_path (sandbox_data_dir);
                var sandbox_file = GLib.File.new_for_path (sandbox_db_path);

                if (host_file.query_exists () && !sandbox_file.query_exists ())
                {
                    make_directory_with_parents (sandbox_dir_file);

                    try {
                        host_file.copy (sandbox_file, GLib.FileCopyFlags.NONE, null, null);
                        GLib.info ("Imported database from host to sandbox: %s -> %s",
                                   host_db_path, sandbox_db_path);
                    }
                    catch (GLib.Error error) {
                        GLib.warning ("Failed to import host database: %s", error.message);
                    }
                }
            }

            var file_path = GLib.Path.build_filename (GLib.Environment.get_user_data_dir (),
                                                      Config.PACKAGE_NAME,
                                                      "database.sqlite");
            file = GLib.File.new_for_path (file_path);
        }

        Pomodoro.Database.adapter = new Gom.Adapter ();
        Pomodoro.Database.repository = open_repository (Pomodoro.Database.adapter, file);
    }

    public void close ()
    {
        if (Pomodoro.Database.repository == null) {
            return;
        }

        close_repository (Pomodoro.Database.repository);

        Pomodoro.Database.repository = null;
        Pomodoro.Database.adapter = null;
    }

    public string serialize_date (GLib.Date date)
    {
        return Pomodoro.DateUtils.format_date (date, DATE_FORMAT);
    }

    public GLib.Date parse_date (string date_string)
    {
        var parts = date_string.split ("-");
        var date = GLib.Date ();

        if (parts.length == 3)
        {
            var year  = uint.parse (parts[0]);
            var month = uint.parse (parts[1]);
            var day   = uint.parse (parts[2]);

            date.set_dmy ((GLib.DateDay) day,
                          (GLib.DateMonth) month,
                          (GLib.DateYear) year);
        }

        return date;
    }
}
