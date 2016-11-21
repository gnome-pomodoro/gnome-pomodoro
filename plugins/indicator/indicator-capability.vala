/*
 * Copyright (c) 2016 gnome-pomodoro contributors
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

using GLib;


namespace IndicatorPlugin
{
    public class IndicatorCapability : Pomodoro.Capability
    {
        private static string DEFAULT_THEME = "Ambiance";
        private static uint   STEPS         = 21;

        private AppIndicator.Indicator   indicator;
        private Pomodoro.Timer           timer;
        private uint                     timeout_id = 0;
        private bool                     has_blinked = false;

        public IndicatorCapability (string name)
        {
            base (name);
        }

        private void on_gtk_settings_gtk_theme_name_notify ()
        {
            this.indicator.set_icon_theme_path (this.get_theme_path ());
        }

        private void on_timer_is_paused_notify ()
        {
            this.on_timer_elapsed_notify ();

            if (this.timer.is_paused) {
                this.schedule_blinking ();
            }
        }

        private void on_timer_elapsed_notify ()
        {
            var icon_name = this.get_icon_name ();

            if (this.indicator.icon_name != icon_name) {
                this.indicator.icon_name = icon_name;
            }
        }

        private bool on_timeout ()
        {
            if (this.timer.is_paused) {
                this.indicator.icon_name = this.get_icon_name (!this.has_blinked);
                this.has_blinked         = !this.has_blinked;

                return GLib.Source.CONTINUE;
            }
            else {
                this.timeout_id  = 0;
                this.has_blinked = false;

                return GLib.Source.REMOVE;
            }
        }

        private void unschedule_blinking ()
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }
        }

        private void schedule_blinking ()
        {
            if (this.timeout_id == 0) {
                this.timeout_id = GLib.Timeout.add (1000, this.on_timeout);

                this.has_blinked = false;
                this.on_timeout ();
            }
        }

        private string get_icon_name (bool is_paused = false)
        {
            var state_name = (this.timer.state is Pomodoro.PomodoroState)
                             ? "pomodoro"
                             : "break";
            var progress = this.timer.state_duration > 0.0
                             ? (this.timer.elapsed / this.timer.state_duration).clamp (0.0, 1.0)
                             : 0.0;
            var progress_uint = (uint) Math.floor (progress * (double)(STEPS - 1)) * 100 / (STEPS - 1);

            return "%s%s-%03u".printf (state_name,
                                       is_paused ? "-paused" : "",
                                       progress_uint);
        }

        private string get_theme_path ()
        {
            var theme_name = Gtk.Settings.get_default ().gtk_theme_name;
            var theme_path = GLib.Path.build_filename (Config.PACKAGE_DATA_DIR, "indicator", theme_name);

            if (!GLib.FileUtils.test (theme_path, GLib.FileTest.IS_DIR)) {
                GLib.warning ("Could not find theme directory \"%s\"", theme_path);

                theme_path = GLib.Path.build_filename (Config.PACKAGE_DATA_DIR, "indicator", DEFAULT_THEME);
            }

            return theme_path;
        }

        public override void enable ()
        {
            if (!this.enabled) {
                this.timer = Pomodoro.Timer.get_default ();
                this.timer.notify["elapsed"].connect (this.on_timer_elapsed_notify);
                this.timer.notify["is-paused"].connect (this.on_timer_is_paused_notify);

                this.indicator = new AppIndicator.Indicator.with_path
                                           ("org.gnome.Pomodoro",
                                            this.get_icon_name (),
                                            AppIndicator.IndicatorCategory.APPLICATION_STATUS,
                                            this.get_theme_path ());

                try {
                    var builder = new Gtk.Builder ();
                    builder.add_from_resource ("/org/gnome/pomodoro/menus.ui");

                    var menu_model = builder.get_object ("indicator") as GLib.MenuModel;

                    var menu = new Gtk.Menu.from_model (menu_model);
                    menu.insert_action_group ("timer", this.timer.get_action_group ());
                    menu.insert_action_group ("app", GLib.Application.get_default () as GLib.ActionGroup);

                    this.indicator.set_menu (menu);
                }
                catch (GLib.Error error) {
                    GLib.warning (error.message);
                }

                this.indicator.set_status (AppIndicator.IndicatorStatus.ACTIVE);

                var gtk_settings = Gtk.Settings.get_default ();
                gtk_settings.notify["gtk-theme-name"].connect (this.on_gtk_settings_gtk_theme_name_notify);

                this.on_timer_elapsed_notify ();

                if (this.timer.is_paused) {
                    this.schedule_blinking ();
                }
            }

            base.enable ();
        }

        public override void disable ()
        {
            if (this.enabled) {
                this.unschedule_blinking ();

                var gtk_settings = Gtk.Settings.get_default ();
                gtk_settings.notify["gtk-theme-name"].disconnect (this.on_gtk_settings_gtk_theme_name_notify);

                this.timer.notify["elapsed"].disconnect (this.on_timer_elapsed_notify);
                this.timer.notify["is-paused"].disconnect (this.on_timer_is_paused_notify);

                this.timer = null;
                this.indicator = null;
            }

            base.disable ();
        }
    }
}
