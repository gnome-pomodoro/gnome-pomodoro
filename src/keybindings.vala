/*
 * based on keyboard-shortcuts.c from gnome-control-center
 *
 * Copyright (c) 2013 gnome-pomodoro contributors
 *               2010 Intel, Inc
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *          Thomas Wood <thomas.wood@intel.com>
 *          Rodrigo Moya <rodrigo@gnome.org>
 */

/* TODO:
 * Handle integration with window manager
 *  - suppress any keybings from being triggered
 *  - if keybinding is taken, notify about it
 *
 * For now gnome-shell extension is responsible for setting it.
 */


public errordomain Pomodoro.KeybindingError
{
    INVALID,
    FORBIDDEN,
    TYPING_COLLISION
}


public class Pomodoro.Keybinding : GLib.Object
{
    public uint key { get; private set; }
    public Gdk.ModifierType modifiers { get; private set; }

    public string accelerator
    {
        owned get {
            var accelerator = new StringBuilder ();

            foreach (var element in this.get_string_list (true)) {
                accelerator.append (element);
            }

            return accelerator.str;
        }
        set {
            uint key = 0;
            Gdk.ModifierType modifiers = 0;

            Keybinding.parse (value, out key, out modifiers);

            this.key = key;
            this.modifiers = modifiers;

            this.changed ();
        }
    }

    public Keybinding (uint             key = 0,
                       Gdk.ModifierType modifiers = 0)
    {
        this.key = key;
        this.modifiers = modifiers;
    }

    public Keybinding.from_string (string? str)
    {
        this.accelerator = str;
    }

    public static void parse (string?              str,
                              out uint             keyval,
                              out Gdk.ModifierType modifiers)
    {
        int pos = 0;
        int start = 0;
        char chr = '\0';
        bool is_modifier = false;

        keyval = 0;
        modifiers = 0;

        if (str == null) {
            return;
        }

        while ((chr = str[pos]) != '\0')
        {
            if (chr == '<') {
                start = pos + 1;
                is_modifier = true;
            }
            else if (chr == '>' && is_modifier)
            {
                var modifier = str.slice (start, pos);

                if (modifier == "Ctrl" || modifier == "Control") {
                    modifiers |= Gdk.ModifierType.CONTROL_MASK;
                }

                if (modifier == "Alt") {
                    modifiers |= Gdk.ModifierType.MOD1_MASK;
                }

                if (modifier == "Shift") {
                    modifiers |= Gdk.ModifierType.SHIFT_MASK;
                }

                if (modifier == "Super") {
                    modifiers |= Gdk.ModifierType.SUPER_MASK;
                }

                is_modifier = false;
                start = pos + 1;
            }

            pos++;
        }

        keyval = Gdk.keyval_from_name (str.slice (start, pos));
    }

    public void set_values (uint             key,
                            Gdk.ModifierType modifiers)
    {
        this.key = key;
        this.modifiers = modifiers & (
                Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK |
                Gdk.ModifierType.SUPER_MASK | Gdk.ModifierType.MOD1_MASK);

        this.notify_property ("accelerator");
        this.changed ();
    }

    public void verify () throws KeybindingError
    {
        var key = this.key;
        var modifiers = this.modifiers;

        if (!Gtk.accelerator_valid (key, modifiers))
        {
            throw new KeybindingError.INVALID ("Invalid");
        }

        if (modifiers == 0 && key != 0)
        {
            if (key == Gdk.Key.Escape ||
                key == Gdk.Key.BackSpace ||
                key == Gdk.Key.Return)
            {
                throw new KeybindingError.FORBIDDEN ("Forbidden");
            }
        }

        /* Check for unmodified keys */
        if ((modifiers == 0 || modifiers == Gdk.ModifierType.SHIFT_MASK) && key != 0)
        {
            if ((key >= Gdk.Key.a && key <= Gdk.Key.z) ||
                (key >= Gdk.Key.A && key <= Gdk.Key.Z) ||
                (key >= Gdk.Key.@0 && key <= Gdk.Key.@9) ||
                (key >= Gdk.Key.kana_fullstop && key <= Gdk.Key.semivoicedsound) ||
                (key >= Gdk.Key.Arabic_comma && key <= Gdk.Key.Arabic_sukun) ||
                (key >= Gdk.Key.Serbian_dje && key <= Gdk.Key.Cyrillic_HARDSIGN) ||
                (key >= Gdk.Key.Greek_ALPHAaccent && key <= Gdk.Key.Greek_omega) ||
                (key >= Gdk.Key.hebrew_doublelowline && key <= Gdk.Key.hebrew_taf) ||
                (key >= Gdk.Key.Thai_kokai && key <= Gdk.Key.Thai_lekkao) ||
                (key >= Gdk.Key.Hangul && key <= Gdk.Key.Hangul_Special) ||
                (key >= Gdk.Key.Hangul_Kiyeog && key <= Gdk.Key.Hangul_J_YeorinHieuh))
            {
                throw new KeybindingError.TYPING_COLLISION ("Typing collision");
            }
        }
    }

    private List<string> get_string_list (bool escape_modifiers=true)
    {
        var elements = new List<string> ();

        if (Gdk.ModifierType.SHIFT_MASK in this.modifiers) {
            elements.append (escape_modifiers ? "<Shift>" : "Shift");
        }

        if (Gdk.ModifierType.SUPER_MASK in this.modifiers) {
            elements.append (escape_modifiers ? "<Super>" : "Super");
        }

        if (Gdk.ModifierType.CONTROL_MASK in this.modifiers) {
            elements.append (escape_modifiers ? "<Ctrl>" : "Ctrl");
        }

        if (Gdk.ModifierType.MOD1_MASK in this.modifiers) {
            elements.append (escape_modifiers ? "<Alt>" : "Alt");
        }

        if (this.key != 0) {
            var keyval = Gdk.keyval_to_upper (this.key);
            elements.append (Gdk.keyval_name (keyval));
        }

        return elements;
    }

    public string get_label ()
    {
        var label = new StringBuilder ();
        var is_first = true;

        foreach (var element in this.get_string_list (false))
        {
            if (!is_first) {
                label.append ("+");
            } else {
                is_first = false;
            }

            label.append (element);
        }

        return label.str;
    }

    public signal void changed ();
}
