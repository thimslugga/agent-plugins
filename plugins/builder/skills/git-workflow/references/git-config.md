# Git Config: Sane Defaults and Aliases

Opt-in global configuration distilled from the user's git cheatsheet. These
are one-time settings; review each line before applying, since they change
git behavior globally.

## Defaults

```bash
git config --global init.defaultBranch main
git config --global user.name "First Last"
git config --global user.email "first.last@example.com"

# Sync behavior: rebase on pull, autostash, prune dead remotes
git config --global pull.rebase true
git config --global rebase.autoStash true
git config --global fetch.prune true
git config --global remote.origin.prune true
git config --global push.default simple
git config --global push.autoSetupRemote true
git config --global push.useForceIfIncludes true   # makes --force-with-lease safer

# Merge behavior: fast-forward only, zdiff3 conflict markers
git config --global merge.ff only
git config --global pull.ff only
git config --global merge.conflictStyle zdiff3

# Remember conflict resolutions
git config --global rerere.enabled true
git config --global rerere.autoUpdate true

# Diff and display
git config --global diff.algorithm histogram
git config --global diff.renames true
git config --global color.ui auto
git config --global column.ui auto
git config --global branch.sort -committerdate
git config --global tag.sort version:refname
git config --global status.branch true
git config --global status.short true
git config --global commit.verbose true
git config --global format.pretty "format:%C(yellow)%h%Creset %C(blue)%an%Creset %C(green)%ar%Creset %s"

# Line endings and paths
git config --global core.eol lf
git config --global core.autocrlf input
git config --global core.ignorecase false
git config --global core.quotepath false
```

Optional, uncomment to enable: `gc.auto 256`, `advice.* false` (silence
hints once you know them), `gpg.program` + `user.signingkey` +
`commit.gpgsign true` for signed commits.

## Aliases

```bash
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
git config --global alias.a 'add .'
git config --global alias.aa 'add -A'
git config --global alias.amend 'commit --amend --no-edit'
git config --global alias.ri 'rebase -i'
git config --global alias.unstage 'reset HEAD --'
git config --global alias.undo 'reset HEAD~1 --mixed'
git config --global alias.nuke 'reset HEAD~1 --hard'
git config --global alias.branches 'branch -a --sort=-committerdate'
git config --global alias.dl 'diff HEAD~1'
git config --global alias.up '!git fetch && git rebase origin/$(git symbolic-ref --short HEAD)'
git config --global alias.publish '!git push -u origin $(git branch --show-current)'
git config --global alias.cleanup '!git branch --merged | grep -v "\\*\\|main\\|master" | xargs -n 1 git branch -d'
git config --global alias.save '!git add -A && git commit -m "SAVEPOINT"'
git config --global alias.wipe '!git add -A && git commit -qm "WIPE SAVEPOINT" && git reset HEAD~1 --hard'
git config --global alias.last 'log -1 HEAD --stat'
git config --global alias.recent "log --oneline -10"
git config --global alias.grep "log --grep"
git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
```

Verify with `git config --get-regexp alias`.

Note on `save`/`wipe`: quick savepoints for experiments. `wipe` commits then
hard-resets, which is a fast way to discard an experiment while leaving a
reflog trail.
