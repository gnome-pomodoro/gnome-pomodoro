namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/preferences-page-timer.ui")]
    public class PreferencesPageTimer : Adw.PreferencesPage
    {
        private const uint MIN_TOAST_TIMEOUT = 3;
        private const uint MAX_TOAST_TIMEOUT = 30;

        [GtkChild]
        private unowned Gtk.Adjustment pomodoro_duration_adjustment;
        [GtkChild]
        private unowned Gtk.Adjustment short_break_duration_adjustment;
        [GtkChild]
        private unowned Gtk.Adjustment long_break_duration_adjustment;
        [GtkChild]
        private unowned Gtk.Adjustment cycles_adjustment;
        [GtkChild]
        private unowned Gtk.Label session_stats_label;
        [GtkChild]
        private unowned Gtk.Label breaks_stats_label;
        [GtkChild]
        private unowned Adw.ComboRow break_advancement_mode_comborow;
        [GtkChild]
        private unowned Adw.ComboRow pomodoro_advancement_mode_comborow;
        [GtkChild]
        private unowned Pomodoro.LogScaleRow long_break_row;

        private GLib.Settings?  settings;
        private ulong           settings_changed_id = 0;
        private Pomodoro.Timer? timer;
        private ulong           timer_state_changed_id = 0;
        private Adw.Toast?      apply_changes_toast;

        construct
        {
            this.settings = Pomodoro.get_settings ();
            this.settings.bind ("pomodoro-duration", this.pomodoro_duration_adjustment, "value", GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("short-break-duration", this.short_break_duration_adjustment, "value", GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("long-break-duration", this.long_break_duration_adjustment, "value", GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("cycles", this.cycles_adjustment, "value", GLib.SettingsBindFlags.DEFAULT);

            this.settings_changed_id = settings.changed.connect (this.on_settings_changed);

            this.timer = Pomodoro.Timer.get_default ();

            if (this.timer_state_changed_id == 0) {
                this.timer_state_changed_id = this.timer.state_changed.connect (this.on_timer_state_changed);
            }

            this.update_long_break_row_sensitivity ();
            this.update_stats_labels ();
            this.update_advancement_modes ();
        }

        private void update_long_break_row_sensitivity ()
        {
            this.long_break_row.sensitive = this.cycles_adjustment.value > 1.0;
        }

        private void update_stats_labels ()
        {
            var session_template = Pomodoro.SessionTemplate.with_defaults ();
            var total_duration = Pomodoro.Timestamp.to_seconds_uint (session_template.calculate_total_duration ());
            var break_percentage = (uint) Math.round (session_template.calculate_break_percentage ());

            this.session_stats_label.label = _("A single session will take <b>%s</b>.").printf (Pomodoro.format_time (total_duration));
            this.breaks_stats_label.label = _("<b>%u%%</b> of the time will be allocated for breaks.").printf (break_percentage);
        }

        private void update_advancement_modes ()
        {
            this.pomodoro_advancement_mode_comborow.selected = (uint) (
                (Pomodoro.AdvancementMode) this.settings.get_enum ("pomodoro-advancement-mode"));

            this.break_advancement_mode_comborow.selected = (uint) (
                (Pomodoro.AdvancementMode) this.settings.get_enum ("break-advancement-mode"));
        }

        private void apply_changes ()
        {
            var current_time_block = this.timer.user_data as Pomodoro.TimeBlock;

            if (current_time_block != null)
            {
                var duration = current_time_block.state.get_default_duration ();

                current_time_block.set_intended_duration (duration);
                this.timer.duration = duration;
            }
        }

        private uint calculate_apply_changes_toast_timeout (Pomodoro.State changed_state)
        {
            var current_time_block = this.timer.user_data as Pomodoro.TimeBlock;

            if (current_time_block == null ||
                current_time_block.state != changed_state ||
                current_time_block.get_intended_duration () == current_time_block.state.get_default_duration ())
            {
                return 0U;
            }

            if (this.timer.is_paused ()) {
                return MAX_TOAST_TIMEOUT;
            }

            var timeout = Pomodoro.Timestamp.to_seconds_uint (current_time_block.state.get_default_duration () -
                                                              this.timer.calculate_elapsed ());

            return uint.min (timeout, MAX_TOAST_TIMEOUT);
        }

        private void show_apply_changes_toast (Pomodoro.State changed_state,
                                               uint           timeout)
        {
            var window = this.get_root () as Pomodoro.PreferencesWindow;
            assert (window != null);

            var toast = this.apply_changes_toast;

            if (toast == null)
            {
                toast = new Adw.Toast (changed_state == Pomodoro.State.POMODORO
                                       ? _("Apply changes to ongoing Pomodoro?")
                                       : _("Apply changes to ongoing break?"));
                toast.use_markup = false;
                toast.button_label = _("Apply");
                toast.button_clicked.connect (
                    () => {
                        this.apply_changes_toast = null;
                        this.apply_changes ();
                    }
                );
                toast.dismissed.connect (() => { this.apply_changes_toast = null; });

                this.apply_changes_toast = toast;
            }

            toast.timeout = timeout;

            window.add_toast (toast);
        }

        private void hide_apply_changes_toast ()
        {
            if (this.apply_changes_toast != null) {
                this.apply_changes_toast.dismiss ();
            }
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            this.hide_apply_changes_toast ();
        }

        private void on_settings_changed (GLib.Settings settings,
                                          string        key)
        {
            var changed_state = Pomodoro.State.UNDEFINED;
            var session_manager = Pomodoro.SessionManager.get_default ();

            switch (key)
            {
                case "pomodoro-duration":
                    changed_state = Pomodoro.State.POMODORO;
                    this.update_stats_labels ();
                    break;

                case "short-break-duration":
                    changed_state = settings.get_uint ("cycles") > 1
                        ? Pomodoro.State.SHORT_BREAK
                        : Pomodoro.State.BREAK;
                    this.update_stats_labels ();
                    break;

                case "long-break-duration":
                    changed_state = Pomodoro.State.LONG_BREAK;
                    this.update_stats_labels ();
                    break;

                case "cycles":
                    this.update_long_break_row_sensitivity ();
                    this.update_stats_labels ();
                    break;

                case "pomodoro-advancement-mode":
                case "break-advancement-mode":
                    this.update_advancement_modes ();
                    break;

                default:
                    break;
            }

            if (session_manager.current_time_block != null &&
                session_manager.current_time_block.state == changed_state)
            {
                var apply_changes_toast_timeout = this.calculate_apply_changes_toast_timeout (changed_state);

                if (apply_changes_toast_timeout >= MIN_TOAST_TIMEOUT) {
                    this.show_apply_changes_toast (changed_state, apply_changes_toast_timeout);
                }
                else {
                    this.hide_apply_changes_toast ();
                }
            }
        }

        [GtkCallback]
        private void on_pomodoro_advancement_mode_selected_notify (GLib.Object    object,
                                                                   GLib.ParamSpec pspec)
        {
            var combo_row = (Adw.ComboRow) object;
            var pomodoro_advancement_mode = (Pomodoro.AdvancementMode) combo_row.selected;

            this.settings.set_enum ("pomodoro-advancement-mode", (int) pomodoro_advancement_mode);
        }

        [GtkCallback]
        private void on_break_advancement_mode_selected_notify (GLib.Object    object,
                                                                GLib.ParamSpec pspec)
        {
            var combo_row = (Adw.ComboRow) object;
            var break_advancement_mode = (Pomodoro.AdvancementMode) combo_row.selected;

            this.settings.set_enum ("break-advancement-mode", (int) break_advancement_mode);
        }

        public override void dispose ()
        {
            this.hide_apply_changes_toast ();

            if (this.settings_changed_id != 0) {
                this.settings.disconnect (this.settings_changed_id);
                this.settings_changed_id = 0;
            }

            if (this.timer_state_changed_id != 0) {
                this.timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }

            this.settings = null;
            this.timer = null;

            base.dispose ();
        }
    }
}