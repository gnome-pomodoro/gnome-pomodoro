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
