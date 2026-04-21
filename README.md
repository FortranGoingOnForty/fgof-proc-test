# fgof-proc-test

Process-test fixtures for modern Fortran.

`fgof-proc-test` is intended to be a small, standalone library for building
reliable process-level tests around command-line tools, daemons, and helper
programs.

It is part of the [FortranGoingOnForty lib-modules](https://github.com/FortranGoingOnForty/lib-modules)
catalog, but it is intended to stand on its own as a normal `fpm` package.

Current v1 target:

- build on `fgof-process` instead of re-implementing subprocess control
- expose fixture options and process-test session state
- support stable setup, teardown, retry, and cleanup flows
- stay focused on process-level testing, not general assertion frameworks

Future scope:

- expect-backed fixtures layered on top of `fgof-expect`
- richer assertions and transcript snapshots
- higher-level scenario runners layered on top of the stable core

## Status

Initial scaffold is in place.

Tracked today:

- public `fgof_proc_test` and `fgof_proc_test_types` modules
- initial fixture and options types
- stable error constants with naming helpers
- CI and `fpm test` baseline wiring

## Why Use It

- process-level tests are still a repeated pain point in Fortran tooling
- `fgof-process` now gives us a strong base to build a cleaner fixture layer
- many integration suites still hand-roll setup, polling, teardown, and cleanup
- a focused package here can make app and tool testing much less fragile

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
- `FGOF_PROC_TEST_ERR_CLEANUP_FAILED`
- `FGOF_PROC_TEST_ERR_INTERNAL`

Current public procedures:

- `clear_fixture_options`
- `clear_process_fixture`
- `proc_test_backend_name`
- `proc_test_error_name`

## Build And Test

```bash
fpm test
```

That is the baseline verification command locally and in CI.

## Supported Platforms

- macOS
- Linux

## Boundaries

- intended to stay independently versioned and releasable
- focused on process-fixture ergonomics, not full test-framework replacement
- should sit cleanly beside `test-drive`, `vegetables`, or other assertion layers
- `fgof-process` remains the subprocess backend underneath this package

## License

MIT
