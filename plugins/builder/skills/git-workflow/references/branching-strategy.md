# Branching Strategy

## The core rule

Never commit to the trunk branch. It goes by `main`, `master`, or
`mainline` depending on the repo; use whichever name the repo uses. Every
change, however small, goes on a branch created from a synced trunk. The
trunk is the branch you pull upstream changes from, so keeping it clean keeps
syncing trivial. `git status` tells you what branch you are on; put the branch
in your shell prompt so you always know.

## The strategies

Seven models cover nearly every team. This skill's day-to-day workflow
(branch, PR, merge) is GitHub Flow; know the others so you can recognize and
adapt to a repo that uses them.

**Sync note:** where the strategies below say "stay current," this skill
prefers `git fetch` + `git rebase origin/main` over merging main into the
feature branch, to keep history linear. See
`references/sync-and-recovery.md`.

### Feature branching (the foundation)

The default mental model: branch off the trunk (or `develop`) for each unit
of work, commit in isolation, merge back via pull request when reviewed and
tested. Named `feature/<name>` or `bugfix/<name>`.

Pros: clear isolation between changes; easy to learn and onboard; PRs give a
natural review gate; the foundation GitHub Flow and GitLab Flow build on.

Cons: branches that live too long drift and merge painfully; integration
surprises when several long-lived branches land at once.

Use when: the team is new to Git workflows, or any project of medium
complexity where work needs isolation without heavier process. If branches
keep living for weeks, move up to trunk-based or GitHub Flow discipline.

### Trunk-based development

Everyone works off `main` (trunk). Changes land directly or through
short-lived branches (hours to a day or two) that merge back fast. Unfinished
work is hidden behind feature flags or built with branch-by-abstraction, not
long-lived branches. CI runs on every commit to trunk.

Pros: almost no merge conflicts, since branches never drift; fast feedback;
simple mental model; pairs naturally with continuous delivery.

Cons: demands strong CI discipline and high test coverage; every commit to
trunk must keep main green; feature flags add runtime complexity; review
bottlenecks hurt more when nothing can wait on a branch.

Use when: small teams, SaaS or web services with automated deploys,
monorepos, high CI maturity. This is the model the industry's highest
performing teams converge on.

### GitHub Flow

`main` is always deployable. Branch per change, open a PR, get review, merge
to `main`, deploy immediately. No release branches, no develop branch.

Pros: simple, lightweight, review-centric, works well with CI/CD. The branch
naming and PR workflow elsewhere in this skill are written for this model.

Cons: no formal release versioning; "always deployable" requires the same CI
discipline as trunk; awkward for shipping multiple in-flight versions (mobile
apps, libraries with support windows).

Use when: web services, SaaS, internal tools, any team deploying continuously
from main. This is the default assumption of the skill.

### GitFlow

Long-lived branches with fixed roles: `main` holds releases only, `develop`
is the integration branch, `feature/*` branches merge into `develop`,
`release/*` branches are cut from `develop` for stabilization, then merged to
`main` and tagged; `hotfix/*` branches cut from `main` for production
patches.

Pros: explicit release management; parallel version support; clear separation
between in-progress and shippable code; every release is a tagged artifact.

Cons: heavy ceremony; long-lived branches accumulate merge pain; release
branches rot while stabilization drags; poor fit for continuous delivery;
`develop` and `main` drift apart.

Use when: versioned software with scheduled releases and support windows,
desktop apps, mobile apps, libraries that maintain multiple releases.

### GitLab Flow

Environment branches (`main` -> `staging` -> `production`) or release
branches per version. Changes merge up the chain toward production; the
production branch is always deployable.

Pros: maps cleanly to deployment environments; supports versioned releases
without GitFlow's full branch taxonomy; production state is always visible as
a branch.

Cons: cherry-picking fixes across environment branches can tangle; still
slower than trunk for true continuous delivery; multiple models can confuse
beginners.

Use when: staged deployments with promotion gates, multiple supported
versions, teams that want release control without full GitFlow.

### Release branching

