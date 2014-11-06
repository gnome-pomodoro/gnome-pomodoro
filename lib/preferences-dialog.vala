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


private abstract class Pomodoro.PreferencesTab : Gtk.Box
{
    public Gtk.Label? label;

    protected Gtk.Box info_box;

    private enum MessageType {
        PRESENCE_STATUS,
    }

    construct {
        this.orientation = Gtk.Orientation.VERTICAL;

        this.info_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        this.info_box.show ();

        this.pack_start (this.info_box, false, true);
    }

    /* TODO: Move to Utils? */
    protected void contents_separator_func (Gtk.ListBoxRow  row,
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

    protected Gtk.ListBoxRow create_field (string      text,
                                           Gtk.Widget  widget,
                                           Gtk.Widget? bottom_widget=null)
    {
        var row = new Gtk.ListBoxRow ();

        var bin = new Gtk.Alignment (0.0f, 0.0f, 1.0f, 1.0f);
        bin.set_padding (10, 10, 16, 16);

        var label = new Gtk.Label (text);
        label.set_alignment (0.0f, 0.5f);

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
            bin.add (hbox);
        }

        row.add (bin);
        row.show_all ();

        return row;
    }

    protected Gtk.Widget create_scale_field (string         text,
                                             Gtk.Adjustment adjustment)
    {
        var value_label = new Gtk.Label (null);
        value_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var scale = new LogScale (adjustment, 2.0);
        var widget = this.create_field (text, value_label, scale);

        adjustment.value_changed.connect (() => {
            value_label.set_text (format_time ((long) adjustment.value));
        });

        adjustment.value_changed ();

        return widget;
    }

    protected unowned Gtk.InfoBar get_info_bar (string message_id)
    {
        unowned Gtk.InfoBar info_bar = null;

        foreach (unowned Gtk.Widget child in this.info_box.get_children ())
        {
            var message_type = child.get_data<string> ("message-id");

            if (message_type == message_id)
            {
                info_bar = child as Gtk.InfoBar;

                break;
            }
        }

        return info_bar;
    }
}


private class Pomodoro.TimerPreferencesTab : PreferencesTab
{
    private Gtk.SizeGroup combo_box_size_group;

    private GLib.Settings settings;

    private Gtk.Box preferences_vbox;

    construct {
        this.label = new Gtk.Label (_("Timer"));

        this.settings = Pomodoro.get_settings ().get_child ("preferences");

        this.preferences_vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
        this.preferences_vbox.show ();

        this.combo_box_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);

        var alignment = new Gtk.Alignment (0.5f, 0.0f, 1.0f, 0.0f);
        alignment.set_padding (20, 16, 40, 40);
        alignment.add (this.preferences_vbox);
        alignment.show ();

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.set_policy (Gtk.PolicyType.NEVER,
                                    Gtk.PolicyType.AUTOMATIC);
        scrolled_window.set_size_request (500, 300);
        scrolled_window.add (alignment);
        scrolled_window.show ();

        var context = scrolled_window.get_style_context ();
        context.add_class ("timer-page");

        this.add_timer_section ();
        this.add_indicator_section ();
        this.add_notifications_section ();
        this.add_presence_section ();
        this.add_sounds_section ();

        this.pack_end (scrolled_window, true, true);
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
        list_box.set_header_func (contents_separator_func);
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

        this.preferences_vbox.pack_start (vbox);

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

        list_box.insert (this.create_scale_field (_("Pomodoro duration"),
                                                  pomodoro_adjustment), -1);

        list_box.insert (this.create_scale_field (_("Short break duration"),
                                                  short_break_adjustment), -1);

        list_box.insert (this.create_scale_field (_("Long break duration"),
                                                  long_break_adjustment), -1);

        var long_break_interval_entry = new Gtk.SpinButton (long_break_interval_adjustment, 1.0, 0);
        long_break_interval_entry.snap_to_ticks = true;
        long_break_interval_entry.update_policy = Gtk.SpinButtonUpdatePolicy.IF_VALID;
        long_break_interval_entry.set_size_request (100, -1);

        /* @translators: You can refer it to number of pomodoros in a cycle */
        list_box.insert (this.create_field (_("Pomodoros to a long break"),
                                            long_break_interval_entry), -1);

