# fgof-proc-test

Process-test fixtures for modern Fortran.

`fgof-proc-test` is intended to be a small, standalone library for building
reliable process-level tests around command-line tools, daemons, and helper
programs.

It is part of the [FortranGoingOnForty lib-modules](https://github.com/FortranGoingOnForty/lib-modules)
catalog, but it is intended to stand on its own as a normal `fpm` package.

Current v1 target:

- build on `fgof-process` instead of re-implementing subprocess control
- expose fixture options and process-fixture state
- support stable setup, start, readiness, retry, and cleanup flows
- stay focused on process-level testing, not general assertion frameworks

Future scope:

- expect-backed fixtures layered on top of `fgof-expect`
- richer assertions and transcript snapshots
- higher-level scenario runners layered on top of the stable core

## Status

Fixture lifecycle, setup hooks, and first assertion layer are in place.

Tracked today:

- public `fgof_proc_test` and `fgof_proc_test_types` modules
- `make_fixture()`, `run_fixture()`, and `cleanup_fixture()` lifecycle helpers
- optional setup commands plus cleanup-on-failure behavior
- readiness checks, retry tracking, and captured last-result state
- assertion helpers for exit codes and output checks
- `fixture_diagnostics()` for richer failure detail
- retry-delay support plus `retry_fixture()` convenience
- tracked examples for setup/cleanup and assertion flows
- initial fixture and options types
- stable error constants with naming helpers
- CI and `fpm test` baseline wiring

## Why Use It

- process-level tests are still a repeated pain point in Fortran tooling
- `fgof-process` now gives us a strong base to build a cleaner fixture layer
- many integration suites still hand-roll setup, polling, teardown, and cleanup
- a focused package here can make app and tool testing much less fragile
- current fixtures work well for one-shot process checks and reusable setup or
  teardown steps even before `fgof-process` grows async handles
- assertion helpers keep common exit-code and output checks close to the fixture
  state instead of scattering them through each test file
- diagnostics make failed fixtures much easier to inspect without rebuilding the
  context in every test

## Public API Shape

Primary modules:

- `fgof_proc_test`
- `fgof_proc_test_types`

Public types:

- `fixture_options`
- `process_fixture`

Public constants:

- `FGOF_PROC_TEST_OK`
- `FGOF_PROC_TEST_ERR_INVALID_OPTIONS`
- `FGOF_PROC_TEST_ERR_SPAWN_FAILED`
- `FGOF_PROC_TEST_ERR_READINESS_FAILED`
- `FGOF_PROC_TEST_ERR_SETUP_FAILED`
- `FGOF_PROC_TEST_ERR_CLEANUP_FAILED`
- `FGOF_PROC_TEST_ERR_ASSERTION_FAILED`
- `FGOF_PROC_TEST_ERR_INTERNAL`

Current public procedures:

- `assert_fixture_exit_code`
- `assert_fixture_output_contains`
- `assert_fixture_stderr_contains`
- `assert_fixture_stdout_contains`
- `assert_fixture_success`
- `cleanup_fixture`
- `clear_fixture_options`
- `clear_process_fixture`
- `fixture_diagnostics`
- `fixture_ready`
- `fixture_result`
- `make_fixture`
- `proc_test_backend_name`
- `proc_test_error_name`
- `retry_fixture`
- `run_fixture`

## Quick Start

```fortran
program demo_proc_test
  use fgof_process, only : shell
  use fgof_proc_test, only : &
    cleanup_fixture, clear_fixture_options, fixture_diagnostics, &
    fixture_ready, make_fixture, run_fixture
  use fgof_proc_test_types, only : fixture_options, process_fixture
  implicit none

  type(fixture_options) :: options
  type(process_fixture) :: fixture

  options = clear_fixture_options()
  options%ready_text = "READY"
  options%retry_delay_ms = 10

  fixture = make_fixture( &
    "demo", &
    shell("printf READY"), &
    options, &
    cleanup_cmd=shell("printf CLEANED >/dev/null"), &
    setup_cmd=shell("printf MADE >/dev/null"))

  if (run_fixture(fixture)) then
    if (fixture_ready(fixture)) print *, "fixture is ready"
  else
    print *, trim(fixture_diagnostics(fixture))
  end if

  if (.not. cleanup_fixture(fixture)) then
    print *, fixture%error_message
  end if
end program demo_proc_test
```

## Build And Test

```bash
fpm test
```

That is the baseline verification command locally and in CI.

Example binaries are also tracked under `example/`:

- `setup_cleanup_demo`
- `assertion_demo`

## Supported Platforms

- macOS
- Linux

## Boundaries

- intended to stay independently versioned and releasable
- focused on process-fixture ergonomics, not full test-framework replacement
- should sit cleanly beside `test-drive`, `vegetables`, or other assertion layers
- `fgof-process` remains the subprocess backend underneath this package
- current fixtures are synchronous and one-shot; persistent daemons and richer
  async supervision should wait for later backend support
- assertion helpers are intentionally simple string and exit-code checks for now
- richer transcript assertions and expect-backed fixtures can sit above this
  package later

## License

MIT
