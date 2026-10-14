# Harness notes: poka-yoke

Per-harness differences for the `poka-yoke` skill. The skill body is harness-neutral; this file records what changes per runtime.

## Install paths

| Harness | Location |
|---|---|
| Claude Code | `~/.claude/skills/poka-yoke/` |
| Codex | `~/.codex/skills/poka-yoke/` or project `.agents/skills/poka-yoke/` |
| Kiro | `~/.kiro/skills/poka-yoke/` or project `.agents/skills/poka-yoke/` |
| Muse | `~/workspace/skills/poka-yoke/` |
| Pi | `~/.pi/agent/skills/poka-yoke/` or project `.agents/skills/poka-yoke/` |

## Notes

- The scanner is stdlib-only Python 3.9+ (`python3 scripts/detect_hazards.py`), so it runs identically on every harness with no install step. Invoke it as `python3 <skill-dir>/scripts/detect_hazards.py`.
- Exit contract: 1 when reportable findings exist, 0 when clean, 2 when zero files were scanned (a loud non-all-clear). `--diff --json` is the CI form.
- `assets/devices/lint/README.md` tells the agent which linter to enable for each hazard class the scanner defers; the concrete config snippets are tool-native, not harness-specific.

## Codex metadata

`agents/openai.yaml` carries Codex UI metadata (`display_name`, `short_description`). It is ignored by other harnesses.
