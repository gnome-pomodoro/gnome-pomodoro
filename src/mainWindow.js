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
const Signals = imports.signals;
const _ = imports.gettext.gettext;
const ngettext = imports.gettext.ngettext;

const EggListBox = imports.gi.EggListBox;
const Gdk = imports.gi.Gdk;
const GLib = imports.gi.GLib;
const Gtk = imports.gi.Gtk;
const Gio = imports.gi.Gio;
const GObject = imports.gi.GObject;
const Pango = imports.gi.Pango;

const Application = imports.application;
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



// Slider helper functions
const SLIDER_LOWER = 60;
const SLIDER_UPPER = 60*240;
const SLIDER_EXP = 2.0;


function value_to_seconds(value) {
    return SLIDER_LOWER + 60 * Math.floor(
        Math.pow(value, SLIDER_EXP) * (SLIDER_UPPER - SLIDER_LOWER) / 60);
}

function seconds_to_value(seconds) {
    return Math.pow((seconds - SLIDER_LOWER) / (SLIDER_UPPER - SLIDER_LOWER), 1.0 / SLIDER_EXP);
}

function format_time(seconds) {
    let minutes = Math.floor(seconds / 60) % 60;
    let hours = Math.floor(seconds / 3600);
    let text = '';

    if (hours > 0)
        text = ngettext("%d hour", "%d hours", hours).format(hours);

    if (text)
        text += ' ';

    if (minutes > 0)
        text += ngettext("%d minute", "%d minutes", minutes).format(minutes);

    return text;
}

const LogScale = new Lang.Class({
    Name: 'LogScale',
    Extends: Gtk.Scale,

    _init: function(adjustment, value_to_func, value_from_func) {
        this.parent({
            orientation: Gtk.Orientation.HORIZONTAL,
            digits: 0,
            draw_value: false,
            margin_top: 4,
//            value_pos: Gtk.PositionType.TOP,
//            width_request: 250,
            halign: Gtk.Align.FILL
        });
        this.value_to_func = value_to_func;
        this.value_from_func = value_from_func
        this._set_adjustment(adjustment);
    },

    _set_adjustment: function(adjustment) {
        let adjustment_log = new Gtk.Adjustment({
            value: 0.0,
            lower: 0.0,
            upper: 1.0,
            step_increment: 0.0001,
            page_increment: 0.001,
        });

        this.adjustment = adjustment_log;
        this.adjustment.connect('value-changed', Lang.bind(this, function(adjustment_log) {
            adjustment.value = value_to_seconds(adjustment_log.value);
        }));
    },

    add_mark: function(value, position, label) {
        return this.parent(this.value_to_func(value), position, label);
    },

//    vfunc_grab_notify: function(was_grabbed) {
//        if (was_grabbed)
//            log(this.adjustment.value);
//    },

    vfunc_format_value: function(value) {
        return format_time(value);
    }
});

