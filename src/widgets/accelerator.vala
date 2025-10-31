/*
 * based on keyboard-shortcuts.c from gnome-control-center
 *
 * Copyright (c) 2013-2025 gnome-pomodoro contributors
 *               2010 Intel, Inc
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
 *          Thomas Wood <thomas.wood@intel.com>
 *          Rodrigo Moya <rodrigo@gnome.org>
 */

using GLib;


namespace Pomodoro
{
    public struct Accelerator
    {
        private const uint[] FORBIDDEN_KEYVALS = {
            Gdk.Key.Home,
            Gdk.Key.Left,
            Gdk.Key.Up,
            Gdk.Key.Right,
            Gdk.Key.Down,
            Gdk.Key.Page_Up,
            Gdk.Key.Page_Down,
            Gdk.Key.End,
            Gdk.Key.Tab,
            Gdk.Key.Escape,
            Gdk.Key.KP_Enter,
            Gdk.Key.Return,
            Gdk.Key.space,
            Gdk.Key.BackSpace,
            Gdk.Key.Mode_switch
        };

        public uint             keycode;
        public uint             keyval;
        public Gdk.ModifierType modifiers;

        public static Pomodoro.Accelerator empty ()
        {
            return Pomodoro.Accelerator () {
                keycode   = 0,
                keyval    = 0,
                modifiers = Gdk.ModifierType.NO_MODIFIER_MASK
            };
        }

        public static Pomodoro.Accelerator from_keycode (uint             keycode,
                                                         Gdk.ModifierType modifiers,
                                                         uint             group)
        {
            var accelerator = Pomodoro.Accelerator () {
                keycode   = keycode,
                keyval    = 0,
                modifiers = modifiers
            };

            return accelerator.normalize (group);
        }

        public static Pomodoro.Accelerator from_string (string accelerator_string)
        {
            int index = 0;
            int modifier_position = -1;
            int keyval_position = 0;
            unichar chr;

            var modifiers = Gdk.ModifierType.NO_MODIFIER_MASK;

            while (accelerator_string.get_next_char (ref index, out chr))
            {
                if (chr == '<' && modifier_position == -1) {
                    modifier_position = index;
                }
                else if (chr == '>' && modifier_position >= 0)
                {
                    var modifier_name = accelerator_string.slice (modifier_position, index - 1);

                    switch (modifier_name.down ())
                    {
                        case "ctrl":
                        case "control":
                            modifiers |= Gdk.ModifierType.CONTROL_MASK;
                            break;

                        case "⌘":
                        case "meta":
                            modifiers |= Gdk.ModifierType.META_MASK;
                            break;

                        case "alt":
                            modifiers |= Gdk.ModifierType.ALT_MASK;
                            break;

                        case "shift":
                            modifiers |= Gdk.ModifierType.SHIFT_MASK;
                            break;

                        case "super":
                            modifiers |= Gdk.ModifierType.SUPER_MASK;
                            break;

                        case "hyper":
                            modifiers |= Gdk.ModifierType.HYPER_MASK;
                            break;

                        default:
                            GLib.warning ("Unknown modifier name: '%s'", modifier_name);
                            break;
                    }

                    modifier_position = -1;
                    keyval_position = index;
                }
            }

            return Pomodoro.Accelerator () {
                keycode   = 0,
                keyval    = Gdk.keyval_from_name (accelerator_string.slice (keyval_position, index)),
                modifiers = modifiers
            };
        }

        public bool is_empty ()
        {
            return this.keycode == 0 && this.keyval == 0;
        }

        public bool is_valid ()
        {
            var keyval    = this.keyval;
            var modifiers = this.modifiers;

            if (this.is_empty ()) {
                return true;
            }

            if (modifiers == Gdk.ModifierType.NO_MODIFIER_MASK ||
                modifiers == Gdk.ModifierType.SHIFT_MASK)
            {
                /* Check for typing collision */
                if ((keyval >= Gdk.Key.a && keyval <= Gdk.Key.z) ||
                    (keyval >= Gdk.Key.A && keyval <= Gdk.Key.Z) ||
                    (keyval >= Gdk.Key.@0 && keyval <= Gdk.Key.@9) ||
                    (keyval >= Gdk.Key.kana_fullstop && keyval <= Gdk.Key.semivoicedsound) ||
                    (keyval >= Gdk.Key.Arabic_comma && keyval <= Gdk.Key.Arabic_sukun) ||
                    (keyval >= Gdk.Key.Serbian_dje && keyval <= Gdk.Key.Cyrillic_HARDSIGN) ||
                    (keyval >= Gdk.Key.Greek_ALPHAaccent && keyval <= Gdk.Key.Greek_omega) ||
                    (keyval >= Gdk.Key.hebrew_doublelowline && keyval <= Gdk.Key.hebrew_taf) ||
                    (keyval >= Gdk.Key.Thai_kokai && keyval <= Gdk.Key.Thai_lekkao) ||
                    (keyval >= Gdk.Key.Hangul_Kiyeog && keyval <= Gdk.Key.Hangul_J_YeorinHieuh))
                {
                    return false;
                }

                /* Don't allow navigation keys and such */
                for (var index = 0; index < FORBIDDEN_KEYVALS.length; index++)
                {
                    if (keyval == FORBIDDEN_KEYVALS[index]) {
                        return false;
                    }
                }
            }

            return Gtk.accelerator_valid (keyval, modifiers);
        }

