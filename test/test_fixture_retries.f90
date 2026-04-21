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
  character(len=*), parameter :: marker = "./fgof-proc-test-retry-marker.tmp"
  character(len=:), allocatable :: start_command
  character(len=:), allocatable :: cleanup_command

  call execute_command_line("rm -f " // marker)

  start_command = &
    "if [ -f '" // marker // "' ]; then printf READY; rm -f '" // marker // &
    "'; exit 0; else touch '" // marker // "'; exit 1; fi"
  cleanup_command = "rm -f '" // marker // "'"

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
  call execute_command_line("rm -f " // marker)
end program test_fixture_retries
