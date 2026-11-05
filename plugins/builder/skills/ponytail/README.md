# ponytail

Lazy senior dev mode: the smallest change that fully solves the task, and a
reply a busy human understands in one read. YAGNI, reuse before writing,
stdlib before dependencies, no unrequested abstractions.

Invoke with `/ponytail`; it stays on for the session until the user says
"stop ponytail" or "normal mode".

## What it does

- **Scope first:** before writing, list every place the change must reach
  (callers, tests, fixtures, config, exports) and what it could break.
- **Smallest complete change:** take the first option that fully works:
  skip it, reuse what the codebase has, use the stdlib or platform, use an
  installed dependency, one readable line, otherwise the minimum code.
- **Lazy about the solution, never the change:** finish every caller, test,
  and fixture the change breaks. Non-trivial new logic leaves one small test
  or self-check. Known limits get a `shortcut: <limit>, <when to upgrade>`
  comment.
- **Never cut:** validation at trust boundaries, error handling that prevents
  data loss, security, accessibility, hardware calibration, anything the user
  asked for.
- **Reply shape:** ends with one or two lines on what was skipped or not
  checked, and any risk the user must know.

## Layout

- `SKILL.md`: the whole skill (scope check, the six-step ladder, rules,
  never-cut list, levels).
- `agents/openai.yaml`: Codex UI metadata.
- `LICENSE`: MIT (DietrichGebert), copied from upstream.

## Usage

| Level | Behavior |
|---|---|
| `lite` | Build what was asked; name the smaller option in one line. |
| `full` | All the rules. Default. |
| `ultra` | Also push back on any part of the request the need doesn't justify. |

Switch with `/ponytail lite|full|ultra`; `/ponytail off`, "stop ponytail", or
"normal mode" turns it off. Also triggers on "be lazy", "simplest solution",
"yagni", or complaints about over-engineering.

## Harness setup

| Harness | Install to |
|---|---|
| Claude Code | `~/.claude/skills/ponytail/` |
| Codex | `~/.codex/skills/ponytail/` or project `.agents/skills/ponytail/` |
| Kiro | `~/.kiro/skills/ponytail/` or project `.kiro/skills/ponytail/` |
| Muse | `~/workspace/skills/ponytail/` |
| Pi | `~/.pi/agent/skills/ponytail/` or project `.agents/skills/ponytail/` |

On Claude Code the full upstream plugin is also installed, which adds hooks,
the task board, and the sibling skills (`ponytail-review`, `ponytail-audit`,
`ponytail-debt`, `ponytail-gain`, `ponytail-help`). This folder carries only
the core skill.

## Testing

Behavioral skill, no scripts. Verification is by inspection:

- `SKILL.md` frontmatter parses (`name`, `description`, `argument-hint`,
  `license`); `name` matches the directory.
- Matches upstream `skills/ponytail/SKILL.md` at v5.3.3 except the
  `description` block scalar (`>-` here, `>` upstream).

## Attribution

- Upstream: [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail),
  `skills/ponytail/SKILL.md` (plugin v5.3.3).
- License: MIT, Copyright (c) 2026 DietrichGebert (`LICENSE` copied from
  upstream).
- Changes: `description` uses `>-` (strip the trailing newline) instead of
  `>`; otherwise identical. Added `README.md` and `agents/openai.yaml`. Not carried over: the sibling skills, hooks,
  commands, benchmarks, and multi-harness packaging.
