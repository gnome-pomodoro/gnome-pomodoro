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
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */


namespace NotificationsPlugin
{
    public class ApplicationExtension : Peas.ExtensionBase, Pomodoro.ApplicationExtension
    {
        private Pomodoro.Timer timer;
        private GLib.Settings  settings;

        construct
        {
            this.settings = Pomodoro.get_settings ().get_child ("preferences");

            this.timer = Pomodoro.Timer.get_default ();
            this.timer.state_changed.connect_after (this.on_timer_state_changed);
            this.timer.notify["state-duration"].connect (this.on_timer_state_duration_notify);

            this.on_timer_state_changed (this.timer.state,
                                         new Pomodoro.DisabledState ());
        }

        ~ApplicationExtension ()
        {
            this.timer.state_changed.disconnect (this.on_timer_state_changed);

            GLib.Application.get_default ()
                            .withdraw_notification ("timer");
        }

        private void notify_pomodoro_start ()
        {
            var notification = new GLib.Notification (_("Pomodoro"));
            notification.set_body (_("Focus on your task."));
            notification.set_priority (GLib.NotificationPriority.HIGH);

            try {
                notification.set_icon (GLib.Icon.new_for_string (Config.PACKAGE_NAME));
            }
            catch (GLib.Error error) {
                GLib.warning (error.message);
            }

            notification.add_button (_("Take a break"), "app.timer-skip");

            GLib.Application.get_default ()
                            .send_notification ("timer", notification);
        }

        private void notify_pomodoro_end ()
        {
            var remaining = (int) Math.ceil (this.timer.remaining);
            var minutes   = (int) Math.floor (remaining / 60);
            var seconds   = (int) Math.floor (remaining % 60);
            var body      = remaining > 45
                  ? ngettext ("You have %d minute",
                              "You have %d minutes", minutes).printf (minutes)
                  : ngettext ("You have %d second",
                              "You have %d seconds", seconds).printf (seconds);

            var notification = new GLib.Notification (_("Take a break!"));
            notification.set_body (body);
            notification.set_priority (GLib.NotificationPriority.HIGH);

            // TODO
            // notification.set_default_action ("app.show-screen-notification");

            try {
                notification.set_icon (GLib.Icon.new_for_string (Config.PACKAGE_NAME));
            }
            catch (GLib.Error error) {
                GLib.warning (error.message);
            }

            if (this.timer.state is Pomodoro.ShortBreakState) {
                notification.add_button_with_target_value (_("Lengthen it"),
                                                           "app.timer-switch-state",
                                                           new GLib.Variant.string ("long-break"));
            }
            else {
                notification.add_button_with_target_value (_("Shorten it"),
                                                           "app.timer-switch-state",
                                                           new GLib.Variant.string ("short-break"));
            }

            notification.add_button_with_target_value (_("Start pomodoro"),
                                                       "app.timer-set-state",
                                                       new GLib.Variant.string ("pomodoro"));

            GLib.Application.get_default ()
                            .send_notification ("timer", notification);
        }

        private void on_timer_state_changed (Pomodoro.TimerState state,
                                             Pomodoro.TimerState previous_state)
        {
            GLib.Application.get_default ()
                            .withdraw_notification ("timer");

            if (state is Pomodoro.PomodoroState)
            {
                this.notify_pomodoro_start ();
            }
            else if (state is Pomodoro.BreakState)
            {
                this.notify_pomodoro_end ();
            }
        }

        private void on_timer_state_duration_notify ()
        {
            if (this.timer.state is Pomodoro.BreakState)
            {
                GLib.Application.get_default ()
                                .withdraw_notification ("timer");

                this.notify_pomodoro_end ();
            }
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
    var object_module = module as Peas.ObjectModule;

    object_module.register_extension_type (typeof (Pomodoro.ApplicationExtension),
                                           typeof (NotificationsPlugin.ApplicationExtension));
}
