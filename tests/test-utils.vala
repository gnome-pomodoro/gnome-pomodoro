/*
 * This file is part of focus-timer
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Tests
{
    public class AsyncQueueTest : Tests.MainLoopTestSuite
    {
        public AsyncQueueTest ()
        {
            this.add_test ("push", this.test_push);
            this.add_test ("pop", this.test_pop);
            this.add_test ("length", this.test_length);
            this.add_test ("wait", this.test_wait);
        }

        public void test_push ()
        {
            var queue = new Ft.AsyncQueue<string> ();
            assert_cmpuint (queue.length (), GLib.CompareOperator.EQ, 0U);

            queue.push ("a");
            assert_cmpuint (queue.length (), GLib.CompareOperator.EQ, 1U);

            queue.push ("b");
            assert_cmpuint (queue.length (), GLib.CompareOperator.EQ, 2U);
        }

        public void test_pop ()
        {
            var queue = new Ft.AsyncQueue<string> ();

            var item = queue.pop ();
            assert_null (item);

            queue.push ("x");
            item = queue.pop ();
            assert_nonnull (item);
            assert_cmpstr (item, GLib.CompareOperator.EQ, "x");
            assert_cmpuint (queue.length (), GLib.CompareOperator.EQ, 0U);
        }

        public void test_length ()
        {
            var queue = new Ft.AsyncQueue<string> ();
            assert_cmpuint (queue.length (), GLib.CompareOperator.EQ, 0U);

            queue.push ("a");
            queue.push ("b");
            queue.push ("c");
            assert_cmpuint (queue.length (), GLib.CompareOperator.EQ, 3U);

            var item = queue.pop ();
            assert_cmpstr (item, GLib.CompareOperator.EQ, "a");
            assert_cmpuint (queue.length (), GLib.CompareOperator.EQ, 2U);
        }

        public void test_wait ()
        {
            var queue = new Ft.AsyncQueue<string> ();
            var completed = false;

            // Fill queue, then wait for it to become empty
            queue.push ("a");
            queue.push ("b");

            queue.wait.begin ((obj, res) => {
                queue.wait.end (res);
                completed = true;
                this.quit_main_loop ();
            });

            // Drain the queue asynchronously to trigger completion
            GLib.Timeout.add (10, () => {
                assert_nonnull (queue.pop ());
                assert_nonnull (queue.pop ());
                return GLib.Source.REMOVE;
            });

            assert_true (this.run_main_loop (1000));
            assert_true (completed);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.AsyncQueueTest ()
    );
}
