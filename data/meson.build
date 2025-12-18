# D-Bus
dbus_conf = configuration_data()
dbus_conf.set(
  'bindir',
  get_option('prefix') / get_option('bindir'),
)

configure_file(
  input: 'org.gnomepomodoro.Pomodoro.service.in',
  output: '@BASENAME@',
  configuration: dbus_conf,
  install_dir: get_option('datadir') / 'dbus-1' / 'services',
)

install_data(
  'org.gnomepomodoro.Pomodoro.xml',
  'org.gnomepomodoro.Pomodoro.Session.xml',
  'org.gnomepomodoro.Pomodoro.Timer.xml',
  install_dir: get_option('datadir') / 'dbus-1' / 'interfaces',
)

# Desktop file
desktop_file = i18n.merge_file(
  input: 'org.gnomepomodoro.Pomodoro.desktop.in',
  output: '@BASENAME@',
  install: true,
  install_dir:  get_option('datadir') / 'applications',
  po_dir: '..' / 'po',
  type: 'desktop',
)

desktop_file_validate = find_program('desktop-file-validate', required:false)
if desktop_file_validate.found()
  test (
    'Validate .desktop',
    desktop_file_validate,
    args: [desktop_file.full_path()]
  )
endif

# Appdata
appdata = i18n.merge_file(
  input: 'org.gnomepomodoro.Pomodoro.metainfo.xml.in',
  output: '@BASENAME@',
  install: true,
  install_dir: get_option('datadir') / 'metainfo',
  po_dir: '..' / 'po',
)

appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
  test(
    'Validate .metainfo.xml',
    appstreamcli,
    args: [
      'validate', '--no-net', '--explain', appdata.full_path()
    ]
  )
endif

# GSchema
install_data(
  'org.gnomepomodoro.Pomodoro.gschema.xml',
  install_dir: gschema_dir,
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file', compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()]
  )
endif

compiled_schemas = gnome.compile_schemas(
  depend_files: 'org.gnomepomodoro.Pomodoro.gschema.xml'
)

# Run required post-install steps
gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)

# Assets
subdir('icons')
subdir('sounds')
