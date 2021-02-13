gnome_pomodoro_test_vala_sources = [
  'tests.vala',
  'test-application.vala',
  'test-capability.vala',
  'test-capability-group.vala',
  'test-capability-manager.vala',
  'test-timer.vala',
]

test_executable = executable(
  'gnome-pomodoro-test-executable',
  gnome_pomodoro_test_vala_sources,
  dependencies: gnome_pomodoro_lib_dep,
)

test(
  'gnome-pomodoro-tests',
  test_executable,
)