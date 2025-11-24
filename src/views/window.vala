/*
 * Copyright (c) 2016-2025 gnome-pomodoro contributors
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
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */


namespace Pomodoro
{
    public enum WindowSize
    {
        NORMAL = 0,
        COMPACT = 1;

        public static WindowSize from_string (string? name)
        {
            switch (name)
            {
                case "compact":
                    return WindowSize.COMPACT;

                default:
                    return WindowSize.NORMAL;
            }
        }

        public string to_string ()
        {
            switch (this)
            {
                case NORMAL:
                    return "normal";

                case COMPACT:
                    return "compact";

                default:
                    assert_not_reached ();
            }
        }
    }

    public enum WindowView
    {
        DEFAULT = 0,
        TIMER = 1,
        STATS = 2;

        public static WindowView from_string (string? view_name)
        {
            switch (view_name)
            {
                case "timer":
                    return WindowView.TIMER;

                case "stats":
                    return WindowView.STATS;

                default:
                    return WindowView.DEFAULT;
            }
        }

        public string to_string ()
        {
            switch (this)
            {
                case TIMER:
                    return "timer";

                case STATS:
                    return "stats";

                case DEFAULT:
                    return "";

                default:
                    assert_not_reached ();
            }
        }
    }


    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/window.ui")]
    public class Window : Adw.ApplicationWindow, Gtk.Buildable
    {
        private const uint TOAST_DISMISS_TIMEOUT = 3;


        [CCode (notify = false)]
        public Pomodoro.WindowSize size {
            get {
                return this._size;
            }
            set {
                if (this._size == value) {
                    return;
                }

                this._size = value;

                this.size_stack.visible_child_name = value.to_string ();
                this.notify_property ("size");
            }
        }

        [CCode (notify = false)]
        public Pomodoro.WindowView view {
            get {
                return this._view;
            }
            set {
                if (this._view == value) {
                    return;
                }

                this._view = value;

                var resolved_view = value;
                if (resolved_view == Pomodoro.WindowView.DEFAULT) {
                    resolved_view = this.get_default_view ();
                }

                this.view_stack.visible_child_name = resolved_view.to_string ();
                this.notify_property ("view");
            }
        }

        [GtkChild]
        private unowned Pomodoro.SizeStack size_stack;
        [GtkChild]
        private unowned Adw.ViewStack view_stack;
        [GtkChild]
        private unowned Adw.ToastOverlay toast_overlay;
        [GtkChild]
        private unowned Pomodoro.TimerView timer_view;

        private Pomodoro.SessionManager session_manager;
        private Pomodoro.Timer          timer;
        private Pomodoro.WindowSize     _size = Pomodoro.WindowSize.NORMAL;
        private Pomodoro.WindowView     _view = Pomodoro.WindowView.DEFAULT;
        private Pomodoro.Extension?     extension = null;
        private Adw.Toast?              install_extension_toast = null;
        private static bool             install_extension_toast_dismissed = false;

        construct
        {
            // TODO: this.default_page should be set from application.vala
            // var application = Pomodoro.Application.get_default ();
            var settings = Pomodoro.get_settings ();

            this.session_manager = Pomodoro.SessionManager.get_default ();
            this.timer           = session_manager.timer;
            this.timer.state_changed.connect (() => {
                this.update_timer_indicator ();
            });

            this.insert_action_group ("session-manager", new Pomodoro.SessionManagerActionGroup ());
            this.insert_action_group ("timer", new Pomodoro.TimerActionGroup ());

            if (settings.get_boolean ("prefer-compact-size")) {
                this.size = Pomodoro.WindowSize.COMPACT;
            }

            this.update_title ();
            this.update_timer_indicator ();

            this.extension = new Pomodoro.Extension ();
            this.extension.notify["available"].connect (this.on_extension_notify_available);
        }

        private void update_title ()
        {
            var page = this._size == Pomodoro.WindowSize.NORMAL
                ? this.view_stack.get_page (this.view_stack.visible_child)
                : null;

            this.title = page != null ? page.title : _("Pomodoro");
        }

