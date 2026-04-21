module fgof_proc_test
  use fgof_process, only : &
    FGOF_PROCESS_ERR_EXEC_FAILED, &
    FGOF_PROCESS_ERR_INTERNAL, &
    FGOF_PROCESS_ERR_INVALID_COMMAND, &
    FGOF_PROCESS_ERR_INVALID_OPTION, &
    FGOF_PROCESS_ERR_PIPE_FAILED, &
    FGOF_PROCESS_ERR_SPAWN_FAILED, &
    FGOF_PROCESS_ERR_TIMEOUT, &
    FGOF_PROCESS_MODE_NONE, &
    FGOF_PROCESS_OK, &
    process_command, &
    process_options, &
    process_result, &
    run
  use fgof_proc_test_types, only : &
    FGOF_PROC_TEST_ERR_ASSERTION_FAILED, &
    FGOF_PROC_TEST_ERR_CLEANUP_FAILED, &
    FGOF_PROC_TEST_ERR_INTERNAL, &
    FGOF_PROC_TEST_ERR_INVALID_OPTIONS, &
    FGOF_PROC_TEST_ERR_READINESS_FAILED, &
    FGOF_PROC_TEST_ERR_SETUP_FAILED, &
    FGOF_PROC_TEST_ERR_SPAWN_FAILED, &
    FGOF_PROC_TEST_OK, &
    fixture_options, &
    process_fixture
  implicit none
  private

  public :: &
    FGOF_PROC_TEST_ERR_ASSERTION_FAILED, &
    FGOF_PROC_TEST_ERR_CLEANUP_FAILED, &
    FGOF_PROC_TEST_ERR_INTERNAL, &
    FGOF_PROC_TEST_ERR_INVALID_OPTIONS, &
    FGOF_PROC_TEST_ERR_READINESS_FAILED, &
    FGOF_PROC_TEST_ERR_SETUP_FAILED, &
    FGOF_PROC_TEST_ERR_SPAWN_FAILED, &
    FGOF_PROC_TEST_OK, &
    assert_fixture_exit_code, &
    assert_fixture_output_contains, &
    assert_fixture_stderr_contains, &
    assert_fixture_stdout_contains, &
    assert_fixture_success, &
    cleanup_fixture, &
    clear_fixture_options, &
    clear_process_fixture, &
    fixture_diagnostics, &
    fixture_ready, &
    fixture_result, &
    fixture_options, &
    make_fixture, &
    proc_test_backend_name, &
    proc_test_error_name, &
    process_fixture, &
    retry_fixture, &
    run_fixture

