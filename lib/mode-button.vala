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


public class Pomodoro.Widgets.ModeButton : Gtk.Box
{
    private int _selected = -1;

    public int selected {
        get {
            return this._selected;
        }
        set {
            var children = this.get_children ();
            var index = 0;

            if (value < 0 || value >= children.length ()) {
                return;
            }

            foreach (var child in children)
            {
                if (child is Gtk.ToggleButton)
                {
                    var item = child as Item;

                    item.can_toggle = true;
                    item.active = (index == value);

                    if (item.active)
                        item.can_toggle = false;
                }

                index++;
            }

            if (value != this._selected) {
                this._selected = value;
                this.changed ();
            }
        }
    }

    public ModeButton (Gtk.Orientation orientation)
    {
        GLib.Object (
            orientation: orientation,
            homogeneous: true,
            spacing: 0
        );

        this.halign = Gtk.Align.CENTER;
        this.can_focus = false;

        var style_context = this.get_style_context ();
        style_context.add_class (Gtk.STYLE_CLASS_LINKED);
    }

    public new void add (Gtk.Widget child)
    {
        assert (child is Gtk.ToggleButton);

        var style_context = child.get_style_context ();
        style_context.add_class (Gtk.STYLE_CLASS_RAISED);

        var button = child as Gtk.ToggleButton;

        button.set_alignment (0.5f, 0.5f);
        button.can_focus = true;
        button.add_events (Gdk.EventMask.SCROLL_MASK);

        button.toggled.connect (this.on_child_toggled);

        this.pack_start (button, true, true, 0);

        if (this.selected < 0) {
            this.selected = 0;
        }
    }

    private void on_child_toggled (Gtk.ToggleButton button)
    {
        if (button.active) {
            this.selected = this.get_children ().index (button);
        }
    }

    public unowned Gtk.Widget add_label (string text)
    {
        var item = new Item.with_label (text);
        item.set_focus_on_click (false);
        item.show ();

        this.add (item);

        return item as Gtk.Widget;
    }

    public override bool scroll_event (Gdk.EventScroll event)
    {
        switch (event.direction)
        {
            case Gdk.ScrollDirection.RIGHT:
            case Gdk.ScrollDirection.DOWN:
                this.selected += 1;
                break;

            case Gdk.ScrollDirection.LEFT:
            case Gdk.ScrollDirection.UP:
                this.selected -= 1;
                break;
        }

        return false;
    }

    public signal void changed ();


    class Item : Gtk.ToggleButton
    {
        public bool can_toggle { get; set; default=true; }

        private Pango.Layout layout_bold;

        public Item.with_label (string label)
        {
            this.label = label;

            var style_context = this.get_style_context ();
            style_context.add_class ("text-button");
        }

        private void set_bold_attribute (bool is_bold)
        {
            var child = this.get_child ();

            if (child is Gtk.Label)
            {
                var label = child as Gtk.Label;

                if (is_bold) {
                    var attr = Pango.attr_weight_new (Pango.Weight.BOLD);

                    label.attributes = new Pango.AttrList ();
                    label.attributes.insert (attr.copy ());
                }
                else {
                    label.attributes = null;
                }
            }
        }

        public override void get_preferred_width (out int minimum_width,
                                                  out int natural_width)
        {
            var child = this.get_child ();
            var width = 0;
            var width_bold = 0;

            base.get_preferred_width (out minimum_width, out natural_width);

            if (child is Gtk.Label)
            {
                var label = child as Gtk.Label;
                var layout = label.get_layout ();

                layout.get_pixel_size (out width, null);

                if (this.layout_bold == null)
                {
                    Pango.FontDescription font;
                    child.get_style_context ().@get (Gtk.StateFlags.NORMAL,
                                                     "font",
                                                     out font);
                    font.set_weight (Pango.Weight.BOLD);

                    this.layout_bold = layout.copy ();
                    this.layout_bold.set_font_description (font);
                }

                this.layout_bold.get_pixel_size (out width_bold, null);

                minimum_width += int.max (width_bold - width, 0);
            }

            if (natural_width < minimum_width)
                natural_width = minimum_width;
        }

        public override void style_updated ()
        {
            this.layout_bold = null;
            base.style_updated ();
        }

        public override void clicked ()
        {
            if (this.can_toggle)
                base.clicked ();
        }

        public override void toggled ()
        {
            this.set_bold_attribute (this.active);
        }
    }
}
