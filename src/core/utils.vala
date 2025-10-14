/*
 * Copyright (c) 2013, 2025 gnome-pomodoro contributors
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
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Pomodoro
{
    private static int _is_flatpak = -1;


    public inline void ensure_timestamp (ref int64 timestamp)
    {
        if (Pomodoro.Timestamp.is_undefined (timestamp)) {
            timestamp = Pomodoro.Timestamp.from_now ();
        }
    }


    public inline string ensure_string (string? str)
    {
        return str != null ? str : "";
    }


    /**
     * Round seconds to 1s, 5s, 10s, 1m.
     *
     * Its intended for displaying rough estimation of duration.
     */
    public double round_seconds (double seconds)
    {
        if (seconds < 10.0) {
            return Math.round (seconds);
        }

        if (seconds < 30.0) {
            return 5.0 * Math.round (seconds / 5.0);
        }

        if (seconds < 60.0) {
            return 10.0 * Math.round (seconds / 10.0);
        }

        return 60.0 * Math.round (seconds / 60.0);
    }


    /**
     * Convert seconds to text.
     *
     * If hours are present, seconds are omitted.
     */
    public string format_time (uint seconds)  // TODO: rename to format_interval
    {
        var hours = seconds / 3600;
        var minutes = (seconds % 3600) / 60;
        var str = "";

        seconds = seconds % 60;

        if (hours > 0)
        {
            str = ngettext ("%u hour", "%u hours", hours).printf (hours);
        }

        if (minutes > 0)
        {
            if (str != "") {
                str += " ";
            }

            str += ngettext ("%u minute", "%u minutes", minutes).printf (minutes);
        }

        if (seconds > 0 && hours == 0)
        {
            if (str != "") {
                str += " ";
            }

            str += ngettext ("%u second", "%u seconds", seconds).printf (seconds);
        }

        return str;
    }


    public inline double lerp (double value_from,
                               double value_to,
                               double t)
    {
        return value_from + (value_to - value_from) * t;
    }

    public bool is_flatpak ()
    {
        if (_is_flatpak < 0) {
            var value = GLib.Environment.get_variable ("container") == "flatpak" &&
                        GLib.Environment.get_variable ("G_TEST_ROOT_PROCESS") == null;
            _is_flatpak = value ? 1 : 0;
        }

        return _is_flatpak > 0;
    }


    internal bool is_test ()
    {
        return GLib.Environment.get_variable ("G_TEST_ROOT_PROCESS") != null ||
               GLib.Environment.get_variable ("G_TEST_BUILDDIR") != null ||
               GLib.Environment.get_variable ("MESON_TEST_ITERATION") != null;
    }


    public string to_camel_case (string name)
    {
        var     result = new GLib.StringBuilder ();
        var     was_hyphen = false;
        unichar chr;
        int     chr_span_end = 0;

        while (name.get_next_char (ref chr_span_end, out chr))
        {
            if (chr == '-') {
                was_hyphen = true;
                continue;
            }

            if (was_hyphen) {
                was_hyphen = false;
                result.append_unichar (chr.toupper ());
            }
            else {
                result.append_unichar (chr);
            }
        }

        return result.str;
    }


    public string from_camel_case (string name)
    {
        var     result = new GLib.StringBuilder ();
        var     was_lowercase = false;
        unichar chr;
        int     chr_span_end = 0;

        while (name.get_next_char (ref chr_span_end, out chr))
        {
            if (chr.isupper () && was_lowercase) {
                was_lowercase = false;
                result.append_c ('-');
                result.append_unichar (chr.tolower ());
            }
            else {
                was_lowercase = chr.islower ();
                result.append_unichar (was_lowercase ? chr : chr.tolower ());
            }
        }

        return result.str;
    }


    /**
     * Convenience class for waiting until an internal counter (the number of holds) reaches zero.
     *
     * Unlike promises in JavaScript, it is reusable and does not transfer result value.
     */
    public class Promise
    {
        private int counter = 0;
        private bool resolved = false;
        private bool in_dispose = false;
        private GLib.Mutex mutex;
        private GLib.Cond cond;
        private GLib.GenericArray<GLib.Thread<bool>> waiting_threads;

        public Promise ()
        {
            this.mutex = GLib.Mutex ();
            this.cond = GLib.Cond ();
            this.waiting_threads = new GLib.GenericArray<GLib.Thread<bool>> ();
        }

        ~Promise ()
        {
            this.mutex.lock ();
            this.in_dispose = true;
            this.resolved = true;  // Signal any waiting threads to exit
            this.cond.broadcast ();  // Wake up all waiting threads
            this.mutex.unlock ();

            // Wait for all spawned threads to complete
            foreach (var thread in waiting_threads) {
                thread.join ();
            }
        }

        /**
         * Returns the current counter value.
         *
         * @return the current counter value
         */
        public int get_counter ()
        {
            this.mutex.lock ();
            var value = this.counter;
            this.mutex.unlock ();

            return value;
        }

        /**
         * Increases the internal counter.
         */
        public void hold ()
        {
            this.mutex.lock ();

            if (!this.in_dispose) {
                this.counter++;
                this.resolved = false;
            }

            this.mutex.unlock ();
        }

        /**
         * Decreases the internal counter.
         * If the counter reaches zero, any waiting tasks will be notified.
         */
        public void release ()
        {
            this.mutex.lock ();

            if (!this.in_dispose && this.counter > 0)
            {
                this.counter--;

                if (this.counter == 0) {
                    this.resolved = true;
                    this.cond.broadcast ();
                }
            }
            else if (this.counter == 0) {
                GLib.critical ("Too many calls of Promise.release()");
            }

            this.mutex.unlock ();
        }

        /**
         * Asynchronously waits until the internal counter reaches zero.
         *
         * @return true when the internal counter has reached zero
         */
        public async void wait ()
        {
            if (this.in_dispose) {
                return;
            }

            // Check if already resolved to avoid creating a thread
            this.mutex.lock ();
            var already_resolved = this.resolved || this.counter == 0;
            this.mutex.unlock ();

            if (already_resolved) {
                return;
            }

            SourceFunc callback = this.wait.callback;

            var thread = new GLib.Thread<bool> (
                "promise-wait",
                () => {
                    this.mutex.lock ();

                    while (!this.resolved && !this.in_dispose) {
                        this.cond.wait (this.mutex);
                    }

                    this.mutex.unlock ();

                    // Schedule the callback in the main loop
                    var idle_id = GLib.Idle.add ((owned) callback);
                    GLib.Source.set_name_by_id (idle_id, "Pomodoro.Promise.wait");

                    return true;
                });

            this.mutex.lock ();
            this.waiting_threads.add (thread);
            this.mutex.unlock ();

            // Wait for the callback
            yield;

            this.mutex.lock ();
            this.waiting_threads.remove_fast (thread);
            this.mutex.unlock ();
        }
    }


    /**
     * A convenience wrapper around GLib.Queue that provides an async wait()
     * which resolves in the main loop once the queue becomes empty.
     */
    public class AsyncQueue<T>
    {
        private GLib.Queue<T>                        queue;
        private GLib.Mutex                           mutex;
        private GLib.Cond                            cond;
        private bool                                 in_dispose = false;
        private GLib.GenericArray<GLib.Thread<bool>> waiting_threads;

        public AsyncQueue ()
        {
            this.queue = new GLib.Queue<T> ();
            this.mutex = GLib.Mutex ();
            this.cond = GLib.Cond ();
            this.waiting_threads = new GLib.GenericArray<GLib.Thread<bool>> ();
        }

        ~AsyncQueue ()
        {
            this.mutex.lock ();
            this.in_dispose = true;
            this.cond.broadcast ();
            this.mutex.unlock ();

            foreach (var thread in this.waiting_threads) {
                thread.join ();
            }
        }

        /**
         * Push an item to the tail of the queue.
         */
        public void push (owned T item)
        {
            this.mutex.lock ();
            this.queue.push_tail ((owned) item);
            this.mutex.unlock ();
        }

        /**
         * Try to pop an item without blocking. Returns null if empty.
         */
        public T? pop ()
        {
            this.mutex.lock ();
            T? item = null;

            if (this.queue.get_length () > 0)
            {
                item = this.queue.pop_head ();

                if (this.queue.get_length () == 0) {
                    this.cond.broadcast ();
                }
            }

            this.mutex.unlock ();

            return item;
        }

        /**
         * Current length of the queue.
         */
        public uint length ()
        {
            this.mutex.lock ();
            var length = this.queue.get_length ();
            this.mutex.unlock ();

            return length;
        }

        /**
         * Asynchronously waits until the queue becomes empty.
         *
         * The completion is dispatched back to the main loop.
         */
        public async void wait ()
        {
            if (this.in_dispose) {
                return;
            }

            // Fast-path: already empty
            this.mutex.lock ();
            var already_empty = this.queue.get_length () == 0;
            this.mutex.unlock ();

            if (already_empty) {
                return;
            }

            SourceFunc callback = this.wait.callback;

            var thread = new GLib.Thread<bool> (
                "async-queue-wait",
                () => {
                    this.mutex.lock ();
                    while (this.queue.get_length () > 0 && !this.in_dispose) {
                        this.cond.wait (this.mutex);
                    }
                    this.mutex.unlock ();

                    // Schedule the callback in the main loop
                    var idle_id = GLib.Idle.add ((owned) callback);
                    GLib.Source.set_name_by_id (idle_id, "Pomodoro.AsyncQueue.wait");

                    return true;
                });

            this.mutex.lock ();
            this.waiting_threads.add (thread);
            this.mutex.unlock ();

            // Wait for the callback
            yield;

            this.mutex.lock ();
            this.waiting_threads.remove_fast (thread);
            this.mutex.unlock ();
        }
    }
}
