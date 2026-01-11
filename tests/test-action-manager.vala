/*
 * This file is part of focus-timer
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

namespace Tests
{
    public class EventActionTest : Tests.TestSuite
    {
        private string uuid;

        public EventActionTest ()
        {
            this.add_test ("load", this.test_load);
            this.add_test ("save", this.test_save);
        }

        public override void setup ()
        {
            this.uuid = GLib.Uuid.string_random ();
        }

        public void test_load ()
        {
            var settings = new GLib.Settings.with_path (
                    "io.github.focustimerhq.FocusTimer.actions.action",
                    @"/io/github/focustimerhq/FocusTimer/actions/$(this.uuid)/");
            settings.set_enum ("trigger", Ft.ActionTrigger.EVENT);
            settings.set_boolean ("enabled", true);
            settings.set_string ("display-name", "Event Action");
            settings.set_strv ("events", {"start", "stop"});
            settings.set_string ("condition", "isRunning");
            settings.set_boolean ("wait-for-completion", true);
            settings.set_string ("command", "echo Event");
            settings.set_string ("working-directory", "/tmp");
            settings.set_boolean ("use-subshell", true);
            settings.set_boolean ("pass-input", true);

            var action = new Ft.EventAction (this.uuid);
            action.load (settings);

            assert_true (action.enabled);
            assert_cmpstr (action.display_name, GLib.CompareOperator.EQ, "Event Action");
            assert_cmpstrv (action.event_names, {"start", "stop"});
            assert_nonnull (action.condition);
            assert_cmpstr (action.condition.to_string (), GLib.CompareOperator.EQ, "isRunning");
            assert_true (action.wait_for_completion);
            assert_cmpstr (action.command.line, GLib.CompareOperator.EQ, "echo Event");
            assert_cmpstr (action.command.working_directory, GLib.CompareOperator.EQ, "/tmp");
            assert_true (action.command.use_subshell);
            assert_true (action.command.pass_input);
        }

        public void test_save ()
        {
            var settings = new GLib.Settings.with_path (
                    "io.github.focustimerhq.FocusTimer.actions.action",
                    @"/io/github/focustimerhq/FocusTimer/actions/$(uuid)/");

            var action = new Ft.EventAction (this.uuid);
            action.display_name = "Event Action";
            action.event_names = {"start", "stop"};
            action.condition = new Ft.Variable ("is-running");
            action.wait_for_completion = true;
            action.command = new Ft.Command ("echo Event");
            action.command.working_directory = "/tmp";
            action.command.use_subshell = true;
            action.command.pass_input = true;
            action.save (settings);

            assert_true (settings.get_boolean ("enabled"));
            assert_cmpstr (settings.get_string ("display-name"), GLib.CompareOperator.EQ, "Event Action");
            assert_cmpstrv (settings.get_strv ("events"), {"start", "stop"});
            assert_cmpstr (settings.get_string ("condition"), GLib.CompareOperator.EQ, "isRunning");
            assert_true (settings.get_boolean ("wait-for-completion"));
            assert_cmpstr (settings.get_string ("command"), GLib.CompareOperator.EQ, "echo Event");
            assert_cmpstr (settings.get_string ("working-directory"), GLib.CompareOperator.EQ, "/tmp");
            assert_true (settings.get_boolean ("use-subshell"));
            assert_true (settings.get_boolean ("pass-input"));
        }
    }


    public class ConditionActionTest : Tests.TestSuite
    {
        private string uuid;

        public ConditionActionTest ()
        {
            this.add_test ("load", this.test_load);
            this.add_test ("save", this.test_save);
        }

        public override void setup ()
        {
            this.uuid = GLib.Uuid.string_random ();
        }

        public void test_load ()
        {
            var settings = new GLib.Settings.with_path (
                    "io.github.focustimerhq.FocusTimer.actions.action",
                    @"/io/github/focustimerhq/FocusTimer/actions/$(this.uuid)/");
            settings.set_enum ("trigger", Ft.ActionTrigger.CONDITION);
            settings.set_boolean ("enabled", true);
            settings.set_string ("display-name", "Condition Action");
            settings.set_string ("condition", "isRunning");
            settings.set_string ("command", "echo Enter");
            settings.set_string ("exit-command", "echo Exit");
            settings.set_string ("working-directory", "/tmp");
            settings.set_boolean ("use-subshell", true);
            settings.set_boolean ("pass-input", true);

            var action = new Ft.ConditionAction (this.uuid);
            action.load (settings);

            assert_true (action.enabled);
            assert_cmpstr (action.display_name, GLib.CompareOperator.EQ, "Condition Action");
            assert_nonnull (action.condition);
            assert_cmpstr (action.condition.to_string (), GLib.CompareOperator.EQ, "isRunning");
            assert_cmpstr (action.enter_command.line, GLib.CompareOperator.EQ, "echo Enter");
            assert_cmpstr (action.enter_command.working_directory, GLib.CompareOperator.EQ, "/tmp");
            assert_true (action.enter_command.use_subshell);
            assert_true (action.enter_command.pass_input);
            assert_cmpstr (action.exit_command.line, GLib.CompareOperator.EQ, "echo Exit");
            assert_cmpstr (action.exit_command.working_directory, GLib.CompareOperator.EQ, "/tmp");
            assert_true (action.exit_command.use_subshell);
            assert_true (action.exit_command.pass_input);
        }

        public void test_save ()
        {
            var settings = new GLib.Settings.with_path (
                    "io.github.focustimerhq.FocusTimer.actions.action",
                    @"/io/github/focustimerhq/FocusTimer/actions/$(this.uuid)/");

            var action = new Ft.ConditionAction (this.uuid);
            action.display_name = "Condition Action";
            action.condition = new Ft.Variable ("is-running");
            action.enter_command = new Ft.Command ("echo Enter");
            action.exit_command = new Ft.Command ("echo Exit");
            action.exit_command.working_directory = action.enter_command.working_directory = "/tmp";
            action.exit_command.use_subshell = action.enter_command.use_subshell = true;
            action.exit_command.pass_input = action.enter_command.pass_input = true;
            action.save (settings);

            assert_cmpuint (settings.get_enum ("trigger"),
                            GLib.CompareOperator.EQ,
                            Ft.ActionTrigger.CONDITION);
            assert_true (settings.get_boolean ("enabled"));
            assert_cmpstr (settings.get_string ("display-name"), GLib.CompareOperator.EQ, "Condition Action");
            assert_cmpstr (settings.get_string ("condition"), GLib.CompareOperator.EQ, "isRunning");
            assert_cmpstr (settings.get_string ("command"), GLib.CompareOperator.EQ, "echo Enter");
            assert_cmpstr (settings.get_string ("exit-command"), GLib.CompareOperator.EQ, "echo Exit");
            assert_cmpstr (settings.get_string ("working-directory"), GLib.CompareOperator.EQ, "/tmp");
            assert_true (settings.get_boolean ("use-subshell"));
            assert_true (settings.get_boolean ("pass-input"));
        }
    }


    public class ActionListModelTest : Tests.TestSuite
    {
        private GLib.Settings? settings;

        public ActionListModelTest ()
        {
            this.add_test ("save_action__create", this.test_save_action__create);
            this.add_test ("save_action__update", this.test_save_action__update);
            this.add_test ("delete_action", this.test_delete_action);
            this.add_test ("move_action", this.test_move_action);
        }

        public override void setup ()
        {
            this.settings = new GLib.Settings ("io.github.focustimerhq.FocusTimer.actions");
            this.settings.set_strv ("actions", {});
        }

        public override void teardown ()
        {
            this.settings = null;
        }

        public void test_save_action__create ()
        {
            var model = new Ft.ActionListModel ();

            assert_true (model.get_item_type () == typeof (Ft.Action));
            assert_cmpuint (model.get_n_items (), GLib.CompareOperator.EQ, 0U);
            assert_cmpuint (model.n_items, GLib.CompareOperator.EQ, 0U);
            assert_null (model.get_item (0));

            var observed_position = 999U;
            var observed_removed = 999U;
            var observed_added = 999U;
            var signals_count = 0U;
            model.items_changed.connect ((position, removed, added) => {
                observed_position = position;
                observed_removed = removed;
                observed_added = added;
                signals_count++;
            });

            var action = new Ft.EventAction (null);
            action.display_name = "Action";
            action.command = new Ft.Command ("echo Action");
            action.event_names = {"start"};

            model.save_action (action);

            assert_cmpuint (signals_count, GLib.CompareOperator.EQ, 1U);
            assert_cmpuint (observed_position, GLib.CompareOperator.EQ, 0U);
            assert_cmpuint (observed_removed, GLib.CompareOperator.EQ, 0U);
            assert_cmpuint (observed_added, GLib.CompareOperator.EQ, 1U);

            assert_cmpuint (model.get_n_items (), GLib.CompareOperator.EQ, 1U);
            assert_nonnull (model.get_item (0));
            assert_null (model.get_item (1));

            // index and lookup must be consistent
            var uuid = action.uuid;
            assert_true (uuid != null && uuid != "");
            assert_cmpint (model.index (uuid), GLib.CompareOperator.EQ, 0);
            assert (model.lookup (uuid) == action);

            // After first get_item, subsequent calls should return same instance
            var item_0 = (Ft.Action) model.get_item (0);
            var item_0_again = (Ft.Action) model.get_item (0);
            assert (item_0 == item_0_again);
        }

        public void test_save_action__update ()
        {
            var model = new Ft.ActionListModel ();

            var action_1 = new Ft.EventAction ("00000000-0000-0000-0000-000000000000");
            action_1.display_name = "Action 1";
            action_1.command = new Ft.Command ("echo 1");
            action_1.event_names = {"start"};

            model.save_action (action_1);

            var observed_position = 999U;
            var observed_removed = 999U;
            var observed_added = 999U;
            var signals_count = 0U;
            model.items_changed.connect ((position, removed, added) => {
                observed_position = position;
                observed_removed = removed;
                observed_added = added;
                signals_count++;
            });

            var action_2 = new Ft.EventAction (action_1.uuid);
            action_2.display_name = "Action 2";
            action_2.command = new Ft.Command ("echo 2");
            action_2.event_names = {"resume"};

            model.save_action (action_2);

            // Updating should not change length, but should notify 1 removed, 1 added at same position
            assert_cmpuint (signals_count, GLib.CompareOperator.EQ, 1U);
            assert_cmpuint (observed_position, GLib.CompareOperator.EQ, 0U);
            assert_cmpuint (observed_removed, GLib.CompareOperator.EQ, 1U);
            assert_cmpuint (observed_added, GLib.CompareOperator.EQ, 1U);
            assert_cmpuint (model.get_n_items (), GLib.CompareOperator.EQ, 1U);

            var action = (Ft.EventAction?) model.lookup (action_1.uuid);
            assert_cmpstr (action.display_name, GLib.CompareOperator.EQ, action_2.display_name);
            assert_cmpstr (action.command.line, GLib.CompareOperator.EQ, action_2.command.line);
            assert_cmpstrv (action.event_names, action_2.event_names);
        }

        public void test_delete_action ()
        {
            var model = new Ft.ActionListModel ();

            var action = new Ft.EventAction (null);
            action.display_name = "Action";
            action.command = new Ft.Command ("echo Action");
            action.event_names = {"start"};
            model.save_action (action);

            var observed_position = 999U;
            var observed_removed = 999U;
            var observed_added = 999U;
            var signals_count = 0U;
            model.items_changed.connect ((position, removed, added) => {
                observed_position = position;
                observed_removed = removed;
                observed_added = added;
                signals_count++;
            });

            model.delete_action (action.uuid);

            assert_cmpuint (signals_count, GLib.CompareOperator.EQ, 1U);
            assert_cmpuint (observed_position, GLib.CompareOperator.GE, 0U);
            assert_cmpuint (observed_removed, GLib.CompareOperator.EQ, 1U);
            assert_cmpuint (observed_added, GLib.CompareOperator.EQ, 0U);
            assert_cmpuint (model.get_n_items (), GLib.CompareOperator.EQ, 0U);
            assert_null (model.lookup (action.uuid));
        }

        public void test_move_action ()
        {
            var model = new Ft.ActionListModel ();

            var action_1 = new Ft.EventAction (null);
            action_1.display_name = "Action 1";
            action_1.command = new Ft.Command ("echo 1");
            action_1.event_names = {"start"};
            model.save_action (action_1);

            var action_2 = new Ft.EventAction (null);
            action_2.display_name = "Action 2";
            action_2.command = new Ft.Command ("echo 2");
            action_2.event_names = {"start"};
            model.save_action (action_2);

            var action_3 = new Ft.EventAction (null);
            action_3.display_name = "Action 3";
            action_3.command = new Ft.Command ("echo 3");
            action_3.event_names = {"start"};
            model.save_action (action_3);

            assert_cmpuint (model.get_n_items (), GLib.CompareOperator.EQ, 3U);
            assert_cmpint (model.index (action_1.uuid), GLib.CompareOperator.EQ, 0);
            assert_cmpint (model.index (action_2.uuid), GLib.CompareOperator.EQ, 1);
            assert_cmpint (model.index (action_3.uuid), GLib.CompareOperator.EQ, 2);

            var observed_position = 999U;
            var observed_removed = 999U;
            var observed_added = 999U;
            var signals_count = 0U;
            model.items_changed.connect ((position, removed, added) => {
                observed_position = position;
                observed_removed = removed;
                observed_added = added;
                signals_count++;
            });

            // Move first to last
            model.move_action (action_1.uuid, 2U);

            assert_cmpuint (signals_count, GLib.CompareOperator.EQ, 1U);
            assert_cmpuint (observed_position, GLib.CompareOperator.EQ, 0U);
            assert_cmpuint (observed_removed, GLib.CompareOperator.EQ, 2U);
            assert_cmpuint (observed_added, GLib.CompareOperator.EQ, 2U);

            assert_cmpint (model.index (action_2.uuid), GLib.CompareOperator.EQ, 0);
            assert_cmpint (model.index (action_3.uuid), GLib.CompareOperator.EQ, 1);
            assert_cmpint (model.index (action_1.uuid), GLib.CompareOperator.EQ, 2);

            // Verify get_item ordering
            assert ((Ft.Action) model.get_item (0) == model.lookup (action_2.uuid));
            assert ((Ft.Action) model.get_item (1) == model.lookup (action_3.uuid));
            assert ((Ft.Action) model.get_item (2) == model.lookup (action_1.uuid));
        }
    }


    public class ActionManagerTest : Tests.TestSuite
    {
        private class DummyEventAction : Ft.EventAction
        {
            public uint bind_count { get; private set; default = 0U; }
            public uint unbind_count { get; private set; default = 0U; }

            public DummyEventAction (string? uuid = null)
            {
                base (uuid);
            }

            public override void bind ()
            {
                this.bind_count++;
                base.bind ();
            }

            public override void unbind ()
            {
                this.unbind_count++;
                base.unbind ();
            }
        }

        private class DummyConditionAction : Ft.ConditionAction
        {
            public uint bind_count { get; private set; default = 0U; }
            public uint unbind_count { get; private set; default = 0U; }

            public DummyConditionAction (string? uuid = null)
            {
                base (uuid);
            }

            public override void bind ()
            {
                this.bind_count++;
                base.bind ();
            }

            public override void unbind ()
            {
                this.unbind_count++;
                base.unbind ();
            }
        }

        private GLib.Settings? settings;

        public ActionManagerTest ()
        {
            this.add_test ("save_event_action", this.test_save_event_action);
            this.add_test ("delete_event_action", this.test_delete_event_action);
            this.add_test ("save_condition_action", this.test_save_condition_action);
            this.add_test ("delete_condition_action", this.test_delete_condition_action);
            this.add_test ("destroy", this.test_destroy);
        }

        public override void setup ()
        {
            this.settings = new GLib.Settings ("io.github.focustimerhq.FocusTimer.actions");
            this.settings.set_strv ("actions", {});
        }

        public override void teardown ()
        {
            this.settings = null;
        }

        public void test_save_event_action ()
        {
            var manager = new Ft.ActionManager ();

            var action = new DummyEventAction (null);
            action.display_name = "Action";
            action.command = new Ft.Command ("echo Action");
            action.event_names = {"start"};

            manager.model.save_action (action);

            // Manager should bind newly added enabled action
            assert_cmpuint (action.bind_count, GLib.CompareOperator.EQ, 1U);

            // Toggling enabled should sync to settings and call unbind/bind
            assert_true (action.settings.get_boolean ("enabled"));

            action.enabled = false;
            assert_false (action.settings.get_boolean ("enabled"));
            assert_cmpuint (action.unbind_count, GLib.CompareOperator.EQ, 1U);

            action.enabled = true;
            assert_true (action.settings.get_boolean ("enabled"));
            assert_cmpuint (action.bind_count, GLib.CompareOperator.EQ, 2U);
        }

        public void test_delete_event_action ()
        {
            var manager = new Ft.ActionManager ();

            var action = new DummyEventAction (null);
            action.display_name = "Action";
            action.command = new Ft.Command ("echo Action");
            action.event_names = {"start"};

            manager.model.save_action (action);

            // Flip to false once to verify sync while connected
            action.enabled = false;
            assert_false (action.settings.get_boolean ("enabled"));

            // Delete should unbind and disconnect property handler
            manager.model.delete_action (action.uuid);
            assert_cmpuint (action.unbind_count, GLib.CompareOperator.GE, 1U);

            // After removal, toggling enabled should not sync to settings anymore
            var enabled_before = action.settings.get_boolean ("enabled");
            action.enabled = !enabled_before;
            assert_cmpint ((int) action.settings.get_boolean ("enabled"),
                           GLib.CompareOperator.EQ,
                           (int) enabled_before);
        }

        public void test_save_condition_action ()
        {
            var manager = new Ft.ActionManager ();

            var action = new DummyConditionAction (null);
            action.display_name = "Condition";
            action.condition = new Ft.Variable ("is-running");
            action.enter_command = new Ft.Command ("echo Enter");
            action.exit_command = new Ft.Command ("echo Exit");

            manager.model.save_action (action);

            // With condition set and enabled, manager should bind the action
            assert_cmpuint (action.bind_count, GLib.CompareOperator.EQ, 1U);

            // Toggling enabled should sync and unbind/bind
            assert_true (action.settings.get_boolean ("enabled"));

            action.enabled = false;
            assert_false (action.settings.get_boolean ("enabled"));
            assert_cmpuint (action.unbind_count, GLib.CompareOperator.EQ, 1U);

            action.enabled = true;
            assert_true (action.settings.get_boolean ("enabled"));
            assert_cmpuint (action.bind_count, GLib.CompareOperator.EQ, 2U);
        }

        public void test_delete_condition_action ()
        {
            var manager = new Ft.ActionManager ();

            var action = new DummyConditionAction (null);
            action.display_name = "Condition";
            action.condition = new Ft.Variable ("is-running");
            action.enter_command = new Ft.Command ("echo Enter");
            action.exit_command = new Ft.Command ("echo Exit");

            manager.model.save_action (action);

            action.enabled = false;
            assert_false (action.settings.get_boolean ("enabled"));

            manager.model.delete_action (action.uuid);
            assert_cmpuint (action.unbind_count, GLib.CompareOperator.GE, 1U);

            var enabled_before = action.settings.get_boolean ("enabled");
            action.enabled = !enabled_before;
            assert_cmpint ((int) action.settings.get_boolean ("enabled"),
                           GLib.CompareOperator.EQ,
                           (int) enabled_before);
        }

        public void test_destroy ()
        {
            var manager = new Ft.ActionManager ();

            var e = new DummyEventAction (null);
            e.display_name = "E";
            e.command = new Ft.Command ("echo E");
            e.event_names = {"start"};

            var c = new DummyConditionAction (null);
            c.display_name = "C";
            c.condition = new Ft.Variable ("is-running");
            c.enter_command = new Ft.Command ("echo Enter");
            c.exit_command = new Ft.Command ("echo Exit");

            manager.model.save_action (e);
            manager.model.save_action (c);

            // Sanity: initially bound
            assert_cmpuint (e.bind_count, GLib.CompareOperator.EQ, 1U);
            assert_cmpuint (c.bind_count, GLib.CompareOperator.EQ, 1U);

            manager.destroy ();

            // Destroy should unbind actions
            assert_cmpuint (e.unbind_count, GLib.CompareOperator.GE, 1U);
            assert_cmpuint (c.unbind_count, GLib.CompareOperator.GE, 1U);

            // Toggling enabled should NOT sync to settings after destroy (handlers disconnected)
            var e_settings_enabled = e.settings.get_boolean ("enabled");
            var c_settings_enabled = c.settings.get_boolean ("enabled");

            e.enabled = !e_settings_enabled;
            c.enabled = !c_settings_enabled;

            assert_cmpint ((int) e.settings.get_boolean ("enabled"),
                           GLib.CompareOperator.EQ,
                           (int) e_settings_enabled);
            assert_cmpint ((int) c.settings.get_boolean ("enabled"),
                           GLib.CompareOperator.EQ,
                           (int) c_settings_enabled);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.EventActionTest (),
        new Tests.ConditionActionTest (),
        new Tests.ActionListModelTest (),
        new Tests.ActionManagerTest ()
    );
}
