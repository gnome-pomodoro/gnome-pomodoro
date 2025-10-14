namespace Pomodoro
{
    public interface Job : GLib.Object
    {
        public abstract bool        completed { get; set; default = false; }
        public abstract GLib.Error? error { get; set; default = null; }

        public abstract async bool run () throws GLib.Error;
    }


    /**
     * Run scheduled jobs sequentially. Currently we only run one type of jobs - actions / commands.
     * If there were more types, likely we would need to manage several queues / workers.
     */
    [SingleInstance]
    public class JobQueue : GLib.Object
    {
        private GLib.AsyncQueue<Pomodoro.Job> queue;
        private bool running = false;

        construct
        {
            this.queue = new GLib.AsyncQueue<Pomodoro.Job> ();
        }

        private void run_job (Pomodoro.Job job)
                              requires (!this.running)
        {
            this.running = true;

            job.run.begin (
                (obj, res) => {
                    try {
                        job.run.end (res);
                    }
                    catch (GLib.Error error) {
                        assert (job.error != null);
                    }

                    if (!job.completed) {
                        GLib.warning ("Job %s did not complete", job.get_type ().name ());
                    }

                    this.running = false;
                    this.pop (false);

                    if (!this.running && this.queue.length () == 0) {
                        this.drained ();
                    }
                });
        }

        private void pop (bool may_block)
        {
            var job = may_block ? this.queue.pop () : this.queue.try_pop ();

            if (job != null) {
                this.run_job (job);
            }
        }

        public void push (Pomodoro.Job job)
        {
            this.queue.push (job);

            if (!this.running) {
                this.pop (false);
            }
        }

        /**
         * Wait until all jobs are completed.
         */
        public async void wait ()
        {
            ulong drained_id = 0;

            if (!this.running && this.queue.length () == 0) {
                return;
            }

            drained_id = this.drained.connect (() => {
                this.disconnect (drained_id);
                wait.callback ();
            });

            yield;
        }

        /*
         * Emitted when the queue is empty and all jobs have completed.
         */
        public signal void drained ();

        public override void dispose ()
        {
            this.queue = null;

            base.dispose ();
        }
    }
}
