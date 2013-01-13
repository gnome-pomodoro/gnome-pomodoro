/*
 * Copyright (c) 2012 gnome-shell-pomodoro contributors
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
 *
 */

const Lang = imports.lang;
const Signals = imports.signals;
const _ = imports.gettext.gettext;

const Gdk = imports.gi.Gdk;
const GLib = imports.gi.GLib;
const Gtk = imports.gi.Gtk;
const Gio = imports.gi.Gio;
const Pango = imports.gi.Pango;


const ModeButton = new Lang.Class({
    Name: 'ModeButton',
    Extends: Gtk.Box,

    _selected: -1,
    _busy: false,

    get selected() {
        return this._selected;
    },

    set selected(value) {
        let children = this.get_children();

        if (value < 0 || value >= children.length)
            return;

        if (!this._busy)
        {
            this._busy = true;

            for (let index in children) {
                children[index].active = (index == value);
            }

            this._busy = false;

            if (this._selected != value) {
                this._selected = value;
                this.emit('changed');
            }
        }
    },

    _init: function() {
        this.parent();

        this.homogeneous = true;
        this.halign = Gtk.Align.CENTER;
        this.can_focus = false;
        this.spacing = 0;

        let style_context = this.get_style_context ();
        style_context.add_class('linked');
    },

    add: function(child) {
        let style_context = child.get_style_context ();
        style_context.add_class('raised');

        child.set_alignment(0.5, 0.5);
        child.can_focus = true;
        child.add_events(Gdk.EventMask.SCROLL_MASK);

        child.connect('clicked', Lang.bind(this, function(widget) {
            this.selected = this.get_children().indexOf(widget);
        }));

        this.pack_start (child, true, true, 0);

        if (this.selected < 0)
            this.selected = 0;
    },

    append_text: function(text) {
        let item = new ModeButtonItem({ label: text });
        this.add(item);
    },

    append_icon: function(icon_name, icon_size) {
        let item = new ModeButtonItem();
        this.add(item);

        let icon = Gtk.Image.new_from_icon_name(icon_name, icon_size);
        item.add(icon);
    },

    vfunc_scroll_event: function(event) {
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
});
Signals.addSignalMethods(ModeButton.prototype);

const ModeButtonItem = new Lang.Class({
    Name: 'ModeButtonItem',
    Extends: Gtk.ToggleButton,

    vfunc_get_preferred_width: function() {
        let minimum_width;
        let natural_width;
        let child = this.get_child();

        [minimum_width, natural_width] = this.parent();

        if (child instanceof Gtk.Label) {
            let style_context = child.get_style_context();
            let layout = child.get_layout();
            let font = layout.get_font_description();

            let font_bold = style_context.get_font(Gtk.StateFlags.NORMAL);
            font_bold.set_weight(Pango.Weight.HEAVY);

            layout.set_font_description(font_bold);
            minimum_width += layout.get_pixel_size()[0];

            layout.set_font_description(font);
            minimum_width -= layout.get_pixel_size()[0];
        }

        if (natural_width < minimum_width) {
            natural_width = minimum_width;
        }
        return [minimum_width, natural_width];
    },

    vfunc_toggled: function() {
        let context = this.get_style_context();
        if (this.active)
            context.add_class('active');
        else
            context.remove_class('active');
    }
});

const SymbolicButton = new Lang.Class({
    Name: 'SymbolicButton',
    Extends: Gtk.Button,

    _init: function(icon_name) {
        this.parent();
        this.set_alignment(0.5, 0.5);
        this.set_size_request(34, 34);

        let icon = Gio.ThemedIcon.new_with_default_fallbacks(icon_name);
        let image = new Gtk.Image();
        image.set_from_gicon(icon, Gtk.IconSize.MENU);

        this.add(image);
    }
});
