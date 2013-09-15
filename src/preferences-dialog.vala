/*
 * Copyright (c) 2013 gnome-shell-pomodoro contributors
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

namespace Pomodoro
{
    const double TIMER_SCALE_LOWER = 60.0;
    const double TIMER_SCALE_UPPER = 60.0 * 120.0;

    const GLib.SettingsBindFlags BINDING_FLAGS =
                            GLib.SettingsBindFlags.DEFAULT |
                            GLib.SettingsBindFlags.GET |
                            GLib.SettingsBindFlags.SET;

    /* mapping from settings to keybinding */
    public bool get_keybinding_mapping (GLib.Value value,
                                        GLib.Variant variant,
                                        void* user_data)
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

    /* mapping from keybinding to settings */
    public Variant set_keybinding_mapping (GLib.Value value,
                                           GLib.VariantType expected_type,
                                           void* user_data)
    {
        var accelerator = value.get_string ();
        //if (accelerator != "") {
        string[] strv = { accelerator };
        return new Variant.strv (strv);
        //}

        //return new Variant.strv (""); // TODO: why we can't pass null?
    }

    /* mapping from settings to file chooser */
    public bool get_file_mapping (GLib.Value value,
                                  GLib.Variant variant,
                                  void* user_data)
    {
        value.set_object (GLib.File.new_for_uri (variant.get_string ()));
        return true;
    }

    /* mapping from keybinding to file chooser */
    public Variant set_file_mapping (GLib.Value value,
                                     GLib.VariantType expected_type,
                                     void* user_data)
    {
        var file = value.get_object () as GLib.File;
        return new Variant.string (file != null
                                   ? file.get_uri () : "");
    }
}


public class Pomodoro.PreferencesDialog : Gtk.ApplicationWindow
{
    private GLib.Settings settings;
    private GLib.Settings timer_settings;
    private GLib.Settings keybindings_settings;
    private GLib.Settings notifications_settings;
    private GLib.Settings sounds_settings;
    private GLib.Settings presence_settings;
    private Gtk.Notebook  notebook;

    private Gtk.Label presence_notice;

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

        var application = GLib.Application.get_default() as Pomodoro.Application;
        this.settings = application.settings.get_child("preferences");
        this.timer_settings = this.settings.get_child ("timer");
        this.keybindings_settings = this.settings.get_child ("keybindings");
        this.notifications_settings = this.settings.get_child ("notifications");
        this.sounds_settings = this.settings.get_child ("sounds");
        this.presence_settings = this.settings.get_child ("presence");

        this.setup();
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
        context.add_provider_for_screen (Gdk.Screen.get_default(),
                                         css_provider,
                                         Gtk.STYLE_PROVIDER_PRIORITY_USER);
        context.add_class ("preferences-dialog");

