/*
 * This file is part of focus-timer
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Tests
{
    private class DummyJob : GLib.Object, Ft.Job
    {
        public uint delay { get; construct; }

        public bool completed { get; set; default = false; }
        public GLib.Error? error { get; set; default = null; }

        public DummyJob (uint delay)
        {
            Object (delay: delay);
        }

        public async bool run () throws GLib.Error
        {
            GLib.Timeout.add (this.delay, () => {
                this.completed = true;
                run.callback ();

                return GLib.Source.REMOVE;
            });

            yield;

            return true;
        }
    }


    public class JobQueueTest : Tests.MainLoopTestSuite
    {
        public JobQueueTest ()
        {
            this.add_test ("push__simple", this.test_push__simple);
            this.add_test ("push__many", this.test_push__many);
            this.add_test ("wait__empty", this.test_wait__empty);
            this.add_test ("wait", this.test_wait);
        }

        public void test_push__simple ()
        {
            var queue = new Ft.JobQueue ();
            var job = new DummyJob (10);

            job.notify["completed"].connect (() => {
                this.quit_main_loop ();
            });

            queue.push (job);

            assert_true (this.run_main_loop (1000));
            assert_true (job.completed);
        }

        public void test_push__many ()
        {
            var queue = new Ft.JobQueue ();
            var job_1 = new DummyJob (10);
            var job_2 = new DummyJob (10);
            var job_3 = new DummyJob (10);

            var completed_jobs = new string[0];

            job_1.notify["completed"].connect (() => {
                completed_jobs += "job-1";

                if (completed_jobs.length == 3) {
                    this.quit_main_loop ();
                }
            });

            job_2.notify["completed"].connect (() => {
                completed_jobs += "job-2";

                if (completed_jobs.length == 3) {
                    this.quit_main_loop ();
                }
            });

            job_3.notify["completed"].connect (() => {
                completed_jobs += "job-3";

                if (completed_jobs.length == 3) {
                    this.quit_main_loop ();
                }
            });

            queue.push (job_1);
            queue.push (job_2);
            queue.push (job_3);

            assert_true (this.run_main_loop (1000));

            assert_true (job_1.completed);
            assert_true (job_2.completed);
            assert_true (job_3.completed);
            assert_cmpint (completed_jobs.length, GLib.CompareOperator.EQ, 3);
            assert_cmpstrv (completed_jobs, { "job-1", "job-2", "job-3" });
        }

        public void test_wait__empty ()
        {
            var queue = new Ft.JobQueue ();

            var returned = false;
            queue.wait.begin ((obj, res) => {
                queue.wait.end (res);
                returned = true;
                this.quit_main_loop ();
            });

            assert_true (this.run_main_loop (1000));
            assert_true (returned);
        }

        public void test_wait ()
        {
            var queue = new Ft.JobQueue ();
            var job_1 = new DummyJob (10);
            var job_2 = new DummyJob (10);
            var job_3 = new DummyJob (10);

            queue.push (job_1);
            queue.push (job_2);
            queue.push (job_3);

            assert_false (job_1.completed);

            var returned = false;
            queue.wait.begin ((obj, res) => {
                queue.wait.end (res);
                returned = true;
                this.quit_main_loop ();
            });

            assert_true (this.run_main_loop (1000));
            assert_true (returned);
            assert_true (job_1.completed);
            assert_true (job_2.completed);
            assert_true (job_3.completed);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.JobQueueTest ()
    );
}
