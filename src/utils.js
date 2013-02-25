
/* Based on gnome-shell/js/misc/util.js */

const GLib = imports.gi.GLib;
const _ = imports.gettext.gettext;


/* try_spawn:
 * @argv: an argv array
 *
 * Runs @argv in the background. If launching @argv fails,
 * this will throw an error.
 */
function try_spawn(argv)
{
    var success, pid;
    try {
        [success, pid] = GLib.spawn_async(null, argv, null,
                                          GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD,
                                          null);
    } catch (err) {
        /* Rewrite the error in case of ENOENT */
        if (err.matches(GLib.SpawnError, GLib.SpawnError.NOENT)) {
            throw new GLib.SpawnError({ code: GLib.SpawnError.NOENT,
                                        message: _("Command not found") });
        } else if (err instanceof GLib.Error) {
            /* The exception from gjs contains an error string like:
                  Error invoking GLib.spawn_command_line_async: Failed to
                  execute child process "foo" (No such file or directory)
               We are only interested in the part in the parentheses. (And
               we can't pattern match the text, since it gets localized.) */
            let message = err.message.replace(/.*\((.+)\)/, '$1');
            throw new (err.constructor)({ code: err.code,
                                          message: message });
        } else {
            throw err;
        }
    }
    /* Dummy child watch; we don't want to double-fork internally
       because then we lose the parent-child relationship, which
       can break polkit.  See https://bugzilla.redhat.com//show_bug.cgi?id=819275 */
    GLib.child_watch_add(GLib.PRIORITY_DEFAULT, pid, function () {}, null);
}

/* try_spawn_command_line:
 * @command_line: a command line
 *
 * Runs @command_line in the background. If launching @command_line
 * fails, this will throw an error.
 */
function try_spawn_command_line(command_line)
{
    let success, argv;

    try {
        [success, argv] = GLib.shell_parse_argv(command_line);
    } catch (err) {
        /* Replace "Error invoking GLib.shell_parse_argv: "
           with something nicer */
        err.message = err.message.replace(/[^:]*: /, _("Could not parse command:") + "\n");
        throw err;
    }

    try_spawn(argv);
}
