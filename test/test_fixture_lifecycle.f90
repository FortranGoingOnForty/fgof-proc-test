program test_fixture_lifecycle
  use fgof_process, only : shell
  use fgof_proc_test, only : &
    FGOF_PROC_TEST_OK, &
    cleanup_fixture, &
    clear_fixture_options, &
    fixture_ready, &
    fixture_result, &
    make_fixture, &
    run_fixture
  use fgof_proc_test_types, only : fixture_options, process_fixture
  use fgof_process_types, only : process_result
  implicit none

  type(fixture_options) :: options
  type(process_fixture) :: fixture
  type(process_result) :: result

  options = clear_fixture_options()
  options%timeout_ms = 500
  options%ready_text = "READY"

  fixture = make_fixture("ready-fixture", shell("printf READY"), options)
  if (.not. run_fixture(fixture)) error stop "ready fixture should run successfully"
  if (.not. fixture_ready(fixture)) error stop "successful fixture should report ready"
  if (fixture%attempts /= 1) error stop "successful fixture should use one attempt"
  result = fixture_result(fixture)
  if (result%stdout /= "READY") error stop "fixture stdout should be captured"
  if (fixture%error_code /= FGOF_PROC_TEST_OK) error stop "successful fixture should not set an error"

  if (.not. cleanup_fixture(fixture)) error stop "cleanup without a cleanup command should still succeed"
  if (.not. fixture%cleaned_up) error stop "cleanup should mark the fixture cleaned"
  if (fixture%active) error stop "cleanup should clear active state"
end program test_fixture_lifecycle
