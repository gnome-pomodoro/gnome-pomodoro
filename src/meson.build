libgnome_pomodoro_vala_sources = [
  'about-dialog.vala',
  'accelerator.vala',
  'aggregated-entry.vala',
  'animation.vala',
  'application.vala',
  'capability-group.vala',
  'capability-manager.vala',
  'capability.vala',
  'desktop-extension.vala',
  'entry.vala',
  'log-scale.vala',
  'notifications-capability.vala',
  'preferences-dialog.vala',
  'presence.vala',
  'screen-notification.vala',
  'service.vala',
  'settings.vala',
  'stats-page.vala',
  'stats-view.vala',
  'stats-day-page.vala',
  'stats-week-page.vala',
  'stats-month-page.vala',
  'timer.vala',
  'timer-action-group.vala',
  'timer-state.vala',
  'utils.vala',
  'window.vala',
  gnome_pomodoro_generated_sources,
]

libgnome_pomodoro = shared_library(
  'gnome-pomodoro',
  libgnome_pomodoro_vala_sources,
  dependencies: [
    gio_dep,
    gobject_dep,
    gom_dep,
    gtk_dep,
    libm_dep,
    peas_dep,
    sqlite_dep,
  ],
  # include config.h
  include_directories: incs,
  version: '0.0.0',
  install: true,
)

gnome_pomodoro_lib_dep = declare_dependency(
  link_with: libgnome_pomodoro,
  dependencies: [
    gio_dep,
    gobject_dep,
    peas_dep,
    gtk_dep,
    cairo_dep,
  ],
  include_directories: [
    # Include gnome-pomodoro.h
    include_directories('.'),
    # Include config.h
    include_directories('..'),
  ],
)

gnome_pomodoro_vala_sources = [
  'main.vala',
]

executable(
  'gnome-pomodoro',
  gnome_pomodoro_vala_sources,
  dependencies: [
    gnome_pomodoro_lib_dep,
    posix_dep,
  ],
  include_directories: incs,
  install: true,
)
