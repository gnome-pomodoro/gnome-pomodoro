/*
 * Copyright (c) 2013 gnome-pomodoro contributors
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

using GLib;
using Gnome.SessionManager;


namespace Pomodoro
{
    const double TIMER_SCALE_LOWER = 60.0;
    const double TIMER_SCALE_UPPER = 60.0 * 120.0;

    const double LONG_BREAK_INTERVAL_LOWER = 1.0;
    const double LONG_BREAK_INTERVAL_UPPER = 10.0;

    const GLib.SettingsBindFlags BINDING_FLAGS =
                                       GLib.SettingsBindFlags.DEFAULT |
                                       GLib.SettingsBindFlags.GET |
                                       GLib.SettingsBindFlags.SET;

    /**
     * Mapping from settings to keybinding
     */
    public bool get_keybinding_mapping (GLib.Value   value,
                                        GLib.Variant variant,
                                        void*        user_data)
    {
        var accelerators = variant.get_strv ();

        foreach (var accelerator in accelerators)
        {
            value.set_string (accelerator);

            return true;
        }

        value.set_string ("");

        return true;
    }

    /**
     * Mapping from keybinding to settings
     */
    public Variant set_keybinding_mapping (GLib.Value       value,
                                           GLib.VariantType expected_type,
                                           void*            user_data)
    {
        var accelerator = value.get_string ();
        string[] strv = { accelerator };

        return new Variant.strv (strv);
    }

    /**
     * Mapping from settings to file chooser
     */
    public bool get_file_mapping (GLib.Value   value,
                                  GLib.Variant variant,
                                  void*        user_data)
    {
        var uri = variant.get_string ();

        if (uri != "") {
            value.set_object (GLib.File.new_for_uri (uri));
        }
        else {
            value.set_object (null);
        }

        return true;
    }

    /**
     * Mapping from file chooser to settings
     */
    public Variant set_file_mapping (GLib.Value       value,
                                     GLib.VariantType expected_type,
                                     void*            user_data)
    {
        var file = value.get_object () as GLib.File;

        return new Variant.string (file != null
                                   ? file.get_uri () : "");
    }
}


public class Pomodoro.PreferencesDialog : Gtk.ApplicationWindow
{
    private GLib.Settings settings;
    private Gtk.Notebook notebook;

    private Gtk.SizeGroup combo_box_size_group;
    private Gtk.SizeGroup field_size_group;
    private Gtk.Label presence_notice;
    private Gtk.Box vbox;

    public Egg.ListBox contents { get; set; }

    public enum Mode {
        TIMER,
        NOTIFICATION,
        PRESENCE
    }

    private const GLib.SettingsBindFlags SETTINGS_BIND_FLAGS =
                                       GLib.SettingsBindFlags.DEFAULT |
                                       GLib.SettingsBindFlags.GET |
                                       GLib.SettingsBindFlags.SET;

    public PreferencesDialog ()
    {
        this.title = _("Preferences");
        this.set_default_size (380, 500);
        this.set_hide_titlebar_when_maximized (true);
        this.set_destroy_with_parent (true);
        this.set_position (Gtk.WindowPosition.CENTER);

        var application = GLib.Application.get_default () as Pomodoro.Application;
        this.settings = application.settings.get_child ("preferences");

        this.setup ();
    }

    private ModeButton mode_button;
    private Gtk.Toolbar toolbar;

