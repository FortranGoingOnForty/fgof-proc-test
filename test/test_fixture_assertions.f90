program test_fixture_assertions
  use fgof_process, only : shell
  use fgof_proc_test, only : &
    FGOF_PROC_TEST_ERR_ASSERTION_FAILED, &
    assert_fixture_exit_code, &
    assert_fixture_output_contains, &
    assert_fixture_stderr_contains, &
    assert_fixture_stdout_contains, &
    assert_fixture_success, &
    cleanup_fixture, &
    clear_fixture_options, &
    fixture_diagnostics, &
    make_fixture, &
    run_fixture
  use fgof_proc_test_types, only : fixture_options, process_fixture
  implicit none

  type(fixture_options) :: options
  type(process_fixture) :: fixture

  options = clear_fixture_options()
  options%timeout_ms = 500

  fixture = make_fixture("assert-success", shell("printf done"), options)
  if (.not. run_fixture(fixture)) error stop "success fixture should run"
  if (.not. assert_fixture_success(fixture)) error stop "success assertion should pass"
  if (.not. assert_fixture_exit_code(fixture, 0)) error stop "exit code assertion should pass for zero"
  if (.not. assert_fixture_stdout_contains(fixture, "done")) error stop "stdout assertion should pass"
  if (.not. assert_fixture_output_contains(fixture, "done")) error stop "combined output assertion should pass"
  if (.not. cleanup_fixture(fixture)) error stop "success fixture cleanup should succeed"

  fixture = make_fixture("assert-nonzero", shell("printf warn >&2; exit 7"), options)
  if (run_fixture(fixture)) error stop "nonzero fixture should not report success"
  if (.not. assert_fixture_exit_code(fixture, 7)) error stop "exit code assertion should pass for expected nonzero exit"
  if (.not. assert_fixture_stderr_contains(fixture, "warn")) error stop "stderr assertion should pass"
  if (.not. assert_fixture_output_contains(fixture, "warn")) error stop "combined output should include stderr text"

  if (assert_fixture_success(fixture)) error stop "success assertion should fail for nonzero exit"
  if (fixture%error_code /= FGOF_PROC_TEST_ERR_ASSERTION_FAILED) error stop "failed assertion should set assertion-failed"
  if (index(fixture%error_message, "complete successfully") <= 0) error stop "failed success assertion should explain the mismatch"
  if (index(fixture%error_message, "fixture=assert-nonzero") <= 0) error stop "failed assertion should include fixture diagnostics"
  if (index(fixture%error_message, "last_exit_code=7") <= 0) error stop "diagnostics should include the observed exit code"

  if (assert_fixture_stdout_contains(fixture, "missing")) error stop "stdout assertion should fail for missing text"
  if (fixture%error_code /= FGOF_PROC_TEST_ERR_ASSERTION_FAILED) error stop "failed output assertion should set assertion-failed"
  if (index(fixture_diagnostics(fixture), "stderr=warn") <= 0) error stop "fixture diagnostics should include captured stderr"

  if (.not. cleanup_fixture(fixture)) error stop "nonzero fixture cleanup should still succeed"
end program test_fixture_assertions
