# Testing shell scripts

## Bash Automated Testing System (BATS): standard test runner

[bats-core](https://github.com/bats-core/bats-core) runs each `@test` in isolation and reports TAP output.

Example:

```bash
#!/usr/bin/env bats

setup() {
  # Runs before every test. Load the library under test here.
  load '../lib/str.sh'
}

@test "my_module::my_func echoes its input" {
  run my_module::my_func "hello"
  [ "${status}" -eq 0 ]
  [ "${output}" = "hello" ]
}

@test "script fails cleanly with no args" {
  run ./deploy
  [ "${status}" -eq 1 ]
  [[ ${output} == *"Usage:"* ]]
}
```

Guidelines:

- Test behavior, not implementation: exit codes, stdout content, files created.
- One logical assertion group per `@test`; name tests as sentences.
- `run` captures `status` and `output` (combined stdout+stderr; bats 1.5+
  has `run --separate-stderr` when you need them split).
- Keep shared helpers in `test/helpers.bash` and `load` them.
- Never test through the network or the real filesystem when a temp dir
  (`BATS_TEST_TMPDIR`) will do.
- bats files are bash: they get the same shellcheck/shfmt treatment
  (`scripts/lint.sh` covers `test/*.bats` too).

## Smoke-test checklist (no framework)

For glue scripts too small for bats, cover at minimum:

- `-h` exits 0 and prints usage.
- Happy path with representative inputs; verify stdout and exit code.
- Missing required args → non-zero exit + usage hint on stderr.
- Missing external commands → the template's `check_preconditions` error,
  naming what's missing.
- Bad paths / unreadable files → handled explicitly, no raw stack traces.
- `-v` / `VERBOSE=true` emits DEBUG lines; a default run stays quiet.
- Idempotence where it matters: run twice; the second run is a clean no-op
  or a clear "already done".
