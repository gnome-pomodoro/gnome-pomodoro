/*
 * Copyright (c) 2013,2014 gnome-pomodoro contributors
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
using Gnome.SessionManager;


namespace Pomodoro
{
    const double TIMER_SCALE_LOWER = 60.0;
    const double TIMER_SCALE_UPPER = 60.0 * 120.0;

    const double LONG_BREAK_INTERVAL_LOWER = 1.0;
    const double LONG_BREAK_INTERVAL_UPPER = 10.0;

    private const GLib.SettingsBindFlags SETTINGS_BIND_FLAGS =
                                       GLib.SettingsBindFlags.DEFAULT |
                                       GLib.SettingsBindFlags.GET |
                                       GLib.SettingsBindFlags.SET;

    public enum IndicatorType {
        TEXT = 0,
        TEXT_SMALL = 1,
        ICON = 2
    }

    public string indicator_type_to_string (IndicatorType indicator_type)
    {
        switch (indicator_type)
        {
            case IndicatorType.TEXT:
                return "text";

            case IndicatorType.TEXT_SMALL:
                return "text-small";

            case IndicatorType.ICON:
                return "icon";
        }

        return "";
    }

    public IndicatorType string_to_indicator_type (string indicator_type)
    {
        switch (indicator_type)
        {
            case "text":
                return IndicatorType.TEXT;

            case "text-small":
                return IndicatorType.TEXT_SMALL;

            case "icon":
                return IndicatorType.ICON;
        }

        return IndicatorType.TEXT;
    }

    /**
     * Mapping from settings to presence combobox
     */
    public bool get_indicator_type_mapping (GLib.Value   value,
                                            GLib.Variant variant,
                                            void*        user_data)
    {
        var status = string_to_indicator_type (variant.get_string ());

        value.set_int ((int) status);

        return true;
    }

    /**
     * Mapping from presence combobox to settings
     */
    [CCode (has_target = false)]
    public Variant set_indicator_type_mapping (GLib.Value       value,
                                               GLib.VariantType expected_type,
                                               void*            user_data)
    {
        var indicator_type = (IndicatorType) value.get_int ();

        return new Variant.string (indicator_type_to_string (indicator_type));
    }

    /**
     * Mapping from settings to keybinding
     */
    private bool get_keybinding_mapping (GLib.Value   value,
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
    [CCode (has_target = false)]
    private Variant set_keybinding_mapping (GLib.Value       value,
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
    private bool get_file_mapping (GLib.Value   value,
                                   GLib.Variant variant,
                                   void*        user_data)
    {
        var uri = variant.get_string ();

        if (uri != "") {
            value.set_object (GLib.File.new_for_uri (uri));
        }
        else {
            value.unset ();
        }

        return true;
    }

    /**
     * Mapping from file chooser to settings
     */
    [CCode (has_target = false)]
    private Variant set_file_mapping (GLib.Value       value,
                                      GLib.VariantType expected_type,
                                      void*            user_data)
    {
        var file = value.get_object () as GLib.File;

        return new Variant.string (file != null
                                   ? file.get_uri () : "");
    }
}


namespace Pomodoro
{
    private void list_box_separator_func (Gtk.ListBoxRow  row,
                                          Gtk.ListBoxRow? before)
    {
        if (before != null)
        {
            var current = row.get_header ();

            if (current == null)
            {
                current = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
                current.show ();
                row.set_header (current);
            }
        }
    }

    private Gtk.ListBoxRow list_box_create_field (string      text,
                                                  Gtk.Widget? widget,
                                                  Gtk.Widget? bottom_widget=null)
    {
        var row = new Gtk.ListBoxRow ();

        var bin = new Gtk.Alignment (0.0f, 0.0f, 1.0f, 1.0f);
        bin.set_padding (10, 10, 20, 20);

        var label = new Gtk.Label (text);
        label.set_alignment (0.0f, 0.5f);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 30);
        hbox.pack_start (label, true, true, 0);

        if (widget != null) {
            var widget_alignment = new Gtk.Alignment (1.0f, 0.5f, 0.0f, 0.0f);
            widget_alignment.add (widget);
            hbox.pack_start (widget_alignment, false, true, 0);
        }

        if (bottom_widget != null) {
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            vbox.pack_start (hbox, false, true, 0);
            vbox.pack_start (bottom_widget, true, true, 0);

            bin.add (vbox);
        }
        else {
            bin.add (hbox);
        }

        row.add (bin);
        row.show_all ();

        return row;
    }

    private Gtk.Widget list_box_create_log_scale_field (string         text,
                                             Gtk.Adjustment adjustment)
    {
        var value_label = new Gtk.Label (null);
        value_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var scale = new LogScale (adjustment, 2.0);
        var widget = list_box_create_field (text, value_label, scale);

        adjustment.value_changed.connect (() => {
            value_label.set_text (format_time ((long) adjustment.value));
        });

        adjustment.value_changed ();

        return widget;
    }
}


