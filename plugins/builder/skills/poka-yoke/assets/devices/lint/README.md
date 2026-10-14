# Lint devices the scanner defers to

`scripts/detect_hazards.py` deliberately does not reimplement checks a real linter does
better. The rules it suppresses by default (see `COVERED_BY` in the script; re-enable them
with `--all`) are covered by the tools below. Enable the tool rather than relying on the
scanner for these: a linter failure is a build failure, which is a rung-1 or rung-2 device,
while a scanner report is rung-3 detection.

## Ruff (Python)

Covers: bare `except` (E722), mutable default argument (B006), `assert` used for validation
(S101), naive datetime (DTZ), dangling `asyncio.create_task` (RUF006), float equality
(PLR0133), `open()` without a context manager (SIM115).

```toml
# pyproject.toml
[tool.ruff.lint]
select = ["E722", "B006", "S101", "DTZ", "RUF006", "PLR0133", "SIM115"]
```

## mypy (Python)

Covers: `# type: ignore` without a code (narrow it to a specific error code with a reason).

```bash
mypy --strict path/to/package
```

## ESLint core (TypeScript / JavaScript)

Covers: empty `catch {}` blocks (`no-empty`), `parseInt` without a radix (`radix`).

```json
{ "rules": { "no-empty": "error", "radix": "error" } }
```

## @typescript-eslint (TypeScript)

Covers: `@ts-ignore` / `@ts-nocheck` (`ban-ts-comment`), explicit `any`
(`no-explicit-any`). The M6 device also recommends `no-floating-promises`.

```json
{
  "rules": {
    "@typescript-eslint/ban-ts-comment": "error",
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/no-floating-promises": "error"
  }
}
```

## eslint-plugin-jest (TypeScript / JavaScript)

Covers: focused tests (`jest/no-focused-tests`), skipped tests
(`jest/no-disabled-tests`). Fail CI on focused tests.

## Clippy (Rust)

Covers: `.unwrap()` / `.expect()` on fallible values (`clippy::unwrap_used`), wildcard
match arms (`clippy::wildcard_enum_match_arm`).

```rust
#![deny(clippy::unwrap_used, clippy::wildcard_enum_match_arm)]
```

## golangci-lint (Go)

Covers: discarded error returns (`errcheck`), `interface{}` / `any` containers, switch
without exhaustiveness (`exhaustive`, with `default-signifies-exhaustive: false` per the F1
device).

```yaml
linters:
  enable: [errcheck, exhaustive]
linters-settings:
  exhaustive:
    default-signifies-exhaustive: false
```

## TypeScript compiler

Not a lint rule, but the C2/C7 devices assume it: `strict: true` in `tsconfig.json`
so the type system is actually on.
