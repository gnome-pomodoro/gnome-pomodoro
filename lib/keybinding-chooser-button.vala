/*
 * Copyright (c) 2013 gnome-pomodoro contributors
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


public class Pomodoro.Widgets.KeybindingChooserButton : Gtk.Box
{
    public bool active
    {
        get {
            return this.keybinding_button.active;
        }
        set {
            this.keybinding_button.active = value;
        }
    }

    public string label
    {
        get {
            return this.keybinding_button.label;
        }
        set {
            this.keybinding_button.label = value;
        }
    }

    public Keybinding keybinding { get; set; }
    private Keybinding tmp_keybinding;

    private Gtk.ToggleButton keybinding_button;
    private Gtk.Button clear_button;

    public KeybindingChooserButton (Keybinding keybinding)
    {
        GLib.Object (orientation: Gtk.Orientation.HORIZONTAL,
                     spacing: 0,
                     halign: Gtk.Align.CENTER,
                     homogeneous: false,
                     can_focus: false);

        this.keybinding_button = new Gtk.ToggleButton ();
        this.keybinding_button.set_events (this.events |
                                           Gdk.EventMask.KEY_PRESS_MASK |
                                           Gdk.EventMask.FOCUS_CHANGE_MASK);
        this.keybinding_button.can_focus = true;

        this.clear_button = new SymbolicButton ("edit-clear-symbolic",
                                                Gtk.IconSize.MENU);
        this.clear_button.can_focus = true;
        this.clear_button.no_show_all = true;
        this.clear_button.clicked.connect (() => {
            this.keybinding.accelerator = null;
            this.active = false;
        });

        this.pack_start (this.keybinding_button, true, true, 0);
        this.pack_start (this.clear_button, false, true, 0);

        var style_context = this.get_style_context ();
        style_context.add_class (Gtk.STYLE_CLASS_LINKED);

        this.keybinding = keybinding;
        this.keybinding.changed.connect (() => {
            this.notify_property ("keybinding");
            this.refresh ();
        });

        this.tmp_keybinding = new Keybinding ();

        this.refresh ();
    }

    private void refresh ()
    {
        var label = this.keybinding.get_label ();
        if (label != "") {
            this.label = label;
        }
        else {
            this.label = _("Disabled");
        }

        this.clear_button.set_visible (this.keybinding.accelerator != "");
    }

    public void toggled ()
    {
        if (this.active) {
            this.grab_focus ();
        }
    }

    public override bool focus_out_event (Gdk.EventFocus event)
    {
        this.active = false;

        return base.focus_out_event (event);
    }

    public override bool key_press_event (Gdk.EventKey event)
    {
        if (!this.active) {
            return base.key_press_event (event);
        }

        switch (event.keyval)
        {
            case Gdk.Key.BackSpace:
                    this.keybinding.accelerator = null;
                    this.active = false;

                    return true;

            case Gdk.Key.Escape:
            case Gdk.Key.Return:
                    this.active = false;

                    return true;
        }

        try
        {
            this.tmp_keybinding.set_values (event.keyval, event.state);
            this.tmp_keybinding.verify ();
        }
        catch (KeybindingError error)
        {
            if (error is KeybindingError.TYPING_COLLISION)
            {
                this.active = false;

                var dialog = new Gtk.MessageDialog (
                        this.get_toplevel () as Gtk.Window,
                        Gtk.DialogFlags.DESTROY_WITH_PARENT | Gtk.DialogFlags.MODAL,
                        Gtk.MessageType.WARNING,
                        Gtk.ButtonsType.CANCEL,
                        _("The shortcut \"%s\" cannot be used because it will become impossible to type using this key.\nPlease try with a key such as Control, Alt or Shift at the same time."),
                        this.tmp_keybinding.get_label ());
                dialog.run ();
                dialog.destroy ();
            }

            return true;
        }

        this.keybinding.set_values (
                this.tmp_keybinding.key,
                this.tmp_keybinding.modifiers);

        this.active = false;

        return true;
    }
}