        /* This adjusts the keyval and modifiers such that it matches how
         * gnome-shell detects shortcuts, which works as follows:
         * First for the non-modifier key, the keycode that generates this
         * keyval at the lowest shift level is determined, which might be a
         * level > 0, such as for numbers in the num-row in AZERTY.
         * Next it checks if all the specified modifiers were pressed.
         */
        public Pomodoro.Accelerator normalize (uint group)
        {
            uint unmodified_keyval;
            uint shifted_keyval;

            /* We want shift to always be included as explicit modifier for
             * gnome-shell shortcuts. That's because users usually think of
             * shortcuts as including the shift key rather than being defined
             * for the shifted keyval.
             * This helps with num-row keys which have different keyvals on
             * different layouts for example, but also with keys that have
             * explicit key codes at shift level 0, that gnome-shell would prefer
             * over shifted ones, such the DOLLAR key.
             */
            var explicit_modifiers = Gdk.ModifierType.SHIFT_MASK |
                                     Gtk.accelerator_get_default_mod_mask ();
            var used_modifiers     = this.modifiers & explicit_modifiers;

            /* Find the base keyval of the pressed key without the explicit
             * modifiers. */
            var display = Gdk.Display.get_default ();
            display.translate_key (this.keycode,
                                   this.modifiers & ~explicit_modifiers,
                                   (int) group,
                                   out unmodified_keyval,
                                   null,
                                   null,
                                   null);

            /* Normalize num-row keys to the number value. This allows these
             * shortcuts to work when switching between AZERTY and layouts where
             * the numbers are at shift level 0. */
            display.translate_key (this.keycode,
                                   Gdk.ModifierType.SHIFT_MASK | (this.modifiers &
                                                                  ~explicit_modifiers),
                                   (int) group,
                                   out shifted_keyval,
                                   null,
                                   null,
                                   null);

            if (shifted_keyval >= Gdk.Key.@0 && shifted_keyval <= Gdk.Key.@9) {
                unmodified_keyval = shifted_keyval;
            }

            /* Normalise <Tab> */
            if (unmodified_keyval == Gdk.Key.ISO_Left_Tab) {
                unmodified_keyval = Gdk.Key.Tab;
            }

            /* CapsLock isn't supported as a keybinding modifier, so keep it from confusing us */
            used_modifiers &= ~Gdk.ModifierType.LOCK_MASK;

            return Pomodoro.Accelerator () {
                keycode   = 0,
                keyval    = unmodified_keyval,
                modifiers = used_modifiers
            };
        }

        /**
         * Intention here is to match the behaviour somewhat of `GtkShortcutLabel` which we use
         * in the edit dialog.
         */
        private string[] get_labels ()
        {
            var labels = new string[0];

            if (Gdk.ModifierType.SHIFT_MASK in this.modifiers) {
                labels += "Shift";
            }

            if (Gdk.ModifierType.CONTROL_MASK in this.modifiers) {
                labels += "Ctrl";
            }

            if (Gdk.ModifierType.META_MASK in this.modifiers) {
                labels += "⌘";  // aka. Command key
            }

            if (Gdk.ModifierType.ALT_MASK in this.modifiers) {
                labels += "Alt";  // aka. Option key / ⌥
            }

            if (Gdk.ModifierType.SUPER_MASK in this.modifiers) {
                labels += "Super";
            }

            if (Gdk.ModifierType.HYPER_MASK in this.modifiers) {
                labels += "Hyper";
            }

            if (Gdk.ModifierType.META_MASK in this.modifiers) {
                labels += "Meta";
            }

            var chr = (unichar) Gdk.keyval_to_unicode (this.keyval);

            if (chr != '\x00' && chr < '\x80' && chr.isgraph ())
            {
                switch (chr)
                {
                    case '\\':
                        labels += "Backslash";
                        break;

                    default:
                        labels += chr.toupper ().to_string ();
                        break;
                }
            }
            else
            {
                switch (this.keyval)
                {
                    case Gdk.Key.Left:
                        labels += "\xe2\x86\x90";
                        break;

                    case Gdk.Key.Up:
                        labels += "\xe2\x86\x91";
                        break;

                    case Gdk.Key.Right:
                        labels += "\xe2\x86\x92";
                        break;

                    case Gdk.Key.Down:
                        labels += "\xe2\x86\x93";
                        break;

                    case Gdk.Key.space:
                        labels += "Space";
                        break;

                    case Gdk.Key.Return:
                        labels += "Return";
                        break;

                    case Gdk.Key.Page_Up:
                        labels += "Page Up";
                        break;

                    case Gdk.Key.Page_Down:
                        labels += "Page Down";
                        break;

                    default:
                        labels += Gdk.keyval_name (this.keyval).replace ("_", " ");
                        break;
                }
            }

            return labels;
        }

        public string get_label ()
        {
            return string.joinv (" + ", this.get_labels ());
        }

        public string to_string ()
        {
            return !this.is_empty ()
                ? Gtk.accelerator_name (this.keyval, this.modifiers)
                : "";
        }
    }
}
