---
name: "python-code-pro"
description: "Write, edit, update, or review Python code to a consistent professional standard: ruff-clean (curated rule set), ruff-formatted, mypy-strict for project code, stdlib-first for one-off scripts. Use whenever creating, editing, updating, or linting .py files."
compatibility: "Requires ruff on PATH (uv tool install ruff); mypy for the project typecheck"
---

# Python Code Pro

## Purpose
Produce Python that is correct, readable, and consistently styled: ruff-clean
under the curated rule set in `assets/pyproject.toml`, ruff-formatted,
mypy-strict for project code, stdlib-first for one-off scripts, with explicit
error handling and no dead weight. Guiding philosophy is the Zen of Python
(PEP 20): clarity and maintainability over cleverness.

## Workflow
1. **Classify the target.** Project or one-off script?
   - Project (dependencies, tests, a `pyproject.toml`): install the shared
     config with `scripts/init-config` (substitutes `__PROJECT_NAME__` /
     `__SOURCE_DIR__`; never overwrites without `--force`). Conventional
     layout is `src/<package>/` + `tests/` (`--src-dir` overrides). Full
     standard: mypy strict, docstrings, annotations, tests. Lock dependencies
     (`uv lock`) and commit the lockfile for reproducible builds; refresh it
     periodically to pick up security fixes.
   - One-off script (single file, does one job): scaffold with
     `scripts/new-script`, which also writes a script-profile `pyproject.toml`
     next to the script (same curated ruff rules with D/ANN/T201 relaxed;
     mypy strict except the annotation requirements, mirroring the ANN
     relaxation) unless a ruff config is already discoverable in that
     directory or its parents, or `--no-config` is given. Plain
     `scripts/check` then enforces the standard with no flags; `--script`
     remains for ad-hoc checks with no config file. Stdlib is preferred but
     not mandatory — if the stdlib can't do the job without reinventing the
     wheel, ask the user whether a third-party dependency (e.g. requests,
     httpx) is acceptable before adding one.
   - Shell stays the default for glue under ~100 lines; port to Python past
     that instead of stretching bash (see `shell-script-pro`).
2. **Write to the standard.** Headlines: `from __future__ import annotations`;
   `pathlib.Path` over `os.path` (banned); type hints on all public
   functions (project); Google-style docstrings on public modules, classes,
   functions (project); logging, not `print` — libraries never print,
   CLIs may (`**/cli.py`); no f-strings or `.format()` in log calls (`G`);
   no bare or blind `except` (`BLE`) — catch specific exceptions; raise with
   intention (`EM`, `TRY` — no string-literal messages, no
   `raise X from None` abuse); timezone-aware datetimes (`DTZ`); modern
   syntax for 3.12+ (`UP`); complexity ≤ 12; no commented-out code (`ERA`).
   Docstrings document parameters, return values, and raised exceptions, with
   examples for complex functions. Comments explain *why*, never *what* — no
   tautological comments, and never leak the prompt or a file overview into
   comments. Follow `references/naming.md` (naming conventions),
   `references/design.md` (function/class design, error handling), and
   `references/frameworks.md` when working inside a framework (its idioms
   layer on top of PEP 8).
   argparse CLIs with `--help`; `main() -> int` + `sys.exit(main())`;
   stdout is the script's real output, diagnostics go to stderr via logging.
3. **Lint.** Run `scripts/check` (ruff check; `--script` relaxes
   `D,ANN,T201`). Fix every finding. A `noqa` is allowed only as
   `# noqa: RULE  # <reason>` with a real reason; blanket `noqa` is banned
   (`PGH`). Never invent a rule code — look it up in the ruff docs.
4. **Format.** Run `scripts/fmt` (`ruff check --fix` + `ruff format`),
   honoring the project's `pyproject.toml`. Never hand-format around its
   output.
