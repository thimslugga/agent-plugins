# Reviewer Checklist

Role-scoped context for tier=reviewer briefs. Reference this file by absolute path in the
brief's Inputs. General by design — project specifics come from the target workspace's own
context files (WORKSPACE_CONTEXT.md, AGENTS.md, steering), never from here.

## Output contract

- Verdict first: APPROVE or NEEDS-CHANGES.
- Findings numbered. Each finding: severity (blocking | non-blocking), file:line, what is
  wrong, why it matters, suggested fix.
- Blocking = correctness bugs, data loss, security issues, broken build/tests. Everything
  else is non-blocking. An APPROVE may still carry non-blocking findings.
- Evidence rule applies: any claim about builds, tests, or counts carries the exact command
  and its exit status or summary line.
- Do not restate the diff. Do not pad with praise. Zero findings is a valid result — say so
  in one line.

## Correctness

- Does the change do what the task says — no more, no less?
- Edge cases: empty/null inputs, boundary values, error paths, concurrency where relevant.
- Validation exists at system boundaries (user input, external APIs) and is NOT duplicated
  for internal code paths that cannot produce the invalid state.

## Tests

- New behavior has tests; changed behavior has updated tests; deleted behavior has deleted
  tests.
- Tests assert behavior, not implementation details. Mocks only at boundaries (APIs,
  services) — never library internals.
- Run the relevant tests when possible and report the command + summary line. If they cannot
  be run, flag that explicitly.

## Security

- No secrets, credentials, or tokens in code, config, or test fixtures.
- Injection-safe: parameterized queries, proper shell quoting, no string-built commands from
  external input.
- Flag any broadened permission, weakened validation, or removed auth check — even if it
  looks intentional.

## Design and maintainability

- Smallest change that solves the problem. Flag speculative abstraction, unused
  configurability, and dead code paths.
- Naming conveys intent; no comments that narrate what the code does.
- The change follows the surrounding file's existing patterns rather than introducing new
  ones without cause.

## Performance

- No accidental O(n^2) on unbounded input; no repeated I/O or allocation inside loops.
- Only raise caching/optimization findings when there is evidence of a hot path — otherwise
  it is speculative.

## Scope discipline

- Flag unrelated drive-by changes mixed into the diff.
- Flag build artifacts, generated files, or machine-local paths committed by m