contains

  function clear_fixture_options() result(options)
    type(fixture_options) :: options

    options%timeout_ms = 1000
    options%retries = 0
    options%retry_delay_ms = 0
    options%capture_output = .true.
    options%cleanup_on_failure = .true.
    allocate(character(len=1) :: options%env_set(0))
    allocate(character(len=1) :: options%env_unset(0))
  end function clear_fixture_options

  function clear_process_fixture() result(fixture)
    type(process_fixture) :: fixture

    fixture%active = .false.
    fixture%ready = .false.
    fixture%setup_completed = .false.
    fixture%cleaned_up = .false.
    fixture%attempts = 0
    fixture%error_code = FGOF_PROC_TEST_OK
    fixture%error_message = ""
    fixture%name = ""
    fixture%options = clear_fixture_options()
    fixture%command%mode = FGOF_PROCESS_MODE_NONE
    fixture%setup_command%mode = FGOF_PROCESS_MODE_NONE
    fixture%cleanup_command%mode = FGOF_PROCESS_MODE_NONE
    fixture%setup_result = clear_process_result()
    fixture%last_result = clear_process_result()
    fixture%cleanup_result = clear_process_result()
  end function clear_process_fixture

  function make_fixture(name, cmd, options, cleanup_cmd, setup_cmd) result(fixture)
    character(len=*), intent(in) :: name
    type(process_command), intent(in) :: cmd
    type(fixture_options), intent(in), optional :: options
    type(process_command), intent(in), optional :: cleanup_cmd
    type(process_command), intent(in), optional :: setup_cmd
    type(process_fixture) :: fixture

    fixture = clear_process_fixture()
    fixture%name = name
    fixture%command = cmd
    if (present(options)) fixture%options = options
    if (present(cleanup_cmd)) fixture%cleanup_command = cleanup_cmd
    if (present(setup_cmd)) fixture%setup_command = setup_cmd
  end function make_fixture

  logical function run_fixture(fixture) result(success)
    type(process_fixture), intent(inout) :: fixture
    type(process_options) :: run_options
    integer :: attempt
    integer :: max_attempts
    logical :: cleanup_ok

    call clear_fixture_error(fixture)
    fixture%active = .false.
    fixture%ready = .false.
    fixture%setup_completed = .false.
    fixture%cleaned_up = .false.
    fixture%attempts = 0
    fixture%setup_result = clear_process_result()
    fixture%last_result = clear_process_result()
    fixture%cleanup_result = clear_process_result()

    if (.not. valid_fixture(fixture)) then
      call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_INVALID_OPTIONS, &
        "fixture must provide a name, command, and valid options")
      success = .false.
      return
    end if

    run_options = build_process_options(fixture%options, need_capture(fixture))
    max_attempts = fixture%options%retries + 1
    success = .false.

    do attempt = 1, max_attempts
      fixture%attempts = attempt
      fixture%setup_completed = .false.
      fixture%setup_result = clear_process_result()
      fixture%last_result = clear_process_result()

      if (.not. run_setup_step(fixture)) then
        if (attempt < max_attempts .and. fixture%options%retry_delay_ms > 0) then
          call sleep_milliseconds(fixture%options%retry_delay_ms)
        end if
        cycle
      end if

      fixture%last_result = run(fixture%command, run_options)

      if (fixture%last_result%error_code == FGOF_PROCESS_OK) then
        if (fixture%last_result%completed .and. fixture%last_result%exited_normally .and. &
            fixture%last_result%exit_code == 0) then
          if (matches_readiness(fixture, fixture%last_result)) then
            fixture%ready = .true.
            fixture%active = .true.
            success = .true.
            return
          end if

          call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_READINESS_FAILED, &
            "fixture output did not satisfy readiness checks")
        else
          call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_SPAWN_FAILED, &
            "fixture command exited unsuccessfully")
        end if
      else
        call map_process_error(fixture, fixture%last_result)
      end if

      if (attempt < max_attempts .and. fixture%options%retry_delay_ms > 0) then
        call sleep_milliseconds(fixture%options%retry_delay_ms)
      end if
    end do

    if (fixture%options%cleanup_on_failure) cleanup_ok = cleanup_fixture(fixture)
  end function run_fixture

  logical function retry_fixture(fixture, retries, retry_delay_ms) result(success)
    type(process_fixture), intent(inout) :: fixture
    integer, intent(in), optional :: retries
    integer, intent(in), optional :: retry_delay_ms

    if (present(retries)) fixture%options%retries = retries
    if (present(retry_delay_ms)) fixture%options%retry_delay_ms = retry_delay_ms
    success = run_fixture(fixture)
  end function retry_fixture

  logical function cleanup_fixture(fixture) result(success)
    type(process_fixture), intent(inout) :: fixture
    type(process_options) :: cleanup_options

    if (fixture%cleaned_up) then
      fixture%active = .false.
      success = .true.
      return
    end if

    if (fixture%cleanup_command%mode == FGOF_PROCESS_MODE_NONE) then
      fixture%cleaned_up = .true.
      fixture%active = .false.
      success = .true.
      return
    end if

    cleanup_options = build_process_options(fixture%options, .true.)
    fixture%cleanup_result = run(fixture%cleanup_command, cleanup_options)
    fixture%cleaned_up = .true.
    fixture%active = .false.

    if (fixture%cleanup_result%error_code /= FGOF_PROCESS_OK) then
      call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_CLEANUP_FAILED, &
        cleanup_message("cleanup process reported a backend error", fixture%cleanup_result))
      success = .false.
      return
    end if

    if (.not. fixture%cleanup_result%completed .or. .not. fixture%cleanup_result%exited_normally .or. &
        fixture%cleanup_result%exit_code /= 0) then
      call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_CLEANUP_FAILED, &
        "cleanup command exited unsuccessfully")
      success = .false.
      return
    end if

    success = .true.
  end function cleanup_fixture

  logical function fixture_ready(fixture) result(ready)
    type(process_fixture), intent(in) :: fixture

    ready = fixture%active .and. fixture%ready
  end function fixture_ready

  function fixture_result(fixture) result(res)
    type(process_fixture), intent(in) :: fixture
    type(process_result) :: res

    res = fixture%last_result
  end function fixture_result

  function fixture_diagnostics(fixture) result(text)
    type(process_fixture), intent(in) :: fixture
    character(len=:), allocatable :: text
    character(len=*), parameter :: nl = new_line('a')

    text = "fixture=" // fixture_name(fixture) // nl // &
      "error=" // proc_test_error_name(fixture%error_code) // nl // &
      "message=" // fixture_message_text(fixture) // nl // &
      "attempts=" // int_text(fixture%attempts) // nl // &
      "ready=" // logical_text(fixture%ready) // nl // &
      "active=" // logical_text(fixture%active) // nl // &
      "setup_completed=" // logical_text(fixture%setup_completed) // nl // &
      "cleaned_up=" // logical_text(fixture%cleaned_up) // nl // &
      "setup_exit_code=" // int_text(fixture%setup_result%exit_code) // nl // &
      "last_exit_code=" // int_text(fixture%last_result%exit_code) // nl // &
      "cleanup_exit_code=" // int_text(fixture%cleanup_result%exit_code) // nl // &
      "stdout=" // fixture%last_result%stdout // nl // &
      "stderr=" // fixture%last_result%stderr
  end function fixture_diagnostics

  logical function assert_fixture_success(fixture) result(success)
    type(process_fixture), intent(inout) :: fixture

    success = fixture%last_result%error_code == FGOF_PROCESS_OK .and. &
      fixture%last_result%completed .and. &
      fixture%last_result%exited_normally .and. &
      fixture%last_result%exit_code == 0

    if (.not. success) then
      call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_ASSERTION_FAILED, &
        assertion_message("fixture did not complete successfully", fixture))
    end if
  end function assert_fixture_success

  logical function assert_fixture_exit_code(fixture, expected_exit_code) result(success)
    type(process_fixture), intent(inout) :: fixture
    integer, intent(in) :: expected_exit_code

    success = fixture%last_result%completed .and. fixture%last_result%exited_normally .and. &
      fixture%last_result%exit_code == expected_exit_code

    if (.not. success) then
      call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_ASSERTION_FAILED, &
        assertion_message(exit_code_message(expected_exit_code, fixture%last_result%exit_code), fixture))
    end if
  end function assert_fixture_exit_code

  logical function assert_fixture_stdout_contains(fixture, expected_text) result(success)
    type(process_fixture), intent(inout) :: fixture
    character(len=*), intent(in) :: expected_text

    success = index(fixture%last_result%stdout, expected_text) > 0
    if (.not. success) then
      call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_ASSERTION_FAILED, &
        assertion_message("fixture stdout did not contain expected text", fixture))
    end if
  end function assert_fixture_stdout_contains

  logical function assert_fixture_stderr_contains(fixture, expected_text) result(success)
    type(process_fixture), intent(inout) :: fixture
    character(len=*), intent(in) :: expected_text

    success = index(fixture%last_result%stderr, expected_text) > 0
    if (.not. success) then
      call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_ASSERTION_FAILED, &
        assertion_message("fixture stderr did not contain expected text", fixture))
    end if
  end function assert_fixture_stderr_contains

  logical function assert_fixture_output_contains(fixture, expected_text) result(success)
    type(process_fixture), intent(inout) :: fixture
    character(len=*), intent(in) :: expected_text

    success = index(fixture%last_result%stdout // fixture%last_result%stderr, expected_text) > 0
    if (.not. success) then
      call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_ASSERTION_FAILED, &
        assertion_message("fixture output did not contain expected text", fixture))
    end if
  end function assert_fixture_output_contains

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
    case (FGOF_PROC_TEST_ERR_READINESS_FAILED)
      name = "readiness-failed"
    case (FGOF_PROC_TEST_ERR_SETUP_FAILED)
      name = "setup-failed"
    case (FGOF_PROC_TEST_ERR_CLEANUP_FAILED)
      name = "cleanup-failed"
    case (FGOF_PROC_TEST_ERR_ASSERTION_FAILED)
      name = "assertion-failed"
    case (FGOF_PROC_TEST_ERR_INTERNAL)
      name = "internal"
    case default
      name = "unknown"
    end select
  end function proc_test_error_name

  logical function valid_fixture(fixture) result(valid)
    type(process_fixture), intent(in) :: fixture

    valid = allocated(fixture%name)
    if (.not. valid) return
    if (len_trim(fixture%name) == 0) then
      valid = .false.
      return
    end if

    valid = fixture%command%mode /= FGOF_PROCESS_MODE_NONE
    if (.not. valid) return

    valid = fixture%options%timeout_ms >= 0 .and. fixture%options%retries >= 0 .and. &
      fixture%options%retry_delay_ms >= 0
  end function valid_fixture

  logical function need_capture(fixture) result(capture)
    type(process_fixture), intent(in) :: fixture

    capture = fixture%options%capture_output
    if (allocated(fixture%options%ready_text)) then
      capture = capture .or. len(fixture%options%ready_text) > 0
    end if
  end function need_capture

  logical function matches_readiness(fixture, res) result(matches)
    type(process_fixture), intent(in) :: fixture
    type(process_result), intent(in) :: res
    character(len=:), allocatable :: text

    if (.not. allocated(fixture%options%ready_text)) then
      matches = .true.
      return
    end if

    if (len(fixture%options%ready_text) == 0) then
      matches = .true.
      return
    end if

    text = res%stdout // res%stderr
    matches = index(text, fixture%options%ready_text) > 0
  end function matches_readiness

  logical function run_setup_step(fixture) result(success)
    type(process_fixture), intent(inout) :: fixture
    type(process_options) :: setup_options

    if (fixture%setup_command%mode == FGOF_PROCESS_MODE_NONE) then
      fixture%setup_completed = .true.
      success = .true.
      return
    end if

    setup_options = build_process_options(fixture%options, .true.)
    fixture%setup_result = run(fixture%setup_command, setup_options)

    if (fixture%setup_result%error_code /= FGOF_PROCESS_OK) then
      call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_SETUP_FAILED, &
        setup_message("setup process reported a backend error", fixture%setup_result))
      success = .false.
      return
    end if

    if (.not. fixture%setup_result%completed .or. .not. fixture%setup_result%exited_normally .or. &
        fixture%setup_result%exit_code /= 0) then
      call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_SETUP_FAILED, &
        "setup command exited unsuccessfully")
      success = .false.
      return
    end if

    fixture%setup_completed = .true.
    success = .true.
  end function run_setup_step

  function build_process_options(options, capture_output) result(proc_options)
    type(fixture_options), intent(in) :: options
    logical, intent(in) :: capture_output
    type(process_options) :: proc_options
    integer :: item_len
    integer :: i

    proc_options%timeout_ms = options%timeout_ms
    proc_options%capture_stdout = capture_output
    proc_options%capture_stderr = capture_output

    if (allocated(options%cwd)) then
      if (len(options%cwd) > 0) proc_options%cwd = options%cwd
    end if

    if (allocated(options%env_set)) then
      item_len = max_string_length(options%env_set)
      allocate(character(len=item_len) :: proc_options%env_set(size(options%env_set)))
      do i = 1, size(options%env_set)
        proc_options%env_set(i) = options%env_set(i)
      end do
    end if

    if (allocated(options%env_unset)) then
      item_len = max_string_length(options%env_unset)
      allocate(character(len=item_len) :: proc_options%env_unset(size(options%env_unset)))
      do i = 1, size(options%env_unset)
        proc_options%env_unset(i) = options%env_unset(i)
      end do
    end if
  end function build_process_options

  subroutine clear_fixture_error(fixture)
    type(process_fixture), intent(inout) :: fixture

    fixture%error_code = FGOF_PROC_TEST_OK
    fixture%error_message = ""
  end subroutine clear_fixture_error

  subroutine set_fixture_error(fixture, code, message)
    type(process_fixture), intent(inout) :: fixture
    integer, intent(in) :: code
    character(len=*), intent(in) :: message

    fixture%error_code = code
    fixture%error_message = message
  end subroutine set_fixture_error

  subroutine map_process_error(fixture, res)
    type(process_fixture), intent(inout) :: fixture
    type(process_result), intent(in) :: res

    select case (res%error_code)
    case (FGOF_PROCESS_ERR_INVALID_COMMAND, FGOF_PROCESS_ERR_INVALID_OPTION)
      call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_INVALID_OPTIONS, process_message(res))
    case (FGOF_PROCESS_ERR_SPAWN_FAILED, FGOF_PROCESS_ERR_EXEC_FAILED, FGOF_PROCESS_ERR_PIPE_FAILED, &
          FGOF_PROCESS_ERR_TIMEOUT)
      call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_SPAWN_FAILED, process_message(res))
    case (FGOF_PROCESS_ERR_INTERNAL)
      call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_INTERNAL, process_message(res))
    case default
      call set_fixture_error(fixture, FGOF_PROC_TEST_ERR_INTERNAL, process_message(res))
    end select
  end subroutine map_process_error

  function process_message(res) result(message)
    type(process_result), intent(in) :: res
    character(len=:), allocatable :: message

    if (allocated(res%error_message)) then
      if (len(res%error_message) > 0) then
        message = res%error_message
        return
      end if
    end if

    message = "process backend reported an error"
  end function process_message

  function cleanup_message(prefix, res) result(message)
    character(len=*), intent(in) :: prefix
    type(process_result), intent(in) :: res
    character(len=:), allocatable :: message
    character(len=:), allocatable :: detail

    detail = process_message(res)
    message = prefix // ": " // detail
  end function cleanup_message

  function setup_message(prefix, res) result(message)
    character(len=*), intent(in) :: prefix
    type(process_result), intent(in) :: res
    character(len=:), allocatable :: message
    character(len=:), allocatable :: detail

    detail = process_message(res)
    message = prefix // ": " // detail
  end function setup_message

  function clear_process_result() result(res)
    type(process_result) :: res

    res%launched = .false.
    res%completed = .false.
    res%timed_out = .false.
    res%exited_normally = .false.
    res%exit_code = -1
    res%term_signal = 0
    res%stdout = ""
    res%stderr = ""
    res%error_code = FGOF_PROCESS_OK
    res%error_message = ""
    res%elapsed_ms = 0
  end function clear_process_result

  integer function max_string_length(values) result(max_len)
    character(len=*), intent(in) :: values(:)
    integer :: i

    max_len = 1
    do i = 1, size(values)
      max_len = max(max_len, len(values(i)))
    end do
  end function max_string_length

  function exit_code_message(expected_exit_code, actual_exit_code) result(message)
    integer, intent(in) :: expected_exit_code
    integer, intent(in) :: actual_exit_code
    character(len=:), allocatable :: message
    character(len=32) :: expected_text
    character(len=32) :: actual_text

    write(expected_text, '(I0)') expected_exit_code
    write(actual_text, '(I0)') actual_exit_code
    message = "expected exit code " // trim(expected_text) // ", got " // trim(actual_text)
  end function exit_code_message

  function assertion_message(prefix, fixture) result(message)
    character(len=*), intent(in) :: prefix
    type(process_fixture), intent(in) :: fixture
    character(len=:), allocatable :: message
    character(len=*), parameter :: nl = new_line('a')

    message = prefix // nl // fixture_diagnostics(fixture)
  end function assertion_message

  function fixture_name(fixture) result(name)
    type(process_fixture), intent(in) :: fixture
    character(len=:), allocatable :: name

    if (allocated(fixture%name)) then
      name = fixture%name
    else
      name = ""
    end if
  end function fixture_name

  function fixture_message_text(fixture) result(message)
    type(process_fixture), intent(in) :: fixture
    character(len=:), allocatable :: message

    if (allocated(fixture%error_message)) then
      message = fixture%error_message
    else
      message = ""
    end if
  end function fixture_message_text

  function int_text(value) result(text)
    integer, intent(in) :: value
    character(len=:), allocatable :: text
    character(len=32) :: buffer

    write(buffer, '(I0)') value
    text = trim(buffer)
  end function int_text

  function logical_text(value) result(text)
    logical, intent(in) :: value
    character(len=:), allocatable :: text

    if (value) then
      text = "true"
    else
      text = "false"
    end if
  end function logical_text

  subroutine sleep_milliseconds(delay_ms)
    integer, intent(in) :: delay_ms
    integer :: start_count
    integer :: current_count
    integer :: rate
    integer :: elapsed_ms

    if (delay_ms <= 0) return

    call system_clock(start_count, rate)
    if (rate <= 0) return

    do
      call system_clock(current_count)
      elapsed_ms = int((real(current_count - start_count) / real(rate)) * 1000.0)
      if (elapsed_ms >= delay_ms) exit
    end do
  end subroutine sleep_milliseconds

end module fgof_proc_test
