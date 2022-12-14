# v1.0.0 - 2022-12-13

- **BREAKING CHANGE:** Changed package to hybrid so it can be used as a library
- **NEW:** `nimxc c` will now automatically install necessary toolchains, unless `--no-auto-install` is given.
- **NEW:** Add `-a/--all` flag to `nimxc this` to list all libc ABIs supported by the current host.
- **NEW:** Support building from macosx-arm64
- **FIX:** Fix regex tests targeting linux ([#8](https://github.com/iffy/nimxc/issues/8), [#9](https://github.com/iffy/nimxc/issues/9))
- When running tests, include a list of failed tests at the end of test run output.

