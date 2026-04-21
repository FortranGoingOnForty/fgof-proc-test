program test_fixture_retries
  use fgof_process, only : shell
  use fgof_proc_test, only : &
    cleanup_fixture, &
    clear_fixture_options, &
    fixture_ready, &
    make_fixture, &
    retry_fixture
  use fgof_proc_test_types, only : fixture_options, process_fixture
  implicit none

  type(fixture_options) :: options
  type(process_fixture) :: fixture
  character(len=*), parameter :: retry_marker = "./fgof-proc-test-retry-state.tmp"
  character(len=*), parameter :: cleanup_marker = "./fgof-proc-test-retry-cleanup.tmp"
  character(len=:), allocatable :: start_command
  character(len=:), allocatable :: cleanup_command

  call execute_command_line("rm -f " // retry_marker // " " // cleanup_marker)

  start_command = &
    "if [ -f '" // retry_marker // "' ]; then printf READY; exit 0; else touch '" // retry_marker // "'; exit 1; fi"
  cleanup_command = "touch '" // cleanup_marker // "'; rm -f '" // cleanup_marker // "'"

  options = clear_fixture_options()
  options%timeout_ms = 500
  options%ready_text = "READY"

  fixture = make_fixture("retry-fixture", shell(start_command), options, shell(cleanup_command))
  if (.not. retry_fixture(fixture, retries=1, retry_delay_ms=1)) error stop "fixture should succeed on the retry attempt"
  if (.not. fixture_ready(fixture)) error stop "retried fixture should report ready"
  if (fixture%attempts /= 2) error stop "fixture should record both attempts"
  if (fixture%options%retries /= 1) error stop "retry helper should update fixture retry count"
  if (fixture%options%retry_delay_ms /= 1) error stop "retry helper should update fixture retry delay"

  if (.not. cleanup_fixture(fixture)) error stop "explicit cleanup should succeed"
  call execute_command_line("rm -f " // retry_marker // " " // cleanup_marker)

  start_command = &
    "if [ -f '" // cleanup_marker // "' ]; then printf stale >&2; exit 9; else touch '" // cleanup_marker // &
    "'; exit 1; fi"
  cleanup_command = "rm -f '" // cleanup_marker // "'; printf RESET"

  options = clear_fixture_options()
  options%timeout_ms = 500
  options%cleanup_on_failure = .false.

  fixture = make_fixture("isolated-retry", shell(start_command), options, shell(cleanup_command))
  if (retry_fixture(fixture, retries=1, retry_delay_ms=1)) error stop "isolated retry fixture should still fail"
  if (fixture%attempts /= 2) error stop "isolated retry fixture should use both attempts"
  if (fixture%last_result%exit_code /= 1) error stop "retry cleanup should reset the fixture state between attempts"
  if (index(fixture%last_result%stderr, "stale") > 0) error stop "stale state should not leak into the retried attempt"
  if (fixture%cleanup_result%stdout /= "RESET") error stop "between-attempt cleanup should be recorded"
  call execute_command_line("rm -f " // retry_marker // " " // cleanup_marker)
end program test_fixture_retries