[Compact]
public struct Pomodoro.SoundInfo
{
    public string name;
    public string uri;

    public string get_absolute_uri () {
        return GLib.Path.build_filename ("file://",
                                         Config.PACKAGE_DATA_DIR,
                                         "sounds",
                                         this.uri);
    }
}


public class Pomodoro.PreferencesDialog : Gtk.ApplicationWindow
{
    private GLib.Settings settings;
    private Gtk.HeaderBar header_bar;
    private Gtk.SizeGroup combo_box_size_group;
    private Gtk.SizeGroup field_size_group;
    private Gtk.Box box;

    private Pomodoro.SoundInfo[] timer_sounds = {
        Pomodoro.SoundInfo() {
            name = _("Clock Ticking"),
            uri = "clock.ogg"
        },
        Pomodoro.SoundInfo() {
            name = _("Timer Ticking"),
            uri = "timer.ogg"
        },
        Pomodoro.SoundInfo() {
            name = _("Woodland Birds"),
            uri = "birds.ogg"
        }
    };

    private Pomodoro.SoundInfo[] notification_sounds = {
        Pomodoro.SoundInfo() {
            name = _("Loud bell"),
            uri = "loud-bell.ogg"
        },
        Pomodoro.SoundInfo() {
            name = _("Bell"),
            uri = "bell.ogg"
        }
    };

    public PreferencesDialog ()
    {
        this.title = _("Preferences");

        var geometry = Gdk.Geometry ();
        geometry.min_width = 600;
        geometry.max_width = 600;
        geometry.min_height = 300;
        geometry.max_height = 1500;

        var geometry_hints = Gdk.WindowHints.MAX_SIZE |
                             Gdk.WindowHints.MIN_SIZE;

        this.set_geometry_hints (this,
                                 geometry,
                                 geometry_hints);

        this.set_default_size (-1, 760);

        this.set_destroy_with_parent (false);

        /* It's not precisely a dialog window, but we want to disable maximize
         * button. We could use set_resizable(false), but then user looses
         * ability to resize it if needed.
         */
        this.set_type_hint (Gdk.WindowTypeHint.DIALOG);

        this.set_startup_id ("gnome-pomodoro-preferences");
    }

    construct
    {
        this.settings = Pomodoro.get_settings ().get_child ("preferences");

        var context = this.get_style_context ();
        context.add_class ("preferences-dialog");

        this.header_bar = new Gtk.HeaderBar ();
        this.header_bar.show_close_button = true;
        this.header_bar.title = this.title;
        this.header_bar.show_all ();
        this.set_titlebar (this.header_bar);

        this.combo_box_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);
        this.field_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.VERTICAL);

        this.box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

        var alignment = new Gtk.Alignment (0.5f, 0.0f, 1.0f, 0.0f);
        alignment.set_padding (20, 16, 40, 40);
        alignment.add (this.box);
        alignment.show ();

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.set_policy (Gtk.PolicyType.NEVER,
                                    Gtk.PolicyType.AUTOMATIC);
        //scrolled_window.set_min_content_height (100);
        //scrolled_window.set_min_content_width (550);
//        scrolled_window.set_size_request (550, 300);
        scrolled_window.add (alignment);
        scrolled_window.show ();

//        var indicator_type_label = new Gtk.Label (_("Show indicator in top panel"));
//        indicator_type_label.set_alignment (0.0f, 0.5f);
//        var indicator_type_combo_box = this.create_indicator_type_combo_box ();

//        var indicator_type_hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
//        indicator_type_hbox.pack_start (indicator_type_label, true, true);
//        indicator_type_hbox.pack_start (indicator_type_combo_box, false, false);
//        this.box.pack_start (indicator_type_hbox);

