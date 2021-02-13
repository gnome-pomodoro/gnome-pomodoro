libdark_theme_vala_sources = [
  'dark-theme-plugin.vala',
]

shared_library(
  'dark-theme',
  libdark_theme_vala_sources,
  dependencies: gnome_pomodoro_lib_dep,
  install: true,
  install_dir: plugin_libdir,
)

install_data(
  'dark-theme.plugin',
  install_dir: plugin_libdir,
)