    private void setup ()
    {
        var css_provider = new Gtk.CssProvider ();
        try {
           var css_file = File.new_for_uri ("resource:///org/gnome/pomodoro/gtk-style.css");

           css_provider.load_from_file (css_file);
        }
        catch (Error e) {
            GLib.warning ("Error while loading css file: %s", e.message);
        }

        var context = this.get_style_context ();
        Gtk.StyleContext.add_provider_for_screen (
                                         Gdk.Screen.get_default (),
                                         css_provider,
                                         Gtk.STYLE_PROVIDER_PRIORITY_USER);
        context.add_class ("preferences-dialog");

        this.combo_box_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);
        this.field_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.VERTICAL);

        this.setup_toolbar ();
        this.setup_notebook ();

        this.vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        this.vbox.pack_start (this.toolbar, false, true);
        this.vbox.pack_start (this.notebook, true, true);
        this.vbox.show_all ();
        this.add (this.vbox);
    }


    private void on_mode_changed ()
    {
        this.notebook.page = this.mode_button.selected;
    }

    private void setup_toolbar ()
    {
        this.toolbar = new Pomodoro.Toolbar ();

        this.mode_button = new ModeButton (Gtk.Orientation.HORIZONTAL);
        this.mode_button.changed.connect (this.on_mode_changed);

        var center_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        center_box.pack_start (this.mode_button, true, false, 0);

        var center_item = new Gtk.ToolItem ();
        center_item.set_expand (true);
        center_item.add (center_box);
        this.toolbar.insert (center_item, -1);

        this.toolbar.show_all ();
    }

    private void setup_notebook ()
    {
        this.notebook = new Gtk.Notebook ();
        this.notebook.set_show_tabs (false);
        this.notebook.set_show_border (false);

        this.setup_timer_page ();
        this.setup_notifications_page ();
        this.setup_presence_page ();

        this.notebook.page = Mode.TIMER;
    }

    private void contents_separator_func (ref Gtk.Widget? separator,
                                          Gtk.Widget      child,
                                          Gtk.Widget?     before)
    {
        if (before != null) {
            if (separator == null) {
                separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            }
        }
        else {
            separator = null;
        }
    }

    private Egg.ListBox create_list_box ()
    {
        var list_box = new Egg.ListBox ();
        list_box.set_selection_mode (Gtk.SelectionMode.NONE);
        list_box.set_activate_on_single_click (false);
        list_box.get_style_context ().add_class ("list");
        list_box.set_separator_funcs (this.contents_separator_func);
        list_box.can_focus = false;
        list_box.show ();

        return list_box;
    }

    private Gtk.Container add_page (string label, Gtk.Widget contents)
    {
        var alignment = new Gtk.Alignment (0.5f, 0.0f, 1.0f, 1.0f);
        alignment.set_padding (10, 10, 22, 22);
        alignment.add (contents);
        alignment.show ();

        this.mode_button.add_label (label);
        this.notebook.append_page (alignment, null);

        return alignment as Gtk.Container;
    }

    private Gtk.Widget create_field (string text, Gtk.Widget widget, Gtk.Widget? bottom_widget=null)
    {
        var bin = new Gtk.Alignment (0.0f, 0.0f, 1.0f, 1.0f);
        bin.set_padding (10, 10, 3, 3);

        var label = new Gtk.Label (text);
        label.xalign = 0.0f;
        label.yalign = 0.5f;

        var widget_alignment = new Gtk.Alignment (1.0f, 0.5f, 0.0f, 0.0f);
        widget_alignment.add (widget);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 30);
        hbox.pack_start (label, true, true, 0);
        hbox.pack_start (widget_alignment, false, true, 0);

        if (bottom_widget != null) {
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            vbox.pack_start (hbox, false, true, 0);
            vbox.pack_start (bottom_widget, true, true, 0);

            bin.add (vbox);
        }
        else {
            this.field_size_group.add_widget (widget);

            bin.add (hbox);
        }

        bin.show_all ();

        return bin;
    }

    private Gtk.Widget create_scale_field (string text,
                                           Gtk.Adjustment adjustment)
    {
        var value_label = new Gtk.Label (null);
        var scale = new LogScale (adjustment, 2.0);
        var widget = this.create_field (text, value_label, scale);

        adjustment.value_changed.connect (() => {
            value_label.set_text (format_time ((long) adjustment.value));
        });

        adjustment.value_changed ();

        return widget;
    }

    private void setup_timer_page ()
    {
        var contents = this.create_list_box ();
        this.add_page (_("Timer"), contents);

        var pomodoro_adjustment = new Gtk.Adjustment (
                                       0.0,
                                       TIMER_SCALE_LOWER,
                                       TIMER_SCALE_UPPER,
                                       60.0,
                                       300.0,
                                       0.0);

        var short_break_adjustment = new Gtk.Adjustment (
                                       0.0,
                                       TIMER_SCALE_LOWER,
                                       TIMER_SCALE_UPPER,
                                       60.0,
                                       300.0,
                                       0.0);

        var long_break_adjustment = new Gtk.Adjustment (
                                       0.0,
                                       TIMER_SCALE_LOWER,
                                       TIMER_SCALE_UPPER,
                                       60.0,
                                       300.0,
                                       0.0);

        var long_break_interval_adjustment = new Gtk.Adjustment (
                                       0.0,
                                       LONG_BREAK_INTERVAL_LOWER,
                                       LONG_BREAK_INTERVAL_UPPER,
                                       1.0,
                                       1.0,
                                       0.0);

        var keybinding = new Keybinding ();

        this.settings.bind ("pomodoro-duration",
                            pomodoro_adjustment,
                            "value",
                            SETTINGS_BIND_FLAGS);

        this.settings.bind ("short-break-duration",
                            short_break_adjustment,
                            "value",
                            SETTINGS_BIND_FLAGS);

        this.settings.bind ("long-break-duration",
                            long_break_adjustment,
                            "value",
                            SETTINGS_BIND_FLAGS);

        this.settings.bind ("long-break-interval",
                            long_break_interval_adjustment,
                            "value",
                            SETTINGS_BIND_FLAGS);

        this.settings.bind_with_mapping ("toggle-timer-key",
                                         keybinding,
                                         "accelerator",
                                         SETTINGS_BIND_FLAGS,
                                         get_keybinding_mapping,
                                         set_keybinding_mapping,
                                         null,
                                         null);

        contents.add (this.create_scale_field (_("Pomodoro duration"),
                                               pomodoro_adjustment));

        contents.add (this.create_scale_field (_("Short break duration"),
                                               short_break_adjustment));

        contents.add (this.create_scale_field (_("Long break duration"),
                                               long_break_adjustment));

        var long_break_interval_entry = new Gtk.SpinButton (long_break_interval_adjustment, 1.0, 0);
        long_break_interval_entry.snap_to_ticks = true;
        long_break_interval_entry.update_policy = Gtk.SpinButtonUpdatePolicy.IF_VALID;
        long_break_interval_entry.set_size_request (100, -1);

        /* @translators: You can refer it to number of pomodoros in a cycle */
        contents.add (this.create_field (_("Pomodoros to a long break"),
                                         long_break_interval_entry));

        var toggle_key_button = new Pomodoro.KeybindingButton (keybinding);
        toggle_key_button.show ();

        contents.add (
            this.create_field (_("Shortcut to toggle the timer"), toggle_key_button));

        string[] sounds = {
            _("Clock Ticking"), GLib.Path.build_filename ("file://",
                                                          Config.PACKAGE_DATA_DIR,
                                                          "sounds",
                                                          "clock.ogg"),
            _("Timer Ticking"), GLib.Path.build_filename ("file://",
                                                          Config.PACKAGE_DATA_DIR,
                                                          "sounds",
                                                          "timer.ogg"),
            _("Woodland Birds"), GLib.Path.build_filename ("file://",
                                                           Config.PACKAGE_DATA_DIR,
                                                           "sounds",
                                                           "birds.ogg"),
        };

        var ticking_sound = new Pomodoro.SoundChooserButton ();
        ticking_sound.title = _("Select ticking sound");
        ticking_sound.backend = SoundBackend.GSTREAMER;
        ticking_sound.has_volume_button = true;

        for (var i = 0; i < sounds.length; i += 2)
        {
            ticking_sound.add_bookmark (sounds[i],
                                        File.new_for_uri (sounds[i+1]));
        }

        contents.add (
            this.create_field (_("Ticking sound"), ticking_sound));

        this.settings.bind_with_mapping ("ticking-sound",
                                         ticking_sound,
                                         "file",
                                         SETTINGS_BIND_FLAGS,
                                         Sounds.get_file_mapping,
                                         Sounds.set_file_mapping,
                                         null,
                                         null);

        this.settings.bind ("ticking-sound-volume",
                            ticking_sound,
                            "volume",
                            SETTINGS_BIND_FLAGS);

        this.combo_box_size_group.add_widget (ticking_sound.combo_box);
    }

    private void setup_notifications_page ()
    {
        var contents = this.create_list_box ();
        this.add_page (_("Notifications"), contents);

        var notifications_toggle = new Gtk.Switch ();
        var notifications_field = this.create_field (
                                       _("Screen notifications"),
                                       notifications_toggle);

        var reminders_toggle = new Gtk.Switch ();
        var reminders_field = this.create_field (
                                       _("Remind to take a break"),
                                       reminders_toggle);

        this.settings.bind ("show-screen-notifications",
                            notifications_toggle,
                            "active",
                            SETTINGS_BIND_FLAGS);

        this.settings.bind ("show-reminders",
                            reminders_toggle,
                            "active",
                            SETTINGS_BIND_FLAGS);

        contents.add (notifications_field);
        contents.add (reminders_field);

        string[] sounds = {
            _("Loud bell"), GLib.Path.build_filename ("file://",
                                                      Config.PACKAGE_DATA_DIR,
                                                      "sounds",
                                                      "loud-bell.ogg"),
            _("Bell"), GLib.Path.build_filename ("file://",
                                                 Config.PACKAGE_DATA_DIR,
                                                 "sounds",
                                                 "bell.ogg"),
        };

        var pomodoro_end_sound = new Pomodoro.SoundChooserButton ();
        pomodoro_end_sound.title = _("Select sound for start of break");

        for (var i = 0; i < sounds.length; i += 2)
        {
            pomodoro_end_sound.add_bookmark (sounds[i],
                                             File.new_for_uri (sounds[i+1]));
        }


        var pomodoro_end_sound_field = this.create_field (
                                       _("Start of break sound"),
                                       pomodoro_end_sound);

        var pomodoro_start_sound = new Pomodoro.SoundChooserButton ();
        pomodoro_start_sound.title = _("Select sound for pomodoro start");

        for (var i = 0; i < sounds.length; i += 2)
        {
            pomodoro_start_sound.add_bookmark (sounds[i],
                                               File.new_for_uri (sounds[i+1]));
        }

        var pomodoro_start_sound_field = this.create_field (
                                       _("Pomodoro start sound"),
                                       pomodoro_start_sound);

        this.settings.bind_with_mapping ("pomodoro-end-sound",
                                         pomodoro_end_sound,
                                         "file",
                                         SETTINGS_BIND_FLAGS,
                                         Sounds.get_file_mapping,
                                         Sounds.set_file_mapping,
                                         null,
                                         null);

        this.settings.bind_with_mapping ("pomodoro-start-sound",
                                         pomodoro_start_sound,
                                         "file",
                                         SETTINGS_BIND_FLAGS,
                                         Sounds.get_file_mapping,
                                         Sounds.set_file_mapping,
                                         null,
                                         null);

        contents.add (pomodoro_end_sound_field);
        contents.add (pomodoro_start_sound_field);

        this.combo_box_size_group.add_widget (pomodoro_end_sound.combo_box);
        this.combo_box_size_group.add_widget (pomodoro_start_sound.combo_box);
    }

    private Gtk.ComboBox create_presence_status_combo_box ()
    {
        var combo_box = new Pomodoro.EnumComboBox ();
        combo_box.add_option (PresenceStatus.DEFAULT, "");
        combo_box.add_option (PresenceStatus.AVAILABLE, _("Available"));
        combo_box.add_option (PresenceStatus.BUSY, _("Busy"));

        /* Currently gnome-shell does not handle invisible status properly */
        combo_box.add_option (PresenceStatus.INVISIBLE, _("Invisible"));

        /* Idle status is used by gnome-shell/screensaver,
         * it's not ment to be set by user
         */
        // combo_box.add_option (PresenceStatus.IDLE,
        //                       _("Idle"));

        combo_box.show ();

        return combo_box as Gtk.ComboBox;
    }

    private void setup_presence_page ()
    {
        var contents = this.create_list_box ();
        this.add_page (_("Presence"), contents);

        var pause_when_idle_toggle = new Gtk.Switch ();
        var pause_when_idle_field = this.create_field (
                                       _("Postpone pomodoro when idle"),
                                       pause_when_idle_toggle);

        var pomodoro_presence = this.create_presence_status_combo_box ();
        pomodoro_presence.changed.connect (this.update_presence_notice);

        var pomodoro_presence_field = this.create_field (
                                       _("Status during pomodoro"),
                                       pomodoro_presence);


        var break_presence = this.create_presence_status_combo_box ();
        break_presence.changed.connect (this.update_presence_notice);

        var notice_icon = new Gtk.Image.from_icon_name (
                                       "dialog-warning-symbolic",
                                       Gtk.IconSize.MENU);
        notice_icon.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        notice_icon.show ();

        var notice_label = new Gtk.Label (null);
        notice_label.wrap = true;
        notice_label.wrap_mode = Pango.WrapMode.WORD;
        notice_label.xalign = 0.0f;
        notice_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        notice_label.show ();
        this.presence_notice = notice_label;

        var notice_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        notice_box.no_show_all = true;
        notice_box.pack_start (notice_icon, false, true);
        notice_box.pack_start (notice_label, false, false);

        var notice_alignment = new Gtk.Alignment (0.5f, 0.0f, 0.0f, 0.0f);
        notice_alignment.set_padding (20, 20, 5, 5);
        notice_alignment.add (notice_box);

        var break_presence_field = this.create_field (
                                       _("Status during break"),
                                       break_presence,
                                       notice_alignment);


        this.settings.bind ("pause-when-idle",
                            pause_when_idle_toggle,
                            "active",
                            SETTINGS_BIND_FLAGS);

        this.settings.bind_with_mapping ("presence-during-pomodoro",
                                         pomodoro_presence,
                                         "value",
                                         SETTINGS_BIND_FLAGS,
                                         Presence.get_status_mapping,
                                         Presence.set_status_mapping,
                                         null,
                                         null);


        this.settings.bind_with_mapping ("presence-during-break",
                                         break_presence,
                                         "value",
                                         SETTINGS_BIND_FLAGS,
                                         Presence.get_status_mapping,
                                         Presence.set_status_mapping,
                                         null,
                                         null);

        contents.add (pause_when_idle_field);
        contents.add (pomodoro_presence_field);
        contents.add (break_presence_field);

        this.update_presence_notice ();
    }

    private void update_presence_notice ()
    {
        var presence_during_pomodoro = string_to_presence_status (
                this.settings.get_string ("presence-during-pomodoro"));

        var presence_during_break = string_to_presence_status (
                this.settings.get_string ("presence-during-break"));

        var has_notifications_during_pomodoro =
                (presence_during_pomodoro == PresenceStatus.DEFAULT) ||
                (presence_during_pomodoro == PresenceStatus.AVAILABLE);

        var has_notifications_during_break =
                (presence_during_break == PresenceStatus.DEFAULT) ||
                (presence_during_break == PresenceStatus.AVAILABLE);

        var text = "";

        if (!has_notifications_during_pomodoro && has_notifications_during_break) {
            text = _("System notifications including chat messages will be disabled during pomodoro.");
        }

        if (has_notifications_during_pomodoro && !has_notifications_during_break) {
            text = _("System notifications including chat messages will be disabled during break.");
        }

        if (!has_notifications_during_pomodoro && !has_notifications_during_break) {
            text = _("System notifications including chat messages will be disabled.");
        }

        this.presence_notice.set_text (text);

        if (text != "") {
            this.presence_notice.parent.show ();
        }
        else {
            this.presence_notice.parent.hide ();
        }
    }
}
