# Sync and Recovery

## Syncing a feature branch

Rebase your branch onto the latest main instead of merging main into it. The
history stays linear and the eventual merge is trivial.

```bash
git fetch origin
git rebase origin/main
```

Order of operations: add, commit, fetch, rebase, push. A dirty tree aborts
the rebase, so commit or stash first. If the branch is already pushed and the
rebase rewrote history, push with `--force-with-lease` (never plain
`--force`; the lease fails if someone else pushed since you last fetched).

```bash
git rebase --abort      # bail out of a rebase gone wrong
git rebase --continue   # after resolving conflicts
```

If you committed locally and then realized main moved:

```bash
git fetch origin
git rebase origin/main
git status
```

## Combining commits

Before opening a PR, collapse a messy local history into reviewable commits.

Interactive rebase (precise control):

```bash
git rebase -i HEAD~n
```

Change `pick` to `squash` (or `s`) for commits to fold into the previous one,
or `fixup` (or `f`) to fold without keeping the message. Save, edit the
combined message, save again.

Soft reset (fast, when you want one commit):

```bash
git reset --soft HEAD~n
git commit -m "feat: single coherent change"
```

`--soft` keeps the working tree and the index intact; you just re-commit.

## Stash

```bash
git stash push -m "work in progress: oauth"   # stash with a label
git stash list
git stash show -p stash@{0}                   # inspect before restoring
git stash pop                                 # restore and drop
git stash apply stash@{0}                     # restore without dropping
git stash branch new-branch                   # branch from a stash
git stash drop stash@{0}                      # drop one entry
```

Prefer named stashes; an unlabeled stack is a mystery a week later.

## Undo, by severity

1. Fix the last commit message or content, nothing pushed yet:
   `git commit --amend` (then `--no-edit` to keep the message).
2. Undo the last commit, keep the changes staged: `git reset --soft HEAD~1`.
3. Undo the last commit, keep the changes unstaged: `git reset --mixed HEAD~1`
   (this is `git reset HEAD~1`, the `undo` alias).
4. Undo the last commit and discard the changes: `git reset --hard HEAD~1`
   (the `nuke` alias). Destructive; nothing pushed can be recovered this way
   except via reflog.
5. Undo a specific file to its committed state: `git checkout -- <file>`
   (or `git restore <file>` on newer git).
6. Undo a pushed commit without rewriting history: `git revert <sha>`. This is
   the only safe undo for shared branches; pair it with a `revert:` type
   commit message.
7. Recover anything: `git reflog`. Every HEAD movement is logged there for
   about 90 days; find the SHA and `git reset --hard <sha>` or check out a
   branch at it.

## Merge conflicts

`merge.conflictStyle zdiff3` (in `references/git-config.md`) shows the common
ancestor alongside both sides, which makes most conflicts self-explanatory.
For repeated identical conflicts, `rerere` (reuse recorded resolution)
remembers how you resolved them and replays the resolution automatically.
