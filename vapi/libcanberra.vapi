/***
  This file is part of libcanberra.

  Copyright (C) 2009 Michael 'Mickey' Lauer <mlauer vanille-media de>

  libcanberra is free software; you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as
  published by the Free Software Foundation, either version 2.1 of the
  License, or (at your option) any later version.

  libcanberra is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with libcanberra. If not, see
  <http://www.gnu.org/licenses/>.
***/

[CCode (cprefix = "CA_", lower_case_cprefix = "ca_", cheader_filename = "canberra.h")]
namespace Canberra {

        public const int MAJOR;
        public const int MINOR;

        [CCode (cname="CA_CHECK_VERSION")]
        public bool CHECK_VERSION(int major, int minor);

        public const string PROP_MEDIA_NAME;
        public const string PROP_MEDIA_TITLE;
        public const string PROP_MEDIA_ARTIST;
        public const string PROP_MEDIA_LANGUAGE;
        public const string PROP_MEDIA_FILENAME;
        public const string PROP_MEDIA_ICON;
        public const string PROP_MEDIA_ICON_NAME;
        public const string PROP_MEDIA_ROLE;
        public const string PROP_EVENT_ID;
        public const string PROP_EVENT_DESCRIPTION;
        public const string PROP_EVENT_MOUSE_X;
        public const string PROP_EVENT_MOUSE_Y;
        public const string PROP_EVENT_MOUSE_HPOS;
        public const string PROP_EVENT_MOUSE_VPOS;
        public const string PROP_EVENT_MOUSE_BUTTON;
        public const string PROP_WINDOW_NAME;
        public const string PROP_WINDOW_ID;
        public const string PROP_WINDOW_ICON;
        public const string PROP_WINDOW_ICON_NAME;
        public const string PROP_WINDOW_X;
        public const string PROP_WINDOW_Y;
        public const string PROP_WINDOW_WIDTH;
        public const string PROP_WINDOW_HEIGHT;
        public const string PROP_WINDOW_HPOS;
        public const string PROP_WINDOW_VPOS;
        public const string PROP_WINDOW_DESKTOP;
        public const string PROP_WINDOW_X11_DISPLAY;
        public const string PROP_WINDOW_X11_SCREEN;
        public const string PROP_WINDOW_X11_MONITOR;
        public const string PROP_WINDOW_X11_XID;
        public const string PROP_APPLICATION_NAME;
        public const string PROP_APPLICATION_ID;
        public const string PROP_APPLICATION_VERSION;
        public const string PROP_APPLICATION_ICON;
        public const string PROP_APPLICATION_ICON_NAME;
        public const string PROP_APPLICATION_LANGUAGE;
        public const string PROP_APPLICATION_PROCESS_ID;
        public const string PROP_APPLICATION_PROCESS_BINARY;
        public const string PROP_APPLICATION_PROCESS_USER;
        public const string PROP_APPLICATION_PROCESS_HOST;
        public const string PROP_CANBERRA_CACHE_CONTROL;
        public const string PROP_CANBERRA_VOLUME;
        public const string PROP_CANBERRA_XDG_THEME_NAME;
        public const string PROP_CANBERRA_XDG_THEME_OUTPUT_PROFILE;
        public const string PROP_CANBERRA_ENABLE;
        public const string PROP_CANBERRA_FORCE_CHANNEL;

        [CCode (cname = "CA_SUCCESS")]
        public const int SUCCESS;

        [CCode (cname = "int", cprefix = "CA_ERROR_")]
        public enum Error {
                NOTSUPPORTED,
                INVALID,
                STATE,
                OOM,
                NODRIVER,
                SYSTEM,
                CORRUPT,
                TOOBIG,
                NOTFOUND,
                DESTROYED,
                CANCELED,
                NOTAVAILABLE,
                ACCESS,
                IO,
                INTERNAL,
                DISABLED,
                FORKED,
                DISCONNECTED,

                [CCode (cname = "_CA_ERROR_MAX")]
                _MAX
        }

        public unowned string? strerror(int code);

        public delegate void FinishCallback(Context c, uint32 id, int code);

        [Compact]
        [CCode (cname = "ca_proplist", free_function = "ca_proplist_destroy")]
        public class Proplist {
                public static int create(out Proplist p);
                public int sets(string key, string value);
                [PrintfFormat]
                public int setf(string key, string format, ...);
                public int set(string key, void* data, size_t nbytes);
        }

        [Compact]
        [CCode (cname = "ca_context", free_function = "ca_context_destroy")]
        public class Context {
                public static int create(out Context context);
                public int set_driver(string? driver = null);
                public int change_device(string? device = null);
                public int open();
                public int change_props(...);
                public int change_props_full(Proplist p);
                public int play_full(uint32 id, Proplist p, FinishCallback? cb = null);
                public int play(uint32 id, ...);
                public int cache_full(Proplist p);
                public int cache(...);
                public int cancel(uint32 id);
                public int playing(uint32 id, out bool playing);
        }
}