const SectionBox = new Lang.Class({
    Name: 'Section',
    Extends: Gtk.Box,

    _init: function(title) {
        this.parent({
            orientation: Gtk.Orientation.VERTICAL,
            margin_top: 10,
            margin_bottom: 10,
            margin_left: 30,
            margin_right: 30,
        });
        this.get_style_context().add_class('section');

        this.label = new Gtk.Label({
            label: title,
            halign: Gtk.Align.START,
            valign: Gtk.Align.END,
            margin_bottom: 10,
            margin_left: 0,
        });
        this.label.get_style_context().add_class('section-header');

        this.contents = new EggListBox.ListBox({
        });
        this.contents.set_selection_mode(Gtk.SelectionMode.NONE);
        this.contents.set_activate_on_single_click(false);

        this.contents.set_separator_funcs(
            Lang.bind(this, this._list_box_separator_func));

        this.contents.get_style_context().add_class('list');

        this.pack_start(this.label, false, true, 0);
        this.pack_start(this.contents, false, true, 0);
    },

    add_widget: function(widget) {
        this.contents.add(widget);
    },

    add_item: function(title, widget) {
        let item, label, adjustment;

        item = new Gtk.Box({
            orientation: Gtk.Orientation.HORIZONTAL,
            halign: Gtk.Align.FILL,
            margin_top: 3,
            margin_bottom: 3,
            margin_left: 10,
            margin_right: 2,
            height_request: 32,
            app_paintable: true,
        });
        item.get_style_context().add_class('list-item');

        label = new Gtk.Label({
            label: title,
            halign: Gtk.Align.START,
            valign: Gtk.Align.CENTER,
        });
        item.pack_start(label, true, true, 0);

        widget.halign = Gtk.Align.END;
        widget.valign = Gtk.Align.CENTER;
        item.pack_start(widget, false, false, 0);

        this.add_widget(item);
    },

    add_scale_item: function(title, adjustment) {
        let item, label;

        item = new Gtk.Box({
            orientation: Gtk.Orientation.VERTICAL,
            halign: Gtk.Align.FILL,
            margin_top: 8,
            margin_bottom: 2,
            margin_left: 8,
            margin_right: 8,
        });
        item.get_style_context().add_class('list-item');

        let hbox = new Gtk.Box({
            orientation: Gtk.Orientation.HORIZONTAL,
            halign: Gtk.Align.FILL,
        });
        item.pack_start(hbox, false, true, 0);

        label = new Gtk.Label({
            label: title,
            halign: Gtk.Align.START,
            valign: Gtk.Align.CENTER,
            margin_left: 2,
        });
        hbox.pack_start(label, true, true, 0);

        let value_label = new Gtk.Label({
            label: format_time(adjustment.value),
            halign: Gtk.Align.START,
            valign: Gtk.Align.CENTER,
            margin_right: 2,
        });
        hbox.pack_start(value_label, false, false, 0);

        let scale = new LogScale(adjustment,
                                 seconds_to_value,
                                 value_to_seconds);

        scale.add_mark(60, Gtk.PositionType.BOTTOM, format_time(60));
        scale.add_mark(60*25, Gtk.PositionType.BOTTOM, format_time(60*25));
        scale.add_mark(60*120, Gtk.PositionType.BOTTOM, format_time(60*120));

        item.pack_start(scale, false, false, 0);

        adjustment.connect('value-changed', Lang.bind(this, function(adjustment) {
            value_label.set_text(format_time(adjustment.value));
        }));

        this.add_widget(item);
    },

    add_toggle_item: function(title, active) {
        let widget = new Gtk.Switch({
            active: active
        });
        this.add_item(title, widget);
    },

    add_combo_box_item: function(title, options, active_id) {
        let widget = new Gtk.ComboBoxText({});
        let position = 0;
        for (let id in options) {
            widget.insert(position, id, options[id]);
            position += 1;
        }
        widget.set_active_id(active_id);
        this.add_item(title, widget);
    },

    add_sound_chooser_item: function(title, options, active_id) {
        let hbox = new Gtk.Box({
            orientation: Gtk.Orientation.HORIZONTAL,
            halign: Gtk.Align.FILL,
            valign: Gtk.Align.FILL,
            spacing: 4,
        });

        let widget = new Gtk.ComboBoxText({});
        hbox.pack_start(widget, true, true, 0);

        let icon = Gio.ThemedIcon.new_with_default_fallbacks('media-playback-start-symbolic');
        let image = new Gtk.Image();
        image.set_from_gicon(icon, Gtk.IconSize.MENU);

        let play_button = new Gtk.ToggleButton();
        play_button.set_alignment(0.5, 0.5);
        play_button.add(image);
//        hbox.pack_start(play_button, false, true, 0);

        let position = 0;
        for (let id in options) {
            widget.insert(position, id, options[id]);
            position += 1;
        }
        widget.set_active_id(active_id);
        this.add_item(title, hbox);
    },

    _list_box_separator_func: function(child, before) {
        return new Gtk.Separator({ orientation: Gtk.Orientation.HORIZONTAL });
    }
});