        var toggle_key_button = new Pomodoro.KeybindingButton (keybinding);
        toggle_key_button.show ();

        list_box.insert (
            this.create_field (_("Shortcut to toggle the timer"), toggle_key_button), -1);
    }

    private void add_indicator_section ()
    {
        Gtk.Box vbox;
        Gtk.ListBox list_box;

        create_section (_("Indicator"), out vbox, out list_box);

        this.preferences_vbox.pack_start (vbox);

        var indicator_type_combo_box = this.create_indicator_type_combo_box ();
        list_box.insert (
            this.create_field (_("Indicator appearance"), indicator_type_combo_box), -1);

        this.settings.bind_with_mapping ("indicator-type",
                                         indicator_type_combo_box,
                                         "value",
                                         SETTINGS_BIND_FLAGS,
                                         (SettingsBindGetMappingShared) get_indicator_type_mapping,
                                         (SettingsBindSetMappingShared) set_indicator_type_mapping,
                                         null,
                                         null);
    }

    private void add_notifications_section ()
    {
        Gtk.Box vbox;
        Gtk.ListBox list_box;

        create_section (_("Notifications"), out vbox, out list_box);

        this.preferences_vbox.pack_start (vbox);

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

        list_box.insert (notifications_field, -1);
        list_box.insert (reminders_field, -1);
    }

    private void add_sounds_section ()
    {
        Gtk.Box vbox;
        Gtk.ListBox list_box;

        create_section (_("Sounds"), out vbox, out list_box);

        this.preferences_vbox.pack_start (vbox);

        string[] ticking_sounds = {
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

        if (Player.is_supported ())
        {  // TODO: Check sounds modules capabilities
            var ticking_sound = new Pomodoro.SoundChooserButton ();
            ticking_sound.title = _("Select ticking sound");
            ticking_sound.backend = SoundBackend.GSTREAMER;
            ticking_sound.has_volume_button = true;

            for (var i = 0; i < ticking_sounds.length; i += 2)
            {
                ticking_sound.add_bookmark (ticking_sounds[i],
                                            File.new_for_uri (ticking_sounds[i+1]));
            }

            var ticking_sound_field = this.create_field (_("Ticking sound"),
                                                         ticking_sound);
            list_box.insert (ticking_sound_field, -1);

            this.settings.bind_with_mapping ("ticking-sound",
                                             ticking_sound,
                                             "file",
                                             SETTINGS_BIND_FLAGS,
                                             (SettingsBindGetMappingShared) Sounds.get_file_mapping,
                                             (SettingsBindSetMappingShared) Sounds.set_file_mapping,
                                             null,
                                             null);

            this.settings.bind ("ticking-sound-volume",
                                ticking_sound,
                                "volume",
                                SETTINGS_BIND_FLAGS);

            this.combo_box_size_group.add_widget (ticking_sound.combo_box);
        }

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
        pomodoro_start_sound.title = _("Select sound for end of break");

        for (var i = 0; i < sounds.length; i += 2)
        {
            pomodoro_start_sound.add_bookmark (sounds[i],
                                               File.new_for_uri (sounds[i+1]));
        }

        var pomodoro_start_sound_field = this.create_field (
                                       _("End of break sound"),
                                       pomodoro_start_sound);

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

        list_box.insert (pomodoro_end_sound_field, -1);
        list_box.insert (pomodoro_start_sound_field, -1);

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

    private void add_presence_section ()
    {
        Gtk.Box vbox;
        Gtk.ListBox list_box;

        create_section (_("Presence"), out vbox, out list_box);

        this.preferences_vbox.pack_start (vbox);

        var pause_when_idle_toggle = new Gtk.Switch ();
        var pause_when_idle_field = this.create_field (
                                       _("Wait for activity after a break"),
                                       pause_when_idle_toggle);

        var pomodoro_presence = this.create_presence_status_combo_box ();
        var pomodoro_presence_field = this.create_field (
                                       _("Status during pomodoro"),
                                       pomodoro_presence);

        var break_presence = this.create_presence_status_combo_box ();
        var break_presence_field = this.create_field (
                                       _("Status during break"),
                                       break_presence);

        list_box.insert (pause_when_idle_field, -1);
        list_box.insert (pomodoro_presence_field, -1);
        list_box.insert (break_presence_field, -1);

        this.settings.bind ("pause-when-idle",
                            pause_when_idle_toggle,
                            "active",
                            SETTINGS_BIND_FLAGS);

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
            text = _("System notifications including chat messages won't show\xC2\xA0up during pomodoro.");
        }

        if (has_notifications_during_pomodoro && !has_notifications_during_break) {
            text = _("System notifications including chat messages won't show\xC2\xA0up during break.");
        }

        if (!has_notifications_during_pomodoro && !has_notifications_during_break) {
            text = _("System notifications including chat messages won't show\xC2\xA0up.");
        }

        Gtk.InfoBar info_bar = this.get_info_bar ("presence-status");

        if (text != "")
        {
            if (info_bar == null)
            {
                info_bar = new Gtk.InfoBar ();
                info_bar.set_message_type (Gtk.MessageType.INFO);
                info_bar.set_data<string> ("message-id", "presence-status");
                info_bar.add_button (_("OK"), Gtk.ResponseType.CLOSE);
                info_bar.response.connect ((info_bar, response_id) => {
                        if (response_id == Gtk.ResponseType.CLOSE) {
                            info_bar.hide ();
                            return;
                        }
                    });
                this.info_box.pack_start (info_bar, false, false);

                var message = new Gtk.Label (text);
                message.set_alignment (0.0f, 0.5f);
                message.wrap = true;
                message.show ();

                var message_box = info_bar.get_content_area () as Gtk.Box;
                message_box.pack_start (message, false, false);
            }
            else {
                var message_box = info_bar.get_content_area () as Gtk.Box;

                foreach (unowned Gtk.Widget child in message_box.get_children ())
                {
                    (child as Gtk.Label).set_text (text);
                }
            }

            if (info_bar != null) {
                info_bar.show ();
            }
        }
        else {
            if (info_bar != null) {
                info_bar.hide ();
            }
        }
    }
}


