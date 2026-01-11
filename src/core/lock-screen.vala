/*
 * Copyright (c) 2024-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Ft
{
    public interface LockScreenProvider : Ft.Provider
    {
        public abstract bool active { get; }

        public abstract void activate ();
    }


    [SingleInstance]
    public class LockScreen : Ft.ProvidedObject<Ft.LockScreenProvider>
    {
        public bool active {
            get {
                return this._active;
            }
        }

        private bool _active = false;

        private void update_active ()
        {
            var active = this.provider != null && this.provider.enabled ? this.provider.active : false;

            if (this._active != active)
            {
                this._active = active;

                this.notify_property ("active");
            }
        }

        private void on_notify_active (GLib.Object    object,
                                       GLib.ParamSpec pspec)
        {
            this.update_active ();
        }

        protected override void initialize ()
        {
        }

        protected override void setup_providers ()
        {
            this.providers.add (new Freedesktop.LockScreenProvider ());
        }

        protected override void provider_enabled (Ft.LockScreenProvider provider)
        {
            provider.notify["active"].connect (this.on_notify_active);

            this.update_active ();
        }

        protected override void provider_disabled (Ft.LockScreenProvider provider)
        {
            provider.notify["active"].disconnect (this.on_notify_active);

            this.update_active ();
        }

        public void activate ()
        {
            if (this.provider != null && this.provider.enabled) {
                this.provider.activate ();
            }
            else {
                GLib.debug ("Unable to activate lock-screen: no provider");
            }
        }
    }
}
