# golang-pro

An agent skill for writing, editing, and reviewing Go code to a consistent,
strict, opinionated standard: **gofumpt**-formatted, `go vet` clean,
**golangci-lint** clean under a curated v2 config — grounded in Effective Go
and the Google Go Style Guide.

## Layout

- `SKILL.md` — the skill: purpose, workflow, output contract, tooling,
  operating rules, sources.
- `references/` — the substance the workflow points at:
  - `naming.md` — package/identifier/error/test-double naming checklist.
  - `design.md` — errors as values, interfaces, packages, concurrency,
    signatures.
  - `comments.md` — doc-comment and comment-hygiene rules.
- `assets/` — shared configuration:
  - `.golangci.yml` — curated strict golangci-lint v2 config for modules.
  - `.golangci-script.yml` — relaxed profile for one-off programs.
  - `.editorconfig` — editor whitespace/indent defaults (Go: tabs).
- `scripts/` — the executable workflow:
  - `new-script` — scaffold an idiomatic one-shot `package main` program
    (+ script-profile `.golangci.yml`, unless a config is already
    discoverable upward or `--no-config`).
  - `init-config` — install `.golangci.yml` + `.editorconfig` into a module
    (`--force` to overwrite).
  - `check` — `gofumpt -l` gate, `go vet`, `golangci-lint run`
    (`--script` skips golangci-lint for ad-hoc checks).
  - `fmt` — `gofumpt -w` (+ `goimports -w` when available).
- `agents/openai.toml` — provider-specific adaptation notes.

## Usage

```bash
# New module: install the shared config
scripts/init-config

# One-off program: scaffold + script-profile config
scripts/new-script hello

# Lint (format gate + vet + golangci-lint)
scripts/check

# Format
scripts/fmt
```

Requires the Go toolchain on PATH (go >= 1.26), `gofumpt`, and
`golangci-lint` for the full profile:

```bash
go install mvdan.cc/gofumpt@latest
# golangci-lint: pin a release per https://golangci-lint.run/docs/installation/
```

## Design decisions

- **gofumpt, not gofmt**: strict superset; running `gofmt` after `gofumpt`
  produces no changes.
- **One complexity family** (`cyclop`, max 15): `funlen`/`gocognit`/`nestif`
  are never stacked on top.
- **gofumpt owns whitespace**: `wsl`, `nlreturn`, `lll` are banned from the
  config — no formatter-vs-linter fights.
- **No `wrapcheck`**: it conflicts with the Go 1.13 doctrine against
  wrapping implementation details into your API.
- **No `gochecknoglobals`**: it fights idiomatic globals (sentinel errors,
  `template.Must`).
- **`govet` runs `enable-all` minus `shadow` and `fieldalignment`**: shadow
  is false-positive-prone; fieldalignment suggests churny reordering.
- **`revive` is curated to doc-comment rules** (`exported`,
  `package-comments`) plus `indent-error-flow` (guard clauses); staticcheck
  already covers identifier style, so nothing double-reports.

## Testing

- `bash -n` on all scripts; `--help` / argument-validation paths.
- `new-script` scaffold verified gofumpt-clean and `go vet`-clean with the
  real toolchain; `check`/`fmt` exercised end to end.
- `init-config` tested in a temp dir (fresh install, skip-without-`--force`,
  `--force` overwrite).
- Both `.golangci*.yml` assets validated as YAML; every settings key used
  was verified against the golangci-lint v2 reference config.
