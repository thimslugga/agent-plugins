# Conventional Commits

Summary of the Conventional Commits 1.0.0 spec
(https://www.conventionalcommits.org/en/v1.0.0/), the commit format this
skill enforces. Validate messages with `scripts/check-commit-msg`.

## Format

```
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

Rules:

- A commit MUST be prefixed with a type (a noun like `feat`, `fix`), followed
  by optional scope in parentheses, optional `!`, and a required colon+space.
- The description MUST immediately follow the colon+space. Keep it short,
  imperative, lowercase, no trailing period: `fix: array parsing with multiple
  spaces in string`, not `Fix: Fixed the array parsing.`
- The body, if present, MUST begin one blank line after the description. It is
  free-form; explain what changed and why.
- Footers come one blank line after the body. Each footer is a word token
  followed by `:` + space or ` #`, e.g. `Reviewed-by: Z`, `Refs: #123`.
- Types are case-insensitive; the `BREAKING CHANGE` footer token MUST be
  uppercase.

## Types

`feat` and `fix` are the only types the spec mandates. Everything else has no
implicit SemVer effect unless it carries a breaking change.

| Type | Meaning | SemVer |
|---|---|---|
| `feat` | new feature | MINOR |
| `fix` | bug fix | PATCH |
| `docs` | documentation only | - |
| `style` | formatting, no code change | - |
| `refactor` | code change that is neither feat nor fix | - |
| `perf` | performance improvement | - |
| `test` | adding or fixing tests | - |
| `build` | build system or external dependencies | - |
| `ci` | CI configuration | - |
| `chore` | other changes that do not modify src or test files | - |
| `revert` | reverts a previous commit | - |

(Angular/commitlint convention; the same set the user's cheatsheet uses.)

## Scope

A noun in parentheses describing the section of the codebase:
`feat(parser): add ability to parse arrays`, `fix(auth): refresh token expiry`.
Keep scopes short and consistent within a repo.

## Breaking changes

Indicate a breaking change either:

- in the prefix with `!` immediately before the colon: `feat!: drop Node 6
  support`, `feat(api)!: send email on shipment`, or
- as a footer: `BREAKING CHANGE: environment variables now take precedence
  over config files`.

A BREAKING CHANGE can ride on any type and maps to a MAJOR SemVer bump.

## Reverts

The spec does not define revert semantics; the recommended pattern is the
`revert` type with a footer referencing the reverted SHAs:

```
revert: let us never again speak of the noodle incident

Refs: 676104e, a215868
```

## Examples

```
feat: allow provided config object to extend other configs

BREAKING CHANGE: `extends` key in config file is now used for extending other config files
```

```
fix: prevent racing of requests

Introduce a request id and a reference to latest request. Dismiss
incoming responses other than from latest request.

Remove timeouts which were used to mitigate the racing issue but are
obsolete now.

Reviewed-by: Z
Refs: #123
```

```
docs: correct spelling of CHANGELOG
```

## Fixing a wrong type

Before merge or release: `git rebase -i` and reword the commit. After
release, the history stands; tooling will simply miss that commit. A commit
that does not meet the spec is not the end of the world, it is just invisible
to spec-based tooling.
