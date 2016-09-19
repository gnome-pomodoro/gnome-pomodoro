/*
 * Copyright (c) 2016 gnome-pomodoro contributors
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
 */

using GLib;


namespace Actions
{
    [Flags]
    public enum State
    {
        NONE = 0,
        POMODORO = 1,
        SHORT_BREAK = 2,
        LONG_BREAK = 4,
        ANY = POMODORO | SHORT_BREAK | LONG_BREAK;

        public GLib.List<Actions.State> to_list ()
        {
            var states = new GLib.List<Actions.State> ();

            if ((this & Actions.State.LONG_BREAK) != 0) {
                states.prepend (Actions.State.LONG_BREAK);
            }

            if ((this & Actions.State.SHORT_BREAK) != 0) {
                states.prepend (Actions.State.SHORT_BREAK);
            }

            if ((this & Actions.State.POMODORO) != 0) {
                states.prepend (Actions.State.POMODORO);
            }

            return states;
        }

        public string to_string ()
        {
            switch (this)
            {
                case Actions.State.POMODORO:
                    return "pomodoro";

                case Actions.State.SHORT_BREAK:
                    return "short-break";

                case Actions.State.LONG_BREAK:
                    return "long-break";
            }

            return "";
        }

        public static State from_timer_state (Pomodoro.TimerState timer_state)
        {
            if (timer_state is Pomodoro.PomodoroState) {
                return Actions.State.POMODORO;
            }

            if (timer_state is Pomodoro.ShortBreakState) {
                return Actions.State.SHORT_BREAK;
            }

            if (timer_state is Pomodoro.LongBreakState) {
                return Actions.State.LONG_BREAK;
            }

            return State.NONE;
        }

        public string get_label ()
        {
            switch (this)
            {
                case Actions.State.POMODORO:
                    return _("Pomodoro");

                case Actions.State.SHORT_BREAK:
                    return _("Short Break");

                case Actions.State.LONG_BREAK:
                    return _("Long Break");
            }

            return "";
        }
    }

    [Flags]
    public enum Trigger
    {
        NONE = 0,
        START = 1,
        COMPLETE = 2,
        SKIP = 4,
        PAUSE = 8,
        RESUME = 16,
        ENABLE = 32,
        DISABLE = 64;

        public GLib.List<Actions.Trigger> to_list ()
        {
            var states = new GLib.List<Actions.Trigger> ();

            if ((this & Actions.Trigger.DISABLE) != 0) {
                states.prepend (Actions.Trigger.DISABLE);
            }

            if ((this & Actions.Trigger.ENABLE) != 0) {
                states.prepend (Actions.Trigger.ENABLE);
            }

            if ((this & Actions.Trigger.RESUME) != 0) {
                states.prepend (Actions.Trigger.RESUME);
            }

            if ((this & Actions.Trigger.PAUSE) != 0) {
                states.prepend (Actions.Trigger.PAUSE);
            }

            if ((this & Actions.Trigger.SKIP) != 0) {
                states.prepend (Actions.Trigger.SKIP);
            }

            if ((this & Actions.Trigger.COMPLETE) != 0) {
                states.prepend (Actions.Trigger.COMPLETE);
            }

            if ((this & Actions.Trigger.START) != 0) {
                states.prepend (Actions.Trigger.START);
            }

            return states;
        }

        public string to_string ()
        {
            switch (this)
            {
                case START:
                    return "start";

                case COMPLETE:
                    return "complete";

                case SKIP:
                    return "skip";

                case PAUSE:
                    return "pause";

                case RESUME:
                    return "resume";

                case ENABLE:
                    return "enable";

                case DISABLE:
                    return "disable";
            }

            return "";
        }

        public string get_label ()
        {
            switch (this)
            {
                case START:
                    return _("Start");

                case COMPLETE:
                    return _("Complete");

                case SKIP:
                    return _("Skip");

                case PAUSE:
                    return _("Pause");

                case RESUME:
                    return _("Resume");

                case ENABLE:
                    return _("Enable");

                case DISABLE:
                    return _("Disable");
            }

            return "";
        }
    }
}
