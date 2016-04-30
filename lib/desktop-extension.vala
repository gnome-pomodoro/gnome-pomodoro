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

namespace Pomodoro
{
    namespace Capabilities
    {
        public const string NOTIFICATIONS = "notifications";
        public const string REMINDERS = "reminders";
        public const string INDICATOR = "indicator";
        public const string HOTKEY = "hotkey";
        public const string PRESENCE = "presence";
    }

    public interface DesktopExtension : Peas.ExtensionBase
    {
        public abstract Pomodoro.PresenceStatus presence_status { get; set; default = Pomodoro.PresenceStatus.AVAILABLE; }

        public abstract async void configure ();
        public abstract unowned Pomodoro.CapabilityGroup get_capabilities ();
    }

    public abstract class BaseDesktopExtension : Peas.ExtensionBase, Pomodoro.DesktopExtension
    {
        public Pomodoro.PresenceStatus  presence_status { get; set; }

        private Pomodoro.CapabilityGroup capabilities = null;

        public virtual async void configure ()
        {
        }

        public virtual unowned Pomodoro.CapabilityGroup get_capabilities ()
        {
            return this.capabilities;
        }

        public override void dispose ()
        {
            this.capabilities.disable_all ();

            base.dispose ();
        }
    }

    public class FallbackDesktopExtension : Pomodoro.BaseDesktopExtension
    {
        private GLib.Settings               settings;
        private Pomodoro.Timer              timer;
        private Pomodoro.ScreenNotification screen_notification;
        private Pomodoro.CapabilityGroup    capabilities;

        construct
        {
            this.settings = Pomodoro.get_settings ().get_child ("preferences");
            this.timer    = Pomodoro.Timer.get_default ();

            this.capabilities = new Pomodoro.CapabilityGroup ();
            this.capabilities.enabled_changed.connect (this.on_capability_enabled_changed);

            this.settings.changed.connect (this.on_settings_changed);
        }

        ~FallbackDesktopExtension ()
        {
            this.get_capabilities ().disable_all ();
        }

        public override unowned Pomodoro.CapabilityGroup get_capabilities ()
        {
            return this.capabilities;
        }

        public override async void configure ()
        {
            this.capabilities.add (new Pomodoro.Capability (Capabilities.NOTIFICATIONS));

            this.capabilities.set_enabled (Capabilities.NOTIFICATIONS, true);
        }

        private void notify_pomodoro_start ()
        {
            this.show_pomodoro_start_notification ();
        }

        private void notify_pomodoro_end ()
        {
            if (this.settings.get_boolean ("show-screen-notifications")) {
                this.show_screen_notification ();
            }
            else {
                this.show_pomodoro_end_notification ();
            }
        }

        private void withdraw_notifications ()
        {
            if (this.screen_notification != null) {
                this.screen_notification.close ();
            }

            GLib.Application.get_default ()
                            .withdraw_notification ("timer");
        }

        private void show_screen_notification ()
        {
            if (this.screen_notification == null) {
                this.screen_notification = new Pomodoro.ScreenNotification ();
                this.screen_notification.notify["visible"].connect(() => {
                    if (this.timer.state is Pomodoro.BreakState) {
                        this.show_pomodoro_end_notification ();
                    }
                });
                this.screen_notification.destroy.connect (() => {
                    this.screen_notification = null;

                    if (this.timer.state is Pomodoro.BreakState) {
                        this.show_pomodoro_end_notification ();
                    }
                });
            }

            this.screen_notification.present ();
        }

        private void show_pomodoro_start_notification ()
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

        private void show_pomodoro_end_notification ()
        {
            // TODO: resident notifications won't be updated, might be better not to display scheduled time

            var remaining = (int) Math.ceil (this.timer.remaining);
            var minutes   = (int) Math.floor (remaining / 60);
            var seconds   = (int) Math.floor (remaining % 60);
            var body      = remaining > 45
                  ? ngettext ("You have %d minute",
                              "You have %d minutes", minutes).printf (minutes)
                  : ngettext ("You have %d second",
                              "You have %d seconds", seconds).printf (seconds);

            var notification = new GLib.Notification ((this.timer.state is Pomodoro.ShortBreakState)
                                                      ? _("Take a break")
                                                      : _("Take a longer break"));
            notification.set_body (body);
            notification.set_priority (GLib.NotificationPriority.HIGH);
            notification.set_default_action ("app.show-screen-notification");

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

        private void on_settings_changed (GLib.Settings settings,
                                          string        key)
        {
            switch (key)
            {
                case "show-screen-notifications":
                    if (this.timer.state is Pomodoro.BreakState) {
                        this.notify_pomodoro_end ();
                    }

                    break;
            }
        }

        private void on_timer_state_changed (Pomodoro.TimerState state,
                                             Pomodoro.TimerState previous_state)
        {
            this.withdraw_notifications ();

            if (state is Pomodoro.PomodoroState) {
                this.notify_pomodoro_start ();
            }
            else if (state is Pomodoro.BreakState) {
                this.notify_pomodoro_end ();
            }
        }

        private void on_timer_state_duration_notify ()
        {
            if (this.timer.state is Pomodoro.BreakState) {
                this.notify_pomodoro_end ();
            }
        }

        private void on_show_screen_notification_activate (GLib.SimpleAction action,
                                                           GLib.Variant?     parameter)
        {
            this.show_screen_notification ();
        }

        private void on_capability_enabled (string capability_name)
        {
            switch (capability_name)
            {
                case Capabilities.NOTIFICATIONS:
                    var show_screen_notification_action = new GLib.SimpleAction ("show-screen-notification", null);
                    show_screen_notification_action.activate.connect (this.on_show_screen_notification_activate);

                    var application = GLib.Application.get_default ();
                    application.add_action (show_screen_notification_action);

                    this.timer.state_changed.connect_after (this.on_timer_state_changed);
                    this.timer.notify["state-duration"].connect (this.on_timer_state_duration_notify);

                    this.on_timer_state_changed (this.timer.state,
                                                 this.timer.state);

                    break;
            }
        }

        private void on_capability_disabled (string capability_name)
        {
            switch (capability_name)
            {
                case Capabilities.NOTIFICATIONS:
                    this.timer.state_changed.disconnect (this.on_timer_state_changed);
                    this.timer.notify["state-duration"].disconnect (this.on_timer_state_duration_notify);

                    this.withdraw_notifications ();

                    var application = GLib.Application.get_default ();
                    application.remove_action ("show-screen-notification");

                    break;
            }
        }

        private void on_capability_enabled_changed (string capability_name,
                                                    bool   enabled)
        {
            if (enabled) {
                this.on_capability_enabled (capability_name);
            }
            else {
                this.on_capability_disabled (capability_name);
            }
        }
    }
}
