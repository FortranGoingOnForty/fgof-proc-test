module fgof_proc_test_types
  use fgof_process_types, only : &
    FGOF_PROCESS_MODE_NONE, &
    process_command, &
    process_result
  implicit none
  private

  integer, parameter, public :: FGOF_PROC_TEST_OK = 0
  integer, parameter, public :: FGOF_PROC_TEST_ERR_INVALID_OPTIONS = 10
  integer, parameter, public :: FGOF_PROC_TEST_ERR_SPAWN_FAILED = 20
  integer, parameter, public :: FGOF_PROC_TEST_ERR_READINESS_FAILED = 21
  integer, parameter, public :: FGOF_PROC_TEST_ERR_CLEANUP_FAILED = 22
  integer, parameter, public :: FGOF_PROC_TEST_ERR_INTERNAL = 99

  type, public :: fixture_options
    integer :: timeout_ms = 1000
    integer :: retries = 0
    logical :: capture_output = .true.
    logical :: cleanup_on_failure = .true.
    character(len=:), allocatable :: ready_text
    character(len=:), allocatable :: cwd
    character(len=:), allocatable :: env_set(:)
    character(len=:), allocatable :: env_unset(:)
  end type fixture_options

  type, public :: process_fixture
    logical :: active = .false.
    logical :: ready = .false.
    logical :: cleaned_up = .false.
    integer :: attempts = 0
    integer :: error_code = FGOF_PROC_TEST_OK
    character(len=:), allocatable :: error_message
    character(len=:), allocatable :: name
    type(fixture_options) :: options
    type(process_command) :: command
    type(process_command) :: cleanup_command
    type(process_result) :: last_result
    type(process_result) :: cleanup_result
  end type process_fixture

end module fgof_proc_test_types
