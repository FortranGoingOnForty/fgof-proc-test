program assertion_demo
  use fgof_process, only : shell
  use fgof_proc_test, only : &
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

  fixture = make_fixture("assert-demo", shell("printf hello"), options)

  if (run_fixture(fixture)) then
    if (assert_fixture_success(fixture) .and. assert_fixture_stdout_contains(fixture, "hello")) then
      print *, "ok"
    else
      print *, trim(fixture_diagnostics(fixture))
    end if
  else
    print *, trim(fixture_diagnostics(fixture))
  end if

  if (.not. cleanup_fixture(fixture)) print *, trim(fixture%error_message)
end program assertion_demo
