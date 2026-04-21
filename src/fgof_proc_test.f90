module fgof_proc_test
  use fgof_proc_test_types, only : &
    FGOF_PROC_TEST_ERR_CLEANUP_FAILED, &
    FGOF_PROC_TEST_ERR_INTERNAL, &
    FGOF_PROC_TEST_ERR_INVALID_OPTIONS, &
    FGOF_PROC_TEST_ERR_SPAWN_FAILED, &
    FGOF_PROC_TEST_OK, &
    fixture_options, &
    process_fixture
  implicit none
  private

  public :: &
    FGOF_PROC_TEST_ERR_CLEANUP_FAILED, &
    FGOF_PROC_TEST_ERR_INTERNAL, &
    FGOF_PROC_TEST_ERR_INVALID_OPTIONS, &
    FGOF_PROC_TEST_ERR_SPAWN_FAILED, &
    FGOF_PROC_TEST_OK, &
    clear_fixture_options, &
    clear_process_fixture, &
    fixture_options, &
    process_fixture, &
    proc_test_backend_name, &
    proc_test_error_name

contains

  function clear_fixture_options() result(options)
    type(fixture_options) :: options

    options%timeout_ms = 1000
    options%retries = 0
    options%capture_output = .true.
    options%cleanup_on_failure = .true.
  end function clear_fixture_options

  function clear_process_fixture() result(fixture)
    type(process_fixture) :: fixture

    fixture%active = .false.
    fixture%error_code = FGOF_PROC_TEST_OK
    fixture%error_message = ""
    fixture%name = ""
  end function clear_process_fixture

  function proc_test_backend_name() result(name)
    character(len=:), allocatable :: name

    name = "fgof-process"
  end function proc_test_backend_name

  function proc_test_error_name(code) result(name)
    integer, intent(in) :: code
    character(len=:), allocatable :: name

    select case (code)
    case (FGOF_PROC_TEST_OK)
      name = "ok"
    case (FGOF_PROC_TEST_ERR_INVALID_OPTIONS)
      name = "invalid-options"
    case (FGOF_PROC_TEST_ERR_SPAWN_FAILED)
      name = "spawn-failed"
    case (FGOF_PROC_TEST_ERR_CLEANUP_FAILED)
      name = "cleanup-failed"
    case (FGOF_PROC_TEST_ERR_INTERNAL)
      name = "internal"
    case default
      name = "unknown"
    end select
  end function proc_test_error_name

end module fgof_proc_test
