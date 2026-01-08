/*
 * This file is part of focus-timer
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Tests
{
    [Flags]
    public enum Scenario
    {
        DEFAULT,
        UNAVAILABLE
    }


    public class AntiGravityCapability : Pomodoro.Capability
    {
        public uint initialize_count = 0;
        public uint uninitialize_count = 0;
        public uint enable_count = 0;
        public uint disable_count = 0;
        public uint activate_count = 0;

        public AntiGravityCapability (string            name,
                                      Pomodoro.Priority priority = Pomodoro.Priority.DEFAULT)
        {
            base (name, priority);
        }

        public override void initialize ()
        {
            this.initialize_count++;

            base.initialize ();
        }

        public override void uninitialize ()
        {
            this.uninitialize_count++;

            base.uninitialize ();
        }

        public override void enable ()
        {
            this.enable_count++;

            base.enable ();
        }

        public override void disable ()
        {
            this.disable_count++;

            base.disable ();
        }

        public override void activate ()
        {
            this.activate_count++;
        }
    }


    public class CapabilityManagerTest : Tests.TestSuite
    {
        public CapabilityManagerTest ()
        {
            this.add_test ("register", this.test_register);
            this.add_test ("enable__before_register", this.test_enable__before_register);

            // TODO: write more tests
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        public void test_register ()
        {
            var manager = new Pomodoro.CapabilityManager ();

            var capability_1 = new AntiGravityCapability ("anti-gravity");
            assert_true (capability_1.status == Pomodoro.CapabilityStatus.NULL);
            assert_false (manager.is_enabled ("anti-gravity"));

            manager.register (capability_1);
            assert_false (manager.is_enabled ("anti-gravity"));
            assert_true (capability_1.status == Pomodoro.CapabilityStatus.DISABLED);
        }

        public void test_enable__before_register ()
        {
            var capability = new AntiGravityCapability ("anti-gravity");
            var manager    = new Pomodoro.CapabilityManager ();

            manager.enable ("anti-gravity");
            assert_false (manager.is_enabled ("anti-gravity"));

            manager.register (capability);
            assert_true (manager.is_enabled ("anti-gravity"));
            assert_true (capability.status == Pomodoro.CapabilityStatus.ENABLED);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.CapabilityManagerTest ()
    );
}