//        this.settings.bind_with_mapping ("indicator-type",
//                                         indicator_type_combo_box,
//                                         "value",
//                                         SETTINGS_BIND_FLAGS,
//                                         (SettingsBindGetMappingShared) get_indicator_type_mapping,
//                                         (SettingsBindSetMappingShared) set_indicator_type_mapping,
//                                         null,
//                                         null);

        this.add_timer_section ();
        this.add_notifications_section ();
        this.add_presence_section ();

        this.box.show_all ();

        this.add (scrolled_window);
    }

    private void create_section (string          title,
                                 out Gtk.Box     vbox,
                                 out Gtk.ListBox list_box)
    {
        var label = new Gtk.Label ("<b>%s</b>".printf (title));
        label.set_use_markup (true);
        label.set_alignment (0.0f, 0.5f);
        label.set_padding (6, 0);
        label.set_margin_bottom (6);
        label.show ();

        list_box = new Gtk.ListBox ();
        list_box.set_selection_mode (Gtk.SelectionMode.NONE);
        list_box.set_activate_on_single_click (false);
        list_box.set_header_func (list_box_separator_func);
        list_box.can_focus = false;
        list_box.show ();

        var frame = new Gtk.Frame (null);
        frame.set_shadow_type (Gtk.ShadowType.IN);
        frame.set_margin_bottom (24);
        frame.add (list_box);
        frame.show ();

        vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.pack_start (label, false, false, 0);
        vbox.pack_start (frame, true, true, 0);
        vbox.show ();
    }

    private void add_timer_section ()
    {
        Gtk.Box vbox;
        Gtk.ListBox list_box;

        create_section (_("Timer"), out vbox, out list_box);

        this.box.pack_start (vbox);

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
                                         (SettingsBindGetMappingShared) get_keybinding_mapping,
                                         (SettingsBindSetMappingShared) set_keybinding_mapping,
                                         null,
                                         null);

        var pomodoro_duration_field = list_box_create_log_scale_field (
                                         _("Pomodoro duration"),
                                         pomodoro_adjustment);

        var short_break_duration_field = list_box_create_log_scale_field (
                                         _("Short break duration"),
                                         short_break_adjustment);

        var long_break_duration_field = list_box_create_log_scale_field (
                                         _("Long break duration"),
                                         long_break_adjustment);

        var long_break_interval_entry = new Gtk.SpinButton (long_break_interval_adjustment, 1.0, 0);
        long_break_interval_entry.snap_to_ticks = true;
        long_break_interval_entry.update_policy = Gtk.SpinButtonUpdatePolicy.IF_VALID;
        long_break_interval_entry.set_size_request (100, -1);

        /* @translators: You can refer it to number of pomodoros in a cycle */
        var long_break_interval_field = list_box_create_field (
                                         _("Pomodoros to a long break"),
                                         long_break_interval_entry);

        var toggle_key_button = new Pomodoro.KeybindingButton (keybinding);
        var toggle_key_field = list_box_create_field (
                                       _("Shortcut to toggle the timer"),
                                       toggle_key_button);

        var indicator_type_combo_box = this.create_indicator_type_combo_box ();
        var indicator_type_field = list_box_create_field (
                                       _("Indicator appearance"),
                                       indicator_type_combo_box);

        this.settings.bind_with_mapping ("indicator-type",
                                         indicator_type_combo_box,
                                         "value",
                                         SETTINGS_BIND_FLAGS,
                                         (SettingsBindGetMappingShared) get_indicator_type_mapping,
                                         (SettingsBindSetMappingShared) set_indicator_type_mapping,
                                         null,
                                         null);

        list_box.insert (pomodoro_duration_field, -1);
        list_box.insert (short_break_duration_field, -1);
        list_box.insert (long_break_duration_field, -1);
        list_box.insert (long_break_interval_field, -1);
        list_box.insert (toggle_key_field, -1);
        list_box.insert (indicator_type_field, -1);

        this.field_size_group.add_widget (long_break_interval_field);
        this.field_size_group.add_widget (toggle_key_field);
        this.field_size_group.add_widget (indicator_type_field);

        if (Pomodoro.Player.is_supported ())
        {
            var ticking_sound_button = new Pomodoro.SoundChooserButton ();
            ticking_sound_button.title = _("Select ticking sound");
            ticking_sound_button.backend = Pomodoro.SoundBackend.GSTREAMER;
            ticking_sound_button.has_volume_button = true;

            foreach (var sound_info in this.timer_sounds)
            {
                var sound_file = File.new_for_uri (
                                       sound_info.get_absolute_uri ());
                ticking_sound_button.add_bookmark (
                                       sound_info.name,
                                       sound_file);
            }

            var ticking_sound_field = list_box_create_field (
                                       _("Ticking sound"),
                                       ticking_sound_button);

            this.settings.bind_with_mapping ("ticking-sound",
                                             ticking_sound_button,
                                             "file",
                                             SETTINGS_BIND_FLAGS,
                                             (SettingsBindGetMappingShared) Sounds.get_file_mapping,
                                             (SettingsBindSetMappingShared) Sounds.set_file_mapping,
                                             null,
                                             null);

            this.settings.bind ("ticking-sound-volume",
                                ticking_sound_button,
                                "volume",
                                SETTINGS_BIND_FLAGS);

            list_box.insert (ticking_sound_field, -1);

            this.field_size_group.add_widget (ticking_sound_field);

            this.combo_box_size_group.add_widget (ticking_sound_button.combo_box);
        }
    }

    private void add_notifications_section ()
    {
        Gtk.Box vbox;
        Gtk.ListBox list_box;

        create_section (_("Notifications"), out vbox, out list_box);

        this.box.pack_start (vbox);

        /* setup fields */
        var screen_notifications_toggle = new Gtk.Switch ();
        var screen_notifications_field = list_box_create_field (
                                       _("Screen notifications"),
                                       screen_notifications_toggle);

        var reminders_toggle = new Gtk.Switch ();
        var reminders_field = list_box_create_field (
                                       _("Remind to take a break"),
                                       reminders_toggle);

        var screen_wake_up_toggle = new Gtk.Switch ();
        var screen_wake_up_field = list_box_create_field (
                                       _("Wake up screen"),
                                       screen_wake_up_toggle);

        var pomodoro_end_sound = new Pomodoro.SoundChooserButton ();
        pomodoro_end_sound.title = _("Select sound for start of break");

        foreach (var sound_info in this.notification_sounds)
        {
            var sound_file = File.new_for_uri (
                                   sound_info.get_absolute_uri ());
            pomodoro_end_sound.add_bookmark (sound_info.name, sound_file);
        }

        var pomodoro_end_sound_field = list_box_create_field (
                                       _("Start of break sound"),
                                       pomodoro_end_sound);

        var pomodoro_start_sound = new Pomodoro.SoundChooserButton ();
        pomodoro_start_sound.title = _("Select sound for end of break");

        foreach (var sound_info in this.notification_sounds)
        {
            var sound_file = File.new_for_uri (
                                   sound_info.get_absolute_uri ());
            pomodoro_start_sound.add_bookmark (sound_info.name, sound_file);
        }

        var pomodoro_start_sound_field = list_box_create_field (
                                       _("End of break sound"),
                                       pomodoro_start_sound);

        /* bind settings */
        this.settings.bind ("show-screen-notifications",
                            screen_notifications_toggle,
                            "active",
                            SETTINGS_BIND_FLAGS);

        this.settings.bind ("show-reminders",
                            reminders_toggle,
                            "active",
                            SETTINGS_BIND_FLAGS);

        this.settings.bind ("wake-up-screen",
                            screen_wake_up_toggle,
                            "active",
                            SETTINGS_BIND_FLAGS);

        this.settings.bind_with_mapping ("pomodoro-end-sound",
                                         pomodoro_end_sound,
                                         "file",
                                         SETTINGS_BIND_FLAGS,
                                         (SettingsBindGetMappingShared) Sounds.get_file_mapping,
                                         (SettingsBindSetMappingShared) Sounds.set_file_mapping,
                                         null,
                                         null);

        this.settings.bind_with_mapping ("pomodoro-start-sound",
                                         pomodoro_start_sound,
                                         "file",
                                         SETTINGS_BIND_FLAGS,
                                         (SettingsBindGetMappingShared) Sounds.get_file_mapping,
                                         (SettingsBindSetMappingShared) Sounds.set_file_mapping,
                                         null,
                                         null);

        this.settings.bind ("pomodoro-end-sound-volume",
                            pomodoro_end_sound,
                            "volume",
                            SETTINGS_BIND_FLAGS);

        this.settings.bind ("pomodoro-start-sound-volume",
                            pomodoro_start_sound,
                            "volume",
                            SETTINGS_BIND_FLAGS);

        /* put fields together */
        list_box.insert (screen_notifications_field, -1);
        list_box.insert (reminders_field, -1);
        list_box.insert (screen_wake_up_field, -1);
        list_box.insert (pomodoro_end_sound_field, -1);
        list_box.insert (pomodoro_start_sound_field, -1);

        this.field_size_group.add_widget (screen_notifications_field);
        this.field_size_group.add_widget (reminders_field);
        this.field_size_group.add_widget (screen_wake_up_field);
        this.field_size_group.add_widget (pomodoro_end_sound_field);
        this.field_size_group.add_widget (pomodoro_start_sound_field);

        this.combo_box_size_group.add_widget (pomodoro_end_sound.combo_box);
        this.combo_box_size_group.add_widget (pomodoro_start_sound.combo_box);
    }

    private Gtk.ComboBox create_indicator_type_combo_box ()
    {
        var combo_box = new Pomodoro.EnumComboBox ();
        combo_box.add_option (IndicatorType.TEXT, _("Text"));
        combo_box.add_option (IndicatorType.TEXT_SMALL, _("Short Text"));
        combo_box.add_option (IndicatorType.ICON, _("Icon"));

        combo_box.show ();

        return combo_box as Gtk.ComboBox;
    }

    private Gtk.ComboBox create_presence_status_combo_box ()
    {
        var combo_box = new Pomodoro.EnumComboBox ();
        combo_box.add_option (PresenceStatus.DEFAULT, "");
        combo_box.add_option (PresenceStatus.AVAILABLE, _("Available"));
        combo_box.add_option (PresenceStatus.BUSY, _("Busy"));
        // combo_box.add_option (PresenceStatus.AWAY, _("Away"));
        combo_box.add_option (PresenceStatus.INVISIBLE, _("Invisible"));

        /* Idle status is used by gnome-shell/screensaver,
         * it's not ment to be set by user
         */
        // combo_box.add_option (PresenceStatus.IDLE,
        //                       _("Idle"));

        combo_box.show ();

        return combo_box as Gtk.ComboBox;
    }

    private void add_presence_section ()
    {
        Gtk.Box vbox;
        Gtk.ListBox list_box;

        create_section (_("Presence"), out vbox, out list_box);

        this.box.pack_start (vbox);


        var pause_when_idle_toggle = new Gtk.Switch ();
        var pause_when_idle_field = list_box_create_field (
                                       _("Wait for activity after a break"),
                                       pause_when_idle_toggle);
        list_box.insert (pause_when_idle_field, -1);

        this.settings.bind ("pause-when-idle",
                            pause_when_idle_toggle,
                            "active",
                            SETTINGS_BIND_FLAGS);

        var hide_notifications_toggle = new Gtk.Switch ();
        var hide_notifications_field = list_box_create_field (
                                       _("Hide notifications during pomodoro"),
                                       hide_notifications_toggle);
        list_box.insert (hide_notifications_field, -1); // TODO

        this.settings.bind ("hide-notifications-during-pomodoro",
                            hide_notifications_toggle,
                            "active",
                            SETTINGS_BIND_FLAGS);


        var change_im_status_label = new Gtk.Label (_("On"));
        var change_im_status_field = list_box_create_field (
                                       _("Change IM status"),
                                       change_im_status_label);
        list_box.insert (change_im_status_field, -1);


        this.field_size_group.add_widget (pause_when_idle_field);
        this.field_size_group.add_widget (hide_notifications_field);
        this.field_size_group.add_widget (change_im_status_field);

/* TODO
        var pomodoro_presence = this.create_presence_status_combo_box ();
        var pomodoro_presence_field = list_box_create_field (
                                       _("Status during pomodoro"),
                                       pomodoro_presence);

        var break_presence = this.create_presence_status_combo_box ();
        var break_presence_field = list_box_create_field (
                                       _("Status during break"),
                                       break_presence);

        list_box.insert (pomodoro_presence_field, -1);
        list_box.insert (break_presence_field, -1);

        this.settings.bind_with_mapping ("presence-during-pomodoro",
                                         pomodoro_presence,
                                         "value",
                                         SETTINGS_BIND_FLAGS,
                                         (SettingsBindGetMappingShared) Presence.get_status_mapping,
                                         (SettingsBindSetMappingShared)Presence.set_status_mapping,
                                         null,
                                         null);


        this.settings.bind_with_mapping ("presence-during-break",
                                         break_presence,
                                         "value",
                                         SETTINGS_BIND_FLAGS,
                                         (SettingsBindGetMappingShared) Presence.get_status_mapping,
                                         (SettingsBindSetMappingShared) Presence.set_status_mapping,
                                         null,
                                         null);

        pomodoro_presence.changed.connect (this.update_presence_notice);
        break_presence.changed.connect (this.update_presence_notice);
*/
    }


}
