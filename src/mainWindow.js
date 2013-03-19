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
const Mainloop = imports.mainloop;
const _ = imports.gettext.gettext;

const Gdk = imports.gi.Gdk;
const GLib = imports.gi.GLib;
const Gtk = imports.gi.Gtk;
const Gio = imports.gi.Gio;
const Pango = imports.gi.Pango;

const Config = imports.config;
const Widgets = imports.widgets;

const COPYRIGHTS = 'Copyright \u00A9 2012 Arun Mahapatra, Kamil Prusko';
const AUTHORS = [
    'Arun Mahapatra <pratikarun@gmail.com>',
    'Kamil Prusko <kamilprusko@gmail.com>',
];

const MainWindow = new Lang.Class({
    Name: 'MainWindow',

    window: null,
    views: null,

    _init: function(app) {
        this.window = new Gtk.ApplicationWindow({
                              application: app,
                              window_position: Gtk.WindowPosition.CENTER,
                              hide_titlebar_when_maximized: true,
                              title: _("Pomodoro") });

        this.window.set_size_request(640, 420);

        let css_provider = new Gtk.CssProvider();
        css_provider.load_from_path(Config.PACKAGE_DATADIR + '/gtk-style.css');

        let context = this.window.get_style_context();
        context.add_provider_for_screen(Gdk.Screen.get_default(),
                                        css_provider,
                                        Gtk.STYLE_PROVIDER_PRIORITY_USER);

        this.setup_toolbar();
        this.setup_notebook();
        this.setup_views();

        let event_box = new Gtk.EventBox();
        event_box.get_style_context().add_class('pomodoro-window');
        event_box.add(this.notebook);

        this.vbox = new Gtk.VBox();
        this.vbox.pack_start(this.toolbar, false, false, 0);
        this.vbox.pack_end(event_box, true, true, 0);
        this.vbox.show_all();

        this.window.add(this.vbox);

        this.window.connect('delete-event',
                            Lang.bind(this, this._quit));
        this.window.connect('key-press-event',
                            Lang.bind(this, this._onKeyPressEvent));
    },

    setup_toolbar: function() {
        this.toolbar = new Gtk.Toolbar();
        this.toolbar.icon_size = Gtk.IconSize.MENU;
        this.toolbar.show_arrow = false;
        this.toolbar.get_style_context().add_class('pomodoro-toolbar');
        this.toolbar.get_style_context().add_class(Gtk.STYLE_CLASS_MENUBAR);

        // left controls
        {
            let left_item = new Gtk.ToolItem();
            this.toolbar.insert(left_item, -1);

            let left_box = new Gtk.Box();
            left_box.set_homogeneous(true);
            left_box.get_style_context().add_class('linked');
            left_item.add(left_box);
        }

        // center controls
        {
            let center_item = new Gtk.ToolItem();
            center_item.set_expand(true);
            this.toolbar.insert(center_item, -1);

            let center_box = new Gtk.Box();
            center_item.add(center_box);

            this.mode_button = new Widgets.ModeButton();
            this.mode_button.set_size_request(34, 34);

            center_box.pack_start(this.mode_button, true, false, 0);
        }

        // right controls
        {
            let right_item = new Gtk.ToolItem();
            this.toolbar.insert(right_item, -1);

            let right_box = new Gtk.Box();
            right_item.add(right_box);
        }
    },

    setup_notebook: function() {
        this.notebook = new Gtk.Notebook();
        this.notebook.set_show_tabs(false);
        this.notebook.set_show_border(false);
    },

    setup_views: function() {
        this.views = [
            new TasksView(),
            new StatisticsView(),
            new PreferencesView(),
        ];

        this._busy = false;

        for (let page in this.views) {
            let view = this.views[page];

            this.notebook.append_page(view.widget, null);
            this.mode_button.append_text(view.title);
        }

        this.mode_button.connect('changed', Lang.bind(this, function() {
            if (!this._busy) {
                this._busy = true;
                this.notebook.set_current_page(this.mode_button.selected);
                this.notebook.grab_focus();
                this._busy = false;
            }
        }));

        this.notebook.connect('switch-page', Lang.bind(this, function(notebook, page_widget, page_num) {
            if (!this._busy)
                this.mode_button.selected = page_num;
        }));
    },

    set_view: function(name) {
        for (let page in this.views) {
            let view = this.views[page];
            if (view && view.name == name) {
                this.notebook.set_current_page(parseInt(page));
                this.notebook.grab_focus();
                return;
            }
        }
    },

    _onKeyPressEvent: function(widget, event) {
        return false;
    },

    _quit: function() {
        return false;
    },

    showAboutDialog: function() {
        let about = new Gtk.AboutDialog();
        about.title = _("About Pomodoro")

        about.program_name = _("Pomodoro");
        about.comments = _("A simple time management utility.");
        about.logo_icon_name = 'timer-symbolic';
        about.version = Config.PACKAGE_VERSION;
        about.website = Config.PACKAGE_URL;
        about.authors = AUTHORS;
        about.copyright = COPYRIGHTS;
        about.translator_credits = _("translator-credits");
        about.wrap_license = true;
        about.license_type = Gtk.License.GPL_3_0;
        about.license = _("This program is free software: you can \
redistribute it and/or modify it under the terms of the GNU General Public \
License as published by the Free Software Foundation; either version 3 \
of the License, or (at your option) any later version.\n\n\
\
This program is distributed in the hope that it will be useful, but \
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY \
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License \
for more details.\n\n\
\
You should have received a copy of the GNU General Public License along \
with this program; if not, write to the Free Software Foundation, Inc., \
51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA");

        about.modal = true;
        about.transient_for = this.window;

        about.connect('response', function() {
            about.destroy();
        });

        about.present();
    }
});

