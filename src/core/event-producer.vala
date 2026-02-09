/*
 * Copyright (c) 2024-2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Ft
{
    [CCode (has_target = false)]
    public delegate bool TriggerFunc ();

    [CCode (has_target = false)]
    public delegate bool TimerStateChangedTriggerFunc (
                                       Ft.TimerState current_state,
                                       Ft.TimerState previous_state);

    [CCode (has_target = false)]
    public delegate bool SessionManagerConfirmAdvancementTriggerFunc (
                                       Ft.TimeBlock next_time_block,
                                       Ft.TimeBlock previous_time_block);

    [CCode (has_target = false)]
    public delegate bool SessionManagerAdvancedTriggerFunc (
                                       Ft.Session?   current_session,
                                       Ft.TimeBlock? current_time_block,
                                       Ft.Session?   previous_session,
                                       Ft.TimeBlock? previous_time_block);

    [CCode (has_target = false)]
    public delegate bool SessionManagerNotifyCurrentStateTriggerFunc (
                                       Ft.State current_state,
                                       Ft.State previous_state);

    [CCode (has_target = false)]
    public delegate bool SessionManagerSessionRescheduledTriggerFunc (
                                       Ft.Session session);

    [CCode (has_target = false)]
    public delegate bool SessionManagerSessionExpiredTriggerFunc (
                                       Ft.Session session);


    public enum TriggerHook
    {
        NONE,
        TIMER_STATE_CHANGED,
        SESSION_MANAGER_CONFIRM_ADVANCEMENT,
        SESSION_MANAGER_ADVANCED,
        SESSION_MANAGER_NOTIFY_CURRENT_STATE,
        SESSION_MANAGER_SESSION_RESCHEDULED,
        SESSION_MANAGER_SESSION_EXPIRED
    }


    public struct Trigger
    {
        public unowned Ft.EventSpec   event_spec;
        public Ft.TriggerHook         hook;
        public Ft.TriggerFunc         func;
    }


    /**
     * Gathers events from various sources and pushes them onto a bus. It's not 1:1 mapping; events are supposed to be
     * more intuitive for the user. Some events are filtered to not trigger them unnecessarily, and some are delayed
     * to collect fuller context.
     */
    [SingleInstance]
    public class EventProducer : GLib.Object
    {
        public Ft.SessionManager session_manager
        {
            get {
                return this._session_manager;
            }
            construct
            {
                this._session_manager = value;
                this._session_manager.confirm_advancement.connect (this.on_session_manager_confirm_advancement);
                this._session_manager.advanced.connect (this.on_session_manager_advanced);
                this._session_manager.notify["current-state"].connect (this.on_session_manager_notify_current_state);
                this._session_manager.session_rescheduled.connect (this.on_session_manager_session_rescheduled);
                this._session_manager.session_expired.connect (this.on_session_manager_session_expired);

                this.previous_state = this._session_manager.current_state;
            }
        }

        public Ft.Timer timer
        {
            get {
                return this._timer;
            }
            construct
            {
                this._timer = value;
                this._timer.state_changed.connect (this.on_timer_state_changed);
            }
        }

        public Ft.EventBus bus
        {
            get {
                return this._bus;
            }
            construct {
                this._bus = value;
            }
        }

        private Ft.SessionManager?                   _session_manager = null;
        private Ft.Timer?                            _timer = null;
        private Ft.EventBus?                         _bus = null;
        private Ft.EventSpec[]                       event_specs = null;
        private GLib.HashTable<string, unowned Ft.EventSpec> event_spec_by_name = null;
        private Ft.State                             previous_state;
        private GLib.Queue<unowned Ft.EventSpec>     queue = null;
        private uint                                 idle_id = 0;
        private int64                                event_source_timestamp = Ft.Timestamp.UNDEFINED;
        private int64                                last_session_rescheduled_time = Ft.Timestamp.UNDEFINED;
        private bool                                 destroying = false;

        private Ft.Trigger[]                         timer_state_change_triggers;
        private Ft.Trigger[]                         session_manager_confirm_advancement_triggers;
        private Ft.Trigger[]                         session_manager_advanced_triggers;
        private Ft.Trigger[]                         session_manager_notify_current_state_triggers;
        private Ft.Trigger[]                         session_manager_session_rescheduled_triggers;
        private Ft.Trigger[]                         session_manager_session_expired_triggers;

        construct
        {
            this.event_specs = new Ft.EventSpec[0];
            this.event_spec_by_name = new GLib.HashTable<string, unowned Ft.EventSpec> (GLib.str_hash, GLib.str_equal);
            this.queue = new GLib.Queue<unowned Ft.EventSpec> ();

            this.timer_state_change_triggers                   = new Ft.Trigger[0];
            this.session_manager_confirm_advancement_triggers  = new Ft.Trigger[0];
            this.session_manager_advanced_triggers             = new Ft.Trigger[0];
            this.session_manager_notify_current_state_triggers = new Ft.Trigger[0];
            this.session_manager_session_rescheduled_triggers  = new Ft.Trigger[0];
            this.session_manager_session_expired_triggers      = new Ft.Trigger[0];

            Ft.initialize_events (this);
        }

        public EventProducer ()
        {
            var bus = new Ft.EventBus ();

            GLib.Object (
                session_manager: Ft.SessionManager.get_default (),
                timer: Ft.Timer.get_default (),
                bus: bus
            );
        }

        public EventProducer.with_session_manager (Ft.SessionManager session_manager)
        {
            var bus = new Ft.EventBus ();

            GLib.Object (
                session_manager: session_manager,
                timer: session_manager.timer,
                bus: bus
            );
        }

        public void install_event (Ft.EventSpec event_spec)
        {
            unowned var unowned_event_spec = event_spec;

            foreach (var trigger in event_spec.triggers)
            {
                switch (trigger.hook)
                {
                    case Ft.TriggerHook.TIMER_STATE_CHANGED:
                        this.timer_state_change_triggers += trigger;
                        break;

                    case Ft.TriggerHook.SESSION_MANAGER_CONFIRM_ADVANCEMENT:
                        this.session_manager_confirm_advancement_triggers += trigger;
                        break;

                    case Ft.TriggerHook.SESSION_MANAGER_ADVANCED:
                        this.session_manager_advanced_triggers += trigger;
                        break;

                    case Ft.TriggerHook.SESSION_MANAGER_NOTIFY_CURRENT_STATE:
                        this.session_manager_notify_current_state_triggers += trigger;
                        break;

                    case Ft.TriggerHook.SESSION_MANAGER_SESSION_RESCHEDULED:
                        this.session_manager_session_rescheduled_triggers += trigger;
                        break;

                    case Ft.TriggerHook.SESSION_MANAGER_SESSION_EXPIRED:
                        this.session_manager_session_expired_triggers += trigger;
                        break;

                    default:
                        assert_not_reached ();
                }
            }

            if (event_spec_by_name.insert (event_spec.name, unowned_event_spec)) {
                this.event_specs += event_spec;
            }
            else {
                GLib.error ("Unable to install event '%s'", event_spec.name);
            }
        }

        public unowned Ft.EventSpec? find_event (string event_name)
        {
            return this.event_spec_by_name.lookup (event_name);
        }

        public (unowned Ft.EventSpec)[] list_events ()
        {
            return this.event_specs;
        }

        private void trigger_queued_events (Ft.Context context)
        {
            Ft.EventSpec event_spec;

            if (this.idle_id != 0) {
                GLib.Source.remove (this.idle_id);
                this.idle_id = 0;
            }

	        while ((event_spec = this.queue.pop_head ()) != null)
            {
                this.event (new Ft.Event (event_spec, context));
	        }
        }

        private void trigger_event (Ft.EventSpec event_spec,
                                    int64        timestamp)
        {
            if (this.destroying) {
                return;
            }

            var context = new Ft.Context.build (timestamp);

            this.trigger_queued_events (context);

            this.event (new Ft.Event (event_spec, context));
        }

        private bool on_idle ()
        {
            var timestamp = this.event_source_timestamp;

            if (Ft.Timestamp.is_undefined (timestamp))
            {
                timestamp = int64.max (this._timer.get_last_state_changed_time (),
                                       this._timer.get_last_tick_time ());
            }

            this.idle_id = 0;
            this.event_source_timestamp = Ft.Timestamp.UNDEFINED;

            this.trigger_queued_events (new Ft.Context.build (timestamp));

            return GLib.Source.REMOVE;
        }

        private void queue_event (Ft.EventSpec event_spec)
        {
            if (this.destroying) {
                return;
            }

            // TODO: preserve event current timestamp, for the context
            this.queue.push_tail (event_spec);

            this.event_source_timestamp = Ft.Context.get_event_source_timestamp ();

            if (this.idle_id == 0) {
                this.idle_id = GLib.Idle.add (this.on_idle, GLib.Priority.DEFAULT);
                GLib.Source.set_name_by_id (this.idle_id, "Ft.EventProducer.trigger_queued_events");
            }
        }

        private void on_timer_state_changed (Ft.TimerState current_state,
                                             Ft.TimerState previous_state)
        {
            var timestamp = this._timer.get_last_state_changed_time ();

            foreach (var trigger in this.timer_state_change_triggers)
            {
                var trigger_func = (Ft.TimerStateChangedTriggerFunc) trigger.func;

                if (trigger_func (current_state, previous_state)) {
                    this.trigger_event (trigger.event_spec, timestamp);
                }
            }
        }

        private void on_session_manager_confirm_advancement (Ft.TimeBlock current_time_block,
                                                             Ft.TimeBlock next_time_block)
        {
            var timestamp = current_time_block.end_time;

            foreach (var trigger in this.session_manager_confirm_advancement_triggers)
            {
                var trigger_func = (Ft.SessionManagerConfirmAdvancementTriggerFunc) trigger.func;

                if (trigger_func (current_time_block, next_time_block)) {
                    this.trigger_event (trigger.event_spec, timestamp);
                }
            }
        }

        private void on_session_manager_advanced (Ft.Session?   current_session,
                                                  Ft.TimeBlock? current_time_block,
                                                  Ft.Session?   previous_session,
                                                  Ft.TimeBlock? previous_time_block)
        {
            var timestamp = this._timer.get_last_state_changed_time ();

            if (previous_time_block != null) {
                timestamp = previous_time_block.end_time;
            }

            if (current_time_block != null) {
                timestamp = current_time_block.start_time;
            }

            foreach (var trigger in this.session_manager_advanced_triggers)
            {
                var trigger_func = (Ft.SessionManagerAdvancedTriggerFunc) trigger.func;

                if (trigger_func (current_session, current_time_block, previous_session, previous_time_block)) {
                    this.trigger_event (trigger.event_spec, timestamp);
                }
            }
        }

        private void on_session_manager_notify_current_state (GLib.Object    object,
                                                              GLib.ParamSpec pspec)
        {
            var current_state = this._session_manager.current_state;
            var previous_state = this.previous_state;

            if (current_state == previous_state) {
                return;
            }

            this.previous_state = current_state;

            foreach (var trigger in this.session_manager_notify_current_state_triggers)
            {
                var trigger_func = (Ft.SessionManagerNotifyCurrentStateTriggerFunc) trigger.func;

                if (trigger_func (current_state, previous_state)) {
                    this.queue_event (trigger.event_spec);
                }
            }
        }

        private void on_session_manager_session_rescheduled (Ft.Session session,
                                                             int64      timestamp)
        {
            // Workaround for redundant signals.
            // FIXME: It should be fixed in SessionManager - it calls rescheduling too often at times
            if (timestamp == this.last_session_rescheduled_time) {
                GLib.debug ("Detected duplicate 'session-rescheduled' event. Dropping...");
                return;
            }

            this.last_session_rescheduled_time = timestamp;

            foreach (var trigger in this.session_manager_session_rescheduled_triggers)
            {
                var trigger_func = (Ft.SessionManagerSessionRescheduledTriggerFunc) trigger.func;

                if (trigger_func (session)) {
                    // Reschedule is typically done as first thing before any action.
                    // To capture timer context we need to to delay collecting the context.
                    this.queue_event (trigger.event_spec);
                }
            }
        }

        private void on_session_manager_session_expired (Ft.Session session,
                                                         int64      timestamp)
        {
            foreach (var trigger in this.session_manager_session_expired_triggers)
            {
                var trigger_func = (Ft.SessionManagerSessionExpiredTriggerFunc) trigger.func;

                if (trigger_func (session)) {
                    this.trigger_event (trigger.event_spec, timestamp);
                }
            }
        }

        public void flush ()
        {
            this.trigger_queued_events (new Ft.Context.build ());
        }

        public void destroy ()
        {
            this.destroying = true;
            this.trigger_queued_events (new Ft.Context.build ());
        }

        [Signal (run = "first")]
        public signal void event (Ft.Event event)
        {
            this._bus.push_event (event);
        }

        public override void dispose ()
        {
            if (this.idle_id != 0) {
                GLib.Source.remove (this.idle_id);
                this.idle_id = 0;
            }

            if (this.event_spec_by_name != null) {
                this.event_spec_by_name.remove_all ();
            }

            if (this._timer != null) {
                this._timer.state_changed.disconnect (this.on_timer_state_changed);
                this._timer = null;
            }

            if (this._session_manager != null) {
                this._session_manager.confirm_advancement.disconnect (this.on_session_manager_confirm_advancement);
                this._session_manager.advanced.disconnect (this.on_session_manager_advanced);
                this._session_manager.notify["current-state"].disconnect (this.on_session_manager_notify_current_state);
                this._session_manager.session_rescheduled.disconnect (this.on_session_manager_session_rescheduled);
                this._session_manager.session_expired.disconnect (this.on_session_manager_session_expired);
                this._session_manager = null;
            }

            this._bus = null;
            this.event_specs = null;
            this.event_spec_by_name = null;
            this.queue = null;
            this.event_source_timestamp = Ft.Timestamp.UNDEFINED;

            this.timer_state_change_triggers = null;
            this.session_manager_confirm_advancement_triggers = null;
            this.session_manager_advanced_triggers = null;
            this.session_manager_notify_current_state_triggers = null;
            this.session_manager_session_rescheduled_triggers = null;
            this.session_manager_session_expired_triggers = null;

            base.dispose ();
        }
    }
}
