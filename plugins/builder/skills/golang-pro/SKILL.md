---
name: "golang-pro"
description: "Write, edit, update, or review Go code to a consistent professional standard: gofumpt-formatted, go vet clean, golangci-lint clean under a curated config. Use whenever creating, editing, updating, or linting .go files."
compatibility: "Requires the Go toolchain on PATH (go >= 1.26); golangci-lint for the full standard"
---

# Golang Pro

## Purpose
Produce Go that is correct, readable, and idiomatic: gofumpt-formatted,
`go vet` clean, golangci-lint clean under `assets/.golangci.yml`, following
Effective Go and the Google Go Style Guide. Guiding philosophy is "least
mechanism": the core language first, then the standard library, then a
dependency — and only when the simpler option genuinely cannot do the job.

## Workflow
1. **Classify the target.** Module or one-off program?
   - Module (a `go.mod`): install the shared config with `scripts/init-config`
     (never overwrites without `--force`). Full standard: curated
     golangci-lint, doc comments on all exported identifiers, table-driven
     tests. Keep the `go` directive current; it governs what `modernize`
     may suggest.
   - One-off program (single `package main`, run with `go run`): scaffold
     with `scripts/new-script`, which also writes a script-profile
     `.golangci.yml` next to it (same curated base; `err113`/`ireturn`/
     `unparam`/`dupl` relaxed, govet on its default analyzers) unless a
     golangci-lint config is already discoverable in that directory or its
     parents, or `--no-config` is given. Plain `scripts/check` then enforces
     the standard with no flags; `--script` remains for ad-hoc checks that
     skip golangci-lint entirely.
2. **Write to the standard.** Headlines: gofumpt formatting (tabs; stdlib
   imports in their own group at the top); doc comments on all exported
   identifiers — full sentences starting with the identifier's name;
   errors are values: wrap with `%w` only to expose an error for
   programmatic inspection, check with `errors.Is`/`errors.As`, sentinel
   errors as package-level `ErrXxx` vars, never `return nil, nil`; small
   interfaces (1–3 methods) declared at the consumer side, accept interfaces
   and return concrete types; no `Get` prefix on getters; MixedCaps with
   uniform initialisms (`ID`, `URL`, `db`, `url`); short consistent
   receivers (`r`, `s`), never `this`/`self`; guard clauses, no `else`
   after `return`; `ctx context.Context` first parameter, never stored in
   structs; no naked shared state between goroutines — share memory by
   communicating. Follow `references/naming.md`, `references/design.md`,
   and `references/comments.md`.
3. **Lint.** Run `scripts/check` (gofumpt gate, `go vet`, `golangci-lint
   run`). Fix every finding. A `//nolint` is allowed only for a specific
   linter with a real reason (`//nolint:thelper // test helper, no *testing.T`);
   blanket `//nolint` is banned (`nolintlint` enforces this).
4. **Format.** Run `scripts/fmt` (`gofumpt -w`, plus `goimports -w` when
   available). Never hand-format around its output.
5. **Vet.** `go vet` runs inside `scripts/check`; the compiler is the
   typechecker — `go build ./...` must pass before anything else matters.
6. **Test.** `go test ./...`; table-driven tests, black-box `_test`
   packages for new packages, `t.Helper()` as the first line of helpers.
   (`go test` already runs a subset of vet checks — a failing vet there is
   still a failure.)
7. **Report** per the Output Contract.

### Review mode
When asked to review (not change) code: run `scripts/check` on it, walk the
Output Contract as a checklist against the untouched files, and report
findings ordered by severity (correctness first, then API design, then
style), each with a `file:line` reference and the concrete fix. Do not edit
the files. If the code is vendored third-party or generated, say so and
don't apply the standard to it.

## Output Contract
- Path(s) of every file created or changed.
- gofumpt: clean (or formatted, listing what changed).
- go vet: clean.
- golangci-lint: clean, or each remaining finding listed with its
  justification and a linter-specific `//nolint`.
- Tests: `go test ./...` results.
- Short changelog: what changed and what it was tested with.

## Tooling
- `gofumpt -l` — the format gate; a strict superset of gofmt.
  `go install mvdan.cc/gofumpt@latest` (requires go >= 1.26).
- `go vet` — the toolchain's suspicion heuristics; instant and
  dependency-free, so `scripts/check` always runs it.
- `golangci-lint run` — the full curated suite (`assets/.golangci.yml`).
  Pin a release for CI; never install at HEAD there.
- `golangci-lint fmt` — runs the configured formatters (v2).
- `gopls` — editor integration: `"gofumpt": true`, `"local"` set to the
  module path for import grouping, `"staticcheck": true`.
- `go test ./...` — tests plus a subset of vet checks.
- `assets/.golangci.yml` — the curated strict config for modules.
- `assets/.golangci-script.yml` — the relaxed config `scripts/new-script`
  writes next to one-off programs.
- `assets/.editorconfig` — editor whitespace/indent defaults (Go: tabs),
  installed by `scripts/init-config`.

## Operating Rules
1. No file is done until `scripts/check` is clean or every remaining finding
   carries a justified, linter-specific `//nolint`.
2. Always run `scripts/fmt` before `scripts/check`; never commit hand
   formatting that contradicts gofumpt.
3. When editing, match the file's existing style; do a full restyle only on
   request.
4. Least mechanism: stdlib before a new dependency. A new dependency needs
   a reason stated in the changelog.
5. Never silently discard errors — check them, wrap them with intent, or
   justify the `//nolint:errcheck`.
6. One complexity family only (`cyclop`, max 15): never stack `funlen`,
   `gocognit`, or `nestif` on top.
7. gofumpt owns whitespace: never add `wsl`, `nlreturn`, or `lll` to the
   config.
8. Keep this file's core stable; lengthy guidance belongs in `references/`.

## Sources
- Effective Go — https://go.dev/doc/effective_go
- Google Go Style Guide — https://google.github.io/styleguide/go/
- gofumpt — https://github.com/mvdan/gofumpt
- golangci-lint — https://github.com/golangci/golangci-lint
- Go wiki: CodeTools — https://go.dev/wiki/CodeTools
- gopls settings — https://pkg.go.dev/golang.org/x/tools/gopls