const PreferencesView = new Lang.Class({
    Name: 'PreferencesView',
    Extends: View,

    name: 'preferences',
    title: _("Preferences"),

    _init: function() {
        let scrolled_window, vbox, timer_section, notifications_section, sounds_section, presence_section;

        this.parent();

        scrolled_window = new Gtk.ScrolledWindow({
            hscrollbar_policy: Gtk.PolicyType.NEVER,
            vscrollbar_policy: Gtk.PolicyType.AUTOMATIC,
        });
        this.widget.pack_start(scrolled_window, true, true, 0);

        let settings = Application.get_default().settings.get_child('preferences');
        let timer_settings = settings.get_child('timer');

        vbox = new Gtk.Box({
            orientation: Gtk.Orientation.VERTICAL,
            width_request: 550,
            halign: Gtk.Align.CENTER,
            valign: Gtk.Align.START,
            margin_bottom: 24,
        });
        scrolled_window.add_with_viewport(vbox);

        let adjustment, widget;

        this.pomodoro_adjustment = new Gtk.Adjustment({
            value: timer_settings.get_uint('pomodoro-time'),
            lower: SLIDER_LOWER,
            upper: SLIDER_UPPER,
            step_increment: 60.0,
            page_increment: 300.0,
        });
//        this._pomodoroTimeSlider.connect('drag-end', Lang.bind(this, this._onPomodoroTimeChanged));
//        this._pomodoroTimeSlider.actor.connect('scroll-event', Lang.bind(this, this._onPomodoroTimeChanged));
        this.pomodoro_adjustment.connect('value-changed', Lang.bind(this, function(adjustment) {
            timer_settings.set_uint('pomodoro-time', parseInt(adjustment.value))
        }));

        this.short_break_adjustment = new Gtk.Adjustment({
            value: timer_settings.get_uint('short-pause-time'),
            lower: SLIDER_LOWER,
            upper: SLIDER_UPPER,
            step_increment: 60.0,
            page_increment: 300.0,
        });
        this.pomodoro_adjustment.connect('value-changed', Lang.bind(this, function(adjustment) {
            timer_settings.set_uint('short-pause-time', parseInt(adjustment.value))
        }));

        this.long_break_adjustment = new Gtk.Adjustment({
            value: timer_settings.get_uint('long-pause-time'),
            lower: SLIDER_LOWER,
            upper: SLIDER_UPPER,
            step_increment: 60.0,
            page_increment: 300.0,
        });
        this.pomodoro_adjustment.connect('value-changed', Lang.bind(this, function(adjustment) {
            timer_settings.set_uint('long-pause-time', parseInt(adjustment.value))
        }));

        let status_options = {
            '': _("Do not change"),
            'available': _("Available"),
            'away': _("Away"),
            'busy': _("Busy")
        };

        let notification_sound_options = {
            '': _("Silent"),
            'default': _("Default"),
        };

        let background_sound_options = {
            '': _("Silent"),
            'cafe': _("Cafe"),
        };

        timer_section = new SectionBox(_("Timer"));
        timer_section.add_scale_item(_("Pomodoro duration"), this.pomodoro_adjustment);
        timer_section.add_scale_item(_("Short break duration"), this.short_break_adjustment);
        timer_section.add_scale_item(_("Long break duration"), this.long_break_adjustment);

        notifications_section = new SectionBox(_("Notifications"));
        notifications_section.add_toggle_item(_("Show screen notifications"), true);
        notifications_section.add_toggle_item(_("Remind about a break"), true);

        sounds_section = new SectionBox(_("Sounds"));
        sounds_section.add_sound_chooser_item(_("Background sound"), background_sound_options, 'cafe')
        sounds_section.add_sound_chooser_item(_("Pomodoro end sound"), notification_sound_options, '')
        sounds_section.add_sound_chooser_item(_("Pomodoro start sound"), notification_sound_options, 'default')

        presence_section = new SectionBox(_("Presence"));
        presence_section.add_toggle_item(_("Delay pomodoro when idle"), true);
        presence_section.add_toggle_item(_("Delay system notifications"), true);
//        presence_section.add_toggle_item(_("Change presence status"), true);
        presence_section.add_combo_box_item(_("Status during pomodoro"), status_options, '');
        presence_section.add_combo_box_item(_("Status during break"), status_options, '');
//        presence_section.add_toggle_item(_("Change status to busy during session"), true);
//        presence_section.add_toggle_item(_("Change status to away during break"), true);

        vbox.pack_start(timer_section, false, true, 0);
        vbox.pack_start(presence_section, false, true, 0);
        vbox.pack_start(notifications_section, false, true, 0);
        vbox.pack_start(sounds_section, false, true, 0);
    },
});

const StatisticsView = new Lang.Class({
    Name: 'StatisticsView',
    Extends: View,

    name: 'statistics',
    title: _("Statistics"),
});
