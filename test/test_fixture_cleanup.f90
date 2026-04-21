program test_fixture_cleanup
  use fgof_process, only : shell
  use fgof_proc_test, only : &
    FGOF_PROC_TEST_ERR_SPAWN_FAILED, &
    cleanup_fixture, &
    clear_fixture_options, &
    fixture_ready, &
    make_fixture, &
    run_fixture
  use fgof_proc_test_types, only : fixture_options, process_fixture
  implicit none

  type(fixture_options) :: options
  type(process_fixture) :: fixture

  options = clear_fixture_options()
  options%timeout_ms = 500
  options%cleanup_on_failure = .true.

  fixture = make_fixture("cleanup-fixture", shell("printf nope; exit 1"), options, shell("printf CLEANED"))
  if (run_fixture(fixture)) error stop "failing fixture should not report success"
  if (fixture_ready(fixture)) error stop "failing fixture should not report ready"
  if (fixture%error_code /= FGOF_PROC_TEST_ERR_SPAWN_FAILED) error stop "failed fixture should report spawn-failed"
  if (.not. fixture%cleaned_up) error stop "failed fixture should auto-clean when configured"
  if (fixture%cleanup_result%stdout /= "CLEANED") error stop "cleanup result should be captured"
  if (fixture%active) error stop "failed fixture cleanup should leave the fixture inactive"

  if (.not. cleanup_fixture(fixture)) error stop "cleanup should remain callable after failure"
end program test_fixture_cleanup
