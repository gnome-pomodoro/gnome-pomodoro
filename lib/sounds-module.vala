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
 */

using GLib;


namespace Pomodoro
{
    private enum EventType {
        POMODORO_START = 1,
        POMODORO_END = 2
    }

    public enum SoundBackend {
        CANBERRA,
        GSTREAMER
    }

    private const uint PLAYER_FADE_IN_TIME = 25000;
    private const uint PLAYER_FADE_OUT_TIME = 15000;

    /* As pomodoro is mostly a background app, we don't want interval time
     * to be too short
     */
    private const uint PLAYER_FADE_INTERVAL = 100;

    private const double MIN_PLAYED_VOLUME = 0.01;


    private double amplitude_to_decibels (double amplitude) {
        return 20.0 * Math.log10 (amplitude);
    }
}


public class Pomodoro.Player : GLib.Object
{
    private double _volume = 0.5;
    public double volume {
        get {
            return this._volume;
        }
        set {
            this._volume = value.clamp (0.0, 1.0);

            this.update_volume ();
        }
    }

    private double fade_value = 1.0;
    private bool is_playing = false;

    private File _file;
    public File file {
        get {
            return this._file;
        }
        set {
            Gst.State state;
            Gst.State pending_state;

            if (value != null && value.query_file_type (FileQueryInfoFlags.NONE) != FileType.REGULAR) {
                value = null;
            }

            var uri = value != null ? value.get_uri () : "";

            this._file = value;

            this.pipeline.get_state (out state,
                                     out pending_state,
                                     Gst.CLOCK_TIME_NONE);

            if (this.is_playing) {
                this.pipeline.set_state (Gst.State.READY);
            }

            if (uri != "")
            {
                this.pipeline.set ("uri", uri);

                if (this.is_playing) {
                    this.pipeline.set_state (Gst.State.PLAYING);
                }
            }
        }
    }

    public bool repeat { get; set; default=false; }

    private Gst.Element pipeline;
    private Pomodoro.Animation fade_animation;

    construct
    {
        dynamic Gst.Element pipeline = Gst.ElementFactory.make ("playbin",
                                                                null);

        assert (pipeline != null);

        pipeline.about_to_finish.connect (this.on_about_to_finish);

        this.pipeline = pipeline;

        var bus = this.pipeline.get_bus ();
        bus.add_watch (GLib.Priority.DEFAULT, this.bus_callback);

        this.fade_animation = null;
        this.fade_value = 0.0;
    }

    ~Player ()
    {
        this.pipeline.set_state (Gst.State.NULL);

        this.pipeline = null;
        this.fade_animation = null;
    }

    public static bool is_supported ()
    {
        /* Check whether playbin exists */
        var element_factory = Gst.ElementFactory.find("playbin");

        return element_factory != null;
    }

    public void play ()
    {
        this.is_playing = true;

        var uri = this.file != null ? this.file.get_uri () : "";

        if (uri != "") {
            this.pipeline.set ("uri", uri);
            this.pipeline.set_state (Gst.State.PLAYING);
        }
    }

    public void stop ()
    {
        Gst.State state;
        Gst.State pending_state;

        this.pipeline.get_state (out state,
                                 out pending_state,
                                 Gst.CLOCK_TIME_NONE);

        if (state != Gst.State.NULL && state != Gst.State.READY)
        {
            this.pipeline.set_state (Gst.State.READY);
        }

        this.is_playing = false;
    }

    public void fade (double value, AnimationMode mode, uint duration=0)
    {
        this.destroy_fade_animation ();

        if (duration > 0 && this.is_playing)
        {
            this.fade_animation = new Animation (duration, mode);
            this.fade_animation.interval = PLAYER_FADE_INTERVAL;
            this.fade_animation.value = this.fade_value;

            this.fade_animation.value_changed.connect (() => {
                this.fade_value = this.fade_animation.value;
                this.update_volume ();
            });
            this.fade_animation.completed.connect (() => {
                this.destroy_fade_animation ();
            });

            this.fade_animation.animate_to (value);
        }
        else {
            this.fade_value = value;
            this.update_volume ();
        }
    }

    private void update_volume ()
    {
        var real_volume = this.volume * this.fade_value;

        if (this.pipeline != null) {
            this.pipeline.set ("volume", real_volume.clamp (0.0, 1.0));
        }
    }

    private void do_repeat ()
    {
        var uri = "";
        this.pipeline.get ("current-uri", out uri);

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
                    this.is_playing = false;
                }
                break;

