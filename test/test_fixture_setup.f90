program test_fixture_setup
  use fgof_process, only : shell
  use fgof_proc_test, only : &
    FGOF_PROC_TEST_ERR_SETUP_FAILED, &
    cleanup_fixture, &
    clear_fixture_options, &
    fixture_ready, &
    make_fixture, &
    run_fixture
  use fgof_proc_test_types, only : fixture_options, process_fixture
  implicit none

  type(fixture_options) :: options
  type(process_fixture) :: fixture
  logical :: exists
  character(len=*), parameter :: marker = "./fgof-proc-test-setup-marker.tmp"

  call execute_command_line("rm -f " // marker)

  options = clear_fixture_options()
  options%timeout_ms = 500
  options%ready_text = "READY"
  options%cleanup_on_failure = .true.

  fixture = make_fixture( &
    "setup-success", &
    shell("if [ -f '" // marker // "' ]; then printf READY; else exit 9; fi"), &
    options, &
    cleanup_cmd=shell("rm -f '" // marker // "'"), &
    setup_cmd=shell("printf MADE; touch '" // marker // "'"))

  if (.not. run_fixture(fixture)) error stop "fixture with successful setup should run"
  if (.not. fixture_ready(fixture)) error stop "successful setup fixture should report ready"
  if (.not. fixture%setup_completed) error stop "successful setup should mark setup complete"
  if (fixture%setup_result%stdout /= "MADE") error stop "setup output should be captured"
  inquire(file=marker, exist=exists)
  if (.not. exists) error stop "setup command should create the marker file"

  if (.not. cleanup_fixture(fixture)) error stop "successful setup fixture cleanup should succeed"
  inquire(file=marker, exist=exists)
  if (exists) error stop "cleanup should remove the setup marker file"

  fixture = make_fixture( &
    "setup-fails", &
    shell("printf NEVER"), &
    options, &
    cleanup_cmd=shell("rm -f '" // marker // "'"), &
    setup_cmd=shell("touch '" // marker // "'; printf nope >&2; exit 4"))

  if (run_fixture(fixture)) error stop "fixture with failing setup should not run successfully"
  if (fixture%error_code /= FGOF_PROC_TEST_ERR_SETUP_FAILED) error stop "setup failure should set setup-failed"
  if (fixture%setup_completed) error stop "failed setup should not mark setup complete"
  if (index(fixture%setup_result%stderr, "nope") <= 0) error stop "setup stderr should be captured"
  if (.not. fixture%cleaned_up) error stop "setup failure should trigger cleanup when configured"
  inquire(file=marker, exist=exists)
  if (exists) error stop "cleanup on setup failure should remove the marker file"
end program test_fixture_setup
