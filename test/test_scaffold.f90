program test_scaffold
  use fgof_proc_test, only : &
    FGOF_PROC_TEST_OK, &
    clear_fixture_options, &
    clear_process_fixture, &
    fixture_ready, &
    proc_test_backend_name, &
    proc_test_error_name
  use fgof_proc_test_types, only : fixture_options, process_fixture
  implicit none

  type(fixture_options) :: options
  type(process_fixture) :: fixture

  options = clear_fixture_options()
  if (options%timeout_ms /= 1000) error stop "default timeout should be 1000 ms"
  if (options%retries /= 0) error stop "default retries should be zero"
  if (options%retry_delay_ms /= 0) error stop "default retry delay should be zero"
  if (.not. options%capture_output) error stop "capture_output should default true"
  if (.not. options%cleanup_on_failure) error stop "cleanup_on_failure should default true"
  if (allocated(options%ready_text)) error stop "ready_text should be unset by default"
  if (allocated(options%cwd)) error stop "cwd should be unset by default"

  fixture = clear_process_fixture()
  if (fixture%active) error stop "new scaffold fixture should be inactive"
  if (fixture%ready) error stop "new scaffold fixture should not be ready"
  if (fixture%cleaned_up) error stop "new scaffold fixture should not start cleaned up"
  if (fixture%attempts /= 0) error stop "new scaffold fixture should have zero attempts"
  if (fixture%error_code /= FGOF_PROC_TEST_OK) error stop "new scaffold fixture should be ok"
  if (fixture%error_message /= "") error stop "new scaffold fixture should have no message"
  if (fixture%name /= "") error stop "new scaffold fixture should have no name"
  if (fixture_ready(fixture)) error stop "cleared fixture should not report ready"

  if (proc_test_backend_name() /= "fgof-process") error stop "backend name should explain the planned dependency"
  if (proc_test_error_name(FGOF_PROC_TEST_OK) /= "ok") error stop "error helper should map ok"
  if (proc_test_error_name(30) /= "assertion-failed") error stop "error helper should map assertion failures"
  if (proc_test_error_name(999) /= "unknown") error stop "error helper should map unknown codes"
end program test_scaffold
