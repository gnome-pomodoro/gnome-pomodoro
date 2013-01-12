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

    get selected() {
        return this._selected;
    },

    set selected(value) {
        let children = this.get_children();
        let button = null;

        if (value == this._selected)
            return;

        if (value >= 0 && value < children.length)
        {
            // deactivate current item
            if (this._selected >= 0) {
                button = children[this._selected];
                button.set_active(false);
            }
            // activate new item
            button = children[value];
            button.set_active(true);

            this._selected = value;
        }
    },

    _init: function() {
        this.parent();

        this.homogeneous = true;
        this.halign = Gtk.Align.CENTER;
        this.can_focus = true;
        this.spacing = 0;

        let style_context = this.get_style_context ();
        style_context.add_class('linked');
    },

    add: function(child) {
        let style_context = child.get_style_context ();
        style_context.add_class('raised');

        child.set_alignment(0.5, 0.5);
        child.can_focus = false;
        child.add_events(Gdk.EventMask.SCROLL_MASK);

        child.connect('button-press-event', Lang.bind(this, function() {
            this.selected = this.get_children().indexOf(child);
            return true;
        }));

        this.pack_start (child, true, true, 0);

        if (this.selected < 0)
            this.selected = 0;
    },

    append_text: function(text)
    {
        let item = new ModeButtonItem({ label: text });
        this.add(item);
    },

    append_icon: function(icon_name, icon_size)
    {
        let icon = Gtk.Image.new_from_icon_name(icon_name, icon_size);
        let item = new ModeButtonItem();
        item.add(icon);

        this.add(item);
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

const ModeButtonItem = new Lang.Class({
    Name: 'ModeButtonItem',
    Extends: Gtk.ToggleButton,

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
