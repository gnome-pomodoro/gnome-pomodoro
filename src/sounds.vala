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
 */

using GLib;


namespace Pomodoro
{
    private enum EventType {
        POMODORO_START = 1,
        POMODORO_END = 2
    }

    private const uint PLAYER_FADE_IN_TIME = 45000;
    private const uint PLAYER_FADE_OUT_TIME = 30000;

    /* As pomodoro is mostly a background app, we don't want interval time
     * to be too short
     */
    private const uint PLAYER_FADE_INTERVAL = 800;
}


public class Pomodoro.Player : Object
{
    private double _volume = 0.5;

    public double volume {
        get {
            return this._volume;
        }
        set {
            this.do_set_volume (value);
        }
    }

    public File file { get; set; }
    public bool repeat { get; set; default=false; }

    private Gst.Element pipeline;
    private Gst.Bus bus;
    private Pomodoro.Animation fade_in_animation;
    private Pomodoro.Animation fade_out_animation;

    construct
    {
        dynamic Gst.Element pipeline = Gst.ElementFactory.make ("playbin2", "player");

        assert (pipeline != null);

        pipeline.about_to_finish.connect (this.on_about_to_finish);

        this.pipeline = pipeline;

        this.bus = this.pipeline.get_bus ();
        this.bus.add_watch (this.bus_callback);
    }

    ~Player ()
    {
        this.pipeline.set_state (Gst.State.NULL);

        this.pipeline = null;
        this.bus = null;
    }

    public void play (uint fade_duration = 0)
    {
        var uri = this.file != null
                  ? this.file.get_uri ()
                  : null;

        if (uri != "") {
            this.pipeline.set ("uri", uri);
            this.pipeline.set_state (Gst.State.PLAYING);

            this.fade_in (fade_duration);
        }
    }

    public void stop (uint fade_duration = 0)
    {
        Gst.State state;
        Gst.State pending_state;

        this.pipeline.get_state (out state,
                                 out pending_state,
                                 Gst.CLOCK_TIME_NONE);

        if (state != Gst.State.NULL && state != Gst.State.READY) {
            this.fade_out (fade_duration);
        }
   }

    private void update_volume () {
        this.do_set_volume (this._volume);
    }

    private void fade_in (uint duration)
    {
        this.destroy_fade_in_animation ();

        if (duration > 0)
        {
            this.fade_in_animation = new Animation (duration,
                                                    AnimationMode.EASE_OUT);
            this.fade_in_animation.interval = PLAYER_FADE_INTERVAL;
            this.fade_in_animation.value = 0.0;
            this.fade_in_animation.value_changed.connect (() => {
                this.update_volume ();
            });
            this.fade_in_animation.completed.connect (() => {
                this.destroy_fade_in_animation ();
            });

            this.fade_in_animation.animate_to (1.0);
        }

        this.pipeline.set_state (Gst.State.PLAYING);
    }

    private void fade_out (uint duration)
    {
        this.destroy_fade_out_animation ();

        if (duration > 0)
        {
            this.fade_out_animation = new Animation (duration,
                                                     AnimationMode.EASE_IN_OUT);
            this.fade_out_animation.interval = PLAYER_FADE_INTERVAL;
            this.fade_out_animation.duration = duration;
            this.fade_out_animation.value = 1.0;
            this.fade_out_animation.value_changed.connect (() => {
                this.update_volume ();
            });
            this.fade_out_animation.completed.connect (() => {
                this.pipeline.set_state (Gst.State.READY);
                this.destroy_fade_out_animation ();
                this.destroy_fade_in_animation ();
            });

            this.fade_out_animation.animate_to (0.0);
        }
        else
        {
            this.pipeline.set_state (Gst.State.READY);
            this.destroy_fade_in_animation ();
        }
    }

    private void do_set_volume (double volume)
    {
        this._volume = volume.clamp (0.0, 1.0);

        var real_volume = this._volume;

        if (this.fade_in_animation != null) {
            real_volume = real_volume * this.fade_in_animation.value;
        }

        if (this.fade_out_animation != null) {
            real_volume = real_volume * this.fade_out_animation.value;
        }

        this.pipeline.set ("volume", real_volume);
    }

    private void do_repeat ()
    {
        var uri = "";
        this.pipeline.get ("uri", out uri);

        if (uri != "") {
            this.pipeline.set ("uri", uri);
        }
    }

    private bool bus_callback (Gst.Bus bus, Gst.Message message)
    {
        GLib.Error error;

        switch (message.type)
        {
            case Gst.MessageType.EOS:
                if (!this.repeat) {
                    this.pipeline.set_state (Gst.State.READY);
                }
                break;

            case Gst.MessageType.ERROR:
                message.parse_error (out error, null);
                GLib.message ("Error: %s\n", error.message);
                break;

            default:
                break;
        }

        return true;
    }

    private void on_about_to_finish ()
    {
        if (this.repeat) {
            this.do_repeat ();
        }
    }

