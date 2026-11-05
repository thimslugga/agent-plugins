---
name: "git-workflow"
description: "Feature-branch git workflow for agentic coding work: start from a synced main, branch with conventional names, write Conventional Commits, sync with rebase, run the PR lifecycle with gh, and recover safely from mistakes. Use when starting work in a repo, staging or writing commits, rebasing, opening or reviewing PRs, resolving conflicts, or undoing git operations."
license: "MIT"
compatibility: "Requires git; gh CLI for the PR sections."
---

# Git Workflow

Opinionated workflow for git work, synthesized from the user's git cheatsheet,
the asmeurer fork-contribution guide, the netresearch git-workflow skill, and
the Conventional Commits 1.0.0 spec (see `README.md`, Attribution).

**Precedence:** the repository's own conventions win. If `CONTRIBUTING.md`,
`AGENTS.md`, or a `.github/` template specifies branch names, commit format,
merge strategy, or sign-off rules, follow those. Everything here is the
default when the project is silent.

## Critical rules

1. Never commit to the trunk branch (`main`, `master`, or `mainline`,
   whichever the repo uses). Branch for everything, even one-liners.
2. Always branch from a synced `main`: check out main, pull, then create the branch.
3. Commit messages follow Conventional Commits: `<type>[scope]: <description>`.
4. Sync a feature branch with rebase (`git fetch origin && git rebase origin/main`), not merge.
5. Force-push only with `--force-with-lease`. Never plain `--force`.
6. Commit (or stash) before you rebase. A dirty tree aborts the rebase.
7. One PR per branch. Push additional commits to the same branch; comment on the PR when it is ready for re-review.
8. Verify before you push: `git status` (right branch, intended files only) and `git log --oneline -5` (sane history).
9. State what changed, not how good it is. No editorializing in commits or PR bodies.

## Workflow

### 1. Orient

- `git status` and `git branch --show-current`: know where you are and what is dirty.
- Read the repo's workflow docs first (`CONTRIBUTING.md`, `AGENTS.md`, PR templates). They outrank this skill.
- Check for hook configs (`lefthook.yml`, `.pre-commit-config.yaml`, `.husky/`). If present, they define the commit gate; do not bypass them.

### 2. Start work

```bash
git checkout main
git pull --rebase            # or: gh repo sync, for GitHub repos
git checkout -b <type>/<short-kebab-description>
```

Branch names: `feature/`, `bugfix/`, `hotfix/`, `docs/` prefixes with a
kebab-case description (`feature/oauth-refresh-token`). For open-source
contributions through a fork: clone the upstream repo, add your fork as a
remote, push the branch to the fork, and open the PR against upstream main.
Details: `references/branching-strategy.md`.

### 3. Commit

- Stage deliberately: `git add <paths>`, not `git add .` unless the tree contains only intended changes.
- One commit per unit of change.
- Validate the message with `scripts/check-commit-msg` (reads a message file or stdin; exit 0 is valid). Install it as `.git/hooks/commit-msg` to enforce the format.

Format, type table, scopes, and breaking changes: `references/conventional-commits.md`.

### 4. Sync while working

```bash
git fetch origin
git rebase origin/main
```

Combine a messy local history before opening the PR: `git rebase -i HEAD~n`
(squash/fixup) or the soft-reset method (`git reset --soft HEAD~n && git commit`).
Resolve conflicts, `git rebase --continue`, then push with
`--force-with-lease`. Details: `references/sync-and-recovery.md`.

### 5. Open the PR

```bash
git push -u origin <branch>
gh pr create --title "<type>: <what it does>" --body "<why, what changed, test evidence>"
```

Title rule: say what the PR does, not which issue it closes; put `Fixes #123`
in the body. Check status with `gh pr status` and `gh pr view`. Feedback loop,
approvals, and merge: `references/pr-workflow.md`.

### 6. Merge and clean up

- Merge with the repo's configured method. When the project does not specify one, `gh pr merge --squash --delete-branch` is the common default.
- After merge:

```bash
git checkout main
git pull --rebase
git branch -d <branch>
git remote prune origin
```

- For stale local branches: `git branch --merged | grep -v '\*\|main\|master' | xargs -n 1 git branch -d`.

## References

| Reference | Triggers |
|---|---|
| `references/conventional-commits.md` | commit message format, types, scopes, breaking changes, footers |
| `references/branching-strategy.md` | branch naming, never-commit-to-main, trunk vs GitHub Flow vs GitFlow vs GitLab Flow vs release vs environment branching, fork-based OSS contributions |
| `references/pr-workflow.md` | gh PR create/review/merge, the feedback loop, PR titles |
| `references/sync-and-recovery.md` | rebase, squash, stash, undo levels, reflog, force-with-lease |
| `references/git-config.md` | sane global git config defaults and aliases (opt-in) |
