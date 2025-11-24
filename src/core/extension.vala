/*
 * Copyright (c) 2017-2025 gnome-pomodoro contributors
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


namespace Pomodoro
{
    public errordomain ExtensionError
    {
        TIMED_OUT,
        NOT_ALLOWED,
        DOWNLOAD_FAILED,
        OTHER
    }

    public interface ExtensionProvider : Pomodoro.Provider
    {
        public abstract bool extension_enabled { get; }

        public abstract async bool enable_extension ();

        public abstract async bool disable_extension ();

        public abstract async bool install_extension () throws Pomodoro.ExtensionError;

        public abstract async bool uninstall_extension ();

        public abstract bool is_installed ();
    }


    [SingleInstance]
    public class Extension : GLib.Object
    {
        public bool available {
            get {
                return this._available;
            }
        }

        public bool enabled {
            get {
                return this._enabled;
            }
        }

        public unowned Pomodoro.CapabilitySet capabilities {
            get {
                return this._capabilities;
            }
        }

        public unowned Pomodoro.Provider provider {
            get {
                return this._provider;
            }
        }

        private Pomodoro.ProviderSet<Pomodoro.ExtensionProvider> providers = null;
        private Pomodoro.ExtensionProvider? _provider = null;
        private Pomodoro.CapabilitySet?     _capabilities = null;
        private bool                        _available = false;
        private bool                        _enabled = false;

        construct
        {
            this.providers = new Pomodoro.ProviderSet<Pomodoro.ExtensionProvider> (
                    Pomodoro.SelectionMode.SINGLE);
            this.providers.provider_selected.connect (this.on_provider_selected);
            this.providers.provider_unselected.connect (this.on_provider_unselected);
            this.providers.provider_enabled.connect (this.on_provider_enabled);
            this.providers.provider_disabled.connect (this.on_provider_disabled);

            this._capabilities = new Pomodoro.CapabilitySet ();

            this.setup_providers ();

            this.providers.enable ();
        }

        private void setup_providers ()
        {
            this.providers.add (new Gnome.ExtensionProvider (), Pomodoro.Priority.HIGH);
        }

        private void update_status ()
        {
            var available = this._provider != null && this._provider.enabled;
            var enabled = available && this._provider.extension_enabled
                    ? this._provider.extension_enabled
                    : false;

            if (this._available != available) {
                this._available = available;
                this.notify_property ("available");
            }

            if (this._enabled != enabled) {
                this._enabled = enabled;
                this.notify_property ("enabled");
            }
        }

        private void on_notify_extension_enabled (GLib.Object    object,
                                                  GLib.ParamSpec pspec)
        {
            this.update_status ();
        }

        private void on_provider_selected (Pomodoro.ExtensionProvider provider)
        {
            if (this._provider != provider) {
                this._provider = provider;
                this.notify_property ("provider");
            }

            this.update_status ();
        }

        private void on_provider_unselected (Pomodoro.ExtensionProvider provider)
        {
            if (this._provider == provider) {
                this._provider = null;
                this.notify_property ("provider");
            }

            this.update_status ();
        }

        private void on_provider_enabled (Pomodoro.ExtensionProvider provider)
        {
            provider.notify["extension-enabled"].connect (this.on_notify_extension_enabled);

            this.update_status ();
        }

        private void on_provider_disabled (Pomodoro.ExtensionProvider provider)
        {
            provider.notify["extension-enabled"].disconnect (this.on_notify_extension_enabled);

            this.update_status ();
        }

        public bool is_installed ()
        {
            return this._provider != null
                    ? this._provider.is_installed ()
                    : false;
        }

        public async bool enable ()
        {
            return this._provider != null
                    ? yield this._provider.enable_extension ()
                    : false;
        }

        public async bool disable ()
        {
            return this._provider != null
                    ? yield this._provider.disable_extension ()
                    : false;
        }

        public async bool install () throws Pomodoro.ExtensionError
        {
            return this._provider != null
                    ? yield this._provider.install_extension ()
                    : false;
        }

        public async bool uninstall ()
        {
            return this._provider != null
                    ? yield this._provider.uninstall_extension ()
                    : false;
        }

        public override void dispose ()
        {
            this.providers.provider_selected.disconnect (this.on_provider_selected);
            this.providers.provider_unselected.disconnect (this.on_provider_unselected);
            this.providers.provider_enabled.disconnect (this.on_provider_enabled);
            this.providers.provider_disabled.disconnect (this.on_provider_disabled);

            this._capabilities = null;
            this._provider = null;
            this.providers = null;

            base.dispose ();
        }
    }
}
