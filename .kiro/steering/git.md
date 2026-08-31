---
inclusion: auto
description: Use when interacting with git or gh.
---

# Git Best Practices

## Repository Management

- Keep repository size manageable (use Git LFS for large files)
- Use `.gitignore` files to exclude build artifacts and secrets

## Workflow

- Pull latest changes before starting work
- Commit frequently with logical chunks
- Use interactive rebase to clean up history before merging
- Review code before merging (pull requests)

## Branching

- Keep main/master/mainline branch stable and deployable
- Use feature branches for new development
- Use descriptive branch names (feature/user-auth, fix/login-bug)
- Delete merged branches to keep repository clean
- Document branching strategy in README

## Commit Messages

- Always use **Conventional Commits** format (`type(scope): description`). You must use the following types:
  - `feat`: new feature or capability
  - `fix`: bug fix
  - `refactor`: code restructuring with no behavior change
  - `chore`: maintenance, build, config, or dependency update
  - `docs`: documentation changes only
  - `test`: adding or fixing tests
  - `style`:
- Keep first line under 50 characters
- Use imperative mood ("Add feature" not "Added feature")
- Include body for complex changes
- Keep commit descriptions concise, imperative (e.g. `feat: add X`, not `feat: added X`), and lowercase without trailing punctuation.

## Releases

- Tag releases with semantic versioning
