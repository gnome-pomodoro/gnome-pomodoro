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
    public class CapabilityTest : Pomodoro.TestSuite
    {
        public CapabilityTest ()
        {
            this.add_test ("is_virtual",
                           this.test_is_virtual);

            this.add_test ("set_fallback",
                           this.test_set_fallback);

            this.add_test ("new_with_fallback",
                           this.test_new_with_fallback);

//            this.add_test ("dispose",
//                           this.test_dispose);

//            this.add_test ("fallback_dispose",
//                           this.test_fallback_dispose);
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        /**
         * Unit test for Pomodoro.Capability.is_virtual() method.
         */
        public void test_is_virtual ()
        {
            var capability = new Pomodoro.Capability ("anti-gravity", true);

            assert (!capability.is_virtual ());
        }

        /**
         * Unit test for Pomodoro.Capability.with_fallback() method.
         */
        public void test_new_with_fallback ()
        {
            var fallback = new Pomodoro.Capability ("anti-gravity", true);

            var capability1 = new Pomodoro.Capability.with_fallback (fallback);
            assert (capability1.name == fallback.name);
        }

        /**
         * Unit test for Pomodoro.Capability.set_fallback() method.
         *
         * Capability enabled state should not change but fallback should be disabled,
         * in other words - fallback should never be used if there is a better implementation.
         */
        public void test_set_fallback ()
        {
            /* Case 1 */
            var capability1 = new Pomodoro.Capability ("anti-gravity", false);
            var fallback1   = new Pomodoro.Capability ("anti-gravity", false);

            capability1.fallback = fallback1;

            assert (!capability1.enabled);
            assert (!fallback1.enabled);

            /* Case 2 */
            var capability2 = new Pomodoro.Capability ("anti-gravity", false);
            var fallback2   = new Pomodoro.Capability ("anti-gravity", true);

            capability2.fallback = fallback2;

            assert (!capability2.enabled);
            assert (!fallback2.enabled);

            /* Case 3 */
            var capability3 = new Pomodoro.Capability ("anti-gravity", true);
            var fallback3   = new Pomodoro.Capability ("anti-gravity", true);

            capability3.fallback = fallback3;

            assert (capability3.enabled);
            assert (!fallback3.enabled);

            /* Case 4 */
            var capability4 = new Pomodoro.Capability ("anti-gravity", true);
            var fallback4   = new Pomodoro.Capability ("anti-gravity", false);

            capability4.fallback = fallback4;

            assert (capability4.enabled);
            assert (!fallback4.enabled);
        }

//        /**
//         *
//         */
//        public void test_set_fallback_rebind ()
//        {
//        }

//        /**
//         *
//         */
//        public void test_enabled_change ()
//        {
//        }

        /**
         * Unit test for Pomodoro.Capability.dispose() method.
         *
         * Enabled state should be passed to fallback.
         */
        public void test_dispose ()
        {
            /* Case 1 */
            var fallback1   = new Pomodoro.Capability ("anti-gravity", false);
            var capability1 = new Pomodoro.Capability ("anti-gravity", true);

            capability1.fallback = fallback1;
            capability1.dispose ();

            assert (fallback1.enabled);

            /* Case 2 */
            var fallback2   = new Pomodoro.Capability ("anti-gravity", true);
            var capability2 = new Pomodoro.Capability ("anti-gravity", false);

            capability2.fallback = fallback2;
            capability2.dispose ();

            assert (!fallback2.enabled);
        }

//        /**
//         * Unit test for Pomodoro.Capability.fallback.dispose() method.
//         *
//         * When capability is virtual and fallback gets destroyed enabled should be turned to false.
//         */
//        public void test_fallback_dispose ()
//        {
//            var capability1 = new Pomodoro.Capability ("anti-gravity", true);
//            var fallback1   = new Pomodoro.Capability ("anti-gravity", true);
//
//            capability1.set_fallback_full (fallback1, true);
//
//            fallback1.dispose ();
//
//            assert (capability1.fallback == null);
//        }
    }
}
