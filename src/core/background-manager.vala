namespace Pomodoro
{
    public interface BackgroundProvider : Pomodoro.Provider
    {
        public abstract async bool request_background (string parent_window);
    }


    public interface BackgroundApplication : GLib.Application
    {
        public abstract bool can_background { get; set; }

        public abstract void hold_background ();

        public abstract void release_background ();

        public abstract bool should_run_in_background ();
    }


    /**
     * TODO: if indicator is present, allow running in background but silently
     */
    [SingleInstance]
    public class BackgroundManager : Pomodoro.ProvidedObject<Pomodoro.BackgroundProvider>
    {
        private weak Pomodoro.BackgroundApplication? application;
        private unowned Pomodoro.SessionManager?     session_manager;
        private bool                                 has_background_hold = false;

        construct
        {
            this.application = GLib.Application.get_default () as Pomodoro.BackgroundApplication;

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
                    this.application.can_background = provider.request_background.end (res);
                });
        }

        private void update_background_hold ()
        {
            if (this.session_manager.current_time_block != null && !this.has_background_hold) {
                this.application.hold_background ();
                this.has_background_hold = true;
            }

            if (this.session_manager.current_time_block == null && this.has_background_hold) {
                this.application.release_background ();
                this.has_background_hold = false;
            }
        }

        private void on_current_time_block_notify (GLib.Object    object,
                                                   GLib.ParamSpec pspec)
        {
            this.update_background_hold ();
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

            this.application.can_background = false;
        }
    }
}