    private void destroy_fade_in_animation ()
    {
        if (this.fade_in_animation != null) {
            this.fade_in_animation.destroy ();
            this.fade_in_animation = null;
        }
    }

    private void destroy_fade_out_animation ()
    {
        if (this.fade_out_animation != null) {
            this.fade_out_animation.destroy ();
            this.fade_out_animation = null;
        }
    }
}


internal class Pomodoro.Sounds : Object
{
    public Player player;

    private Settings settings;
    private Canberra.Context context;

    private unowned Pomodoro.Timer timer;
    private uint fade_out_timeout_id;


    public Sounds (Pomodoro.Timer timer)
    {
        this.timer = timer;

        var application = GLib.Application.get_default () as Pomodoro.Application;

        var binding_flags = GLib.SettingsBindFlags.DEFAULT |
                            GLib.SettingsBindFlags.GET;

        this.settings = application.settings as GLib.Settings;
        this.settings = this.settings.get_child ("preferences");
        this.settings.changed.connect (this.on_settings_changed);

        this.ensure_context ();


        this.player = new Player ();
        this.player.repeat = true;

        this.settings.bind ("ticking-sound-volume",
                            this.player,
                            "volume",
                            binding_flags);

        this.settings.bind_with_mapping ("ticking-sound",
                                         this.player,
                                         "file",
                                         binding_flags,
                                         Sounds.get_file_mapping,
                                         Sounds.set_file_mapping,
                                         (void *) this,
                                         null);

        this.timer.notify["elapsed-limit"].connect (this.on_elapsed_limit_changed);

        this.enable ();
    }

    ~Sounds ()
    {
        this.disable ();
    }

    private void schedule_fade_out ()
    {
        this.unschedule_fade_out ();

        var remaining_time =
            (uint) (this.timer.elapsed_limit - this.timer.elapsed) * 1000;

        if (remaining_time > PLAYER_FADE_OUT_TIME) {
            this.fade_out_timeout_id = GLib.Timeout.add (
                    remaining_time - PLAYER_FADE_OUT_TIME,
                    this.on_fade_out_timeout);
        }
        else {
            this.on_fade_out_timeout ();
        }
    }

    private void unschedule_fade_out ()
    {
        if (this.fade_out_timeout_id != 0) {
            GLib.Source.remove (this.fade_out_timeout_id);
            this.fade_out_timeout_id = 0;
        }
    }

    public void enable ()
    {
        this.timer.state_changed.connect (this.on_state_changed);
        this.timer.notify_pomodoro_end.connect (this.on_notify_pomodoro_end);
        this.timer.notify_pomodoro_start.connect (this.on_notify_pomodoro_start);
        this.timer.pomodoro_end.connect (this.on_pomodoro_end);
        this.timer.pomodoro_start.connect (this.on_pomodoro_start);
    }

    public void disable ()
    {
        SignalHandler.disconnect_by_func (this.timer,
                  (void*) this.on_state_changed, (void*) this);
        SignalHandler.disconnect_by_func (this.timer,
                  (void*) this.on_notify_pomodoro_end, (void*) this);
        SignalHandler.disconnect_by_func (this.timer,
                  (void*) this.on_notify_pomodoro_start, (void*) this);
        SignalHandler.disconnect_by_func (this.timer,
                  (void*) this.on_pomodoro_end, (void*) this);
        SignalHandler.disconnect_by_func (this.timer,
                  (void*) this.on_pomodoro_start, (void*) this);
    }

    private void on_settings_changed (GLib.Settings settings, string key)
    {
        switch (key)
        {
            case "pomodoro-end-sound":
                var file_path = this.get_file_path (key);
                this.ensure_context ();

                if (this.context != null && file_path != "")
                {
                    var status = this.context.cache
                                (Canberra.PROP_EVENT_ID, "pomodoro-end",
                                 Canberra.PROP_MEDIA_FILENAME, file_path);

                    if (status != Canberra.SUCCESS) {
                        GLib.warning ("Couldn't update canberra cache - %s",
                                      Canberra.strerror (status));
                    }
                }

                break;

            case "pomodoro-start-sound":
                var file_path = this.get_file_path (key);
                this.ensure_context ();

                if (this.context != null && file_path != "")
                {
                    var status = this.context.cache
                                (Canberra.PROP_EVENT_ID, "pomodoro-start",
                                 Canberra.PROP_MEDIA_FILENAME, file_path);

                    if (status != Canberra.SUCCESS) {
                        GLib.warning ("Couldn't update canberra cache - %s",
                                      Canberra.strerror (status));
                    }
                }

                break;
        }
    }

