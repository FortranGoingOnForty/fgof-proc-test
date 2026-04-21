program test_failure_edges
  use fgof_process, only : shell
  use fgof_proc_test, only : &
    FGOF_PROC_TEST_ERR_SETUP_FAILED, &
    FGOF_PROC_TEST_ERR_SPAWN_FAILED, &
    cleanup_fixture, &
    clear_fixture_options, &
    fixture_diagnostics, &
    fixture_ready, &
    make_fixture, &
    run_fixture
  use fgof_proc_test_types, only : fixture_options, process_fixture
  implicit none

  type(fixture_options) :: options
  type(process_fixture) :: fixture
  character(len=:), allocatable :: diagnostics

  options = clear_fixture_options()
  options%timeout_ms = 500
  options%capture_output = .false.
  options%ready_text = "READY"

  fixture = make_fixture("ready-without-capture", shell("printf READY"), options)
  if (.not. run_fixture(fixture)) error stop "ready fixture should still run with capture_output disabled"
  if (.not. fixture_ready(fixture)) error stop "ready fixture should still satisfy readiness checks"
  if (fixture%last_result%stdout /= "READY") error stop "readiness should still capture output when needed"
  if (.not. cleanup_fixture(fixture)) error stop "cleanup should succeed for readiness fixture"

  options = clear_fixture_options()
  options%timeout_ms = 500
  options%cleanup_on_failure = .true.

  fixture = make_fixture( &
    "cleanup-preserves-root-cause", &
    shell("printf boom >&2; exit 3"), &
    options, &
    cleanup_cmd=shell("printf CLEANUP >&2; exit 8"))

  if (run_fixture(fixture)) error stop "failing fixture should not report success"
  if (fixture%error_code /= FGOF_PROC_TEST_ERR_SPAWN_FAILED) error stop "cleanup failure should not clobber the root failure code"
  if (index(fixture%error_message, "cleanup_failure=") <= 0) error stop "error message should retain cleanup failure details"
  diagnostics = fixture_diagnostics(fixture)
  if (index(diagnostics, "cleanup_stderr=CLEANUP") <= 0) error stop "diagnostics should include cleanup stderr"

  fixture = make_fixture( &
    "setup-diag", &
    shell("printf NEVER"), &
    options, &
    setup_cmd=shell("printf PREP >&2; exit 4"))

  if (run_fixture(fixture)) error stop "setup failure fixture should not report success"
  if (fixture%error_code /= FGOF_PROC_TEST_ERR_SETUP_FAILED) error stop "setup failure should still set setup-failed"
  diagnostics = fixture_diagnostics(fixture)
  if (index(diagnostics, "setup_stderr=PREP") <= 0) error stop "diagnostics should include setup stderr"
end program test_failure_edges
