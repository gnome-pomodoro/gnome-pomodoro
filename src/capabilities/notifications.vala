/*
 * Copyright (c) 2016-2026 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;


namespace Ft
{
    public class NotificationsCapability : Ft.Capability
    {
        private Ft.NotificationManager?                  notification_manager = null;
        private GLib.Cancellable?                        cancellable = null;
        private Ft.ProviderSet<Ft.NotificationsProvider> providers;

        public NotificationsCapability ()
        {
            base ("notifications", Ft.Priority.DEFAULT);
        }

        private void show_screen_overlay (bool pass_through)
                                          requires (this.notification_manager != null)
        {
            if (this.cancellable != null && !this.cancellable.is_cancelled ()) {
                return;
            }

            var screen_overlay_group = new Ft.LightboxGroup (typeof (Ft.ScreenOverlay));
            var cancellable = new GLib.Cancellable ();

            screen_overlay_group.open.begin (
                cancellable,
                (obj, res) => {
                    try {
                        screen_overlay_group.open.end (res);
                    }
                    catch (GLib.Error error) {
                        if (!cancellable.is_cancelled ()) {
                            GLib.warning ("Failed to open overlay: %s", error.message);
                            cancellable.cancel ();
                        }
                    }

                    if (this.cancellable == cancellable) {
                        this.cancellable = null;
                        this.notification_manager.screen_overlay_closed ();
                    }
                });

            if (!cancellable.is_cancelled ()) {
                this.cancellable = cancellable;
                this.notification_manager.screen_overlay_opened ();
            }
        }

        private void on_provider_enabled (Ft.NotificationsProvider provider)
        {
            this.remove_all_details ();

            GLib.info ("Using notifications server: %s %s from %s", provider.name, provider.version, provider.vendor);

            if (provider.has_actions) {
                this.add_detail ("actions");
            }
        }

        private void on_request_screen_overlay_open ()
        {
            this.show_screen_overlay (true);
        }

        private void on_request_screen_overlay_close ()
        {
            if (this.cancellable != null) {
                this.cancellable.cancel ();
                this.cancellable = null;
            }
        }

        public override void initialize ()
        {
            this.providers = new Ft.ProviderSet<Ft.NotificationsProvider> (Ft.SelectionMode.SINGLE);
            this.providers.provider_enabled.connect (this.on_provider_enabled);
            this.providers.add (new Freedesktop.NotificationsProvider ());
            this.providers.enable ();

            base.initialize ();
        }

        public override void enable ()
        {
            if (this.notification_manager == null)
            {
                var notification_manager = new Ft.NotificationManager ();
                notification_manager.request_screen_overlay_open.connect (this.on_request_screen_overlay_open);
                notification_manager.request_screen_overlay_close.connect (this.on_request_screen_overlay_close);

                this.notification_manager = notification_manager;
            }

            base.enable ();
        }

        public override void disable ()
        {
            if (this.cancellable != null) {
                this.cancellable.cancel ();
                this.cancellable = null;
            }

            if (this.notification_manager != null) {
                this.notification_manager.request_screen_overlay_open.disconnect (this.on_request_screen_overlay_open);
                this.notification_manager.request_screen_overlay_close.disconnect (this.on_request_screen_overlay_close);
                this.notification_manager = null;
            }

            base.disable ();
        }

        public override void uninitialize ()
        {
            this.providers = null;

            base.uninitialize ();
        }

        public override void activate ()
        {
            assert (this.notification_manager != null);

            var current_state = this.notification_manager.session_manager.current_state;
            if (!current_state.is_break ()) {
                GLib.info ("Ignoring NotificationsCapability.activate. Not on a break");
                return;
            }

            var timer = this.notification_manager.timer;
            if (timer.is_finished ()) {
                GLib.info ("Ignoring NotificationsCapability.activate. Break has finished");
                return;
            }

            if (timer.is_paused ()) {
                timer.resume ();
            }
            else if (!timer.is_started ()) {
                timer.start ();
            }

            this.show_screen_overlay (false);
        }
    }
}
