namespace Pomodoro
{
    public interface BackgroundProvider : Pomodoro.Provider
    {
        public abstract async bool request_background (string parent_window);
    }


    public interface BackgroundApplication : GLib.Application
    {
        public abstract bool should_run_in_background ();
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
        private unowned Pomodoro.SessionManager? session_manager;
        private bool                             has_application_hold = false;
        private bool                             request_granted = false;

        construct
        {
            this.application = GLib.Application.get_default ();

            this.session_manager = Pomodoro.SessionManager.get_default ();
            this.session_manager.notify["current-time-block"].connect (this.on_current_time_block_notify);
        }

        private void request_background (string parent_window = "")
                                         requires (this.provider != null)
        {
            var provider = this.provider;

            provider.request_background.begin (
                parent_window,
                (obj, res) => {
                    this.request_granted = provider.request_background.end (res);
                    this.update_application_hold ();
                });
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
            if (this.session_manager.current_time_block != null && this.request_granted) {
                this.hold_application ();
            }
            else {
                this.release_application ();
            }
        }

        private void on_current_time_block_notify (GLib.Object    object,
                                                   GLib.ParamSpec pspec)
        {
            this.update_application_hold ();
        }

        protected override void setup_providers ()
        {
            // TODO: Providers should register themselves in a static constructors, but can't make it work...
            this.providers.add (new Freedesktop.BackgroundProvider ());
        }

        protected override void provider_enabled (Pomodoro.BackgroundProvider provider)
        {
            this.request_background ();
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

            this.session_manager.notify["current-time-block"].disconnect (this.on_current_time_block_notify);

            this.application = null;
            this.session_manager = null;

            base.dispose ();
        }
    }
}
