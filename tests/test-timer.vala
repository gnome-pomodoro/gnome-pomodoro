/*
 * This file is part of GNOME Pomodoro
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
 *
 */

using GLib;


public class Pomodoro.TimerTest : Pomodoro.TestSuite
{
    private const double POMODORO_DURATION = 25.0;
    private const double SHORT_BREAK_DURATION = 5.0;
    private const double LONG_BREAK_DURATION = 15.0;
    private const double IDLE_DURATION = 0.25;

    private double global_time
    {
        get {
            return Pomodoro.get_real_time ();
        }
        set {
            Pomodoro.set_real_time (value);
        }
    }

    public TimerTest ()
    {
        this.add_test ("set_state_full",
                       this.test_set_state_full);

        this.add_test ("restore",
                       this.test_restore);

        this.add_test ("update",
                       this.test_update);

        this.add_test ("update_after_suspend",
                       this.test_update_after_suspend);

        this.add_test ("update_after_suspend_with_idle",
                       this.test_update_after_suspend_with_idle);

        this.add_test ("pomodoro_duration_setting",
                       this.test_pomodoro_duration_setting);

        this.add_test ("state_changed_signal",
                       this.test_state_changed_signal);
    }

    public override void setup () {
        this.global_time = Pomodoro.get_real_time ();

        var settings = Pomodoro.get_settings ().get_child ("preferences");
        settings.set_double ("pomodoro-duration", POMODORO_DURATION);
        settings.set_double ("short-break-duration", SHORT_BREAK_DURATION);
        settings.set_double ("long-break-duration", LONG_BREAK_DURATION);
        settings.set_boolean ("pause-when-idle", false);
    }

    public override void teardown () {
        var settings = Pomodoro.get_settings ();
        settings.revert ();

        this.global_time = 0.0;
    }

    /**
     * Unit test for Pomodoro.Timer.set_state_full() method.
     *
     * Check changing timer state.
     */
    public void test_set_state_full ()
    {
        var timer = new Pomodoro.Timer();

        /* null --> pomodoro */
        timer.set_state_full (Pomodoro.State.POMODORO,
                              POMODORO_DURATION,
                              this.global_time);
        assert (timer.state == Pomodoro.State.POMODORO);
        assert (timer.state_duration == POMODORO_DURATION);

        /* pomodoro --> pause */
        this.global_time += POMODORO_DURATION;

        timer.set_state_full (Pomodoro.State.PAUSE,
                              SHORT_BREAK_DURATION,
                              this.global_time);
        assert (timer.state == Pomodoro.State.PAUSE);
        assert (timer.state_duration == SHORT_BREAK_DURATION);

        /* pause --> idle */
        this.global_time += SHORT_BREAK_DURATION;

        timer.set_state_full (Pomodoro.State.IDLE,
                              IDLE_DURATION,
                              this.global_time);
        assert (timer.state == Pomodoro.State.IDLE);
        assert (timer.state_duration == 0.0);

        /* idle --> pomodoro */
        this.global_time += IDLE_DURATION;

        timer.set_state_full (Pomodoro.State.POMODORO,
                              POMODORO_DURATION,
                              this.global_time);
        assert (timer.state == Pomodoro.State.POMODORO);
        assert (timer.state_duration == POMODORO_DURATION);
    }

    /**
     * Unit test for Pomodoro.Timer.update() method.
     *
     * Check whether states change properly with time.
     */
    public void test_update ()
    {
        var timer = new Pomodoro.Timer();
        timer.session_limit = 4.0;
        timer.start ();

        assert (timer.state == Pomodoro.State.POMODORO);
        assert (timer.state_duration == POMODORO_DURATION);
        assert (timer.session == 0.0);

        /* pomodoro --> pause */
        this.global_time += POMODORO_DURATION;

        timer.update ();
        assert (timer.state == Pomodoro.State.PAUSE);
        assert (timer.state_duration == SHORT_BREAK_DURATION);
        assert (timer.session == 1.0);

        /* pause --> pomodoro */
        this.global_time += SHORT_BREAK_DURATION;

        timer.update ();
        assert (timer.state == Pomodoro.State.POMODORO);
        assert (timer.state_duration == POMODORO_DURATION);
        assert (timer.session == 1.0);

        /* pomodoro --> long pause */
        this.global_time += POMODORO_DURATION;

        timer.session = 3.0;
        timer.update ();
        assert (timer.state == Pomodoro.State.PAUSE);
        assert (timer.state_duration == LONG_BREAK_DURATION);
        assert (timer.session == 4.0);

        /* long pause --> pomodoro */
        this.global_time += LONG_BREAK_DURATION;

        timer.update ();
        assert (timer.state == Pomodoro.State.POMODORO);
        assert (timer.state_duration == POMODORO_DURATION);
        assert (timer.session == 0.0);

        /* TODO: idle state */
    }

    /**
     * Unit test for Pomodoro.Timer.restore() method.
     *
     * Check whether restoring timer works correctly.
     */
    public void test_restore ()
    {
        var state_settings = Pomodoro.get_settings ().get_child ("state");

        var timer = new Pomodoro.Timer();

        /* TODO */
    }

    /**
     * Unit test for org.gnome.pomodoro.preferences.pomodoro_duration setting.
     *
     * Shortening pomodoro_duration shouldn't result in immediate long_break,
     */
    public void test_pomodoro_duration_setting ()
    {
        var settings = Pomodoro.get_settings ().get_child ("preferences");
        settings.set_double ("pomodoro-duration", POMODORO_DURATION);

        var timer = new Pomodoro.Timer();
        timer.session_limit = 4.0;
        timer.start ();

        /* shorten pomodoro duration */
        settings.set_double ("pomodoro-duration", 1.0);
        timer.state_duration = 1.0;

        /* pomodoro --> pause */
        this.global_time += timer.state_duration;

        timer.update ();
        assert (timer.state == Pomodoro.State.PAUSE);
        assert (timer.session == 1.0);
    }

    public void test_update_after_suspend ()
    {
        var timer = new Pomodoro.Timer();
        timer.session_limit = 4.0;
        timer.start ();

        /* pomodoro --> pause */
        this.global_time += timer.state_duration * timer.session_limit;

        timer.update ();
        assert (timer.state == Pomodoro.State.POMODORO);
        assert (timer.session == 1.0);
    }

    public void test_update_after_suspend_with_idle ()
    {
        var settings = Pomodoro.get_settings ().get_child ("preferences");
        settings.set_boolean ("pause-when-idle", true);

        var timer = new Pomodoro.Timer();
        timer.session_limit = 4.0;
        timer.start ();

        /* pomodoro --> pause */
        this.global_time += timer.state_duration * timer.session_limit;

        timer.update ();
        assert (timer.state == Pomodoro.State.IDLE);
        assert (timer.session == 1.0);
    }

    /**
     * Unit test for Pomodoro.Timer.state_changed() signal.
     *
     * We don't want for this signal to get called twice or in bursts.
     */
    public void test_state_changed_signal ()
    {
        /* TODO */
    }

    private void print_timer_state (Pomodoro.Timer timer)
    {
        stdout.printf ("""
    %.2f:
    state = %s
    state_timestamp = %.2f
    state_duration = %.2g
    session = %.2g
    session_limit = %.2g
""",
            this.global_time,
            state_to_string (timer.state),
            timer.state_timestamp,
            timer.state_duration,
            timer.session,
            timer.session_limit);
    }
}
