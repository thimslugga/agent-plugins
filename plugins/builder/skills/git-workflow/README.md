# git-workflow

Agent skill for the feature-branch git workflow: start from a synced main,
branch with conventional names, write Conventional Commits, sync with rebase,
run the PR lifecycle with `gh`, and recover safely from mistakes.

Synthesized from four sources: the user's git cheatsheet gist, the asmeurer
fork-contribution guide, the netresearch git-workflow skill, and the
Conventional Commits 1.0.0 spec (see Attribution below).

## What it does

- **Critical rules:** never commit to main, always branch from a synced main,
  conventional commit messages, rebase to sync, `--force-with-lease` only,
  verify before push, no editorializing.
- **Six-step workflow:** orient, start work, commit, sync, open the PR, merge
  and clean up.
- **Precedence:** the repo's own conventions (`CONTRIBUTING.md`, `AGENTS.md`,
  PR templates) outrank the skill. Everything here is the default when the
  project is silent.

## Layout

- `SKILL.md`: frontmatter plus the critical rules, the six-step workflow, and
  the reference table.
- `references/conventional-commits.md`: format, type table, scopes, breaking
  changes, footers, revert pattern (Conventional Commits 1.0.0).
- `references/branching-strategy.md`: naming (`feature/`, `bugfix/`,
  `hotfix/`, `docs/`), never-commit-to-main, the seven strategies
  (feature branching, trunk-based, GitHub Flow, GitFlow, GitLab Flow,
  release branching, environment branching) with pros, cons, when to use,
  and chooser factors, fork-based OSS contributions, worktrees.
- `references/pr-workflow.md`: `gh` create/status/review/merge, the feedback
  loop, PR title and body rules.
- `references/sync-and-recovery.md`: rebase, squash (interactive and
  soft-reset), stash, undo by severity, reflog, conflicts.
- `references/git-config.md`: opt-in sane global defaults and the alias set
  from the user's cheatsheet.
- `scripts/check-commit-msg`: stdlib-only Conventional Commits validator
  (message file, `--message`, or stdin; exit 0 valid, 1 invalid). Doubles as
  a `.git/hooks/commit-msg` hook. Tests in `scripts/tests/`.
- `agents/openai.yaml`: Codex/OpenAI UI metadata.

## Usage

Install per Harness setup below. Invoke when starting work in a repo,
staging or writing commits, rebasing, opening or reviewing PRs, or undoing
git operations.

Enforce commit format in a repo:

```bash
cp scripts/check-commit-msg .git/hooks/commit-msg
```

Validate a message directly:

```bash
scripts/check-commit-msg --message "feat(auth): add refresh token rotation"
git log -1 --format=%B | scripts/check-commit-msg
```

## Harness setup

| Harness | Install to |
|---|---|
| Claude Code | `~/.claude/skills/git-workflow/` |
| Codex | `~/.codex/skills/git-workflow/` or project `.agents/skills/git-workflow/` |
| Kiro | `~/.kiro/skills/git-workflow/` or project `.kiro/skills/git-workflow/` |
| Muse | `~/workspace/skills/git-workflow/` |
| Pi | `~/.pi/agent/skills/git-workflow/` or project `.agents/skills/git-workflow/` |

The `gh` sections assume `gh` is installed and authenticated. Without
it, the git-only workflow (branching, commits, rebase, recovery) still
applies and the PR steps move to the web UI.

## Testing

- `python3 -m unittest discover -s scripts/tests`: 19 tests, all green.
- End-to-end hook check in a scratch repo: a valid conventional commit is
  accepted, a non-conforming message is rejected with a spec violation.
- `SKILL.md` frontmatter parses as YAML (`name`, `description`, `license`
  present; name matches the directory).
- No em dashes; no invented tooling references.

## Attribution

Synthesized from four sources:

- The user's git cheatsheet gist (aliases, global config defaults, commit types).
- The asmeurer fork-contribution guide.
- The netresearch git-workflow skill.
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) (CC BY 3.0).

`SKILL.md` is licensed `MIT` per its frontmatter.