        this.combo_box_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);

        this.notebook = new Gtk.Notebook ();
        this.notebook.set_show_tabs (false);
        this.notebook.set_show_border (false);

        this.setup_toolbar ();

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.pack_start (this.toolbar, false, true);
        vbox.pack_start (this.notebook, true, true);
        vbox.show_all ();
        this.add (vbox);

        this.setup_timer_page ();
        this.setup_notifications_page ();
        this.setup_presence_page ();

        this.mode_button.changed.connect (this.on_mode_changed);

        this.notebook.page = Mode.TIMER;
    }


    private void on_mode_changed ()
    {
        this.notebook.page = this.mode_button.selected;
    }

    private void setup_toolbar ()
    {
        this.toolbar = new Pomodoro.Toolbar();

        this.mode_button = new ModeButton (Gtk.Orientation.HORIZONTAL);

        var center_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        center_box.pack_start (this.mode_button, true, false, 0);

        var center_item = new Gtk.ToolItem ();
        center_item.set_expand (true);
        center_item.add (center_box);
        this.toolbar.insert (center_item, -1);

        this.toolbar.show_all ();
    }

    private void contents_separator_func (ref Gtk.Widget? separator,
                                          Gtk.Widget      child,
                                          Gtk.Widget?     before)
    {
        var show_separator = true;

        if (before == null)
            show_separator = false;

        if (show_separator)
        {
            if (separator == null)
                separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        }
        else
        {
            separator = null;
        }
    }

    private Gtk.Widget create_section_label (string text)
    {
        var label = new Gtk.Label (text);
        label.halign = Gtk.Align.START;
        label.valign = Gtk.Align.END;
        label.get_style_context().add_class (Gtk.STYLE_CLASS_HEADER);
        label.show ();

        return label;
    }

    private Gtk.Widget create_section_separator ()
    {
        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        separator.show ();

        return separator;
    }

    private Egg.ListBox create_list_box ()
    {
        var list_box = new Egg.ListBox();
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
        //var scrolled_window = new Gtk.ScrolledWindow (null, null);
        //scrolled_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
        //scrolled_window.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;

        var alignment = new Gtk.Alignment (0.5f, 0.0f, 1.0f, 1.0f);
        alignment.set_padding (10, 10, 22, 22);
        //scrolled_window.add (alignment);
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
        bin.get_style_context ().add_class ("list-item");

        var label = new Gtk.Label (text);
        label.xalign = 0.0f;
        label.yalign = 0.5f;

        var widget_alignment = new Gtk.Alignment (1.0f, 0.5f, 0.0f, 0.0f);
        widget_alignment.add (widget);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 30);
        hbox.pack_start (label, true, true, 0);
        hbox.pack_start (widget_alignment, false, true, 0);

        if (bottom_widget != null)
        {
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            vbox.pack_start (hbox, false, true, 0);
            vbox.pack_start (bottom_widget, true, true, 0);

            bin.add (vbox);
        }
        else
        {        
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
        var page = this.add_page (_("Timer"), contents);

        var pomodoro_adjustment = new Gtk.Adjustment (
            0.0,
            TIMER_SCALE_LOWER,
            TIMER_SCALE_UPPER,
            60.0,
            300.0,
            0.0);

        var short_break_adjustment = new Gtk.Adjustment(
            0.0,
            TIMER_SCALE_LOWER,
            TIMER_SCALE_UPPER,
            60.0,
            300.0,
            0.0);

        var long_break_adjustment = new Gtk.Adjustment(
            0.0,
            TIMER_SCALE_LOWER,
            TIMER_SCALE_UPPER,
            60.0,
            300.0,
            0.0);

        var keybinding = new Keybinding ();

        this.timer_settings.bind ("pomodoro-time",
                                  pomodoro_adjustment,
                                  "value",
                                  SETTINGS_BIND_FLAGS);

        this.timer_settings.bind ("short-pause-time",
                                  short_break_adjustment,
                                  "value",
                                  SETTINGS_BIND_FLAGS);

        this.timer_settings.bind ("long-pause-time",
                                  long_break_adjustment,
                                  "value",
                                  SETTINGS_BIND_FLAGS);

        //this.timer_settings.bind ("session-limit",
        //                          session_limit_adjustment,
        //                          "value",
        //                          binding_flags);

        this.keybindings_settings.bind_with_mapping ("toggle-timer",
                                                     keybinding,
                                                     "accelerator",
                                                     SETTINGS_BIND_FLAGS,
                                                     get_keybinding_mapping, 
                                                     set_keybinding_mapping,
                                                     null,
                                                     null);
        //this.timer_settings.delay ();
        //this.timer_settings.apply ();

        contents.add (this.create_scale_field (_("Pomodoro duration"), pomodoro_adjustment));

        contents.add (this.create_scale_field (_("Short break duration"), short_break_adjustment));

        contents.add (this.create_scale_field (_("Long break duration"), long_break_adjustment));

        var toggle_key_button = new Pomodoro.KeybindingButton (keybinding);
        toggle_key_button.show ();

        contents.add (
            this.create_field (_("Shortcut to toggle timer"), toggle_key_button));

        var background_sound = new Pomodoro.SoundChooserButton ();
        background_sound.title = _("Select background sound");
        background_sound.backend = SoundBackend.GSTREAMER;
        background_sound.has_volume_button = true;

        contents.add (
            this.create_field (_("Background sound"), background_sound));

        this.sounds_settings.bind_with_mapping ("background-sound",
                                                background_sound,
                                                "file",
                                                SETTINGS_BIND_FLAGS,
                                                Sounds.get_file_mapping,
                                                Sounds.set_file_mapping,
                                                null,
                                                null);

        this.sounds_settings.bind ("background-sound-volume",
                                   background_sound,
                                   "volume",
                                   SETTINGS_BIND_FLAGS);

        this.combo_box_size_group.add_widget (background_sound.combo_box);
    }

    private Gtk.SizeGroup combo_box_size_group;

    private void setup_notifications_page ()
    {
// TODO
//        let status_options = {
//            '': _("Do not change"),
//            'available': _("Available"),
//            'away': _("Away"),
//            'busy': _("Busy")
//        };

//        let notification_sound_options = {
//            '': _("Silent"),
//            'default': _("Default"),
//        };

//        let background_sound_options = {
//            '': _("Silent"),
//            'cafe': _("Cafe"),
//        };

        var contents = this.create_list_box ();
        var page = this.add_page (_("Notifications"), contents);

        var notifications_toggle = new Gtk.Switch ();
        contents.add (
            this.create_field (_("Screen notifications"), notifications_toggle));

        var reminders_toggle = new Gtk.Switch ();
        contents.add (
            this.create_field (_("Break reminder"), reminders_toggle));

        this.notifications_settings.bind ("screen-notifications",
                                          notifications_toggle,
                                          "active",
                                          SETTINGS_BIND_FLAGS);

        this.notifications_settings.bind ("reminders",
                                          reminders_toggle,
                                          "active",
                                          SETTINGS_BIND_FLAGS);

        /* Sound notifications */

        var default_sound_file_uri = GLib.Path.build_filename (
                "file://",
                Config.PACKAGE_DATA_DIR,
                "sounds",
                "pomodoro-start.wav");

        var pomodoro_end_sound = new Pomodoro.SoundChooserButton ();
        pomodoro_end_sound.title = _("Select sound for start of break");
        contents.add (
            this.create_field (_("Start of break sound"), pomodoro_end_sound));

        pomodoro_end_sound.add_bookmark (
                _("Bell"),
                File.new_for_uri (default_sound_file_uri));

        var pomodoro_start_sound = new Pomodoro.SoundChooserButton();
        pomodoro_start_sound.title = _("Select sound for pomodoro start");
        contents.add (
            this.create_field (_("Pomodoro start sound"), pomodoro_start_sound));

        pomodoro_start_sound.add_bookmark (
                _("Bell"),
                File.new_for_uri (default_sound_file_uri));

        this.sounds_settings.bind_with_mapping ("pomodoro-end-sound",
                                                pomodoro_end_sound,
                                                "file",
                                                SETTINGS_BIND_FLAGS,
                                                Sounds.get_file_mapping,
                                                Sounds.set_file_mapping,
                                                null,
                                                null);

        this.sounds_settings.bind_with_mapping ("pomodoro-start-sound",
                                                pomodoro_start_sound,
                                                "file",
                                                SETTINGS_BIND_FLAGS,
                                                Sounds.get_file_mapping,
                                                Sounds.set_file_mapping,
                                                null,
                                                null);

        this.combo_box_size_group.add_widget (pomodoro_end_sound.combo_box);
        this.combo_box_size_group.add_widget (pomodoro_start_sound.combo_box);
    }

    private Gtk.ComboBox create_presence_status_combo_box ()
    {
        var combo_box = new Pomodoro.EnumComboBox ();

        combo_box.add_option (Gnome.SessionManager.PresenceStatus.DEFAULT,
                              "");

        combo_box.add_option (Gnome.SessionManager.PresenceStatus.AVAILABLE,
                              _("Available"));

        combo_box.add_option (Gnome.SessionManager.PresenceStatus.BUSY,
                              _("Busy"));

        // Currently gnome-shell does not handle invisible status properly
        combo_box.add_option (Gnome.SessionManager.PresenceStatus.INVISIBLE,
                              _("Invisible"));

        // Idle status is used by gnome-shell/screensaver,
        // it's not ment to be set by user
        // combo_box.add_option (Gnome.SessionManager.PresenceStatus.IDLE,
        //                       _("Idle"));

        combo_box.show ();

        return combo_box as Gtk.ComboBox;
    }

    private void setup_presence_page ()
    {
        var contents = this.create_list_box ();
        var page = this.add_page (_("Presence"), contents);

        var pause_when_idle_toggle = new Gtk.Switch ();
        this.presence_settings.bind ("pause-when-idle",
                                     pause_when_idle_toggle,
                                     "active",
                                     SETTINGS_BIND_FLAGS);
        contents.add (this.create_field (_("Postpone pomodoro when idle"),
                                         pause_when_idle_toggle));


        var pomodoro_presence = this.create_presence_status_combo_box ();
        this.presence_settings.bind_with_mapping ("presence-during-pomodoro",
                                                  pomodoro_presence,
                                                  "value",
                                                  SETTINGS_BIND_FLAGS,
                                                  Presence.get_status_mapping,
                                                  Presence.set_status_mapping,
                                                  null,
                                                  null);
        contents.add (this.create_field (_("Status during pomodoro"),
                                         pomodoro_presence));

        var last_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
        contents.add (last_box);

        var break_presence = this.create_presence_status_combo_box ();
        this.presence_settings.bind_with_mapping ("presence-during-break",
                                                  break_presence,
                                                  "value",
                                                  SETTINGS_BIND_FLAGS,
                                                  Presence.get_status_mapping,
                                                  Presence.set_status_mapping,
                                                  null,
                                                  null);
        last_box.pack_start (this.create_field (_("Status during break"),
                                                break_presence), false, true);



        var notice_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        var notice_label = new Gtk.Label (null);
        notice_label.wrap = true;
        notice_label.wrap_mode = Pango.WrapMode.WORD;
        notice_label.xalign = 0.0f;
        notice_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        this.presence_notice = notice_label;

        var notice_icon = new Gtk.Image.from_icon_name ("dialog-warning-symbolic",
                                                        Gtk.IconSize.MENU);
        notice_icon.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        notice_box.pack_start (notice_icon, false, true);
        notice_box.pack_start (notice_label, false, false);


        var notice_alignment = new Gtk.Alignment (0.5f, 0.0f, 0.0f, 0.0f);
        notice_alignment.set_padding (10, 10, 5, 5);
        notice_alignment.add (notice_box);

        last_box.pack_start (notice_alignment, false, true);
        last_box.show_all ();


        pomodoro_presence.changed.connect (this.update_presence_notice);
        break_presence.changed.connect (this.update_presence_notice);

        this.update_presence_notice ();
    }

    private void update_presence_notice ()
    {
        var presence_during_pomodoro = Gnome.SessionManager.string_to_presence_status (
                    this.presence_settings.get_string ("presence-during-pomodoro"));

        var presence_during_break = Gnome.SessionManager.string_to_presence_status (
                    this.presence_settings.get_string ("presence-during-break"));

        var has_notifications_during_pomodoro = (
            presence_during_pomodoro == Gnome.SessionManager.PresenceStatus.DEFAULT ||
            presence_during_pomodoro == Gnome.SessionManager.PresenceStatus.AVAILABLE);

        var has_notifications_during_break = (
            presence_during_break == Gnome.SessionManager.PresenceStatus.DEFAULT ||
            presence_during_break == Gnome.SessionManager.PresenceStatus.AVAILABLE);

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

        if (text != "") {
            this.presence_notice.set_text (text);
            this.presence_notice.parent.show ();
        }
        else {
            this.presence_notice.parent.hide ();
        }
    }
}

