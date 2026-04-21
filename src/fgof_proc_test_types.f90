module fgof_proc_test_types
  implicit none
  private

  integer, parameter, public :: FGOF_PROC_TEST_OK = 0
  integer, parameter, public :: FGOF_PROC_TEST_ERR_INVALID_OPTIONS = 10
  integer, parameter, public :: FGOF_PROC_TEST_ERR_SPAWN_FAILED = 20
  integer, parameter, public :: FGOF_PROC_TEST_ERR_CLEANUP_FAILED = 21
  integer, parameter, public :: FGOF_PROC_TEST_ERR_INTERNAL = 99

  type, public :: fixture_options
    integer :: timeout_ms = 1000
    integer :: retries = 0
    logical :: capture_output = .true.
    logical :: cleanup_on_failure = .true.
  end type fixture_options

  type, public :: process_fixture
    logical :: active = .false.
    integer :: error_code = FGOF_PROC_TEST_OK
    character(len=:), allocatable :: error_message
    character(len=:), allocatable :: name
  end type process_fixture

end module fgof_proc_test_types