5. **Typecheck.** Project code: mypy strict — `scripts/check` runs it when
   `[tool.mypy]` is configured and mypy is installed. Fix every error; a
   `type: ignore` needs the specific error code (`warn_unused_configs` will
   flag stale ones).
6. **Test.** Project code: pytest, coverage gate at 90% per the template.
   Scripts: smoke-run with representative inputs, including `--help` and
   failure cases (missing args, bad paths).
7. **Report** per the Output Contract.

### Review mode
When asked to review (not change) code: run `scripts/check` on it, walk the
Output Contract as a checklist against the untouched files, and report
findings ordered by severity (correctness/safety first, then typing, then
style), each with a `file:line` reference and the concrete fix. Do not edit
the files. If the code is vendored third-party, say so and don't apply the
standard to it.

## Output Contract
- Path(s) of every file created or changed.
- ruff check result: clean, or each remaining rule listed with its
  justification.
- ruff format: applied; any region intentionally left unformatted and why.
- mypy: strict clean for project code, or each remaining error justified.
- Typing/docstring audit: public functions annotated and documented.
- Error handling: no bare excepts; failure paths return/exit non-zero.
- Security: no hardcoded secrets; no secrets, tokens, PII, or key-bearing
  URLs in logs or output.
- Testing: smoke-run cases covered; pytest results + coverage for projects.
- Short changelog: what changed and what it was tested with.

## Tooling
- `ruff check` — lint under the curated rule set (`pyproject.toml`).
- `ruff format` — the formatter; never fight it.
- `ruff rule <CODE>` — look up what a rule means before suppressing it.
- `mypy --strict` — typecheck for project code.
- `ty` — Astral's type checker, in dev deps as a second opinion.
- `pytest` (+ `pytest-cov`, `--cov-fail-under=90`) — tests.
- `uv` — dependency and tool management (`uv tool install ruff`).
- `uv lock` — reproducible builds; commit `uv.lock`, refresh it to pick up
  security fixes.
- `pre-commit` — the deterministic gate: `assets/pre-commit-config.yaml`
  runs the same ruff check the skill runs (`pre-commit install`).
- `assets/pyproject-script.toml` — slim config for one-off scripts, written
  by `scripts/new-script`; same ruff select as the project template, D/ANN/T201
  relaxed, mypy strict minus annotation requirements.
- `assets/.editorconfig` — editor whitespace/indent defaults, installed by
  `scripts/init-config`.
- `assets/pyrightconfig.json` — editor-only Pylance/pyright config in strict
  mode mirroring mypy strict, installed by `scripts/init-config`. Not a gate:
  if pyright and mypy disagree, mypy wins.

## Operating Rules
1. No file is done until `scripts/check` is clean or every remaining finding
   carries an inline, reasoned suppression.
2. Always run `scripts/fmt` last; never commit hand formatting that
   contradicts it.
3. When editing, match the file's existing style; do a full restyle only on
   request.
4. Never invent a ruff rule code — check `ruff rule` / the docs.
5. One-off scripts prefer stdlib; reach for third-party only when the stdlib
   would mean reinventing the wheel — and ask the user first.
6. Security: never hardcode secrets, API keys, or passwords — use environment
   variables or a secrets manager, keep `.env` out of git. Never log secrets,
   tokens, PII, or URLs containing keys. Validate and sanitize external
   inputs.
7. Never silently swallow exceptions — log or re-raise. Use `with` for
   resource management. Prefer exceptions over error codes.
8. Keep this file's core stable; profile-specific or lengthy guidance belongs
   in `references/`.

## Sources
- The Zen of Python (PEP 20) — https://peps.python.org/pep-0020/
- Ruff — https://docs.astral.sh/ruff/ ; rules — https://docs.astral.sh/ruff/rules/
- mypy — https://mypy.readthedocs.io/
- ty — https://docs.astral.sh/ty/
- Google Python Style Guide — https://google.github.io/styleguide/pyguide.html
- PEP 8 — https://peps.python.org/pep-0008/
