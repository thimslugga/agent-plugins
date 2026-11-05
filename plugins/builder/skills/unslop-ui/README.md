# unslop-ui

Derived from the `unslop-ui` skill by Carter Johnson.

## Source

- Repository: https://github.com/JCarterJohnson/vibecoded-design-tells
- Commit: f7c4aefc2c797a66e55b49354a93917ab60d33ac (main, 2026)
- License: MIT — see [LICENSE](LICENSE)

## Local changes

- `SKILL.md`: added the `compatibility` frontmatter field.
- `scripts/devibe_scan.py`: refactored to the repo's lint standard (ruff, mypy
  strict). The report output, `--json` output, and exit codes are unchanged.
- Added `pyproject.toml` for dev tooling (ruff, mypy).

## Testing

Run `python3 -m unittest discover -s scripts -p test_devibe_scan.py`.
The regression test checks path spelling in JSON and text reports.

## Data

The upstream study's harvested Reddit data (`corpus.jsonl.gz`,
`comments.jsonl`) is not included here, and the MIT license does not cover
it.