When a version is ready to stabilize, cut a `release/v2.0` branch from the
trunk. Bug fixes and release-specific tweaks go there while the trunk stays
open for new feature work. Tag and deploy from the release branch; apply
hotfixes to it directly.

Pros: clean isolation between stabilization and new development; parallel
maintenance and feature work; straightforward version tracking and rollback.

Cons: branch proliferation as versions accumulate; fixes must be merged back
to the trunk with discipline or they get lost; many active branches to watch.

Use when: multiple product versions in the wild simultaneously, deadline-tied
releases, long-term support commitments, formal QA before every release.

### Environment branching

Each deployment environment gets a branch: `dev` -> `qa` -> `staging` ->
`prod`, with promotions done by merging up the chain.

Pros: explicit control over what reaches each environment; simple to grasp.

Cons: high risk of environments diverging; code can behave differently per
branch if sync slips; scales poorly with modern CI/CD. Widely considered an
anti-pattern in modern DevOps; prefer GitLab Flow's environment model or
artifact promotion instead.

Use when: legacy systems or manual promotion processes where CI/CD tooling is
limited. Avoid for new projects.

## Choosing

Quick signals:

| Signal | Lean toward |
|---|---|
| Deploying to prod multiple times a day | Trunk-based |
| Deploying from main after each PR | GitHub Flow |
| Scheduled releases, version numbers, support windows | GitFlow |
| Staged environments or multiple maintained versions | GitLab Flow |
| Legacy system, manual promotions | Environment branching (reluctantly) |

And the fuller set of factors:

- **Team size:** 2-5 developers favor trunk-based or GitHub Flow; larger
  teams and multi-squad setups need the coordination structure of GitFlow or
  release branching.
- **Release frequency:** daily or continuous deploys point to trunk-based or
  GitHub Flow; scheduled releases point to GitFlow or release branching.
- **Product complexity:** simple apps and MVPs stay lightweight with GitHub
  Flow; complex enterprise systems benefit from GitFlow's or release
  branching's separation of concerns.
- **Team experience:** new teams start with feature branching or GitHub Flow;
  mature, test-driven teams can run trunk-based.
- **Compliance:** regulated industries (finance, healthcare) often need the
  formal approval gates and audit trail that GitFlow or release branching
  provide.

When in doubt, match the repo: a project already on GitFlow keeps its
`develop` branch regardless of what is fashionable. The repo's conventions
win.

## Starting a branch

```bash
git checkout main
git pull --rebase
git checkout -b <type>/<short-kebab-description>
```

## Naming

`<type>/<kebab-case-description>`, matching the commit-type vocabulary so the
branch name reads like the change it carries:

```
feature/oauth-refresh-token
bugfix/null-pointer-on-empty-cart
hotfix/cve-2026-1234-patch
docs/update-readme-install-steps
```

Good names are short, descriptive, and unique (`fix-install`,
`docs-cleanup`, `add-travis-ci`). Bad names are generic (`feature`, `fix`,
`patch`, `my-branch`): other people will use the name to find and test your
work. Keep it lowercase, hyphen-separated, no slashes beyond the type prefix.

Ticket references are fine as a suffix when the team uses them:
`feature/PROJ-123-oauth-refresh-token`.

## Fork-based contributions (open source)

When you do not have push access to the upstream repo:

1. Clone the upstream repository (not your fork):
   `git clone git@github.com:upstream/project.git`
2. Fork the repo on GitHub to your account.
3. Add your fork as a remote named after your username:
   `git remote add your-username git@github.com:your-username/project.git`
4. Do all work on branches, push them to the fork:
   `git push your-username branch-name`
5. Open the PR from your fork's branch against upstream main.

The clone/fork/remote steps happen once per repository. Everything else
(branch, commit, push, PR) is per change.

## Worktrees for parallel work

When juggling multiple branches (e.g. two agent sessions on one repo), use
one worktree per branch instead of stashing and switching:

```bash
git worktree add ../project-feature-a feature/oauth-refresh-token
git worktree list        # see what is checked out where
git worktree remove ../project-feature-a
```

Never edit the installed skill/plugin cache paths; always the repo worktree,
verified with `pwd`.
