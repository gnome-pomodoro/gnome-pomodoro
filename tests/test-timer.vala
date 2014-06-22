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
    public TimerTest ()
    {
        this.add_test ("set_state_full", this.test_set_state_full);
    }

    public override void setup () {
    }

    public override void teardown () {
        var settings = Pomodoro.get_settings ();
        settings.revert ();
    }

    public void test_set_state_full ()
    {
        var timer = new Pomodoro.Timer();
        var timestamp = get_real_time ();

        /* pomodoro --> pause */
        timer.set_state_full (Pomodoro.State.POMODORO, 25.0, timestamp);
        assert (timer.state == Pomodoro.State.POMODORO);
        timestamp += 25.0;

        timer.set_state_full (Pomodoro.State.PAUSE, 5.0, timestamp);
        assert (timer.state == Pomodoro.State.PAUSE);
        timestamp += 5.0;

        /* idle --> pomodoro */
        timer.set_state_full (Pomodoro.State.IDLE, 0.0, timestamp);
        assert (timer.state == Pomodoro.State.IDLE);
        timestamp += 5.0;

        timer.set_state_full (Pomodoro.State.POMODORO, 25.0, timestamp);
        assert (timer.state == Pomodoro.State.POMODORO);
        timestamp += 25.0;

        /* TODO: test idle monitor  */
    }
}
