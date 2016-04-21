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

namespace Pomodoro
{
    public class CapabilityGroupTest : Pomodoro.TestSuite
    {
        public CapabilityGroupTest ()
        {
            this.add_test ("set_capability_enabled",
                           this.test_set_capability_enabled);

            this.add_test ("fallback",
                           this.test_fallback);
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        /**
         * Unit test for Pomodoro.Timer.set_state_full() method.
         *
         * Check changing timer state.
         */
        public void test_set_capability_enabled ()
        {
            /* Case 1 */
            var group1      = new Pomodoro.CapabilityGroup ();
            var capability1 = new Pomodoro.Capability ("anti-gravity", false);

            group1.add (capability1);
            assert (group1.contains ("anti-gravity"));

            group1.set_enabled ("anti-gravity", true);
            assert (capability1.enabled);
        }

        public void test_fallback ()
        {
            /* Case 1: change enabled state */
            var group1      = new Pomodoro.CapabilityGroup ();
            var capability1 = new Pomodoro.Capability ("anti-gravity", false);
            var fallback1   = new Pomodoro.Capability ("anti-gravity", true);

            capability1.fallback = fallback1;

            group1.add (capability1);

            capability1.enable ();
            assert (capability1.enabled);
            assert (!fallback1.enabled);

            /* Case 2: change enabled state */
            var group2      = new Pomodoro.CapabilityGroup ();
            var capability2 = new Pomodoro.Capability ("anti-gravity", true);
            var fallback2   = new Pomodoro.Capability ("anti-gravity", false);

            capability2.fallback = fallback2;

            group2.add (capability2);

            capability2.enable ();
            assert (capability2.enabled);
            assert (!fallback2.enabled);

            /* Case 3: fallback added later */
            var group3      = new Pomodoro.CapabilityGroup ();
            var capability3 = new Pomodoro.Capability ("anti-gravity", true);
            var fallback3   = new Pomodoro.Capability ("anti-gravity", true);

            group3.add (capability3);

            capability3.enable ();
            capability3.fallback = fallback3;

            assert (capability3.enabled);
            assert (!fallback3.enabled);

            /* Case 4: primary capability added later */
            var group4      = new Pomodoro.CapabilityGroup ();
            var fallback4   = new Pomodoro.Capability ("anti-gravity", true);

            group4.set_capability_fallback (fallback4.name, fallback4);

            var capability4 = new Pomodoro.Capability ("anti-gravity", true);
            group4.add (capability4);

            assert (capability4.fallback == fallback4);
            assert (capability4.enabled);
            assert (!fallback4.enabled);
        }
    }
}