        private void update_timer_indicator ()
        {
            var timer_page = this.view_stack.get_page (this.timer_view);
            var timer      = Pomodoro.Timer.get_default ();

            timer_page.needs_attention = this.view_stack.visible_child != timer_page.child &&
                                         timer.is_started ();
        }

        private void update_install_extension_toast ()
        {
            if (!this.get_mapped ()) {
                return;
            }

            if (this.extension.available && !this.extension.is_installed ()) {
                this.show_install_extension_toast ();
            }
            else if (this.install_extension_toast != null) {
                this.install_extension_toast.dismissed.disconnect (
                        this.on_install_extension_toast_dismissed);
                this.install_extension_toast.dismiss ();
                this.install_extension_toast = null;
            }
        }

        public Pomodoro.WindowView get_default_view ()
                                                     ensures (result != Pomodoro.WindowView.DEFAULT)
        {
            return Pomodoro.WindowView.TIMER;
        }

        /**
         *  Keep the toast until window is focused.
         */
        private void dismiss_toast_once_focused (Adw.Toast toast)
        {
            toast.timeout = 0;

            var state_flags_changed_id = this.state_flags_changed.connect (
                (previous_state_flags) => {
                    var is_backdrop = Gtk.StateFlags.BACKDROP in this.get_state_flags ();

                    if (!is_backdrop) {
                        toast.timeout = TOAST_DISMISS_TIMEOUT;
                        this.toast_overlay.add_toast (toast);  // necessary for updating the timeout
                    }
                }
            );

            toast.dismissed.connect (() => {
                if (state_flags_changed_id != 0) {
                    this.disconnect (state_flags_changed_id);
                    state_flags_changed_id = 0;
                }
            });
        }

        /**
         * Monitor user activity and dismiss notification once user becomes active.
         */
        private void dismiss_toast_once_user_becomes_active (Adw.Toast toast)
        {
            // toast.timeout = 0;

            // TODO
        }

        public void add_toast (owned Adw.Toast toast)
        {
            if (toast.timeout != 0 && this._size == Pomodoro.WindowSize.NORMAL)
            {
                if (Gtk.StateFlags.BACKDROP in this.get_state_flags ()) {
                    this.dismiss_toast_once_focused (toast);
                }
                else {
                    this.dismiss_toast_once_user_becomes_active (toast);
                }
            }

            this.toast_overlay.add_toast (toast);
        }

        private void show_install_extension_toast ()
        {
            if (Pomodoro.Window.install_extension_toast_dismissed ||
                this.install_extension_toast != null)
            {
                return;
            }

            var toast = new Adw.Toast (_("GNOME Shell extension available"));
            toast.button_label = _("Learn More");
            toast.priority = Adw.ToastPriority.HIGH;
            toast.timeout = 0;
            toast.button_clicked.connect (
                () => {
                    var dialog = new Pomodoro.InstallExtensionDialog ();

                    dialog.present (this);
                    this.install_extension_toast = null;
                });
            toast.dismissed.connect (this.on_install_extension_toast_dismissed);

            this.install_extension_toast = toast;

            this.add_toast (toast);
        }

        private void show_close_confirmation_dialog ()
        {
            var parent = this;

            var dialog = new Adw.AlertDialog (
                _("Keep timer running?"),
                _("You can keep it running in the background — notifications and keyboard shortcuts will still work.")
            );
            dialog.prefer_wide_layout = true;

            dialog.add_response ("quit", _("Quit"));
            dialog.set_response_appearance ("quit", Adw.ResponseAppearance.DEFAULT);

            dialog.add_response ("run-in-background", _("Run in background"));
            dialog.set_response_appearance ("run-in-background", Adw.ResponseAppearance.SUGGESTED);

            dialog.set_default_response ("run-in-background");
            dialog.set_close_response ("cancel");
            dialog.response.connect (
                (response) => {
                    switch (response)
                    {
                        case "run-in-background":
                            parent.destroy ();
                            break;

                        case "quit":
                            parent.application.quit ();
                            break;

                        case "cancel":
                            dialog.close ();
                            break;

                        default:
                            assert_not_reached ();
                    }
                });

            dialog.present (parent);
        }