const View = new Lang.Class({
    Name: 'View',

    name: '',
    title: null,
    widget: null,

    _init: function() {
        this.widget = new Gtk.Box({
            orientation: Gtk.Orientation.VERTICAL,
        });
    }
});

const TimerView = new Lang.Class({
    Name: 'TimerView',
    Extends: View,

    name: 'timer',
    title: _("Timer"),

    _init: function() {
        this.parent();

        let style_context = this.widget.get_style_context();
        style_context.add_class('pomodoro-timer');

        let vbox = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL });

        let alignment = new Gtk.Alignment({
            xalign: 0.5,
            yalign: 0.5,
            xscale: 0.0,
            yscale: 0.0,
            bottom_padding: 50,
        });
        alignment.set_sensitive(true);
        alignment.add(vbox);

        this.timer_label = new Gtk.Label({ label: '00:00' });
        this.timer_label.get_style_context().add_class('label');
        this.timer_label.get_style_context().add_class('text-inset');

        this.description = new Gtk.Label();
        this.description.get_style_context().add_class('timer-description');
        this.description.set_justify(Gtk.Justification.CENTER);
        this.description.set_use_markup(true);
        this.description.set_markup("3rd session in a row, 8th today\n25 minutes to a long break");

        let description_box = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL });
        description_box.pack_start(this.description, true, true, 0);

        let state = new Widgets.ModeButton();
        state.append_text(_("Pomodoro"));
        state.append_text(_("Short Break"));
        state.append_text(_("Long Break"));
        state.relief = Gtk.ReliefStyle.HALF;

        // TODO: Undo button
        // TODO: Interrupt button
        // TODO: Reset button

        let toggle = new Gtk.Switch();
        let toggle_alignment = new Gtk.Alignment({
            xalign: 1.0,
            yalign: 0.5,
            xscale: 0.0,
            top_padding: 30,
            right_padding: 20,
        });
        toggle_alignment.add(toggle);
        this.widget.pack_start(toggle_alignment, false, false, 0);

        vbox.pack_start(this.timer_label, false, false, 0);
        vbox.pack_start(description_box, false, false, 0);
        vbox.pack_start(state, false, false, 25);

        this.widget.pack_start(alignment, true, true, 0);
    }
});

const TasksView = new Lang.Class({
    Name: 'TasksView',
    Extends: View,

    name: 'tasks',
    title: _("Tasks"),
});

const PreferencesView = new Lang.Class({
    Name: 'PreferencesView',
    Extends: View,

    name: 'preferences',
    title: _("Preferences"),

    _init: function() {
        this.parent();

        let label = new Gtk.Label({ label: 'Preferences' });
        this.widget.pack_start(label, true, true, 0);
    }
});

const StatisticsView = new Lang.Class({
    Name: 'StatisticsView',
    Extends: View,

    name: 'statistics',
    title: _("Statistics"),
});
