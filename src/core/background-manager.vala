/*
 * Copyright (c) 2025 gnome-pomodoro contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Pomodoro
{
    public interface BackgroundProvider : Pomodoro.Provider
    {
        public abstract async bool request_background (string parent_window);
    }


    [SingleInstance]
    public class BackgroundManager : Pomodoro.ProvidedObject<Pomodoro.BackgroundProvider>
    {
        public bool active {
            get {
                return this.has_application_hold;
            }
        }

        private unowned GLib.Application?        application;
        private bool                             has_application_hold = false;
        private bool                             request_granted = false;
        private GLib.GenericSet<uint>            holds = null;
        private static uint                      next_hold_id = 1U;

        construct
        {
            this.application = GLib.Application.get_default ();
            this.holds = new GLib.GenericSet<uint> (GLib.direct_hash, GLib.direct_equal);
        }

        private async void request_background (string parent_window = "")
        {
            // Ask for request each time when trying to acquire `application_hold`.
            // It's doesn't seem to be required, but just in case.
            if (this.provider != null && !this.has_application_hold)
            {
                this.application.hold ();
                this.request_granted = yield this.provider.request_background (parent_window);

                this.update_application_hold ();
                this.application.release ();
            }
        }

        private void hold_application ()
        {
            if (!this.has_application_hold) {
                this.application.hold ();
                this.has_application_hold = true;
            }
        }

        private void release_application ()
        {
            if (this.has_application_hold) {
                this.application.release ();
                this.has_application_hold = false;
            }
        }

        private void update_application_hold ()
        {
            if (this.holds.length > 0U && this.request_granted) {
                this.hold_application ();
            }
            else {
                this.release_application ();
            }
        }

        public async uint hold (string parent_window = "")
        {
            var hold_id = Pomodoro.BackgroundManager.next_hold_id;
            BackgroundManager.next_hold_id++;

            this.holds.add (hold_id);
            yield this.request_background (parent_window);

            return hold_id;
        }

        public void release (uint hold_id)
        {
            var removed = this.holds.remove (hold_id);

            if (removed) {
                this.update_application_hold ();
            }
        }

        protected override void setup_providers ()
        {
            // TODO: Providers should register themselves in a static constructors, but can't make it work...
            this.providers.add (new Portal.BackgroundProvider ());
        }

        protected override void provider_enabled (Pomodoro.BackgroundProvider provider)
        {
            if (this.holds.length > 0U) {
                this.request_background.begin ();
            }
        }

        protected override void provider_disabled (Pomodoro.BackgroundProvider provider)
        {
            // TODO: use SetStatus to withdraw request?

            this.request_granted = false;
            this.release_application ();
        }

        public override void dispose ()
        {
            this.release_application ();

            this.application = null;
            this.holds = null;

            base.dispose ();
        }
    }
}
