/*
 * Copyright (c) 2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Pomodoro
{
    [GtkTemplate (ui = "/io/github/focustimerhq/FocusTimer/ui/preferences/keyboard-shortcuts/preferences-panel-keyboard-shortcuts.ui")]
    public class PreferencesPanelKeyboardShortcuts : Pomodoro.PreferencesPanel
    {
        [GtkChild]
        private unowned Pomodoro.AcceleratorRow start_stop_timer_row;
        [GtkChild]
        private unowned Pomodoro.AcceleratorRow start_pause_resume_timer_row;
        [GtkChild]
        private unowned Pomodoro.AcceleratorRow start_timer_row;
        [GtkChild]
        private unowned Pomodoro.AcceleratorRow stop_timer_row;
        [GtkChild]
        private unowned Pomodoro.AcceleratorRow pause_timer_row;
        [GtkChild]
        private unowned Pomodoro.AcceleratorRow resume_timer_row;
        [GtkChild]
        private unowned Pomodoro.AcceleratorRow skip_timer_row;
        [GtkChild]
        private unowned Pomodoro.AcceleratorRow rewind_timer_row;
        [GtkChild]
        private unowned Pomodoro.AcceleratorRow toggle_window_row;

        private Pomodoro.KeyboardManager? keyboard_manager = null;

        construct
        {
            this.keyboard_manager = new Pomodoro.KeyboardManager ();
            this.keyboard_manager.shortcut_changed.connect (this.on_shortcut_changed);

            this.update_accelerators ();
        }

        private void open_global_shortcuts_dialog ()
        {
            get_window_identifier.begin (
                this.get_root () as Gtk.Window,
                (obj, res) => {
                    var window_identifier = get_window_identifier.end (res);

                    this.keyboard_manager.open_global_shortcuts_dialog (window_identifier);
                });
        }

        private void update_accelerator (string  shortcut_name,
                                         string? shortcut_accelerator = null)
        {
            string accelerator = shortcut_accelerator != null
                ? shortcut_accelerator
                : this.keyboard_manager.lookup_accelerator (shortcut_name);

            switch (shortcut_name)
            {
                case "timer.toggle":
                case "timer.start-stop":
                    this.start_stop_timer_row.accelerator = accelerator;
                    break;

                case "timer.start-pause-resume":
                    this.start_pause_resume_timer_row.accelerator = accelerator;
                    break;

                case "timer.start":
                    this.start_timer_row.accelerator = accelerator;
                    break;

                case "timer.reset":
                    this.stop_timer_row.accelerator = accelerator;
                    break;

                case "timer.pause":
                    this.pause_timer_row.accelerator = accelerator;
                    break;

                case "timer.resume":
                    this.resume_timer_row.accelerator = accelerator;
                    break;

                case "session-manager.advance":
                    this.skip_timer_row.accelerator = accelerator;
                    break;

                case "timer.rewind":
                    this.rewind_timer_row.accelerator = accelerator;
                    break;

                case "app.toggle-window":
                    this.toggle_window_row.accelerator = accelerator;
                    break;

                default:
                    GLib.warning ("Unhandled shortcut '%s'", shortcut_name);
                    break;
            }
        }

        private void update_accelerators ()
        {
            this.keyboard_manager.foreach_accelerator (
                (shortcut_name, shortcut_accelerator) => {
                    this.update_accelerator (shortcut_name, shortcut_accelerator);
                });
        }

        private void on_shortcut_changed (string shortcut_name)
        {
            this.update_accelerator (shortcut_name);
        }

        [GtkCallback]
        private void on_edit_button_clicked (Gtk.Button button)
        {
            this.open_global_shortcuts_dialog ();
        }

        public override void dispose ()
        {
            this.keyboard_manager = null;

            base.dispose ();
        }
    }
}