            case Gst.MessageType.ERROR:
                message.parse_error (out error, null);
                GLib.critical (error.message);

                this.pipeline.set_state (Gst.State.NULL);
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

    private void destroy_fade_animation ()
    {
        if (this.fade_animation != null)
        {
            this.fade_animation.destroy ();
            this.fade_animation = null;
        }
    }
}


public class Pomodoro.SoundsModule : Pomodoro.Module
{
    public Player player;
    public Player fallback_player;

    private Settings settings;
    private Canberra.Context context;

    private unowned Pomodoro.Timer timer;
    private uint fade_out_timeout_id;

    private bool has_gstreamer;


    public SoundsModule (Pomodoro.Timer timer)
    {
        this.timer = timer;
        this.timer.notify["state-duration"].connect (this.on_state_duration_changed);

        this.settings = Pomodoro.get_settings ().get_child ("preferences");
        this.settings.changed.connect (this.on_settings_changed);

        this.has_gstreamer = Player.is_supported ();

        if (!this.has_gstreamer) {
            GLib.debug ("Can not use Gstramer backend");
        }
    }

    private void setup_libcanberra ()
    {
        this.ensure_context ();
    }

    private void setup_gstreamer ()
    {
        var binding_flags = GLib.SettingsBindFlags.DEFAULT |
                            GLib.SettingsBindFlags.GET;

        if (this.has_gstreamer)
        {
            this.fallback_player = new Player ();
        }

        if (this.has_gstreamer)
        {
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
                                             SoundsModule.get_file_mapping,
                                             SoundsModule.set_file_mapping,
                                             (void *) this,
                                             null);
        }
    }

    private void schedule_fade_out ()
    {
        this.unschedule_fade_out ();

        var remaining_time =
            (uint) ((this.timer.state.duration - this.timer.elapsed) * 1000);

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

    public override void enable ()
    {
        if (!this.enabled)
        {
            this.setup_libcanberra ();
            this.setup_gstreamer ();

            this.timer.state_changed.connect (this.on_state_changed);
//            this.timer.notify_pomodoro_end.connect (this.on_notify_pomodoro_end);
//            this.timer.notify_pomodoro_start.connect (this.on_notify_pomodoro_start);
//            this.timer.pomodoro_start.connect (this.on_pomodoro_start);
        }

        base.enable ();
    }

    public new void disable ()
    {
        if (this.enabled)
        {
            SignalHandler.disconnect_by_func (this.timer,
                      (void*) this.on_state_changed, (void*) this);
//            SignalHandler.disconnect_by_func (this.timer,
//                      (void*) this.on_notify_pomodoro_end, (void*) this);
//            SignalHandler.disconnect_by_func (this.timer,
//                      (void*) this.on_notify_pomodoro_start, (void*) this);
//            SignalHandler.disconnect_by_func (this.timer,
//                      (void*) this.on_pomodoro_start, (void*) this);
        }

        base.disable ();
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

            case "ticking-sound":
                var file_path = this.get_file_path (key);
                if (this.player != null) {
                    this.player.file = GLib.File.new_for_path (file_path);
                }

                break;
        }
    }

    private void ensure_context ()
    {
        /* Create context */
        if (this.context == null)
        {
            Canberra.Context context = null;
            var status = Canberra.Context.create (out context);

            if (status != Canberra.SUCCESS) {
                GLib.critical ("Could not create canberra context: %s",
                               Canberra.strerror (status));

                return;
            }

            /* Set properties about application */
            status = context.change_props (
                    Canberra.PROP_APPLICATION_NAME, Config.PACKAGE_NAME,
                    Canberra.PROP_APPLICATION_ID, "org.gnome.Pomodoro");

            if (status != Canberra.SUCCESS) {
                GLib.critical ("Could not setup canberra context: %s",
                               Canberra.strerror (status));

                return;
            }

            /* Connect to the sound system */
            status = context.open ();

            if (status != Canberra.SUCCESS) {
                GLib.critical ("Could not open canberra context: %s",
                               Canberra.strerror (status));

                return;
            }

            this.context = (owned) context;
        }
    }

    public static bool get_file_mapping (GLib.Value value,
                                         GLib.Variant variant,
                                         void* user_data)
    {
        var uri = variant.get_string ();
        var path = "";

        if (uri != "")
        {
            try {
                if (Uri.parse_scheme (uri) == null) {
                    path = uri;
                }
                else {
                    path = Filename.from_uri (uri);
                }
            }
            catch (ConvertError error) {
            }

            if (!Path.is_absolute (path)) {
                path = Path.build_filename (Config.PACKAGE_DATA_DIR,
                                            "sounds",
                                            path);
            }

            if (path != "") {
                uri = "file://" + path;
            }
        }

        value.set_object (GLib.File.new_for_uri (uri));

        return true;
    }

    public static Variant set_file_mapping (GLib.Value value,
                                            GLib.VariantType expected_type,
                                            void* user_data)
    {
        var file = value.get_object () as GLib.File;
        var prefix = "file://" +
                     Path.build_filename (Config.PACKAGE_DATA_DIR, "sounds") +
                     Path.DIR_SEPARATOR_S;

        if (file != null)
        {
            var uri = file.get_uri ();
            if (uri.has_prefix (prefix)) {
                uri = uri.substring (prefix.length);
            }

            return new Variant.string (uri);
        }

        return new Variant.string ("");
    }

    private string get_file_path (string settings_key)
    {
        string uri = this.settings.get_string (settings_key);
        string path = "";

        if (uri != "")
        {
            try {
                path = Filename.from_uri (uri);
            }
            catch (ConvertError error) {
                path = uri;
            }

            if (!Path.is_absolute (path)) {
                path = Path.build_filename (Config.PACKAGE_DATA_DIR,
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
            var volume = this.settings.get_double ("pomodoro-start-sound-volume");

            if (file_path == "" || volume < MIN_PLAYED_VOLUME) {
                return;
            }

            volume = amplitude_to_decibels (volume);

            var status = this.context.play (
                    EventType.POMODORO_START,
                    Canberra.PROP_EVENT_ID, "pomodoro-start",
                    Canberra.PROP_EVENT_DESCRIPTION, "Pomodoro started",
                    Canberra.PROP_MEDIA_FILENAME, file_path,
                    Canberra.PROP_MEDIA_ROLE, "event",
                    Canberra.PROP_CANBERRA_VOLUME, volume.to_string (),
                    Canberra.PROP_CANBERRA_CACHE_CONTROL, "permanent");

            if (status != Canberra.SUCCESS) {
                GLib.critical ("Could not play sound \"%s\": %s",
                              file_path,
                              Canberra.strerror (status));

                this.fallback_player.file = GLib.File.new_for_path (file_path);
                this.fallback_player.volume = volume;
                this.fallback_player.play ();
            }
        }
    }

    private void on_notify_pomodoro_end (bool is_completed)
    {
        this.ensure_context ();

        if (this.context != null && is_completed)
        {
            var file_path = this.get_file_path ("pomodoro-end-sound");
            var volume = this.settings.get_double ("pomodoro-end-sound-volume");

            if (file_path == "" || volume < MIN_PLAYED_VOLUME) {
                return;
            }

            volume = amplitude_to_decibels (volume);

            var status = this.context.play (
                    EventType.POMODORO_END,
                    Canberra.PROP_EVENT_ID, "pomodoro-end",
                    Canberra.PROP_EVENT_DESCRIPTION, "Pomodoro ended",
                    Canberra.PROP_MEDIA_FILENAME, file_path,
                    Canberra.PROP_MEDIA_ROLE, "event",
                    Canberra.PROP_CANBERRA_VOLUME, volume.to_string (),
                    Canberra.PROP_CANBERRA_CACHE_CONTROL, "permanent");

            if (status != Canberra.SUCCESS) {
                GLib.critical ("Could not play sound \"%s\": %s",
                               file_path,
                               Canberra.strerror (status));

                this.fallback_player.file = GLib.File.new_for_path (file_path);
                this.fallback_player.volume = volume;
                this.fallback_player.play ();
            }
        }
    }

    private void on_state_changed ()
    {
        if (!(this.timer.state is PomodoroState) && this.player != null) {
            this.player.stop ();
        }
    }

    private void on_state_duration_changed ()
    {
        this.unschedule_fade_out ();

        if (this.timer.state is PomodoroState) {
            this.schedule_fade_out ();
        }
    }

    private void on_pomodoro_start (bool is_requested)
    {
        if (this.player != null) {
            this.player.play ();
            this.player.fade (1.0,
                              AnimationMode.EASE_OUT,
                              PLAYER_FADE_IN_TIME);
        }

        this.schedule_fade_out ();
    }

    private bool on_fade_out_timeout ()
    {
        if (this.player != null) {
            this.player.fade (0.0,
                              AnimationMode.EASE_IN_OUT,
                              PLAYER_FADE_OUT_TIME);
        }

        this.unschedule_fade_out ();

        return false;
    }
}