private class Pomodoro.TaskListPreferencesTab : PreferencesTab
{
    construct {
        this.orientation = Gtk.Orientation.VERTICAL;
        this.spacing = 3;

        this.label = new Gtk.Label (_("Task List"));
    }
}


private class Pomodoro.PluginsPreferencesTab : PreferencesTab
{
    construct {
        this.orientation = Gtk.Orientation.VERTICAL;
        this.spacing = 3;

        this.label = new Gtk.Label (_("Plugins"));
    }
}


public class Pomodoro.PreferencesDialog : Gtk.ApplicationWindow
{
    private Gtk.Notebook notebook;
    private Gtk.HeaderBar header_bar;

    public PreferencesDialog ()
    {
        this.title = _("Preferences");

        var geometry = Gdk.Geometry ();
        geometry.min_width = 500;
        geometry.max_width = 500;
        geometry.min_height = 200;
        geometry.max_height = 1000;

        var geometry_hints = Gdk.WindowHints.MAX_SIZE |
                             Gdk.WindowHints.MIN_SIZE;

        this.set_geometry_hints (this,
                                 geometry,
                                 geometry_hints);

        this.set_default_size (-1, 760);

        this.set_destroy_with_parent (true);

        /* It's not precisely a dialog window, but we want to disable maximize
         * button. We could use set_resizable(false), but then user looses
         * ability to resize it if needed.
         */
        this.set_type_hint (Gdk.WindowTypeHint.DIALOG);

        /* Used to transfer focus from gnome-shell */
        this.set_startup_id ("gnome-pomodoro-properties");

        this.setup ();
    }

    private void setup ()
    {
        var context = this.get_style_context ();
        context.add_class ("preferences-dialog");

        this.header_bar = new Gtk.HeaderBar ();
        this.header_bar.show_close_button = true;
        this.header_bar.title = this.title;
        this.header_bar.show_all ();
        this.set_titlebar (this.header_bar);

        this.notebook = new Gtk.Notebook ();
        this.notebook.scrollable = false;
        this.notebook.show_border = false;

        var timer_page = new TimerPreferencesTab ();
        this.notebook.append_page (timer_page, timer_page.label);

        var task_list_page = new TaskListPreferencesTab ();
        this.notebook.append_page (task_list_page, task_list_page.label);

        var plugins_page = new PluginsPreferencesTab ();
        this.notebook.append_page (plugins_page, plugins_page.label);

        this.notebook.show_all ();

        this.add (this.notebook);
    }
}
