/*
 * Copyright (c) 2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Ft
{
    public interface GlobalShortcutsProvider : Ft.Provider
    {
        public abstract void add_shortcut (string name,
                                           string description,
                                           string default_accelerator = "");

        public abstract string lookup_accelerator (string name);

        public abstract void open_global_shortcuts_dialog (string window_identifier);

        public signal void shortcut_activated (string name);

        public signal void accelerator_changed (string name);
    }


    public delegate void ForeachAcceleratorFunc (string shortcut_name,
                                                 string shortcut_accelerator);


    [SingleInstance]
    public class KeyboardManager : GLib.Object
    {
        [Compact]
        private class Shortcut
        {
            public string name;
            public string description;
            public string default_accelerator;

            public Shortcut (string name,
                             string description,
                             string default_accelerator)
            {
                this.name = name;
                this.description = description;
                this.default_accelerator = default_accelerator;
            }

            ~Shortcut ()
            {
                this.name = null;
                this.description = null;
                this.default_accelerator = null;
            }
        }

        public bool global_shortcuts_supported {
            get {
                return this._global_shortcuts_supported;
            }
        }

        private Ft.ProviderSet<Ft.GlobalShortcutsProvider> providers;
        private unowned Ft.GlobalShortcutsProvider?        provider = null;
        private GLib.HashTable<string, Shortcut>           shortcuts = null;
        private bool                                       inhibited = false;
        private bool                                       _global_shortcuts_supported = false;

        construct
        {
            this.shortcuts = new GLib.HashTable<string, Shortcut> (GLib.str_hash, GLib.str_equal);

            this.providers = new Ft.ProviderSet<Ft.GlobalShortcutsProvider> (
                    Ft.SelectionMode.SINGLE);
            this.providers.provider_selected.connect (this.on_provider_selected);
            this.providers.provider_unselected.connect (this.on_provider_unselected);
            this.providers.provider_enabled.connect (this.on_provider_enabled);
            this.providers.provider_disabled.connect (this.on_provider_disabled);
            this.providers.add (new Portal.GlobalShortcutsProvider ());
        }

        private void populate_provider ()
                                        requires (this.provider != null)
        {
            this.shortcuts.@foreach (
                (shortcut_name, shortcut) => {
                    this.provider.add_shortcut (shortcut.name,
                                                shortcut.description,
                                                shortcut.default_accelerator);
                });
        }

        private void on_provider_notify_available (GLib.Object object,
                                                   GLib.ParamSpec pspec)
        {
            var provider = (Ft.GlobalShortcutsProvider) object;

            if (!this._global_shortcuts_supported && provider.available) {
                this._global_shortcuts_supported = true;
                this.notify_property ("global-shortcuts-supported");
            }
        }

        private void on_shortcut_activated (string shortcut_name)
        {
            if (!this.inhibited) {
                this.shortcut_activated (shortcut_name);
            }
        }

        private void on_accelerator_changed (string shortcut_name)
        {
            this.shortcut_changed (shortcut_name);
        }

        private void on_provider_selected (Ft.GlobalShortcutsProvider provider)
        {
            provider.notify["available"].connect (this.on_provider_notify_available);
            provider.shortcut_activated.connect (this.on_shortcut_activated);
            provider.accelerator_changed.connect (this.on_accelerator_changed);

            if (!this._global_shortcuts_supported && provider.available) {
                this._global_shortcuts_supported = true;
                this.notify_property ("global-shortcuts-supported");
            }
        }

        private void on_provider_unselected (Ft.GlobalShortcutsProvider provider)
        {
            provider.notify["available"].disconnect (this.on_provider_notify_available);
            provider.shortcut_activated.disconnect (this.on_shortcut_activated);
            provider.accelerator_changed.disconnect (this.on_accelerator_changed);

            if (this._global_shortcuts_supported) {
                this._global_shortcuts_supported = false;
                this.notify_property ("global-shortcuts-supported");
            }
        }

        private void on_provider_enabled (Ft.GlobalShortcutsProvider provider)
        {
            this.provider = provider;

            if (this.provider != null) {
                this.populate_provider ();
            }
        }

        private void on_provider_disabled (Ft.GlobalShortcutsProvider provider)
        {
            if (this.provider == provider) {
                this.provider = null;
            }
        }

        public void add_shortcut (string name,
                                  string description,
                                  string default_accelerator = "")
        {
            var shortcut = new Shortcut (name,
                                         description,
                                         default_accelerator);
            this.shortcuts.insert (name, (owned) shortcut);

            if (this.provider != null && this.provider.enabled)
            {
                this.provider.add_shortcut (name,
                                            description,
                                            default_accelerator);
            }
        }

        /**
         * We allow global-shortcuts to be implemented externally or overridden
         * through `CapabilityManager`.
         */
        public void enable_global_shortcuts ()
        {
            this.providers.enable ();
        }

        public void disable_global_shortcuts ()
        {
            this.providers.disable ();
        }

        /**
         * Opens a system dialog for editing shortcuts.
         */
        public void open_global_shortcuts_dialog (string window_identifier = "")
        {
            if (this.provider != null) {
                this.provider.open_global_shortcuts_dialog (window_identifier);
            }
        }

        public void inhibit ()
        {
            this.inhibited = true;
        }

        public void uninhibit ()
        {
            this.inhibited = false;
        }

        public string lookup_accelerator (string shortcut_name)
        {
            return this.provider != null
                ? this.provider.lookup_accelerator (shortcut_name)
                : "";
        }

        public void foreach_accelerator (ForeachAcceleratorFunc func)
        {
            this.shortcuts.@foreach (
                (shortcut_name, shortcut) => {
                    func (shortcut_name, this.lookup_accelerator (shortcut_name));
                });
        }

        public signal void shortcut_activated (string shortcut_name);

        public signal void shortcut_changed (string shortcut_name);

        public override void dispose ()
        {
            this.providers = null;
            this.provider = null;

            base.dispose ();
        }
    }
}
