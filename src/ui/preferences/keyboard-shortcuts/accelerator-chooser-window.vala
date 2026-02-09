/*
 * Copyright (c) 2025 focus-timer contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/**
 * Based on cc-keyboard-shortcut-editor.c from gnome-control-center
 */

namespace Ft
{
    // TODO: make it a dialog window
    [GtkTemplate (ui = "/io/github/focustimerhq/FocusTimer/ui/preferences/keyboard-shortcuts/accelerator-chooser-window.ui")]
    public class AcceleratorChooserWindow : Adw.Window
    {
        private enum Mode
        {
            CAPTURE,
            REVIEW
        }

        public string description {
            get {
                return this.description_label.label;
            }
            set {
                this.description_label.label = value;
            }
        }
        public string accelerator { get; set; }

        [GtkChild]
        private unowned Gtk.Button          cancel_button;
        [GtkChild]
        private unowned Gtk.Button          set_button;
        [GtkChild]
        private unowned Gtk.Label           description_label;
        [GtkChild]
        private unowned Gtk.ShortcutLabel   accelerator_label;
        [GtkChild]
        private unowned Gtk.Picture         capture_image;
        [GtkChild]
        private unowned Gtk.Label           capture_hint;

        private Mode                mode;
        private bool                system_shortcuts_inhibited = false;
        private Ft.KeyboardManager? keyboard_manager;

        construct
        {
            this.keyboard_manager = new Ft.KeyboardManager ();

            this.set_mode (Mode.CAPTURE);
        }

        public AcceleratorChooserWindow (string description,
                                         string accelerator)
        {
            this.description = description;
            this.accelerator = accelerator;
        }

        private void inhibit_system_shortcuts ()
        {
            this.keyboard_manager?.inhibit ();

            if (this.system_shortcuts_inhibited) {
                return;
            }

            var toplevel = this.get_native ().get_surface () as Gdk.Toplevel;

            if (toplevel != null)
            {
                toplevel.inhibit_system_shortcuts (null);

                this.system_shortcuts_inhibited = true;
            }
        }

        private void uninhibit_system_shortcuts ()
        {
            this.keyboard_manager?.uninhibit ();

            if (!this.system_shortcuts_inhibited) {
                return;
            }

            var toplevel = this.get_native ().get_surface () as Gdk.Toplevel;

            if (toplevel != null)
            {
                toplevel.restore_system_shortcuts ();

                this.system_shortcuts_inhibited = false;
            }
        }

        private void set_mode (Mode mode)
        {
            this.mode = mode;

            switch (mode)
            {
                case Mode.CAPTURE:
                    this.cancel_button.visible = false;
                    this.set_button.visible = false;
                    this.accelerator_label.visible = false;
                    this.capture_image.visible = true;
                    this.capture_hint.visible = true;
                    this.inhibit_system_shortcuts ();
                    break;

                case Mode.REVIEW:
                    this.cancel_button.visible = true;
                    this.set_button.visible = true;
                    this.accelerator_label.visible = true;
                    this.capture_image.visible = false;
                    this.capture_hint.visible = false;
                    break;

                default:
                    assert_not_reached ();
            }

            if (mode != Mode.CAPTURE) {
                this.uninhibit_system_shortcuts ();
            }
        }

        [GtkCallback]
        private void on_cancel_button_clicked ()
        {
            this.response (Gtk.ResponseType.CANCEL);
        }

        [GtkCallback]
        private void on_set_button_clicked ()
        {
            this.response (Gtk.ResponseType.APPLY);
        }

        [GtkCallback]
        private bool on_key_pressed (Gtk.EventControllerKey event_controller,
                                     uint                   keyval,
                                     uint                   keycode,
                                     Gdk.ModifierType       state)
        {
            var event = event_controller.get_current_event () as Gdk.KeyEvent;

            if (this.mode != Mode.CAPTURE)
            {
                if (keyval == Gdk.Key.Return) {
                    this.response (Gtk.ResponseType.APPLY);
                    return Gdk.EVENT_STOP;
                }

                return Gdk.EVENT_PROPAGATE;
            }

            if (event == null || event.is_modifier ()) {
                return Gdk.EVENT_STOP;
            }

            var accelerator = Ft.Accelerator.from_keycode (keycode,
                                                           state,
                                                           event_controller.get_group ());

            if (accelerator.modifiers == Gdk.ModifierType.NO_MODIFIER_MASK)
            {
                switch (keyval)
                {
                    /* A single Escape press aborts editing */
                    case Gdk.Key.Escape:
                        this.response (Gtk.ResponseType.CANCEL);
                        return Gdk.EVENT_STOP;

                    /* Backspace disables the current shortcut */
                    case Gdk.Key.BackSpace:
                        this.accelerator = "";
                        this.response (Gtk.ResponseType.APPLY);
                        return Gdk.EVENT_STOP;

                    default:
                        break;
                }
            }

            if (accelerator.is_valid ()) {
                this.accelerator = accelerator.to_string ();
                this.set_mode (Mode.REVIEW);
            }

            return Gdk.EVENT_STOP;
        }

        public override void map ()
        {
            base.map ();

            if (this.mode == Mode.CAPTURE) {
                this.inhibit_system_shortcuts ();
            }
        }

        public override void unmap ()
        {
            this.uninhibit_system_shortcuts ();

            base.unmap ();
        }

        public virtual signal void response (int response_id)
        {
            this.close ();
        }

        public override void dispose ()
        {
            this.keyboard_manager = null;

            base.dispose ();
        }
    }
}