    private void ensure_context ()
    {
        /* Create context */
        var status = Canberra.Context.create (out this.context);

        if (status != Canberra.SUCCESS) {
            GLib.warning ("Couldn't create canberra context - %s",
                          Canberra.strerror (status));

            return;
        }

        /* Set properties about application */
        status = this.context.change_props (
                Canberra.PROP_APPLICATION_NAME, Config.PACKAGE_NAME,
                Canberra.PROP_APPLICATION_ID, "org.gnome.Pomodoro");

        if (status != Canberra.SUCCESS) {
            GLib.warning ("Couldn't setup canberra context - %s",
                          Canberra.strerror (status));

            return;
        }

        /* Connect to the sound system */
        status = this.context.open ();

        if (status != Canberra.SUCCESS) {
            GLib.warning ("Couldn't open canberra context - %s",
                          Canberra.strerror (status));

            return;
        }
    }

    public static bool get_file_mapping (GLib.Value value,
                                         GLib.Variant variant,
                                         void* user_data)
    {
        var path = variant.get_string ();

        if (path != "")
        {
            try {
                path = Filename.from_uri (path);
            }
            catch (ConvertError error) {
            }

            if (!Path.is_absolute (path)) {
                path = Path.build_filename ("file://",
                                            Config.PACKAGE_DATA_DIR,
                                            "sounds",
                                            path);
            }
            else {
                if (Uri.parse_scheme (path) == null) {
                    path = "file://" + path;
                }
            }
        }

        value.set_object (GLib.File.new_for_uri (path));

        return true;
    }

    public static Variant set_file_mapping (GLib.Value value,
                                            GLib.VariantType expected_type,
                                            void* user_data)
    {
        var file = value.get_object () as GLib.File;

        if (file != null)
        {
            var uri = file.get_uri ();
            var prefix = Path.build_filename ("file://",
                                              Config.PACKAGE_DATA_DIR,
                                              "sounds",
                                              "");
            if (uri.has_prefix (prefix)) {
                uri = uri.substring (prefix.length);
            }

            return new Variant.string (uri);
        }

        return new Variant.string ("");
    }

    private string? get_file_path (string settings_key)
    {
        string uri = this.settings.get_string (settings_key);
        string path = null;

        if (uri != "")
        {
            try {
                path = Filename.from_uri (uri);
            }
            catch (ConvertError error) {
                path = uri;
            }

            if (!Path.is_absolute (path)) {
                path = Path.build_filename ("file://",
                                            Config.PACKAGE_DATA_DIR,
                                            "sounds",
                                            path);
            }
        }

        return path;
    }

    /**
     * Notify pomodoro start whether it was requested or not to take
     * advantage of Pavlovian conditioning.
     */
    private void on_notify_pomodoro_start (bool is_requested)
    {
        this.ensure_context ();

        if (this.context != null)
        {
            var file_path = this.get_file_path ("pomodoro-start-sound");
            if (file_path == null) {
                return;
            }

            var status = this.context.play (EventType.POMODORO_START,
                    Canberra.PROP_EVENT_ID, "pomodoro-start",
                    Canberra.PROP_EVENT_DESCRIPTION, "Pomodoro started",
                    Canberra.PROP_MEDIA_FILENAME, file_path,
                    Canberra.PROP_MEDIA_ROLE, "event",
                    Canberra.PROP_CANBERRA_CACHE_CONTROL, "permanent");

            if (status != Canberra.SUCCESS) {
                GLib.warning ("Couldn't play sound '%s' - %s",
                              file_path,
                              Canberra.strerror (status));
            }
        }
    }

    private void on_notify_pomodoro_end (bool is_completed)
    {
        this.ensure_context ();

        if (this.context != null && is_completed)
        {
            var file_path = this.get_file_path ("pomodoro-end-sound");
            if (file_path == null) {
                return;
            }

            var status = this.context.play (EventType.POMODORO_END,
                    Canberra.PROP_EVENT_ID, "pomodoro-end",
                    Canberra.PROP_EVENT_DESCRIPTION, "Pomodoro ended",
                    Canberra.PROP_MEDIA_FILENAME, file_path,
                    Canberra.PROP_MEDIA_ROLE, "event",
                    Canberra.PROP_CANBERRA_CACHE_CONTROL, "permanent");

            if (status != Canberra.SUCCESS) {
                GLib.warning ("Couldn't play sound '%s' - %s",
                              file_path,
                              Canberra.strerror (status));
            }
        }
    }

    private void on_state_changed ()
    {
        if (this.timer.state != State.POMODORO) {
            this.player.stop ();
        }
    }

    private void on_elapsed_limit_changed ()
    {
        if (this.timer.state == State.POMODORO) {
            this.schedule_fade_out ();
        }
    }

    private void on_pomodoro_start (bool is_requested)
    {
        this.player.play (PLAYER_FADE_IN_TIME);

        this.schedule_fade_out ();
    }

    private void on_pomodoro_end (bool is_completed)
    {
        this.unschedule_fade_out ();
    }

    private bool on_fade_out_timeout ()
    {
        this.unschedule_fade_out ();

        this.player.stop (PLAYER_FADE_OUT_TIME);

        return false;
    }
}
