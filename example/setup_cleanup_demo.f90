program setup_cleanup_demo
  use fgof_process, only : shell
  use fgof_proc_test, only : &
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

  options = clear_fixture_options()
  options%timeout_ms = 500
  options%ready_text = "READY"

  fixture = make_fixture( &
    "setup-demo", &
    shell("printf READY"), &
    options, &
    cleanup_cmd=shell("printf CLEANED >/dev/null"), &
    setup_cmd=shell("printf MADE >/dev/null"))

  if (run_fixture(fixture)) then
    if (fixture_ready(fixture)) print *, "ready"
  else
    print *, trim(fixture_diagnostics(fixture))
  end if

  if (.not. cleanup_fixture(fixture)) print *, trim(fixture%error_message)
end program setup_cleanup_demo
