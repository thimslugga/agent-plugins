# PR Workflow (GitHub, via gh CLI)

## Open the PR

Push the branch first, then create the PR in one command:

```bash
git push -u origin feature/oauth-refresh-token
gh pr create --title "feat: add OAuth refresh token rotation" --body "...
"
```

**Title rule:** the title says what the PR does. It shows up in the PR
listing and in email notifications, so a vague title gets skipped. Do not
title it after the issue number ("fix for issue #1234" tells nobody what
changed). Put `Fixes #123` or `Closes #123` in the body instead; GitHub
closes the issue automatically on merge when you use that exact format.

**Body rule:** what changed, why, and how it was tested. Paste command
output for verification claims; a claim without evidence is a claim, not a
fact. No editorializing: state what changed, not how good it is.

## Check status and review

```bash
gh pr status                          # your PRs across repos
gh pr view                            # the PR for the current branch
gh pr checkout 42                     # check out someone else's PR locally
gh pr diff                            # diff of the current branch's PR
gh pr review --approve
gh pr review --request-changes --body "Please fix the error handling"
```

## The feedback loop

When review feedback arrives:

1. Make the changes on the same branch. Do not open a new PR.
2. Commit with a conventional message (`fix: address review comments` is fine;
   the squash on merge collapses them).
3. `git push`. The commits attach to the open PR automatically.
4. Leave a comment on the PR (`gh pr comment <n> --body "..."`) saying it is
   ready for re-review. Push notifications are noisy and often disabled; a
   comment is the reliable signal.

Progress-report comments (starting, progress, completed, blockers) on the PR
keep async collaborators informed without a separate channel.

## Merge

Merge with the repo's configured method. Common default:

```bash
gh pr merge <pr-number> --squash --delete-branch
```

Alternatives: `--merge` (merge commit, preserves history) or `--rebase`
(linear history). Match the project: a repo with signed commits or
bisect-friendly history usually forbids squash. If the project is silent,
squash plus branch deletion is the usual default.

## After merge

```bash
git checkout main
git pull --rebase
git branch -d feature/oauth-refresh-token
git remote prune origin
```

Then verify the merge landed: `git log --oneline -5`.
