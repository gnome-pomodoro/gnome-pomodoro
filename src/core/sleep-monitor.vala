/*
 * Copyright (c) 2023-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Ft
{
    public interface SleepMonitorProvider : Ft.Provider
    {
        public signal void prepare_for_sleep ();
        public signal void woke_up ();
    }


    [SingleInstance]
    public class SleepMonitor : Ft.ProvidedObject<Ft.SleepMonitorProvider>
    {
        private void on_prepare_for_sleep ()
        {
            this.prepare_for_sleep ();
        }

        private void on_woke_up ()
        {
            this.woke_up ();
        }

        protected override void initialize ()
        {
        }

        protected override void setup_providers ()
        {
            // TODO: Providers should register themselves in a static constructors, but can't make it work...
            this.providers.add (new Freedesktop.SleepMonitorProvider ());
        }

        protected override void provider_enabled (Ft.SleepMonitorProvider provider)
        {
            provider.prepare_for_sleep.connect (this.on_prepare_for_sleep);
            provider.woke_up.connect (this.on_woke_up);
        }

        protected override void provider_disabled (Ft.SleepMonitorProvider provider)
        {
            provider.prepare_for_sleep.disconnect (this.on_prepare_for_sleep);
            provider.woke_up.disconnect (this.on_woke_up);
        }

        public signal void prepare_for_sleep ();
        public signal void woke_up ();
    }
}
