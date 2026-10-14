# Profiles: project vs one-off script

The standard has two strictness levels. `scripts/check` and `scripts/fmt`
take `--script` for the relaxed one; the default is the project profile.

## Project profile (default)

For anything with a `pyproject.toml`, dependencies, or tests:

- Full rule set from `assets/pyproject.toml` (ruff `select`, no relaxations
  beyond its `per-file-ignores`).
- **mypy strict** on all code (`scripts/check` runs it when mypy is
  installed and `[tool.mypy]` is configured).
- Google-style docstrings on public modules, classes, and functions (`D`).
- Full annotations on every function (`ANN`).
- Tests with pytest; coverage gate at 90% (`--cov-fail-under=90`).
- `print` banned outside `**/cli.py` (`T201`); libraries log.

## Script profile (`--script`)

For single-file tools (`scripts/new-script` output and the like) — stdlib
preferred, third-party only with the user's go-ahead (see SKILL.md). Relaxes
what is noise at this size:

- Ignores `D` (pydocstyle), `ANN` (annotations), `T201` (print) via
  `ruff check --extend-ignore "D,ANN,T201"`.
- No mypy run.
- Still enforced: everything else — pyflakes, bugbear, bandit (`S`),
  blind-except (`BLE`), exception style (`EM`, `TRY`), logging format
  (`G`, `LOG`), pathlib (`PTH`), pyupgrade (`UP`), simplification (`SIM`).

A module docstring is still expected even in the script profile — it costs
one line and `argparse` reuses it as `--help` text.

## When Python at all

Shell stays the default for glue under ~100 lines (see `shell-script-pro`).
Reach for Python when the script needs real data structures, error handling
beyond exit codes, or is growing past that size — port it rather than
stretching bash past what it is good at.