        [GtkCallback]
        private void on_size_stack_visible_child_notify (GLib.Object    object,
                                                         GLib.ParamSpec pspec)
        {
            this.size = Pomodoro.WindowSize.from_string (this.size_stack.visible_child_name);
        }

        [GtkCallback]
        private void on_view_stack_visible_child_notify (GLib.Object    object,
                                                         GLib.ParamSpec pspec)
        {
            var view = Pomodoro.WindowView.from_string (this.view_stack.visible_child_name);

            this._view = this._view == Pomodoro.WindowView.DEFAULT && this.get_default_view () == view
                ? Pomodoro.WindowView.DEFAULT
                : view;

            this.update_title ();
            this.update_timer_indicator ();
        }

        [GtkCallback]
        private void on_gesture_click_pressed (Gtk.GestureClick gesture,
                                               int              n_press,
                                               double           x,
                                               double           y)
        {
            if (gesture.get_current_button () == Gdk.BUTTON_PRIMARY &&
                n_press == 2)
            {
                this.size = this.size != Pomodoro.WindowSize.COMPACT
                    ? Pomodoro.WindowSize.COMPACT
                    : Pomodoro.WindowSize.NORMAL;

                gesture.set_state (Gtk.EventSequenceState.CLAIMED);
            }
        }

        [GtkCallback]
        private bool on_close_request ()
        {
            var application = this.application as Pomodoro.BackgroundApplication;

            if (application.should_run_in_background ())
            {
                this.show_close_confirmation_dialog ();

                return true;
            }
            else {
                application.quit ();

                return false;
            }
        }

        private void on_extension_notify_available (GLib.Object    object,
                                                    GLib.ParamSpec pspec)
        {
            this.update_install_extension_toast ();
        }

        private void on_install_extension_toast_dismissed (Adw.Toast toast)
        {
            this.install_extension_toast = null;

            Pomodoro.Window.install_extension_toast_dismissed = true;
        }

        private void on_compact_size_activate (GLib.SimpleAction action,
                                               GLib.Variant?     parameter)
        {
            this.size = Pomodoro.WindowSize.COMPACT;
        }

        private void on_normal_size_activate (GLib.SimpleAction action,
                                              GLib.Variant?     parameter)
        {
            this.size = Pomodoro.WindowSize.NORMAL;
            this.view = Pomodoro.WindowView.TIMER;
        }

        private void on_toggle_compact_size_activate (GLib.SimpleAction action,
                                                      GLib.Variant?     parameter)
        {
            if (this.size == Pomodoro.WindowSize.NORMAL) {
                this.lookup_action ("compact-size").activate (null);
            }
            else {
                this.lookup_action ("normal-size").activate (null);
            }
        }

        private void setup_actions ()
        {
            var action_map = (GLib.ActionMap) this;

            GLib.SimpleAction action;

            action = new GLib.SimpleAction ("compact-size", null);
            action.activate.connect (this.on_compact_size_activate);
            action_map.add_action (action);

            action = new GLib.SimpleAction ("normal-size", null);
            action.activate.connect (this.on_normal_size_activate);
            action_map.add_action (action);

            action = new GLib.SimpleAction ("toggle-compact-size", null);
            action.activate.connect (this.on_toggle_compact_size_activate);
            action_map.add_action (action);
        }

        public void parser_finished (Gtk.Builder builder)
        {
            this.setup_actions ();
        }

        public override void map ()
        {
            base.map ();

            this.update_install_extension_toast ();
        }

        public override void dispose ()
        {
            this.extension.notify["available"].disconnect (this.on_extension_notify_available);

            this.extension = null;
            this.install_extension_toast = null;

            base.dispose ();
        }
    }
}
