# Environment variables and secrets

Contents: [Where variables apply](#where-variables-apply) - [Set and unset](#set-and-unset) -
[Defaults and required](#defaults-and-required) - [Templates and expansion](#templates-and-expansion) -
[Directives](#directives) - [Precedence](#precedence) - [vars](#vars) - [Secrets](#secrets) -
[Inspect and disable](#inspect-and-disable)

Source pages: https://mise.jdx.dev/environments/, /environments/secrets/, /configuration/vars.html, /templates.html

## Where variables apply

| How a command runs | Receives `[env]` |
| --- | --- |
| `mise exec -- <command>` | Yes |
| `mise run <task>` | Yes, plus the task's own `env` |
| A shell with `mise activate` | Yes, updated at each prompt and on `cd` |
| A shim | Yes, for the program the shim runs, not the shell |
| `mise en` | Yes, in a new shell that does not follow `cd` |

## Set and unset

```toml
[env]
NODE_ENV = "production"
PORT = 8080                 # integers and booleans become strings
LEGACY_FLAG = false         # false unsets a variable from the shell or a parent config
```

```sh
mise set NODE_ENV=development   # writes [env] in the nearest config
mise set NODE_ENV               # prints the value
mise set                        # lists each variable, value and source file
mise unset NODE_ENV
mise set -E staging API_URL=https://staging.example.com   # mise.staging.toml
mise set --prompt API_TOKEN     # keeps the value out of shell history (also --stdin)
```

## Defaults and required

```toml
[env]
NODE_ENV = { default = "development" }      # keeps a value that is already set
DATABASE_URL = { required = "Set DATABASE_URL to your PostgreSQL connection string" }
```

- `default` applies only when the variable is unset or empty in the starting environment
  and lower-precedence config. CI can still export its own value.
- `required = true` (or a help string) never assigns. `mise exec`, `mise run`, `mise env`
  and `mise set` stop with an error when it is missing; an activated shell only warns.
- `required` cannot be combined with `value` or `default`.

## Templates and expansion

Values are Tera templates and also support shell-style expansion. A value can use only
variables defined above it in the same file, in lower-precedence files, or in the
environment mise started with.

```toml
[env]
PROJECT_LIB = "{{config_root}}/lib"
LD_LIBRARY_PATH = "{{env.PROJECT_LIB}}:${LD_LIBRARY_PATH:-}"
GIT_SHA = "{{ exec(command='git rev-parse --short HEAD') }}"   # runs on every prompt: keep it fast
NODE_VERSION = { value = "{{ tools.node.version }}", tools = true }
```

| Syntax | Result |
| --- | --- |
| `$VAR`, `${VAR}` | The value of `VAR` |
| `${VAR:-default}` | `default` when unset or empty |
| `${VAR:-}` | Empty string when unset, without a warning |

Useful template values: `config_root`, `cwd`, `env.NAME`, `vars.name`, `mise_env`,
`tools.<tool>.version`, and functions and filters such as `exec()`, `read_file()`,
`arch()`, `os()`, `basename`, `dirname`, `trim`. mise resolves `[env]` before it loads
tools; add `tools = true` to resolve an entry afterwards. Turn `$VAR` expansion off with
`env_shell_expand = false`.

## Directives

Directives live in a table named `_`. Each takes a path, a table with `path` and options,
or an array of either. They run in the order written; `_.python.venv` always runs last.

```toml
[env]
_.file = [".env", { path = ".secrets.yaml", redact = true }]
_.path = ["bin", { path = "~/.cargo/bin", position = "append" }]
_.source = { path = "scripts/env.sh", redact = true }
_.python.venv = { path = ".venv", create = true }
```

| Option | `_.file` | `_.source` | `_.path` | Effect |
| --- | --- | --- | --- | --- |
| `path` | Yes | Yes | Yes | One path or a list |
| `tools` | Yes | Yes | Yes | Resolve after tools load |
| `position` | No | No | Yes | `"prepend"` (default) or `"append"` |
| `redact` | Yes | Yes | No | Mark every loaded value as sensitive |
| `expand` | Yes | No | No | Let the file use values loaded before it |
| `find_up` | Yes | No | No | Search the config's directory and its parents |

**`_.file`**: the extension selects the format. `.json`, `.yaml` and `.toml` are parsed as
structured files; anything else, including `.yml` and `.env`, as dotenv. Globs work
(`.env.*`). A path that matches no file is skipped without an error, so it can point at an
optional untracked `.env`. SOPS-encrypted JSON, YAML and TOML files are decrypted on load.

**`_.path`**: the only way to change `PATH`; a `PATH` key in `[env]` is ignored. Entries go
ahead of tool paths unless `position = "append"`. Relative paths resolve against the
config root.

**`_.source`**: runs a bash script (shebang ignored) and takes what it exports or unsets.
It runs every time mise computes the environment, so keep it fast and idempotent. Only
prepending to `PATH` is honored. Safe mode never runs it. On Windows it needs a POSIX
bash such as Git for Windows.

**`_.python.venv`**: see `languages.md`.

## Precedence

- `mise.local.toml` wins over `mise.toml`.
- With `MISE_ENV=dev`: `mise.toml` < `mise.dev.toml` < `mise.local.toml` < `mise.dev.local.toml`.
- A project's config wins over a parent directory's, and any project config wins over the
  global config.
- A value in `[env]` replaces a variable of the same name from the starting environment,
  except with `default` and `required`.
- A task's `env` applies to that task only and not to its dependencies.
- `MISE_*` variables in `[env]` do not configure the mise process that reads them. Use
  `[settings]` or the real environment. The SOPS key variables are the exception.

## vars

`[vars]` holds values for templates that should not be exported:

```toml
[vars]
e2e_args = "--headless"
registry = "ghcr.io/myorg"

[tasks.e2e]
run = "./scripts/e2e.sh {{vars.e2e_args}}"
```

Top-level vars are resolved at config load. A task can set its own `vars`, which is how a
task template is parameterized (see `tasks.md`).

## Secrets

`mise.local.toml` and `.env` are plain text; the name does not encrypt anything.

| Approach | You commit | Who receives the values |
| --- | --- | --- |
| fnox (experimental, recommended by the docs) | `fnox.toml` with references or encrypted values | Only tasks that list the key, and commands run with `--secrets` |
| SOPS file | An encrypted `.env.json`, `.env.yaml` or `.env.toml` | Everything that loads `[env]` |
| age values (experimental) | Encrypted values in `mise.toml` | Everything that loads `[env]` |
| Untracked file | Nothing; the file is in `.gitignore` | Everything that loads `[env]` |

SOPS with an age key (mise decrypts age-encrypted SOPS files itself):

```sh
mise use -g sops age
mise exec -- age-keygen -o ~/.config/mise/age.txt          # prints the public key
mise exec -- sops encrypt -i --age "age1..." .env.json
```

```toml
[env]
_.file = { path = ".env.json", redact = true }
```

mise uses the first key it finds: `MISE_SOPS_AGE_KEY` (or the `sops.age_key` setting),
`MISE_SOPS_AGE_KEY_FILE` (or `sops.age_key_file`), `SOPS_AGE_KEY_FILE`, `SOPS_AGE_KEY`,
then `~/.config/mise/age.txt`. For AWS
KMS and other providers set `sops.rops = false` so mise calls the `sops` CLI.

Redaction masks values in task output that mise captures:

```toml
redactions = ["API_KEY", "SECRETS_*"]

[env]
TOKEN = { value = "{{ env.DEPLOY_TOKEN }}", redact = true }
```

Raw and interactive tasks bypass redaction, and commands still receive the real values.
`mise env`, `mise env --json-extended`, trace logs and the MCP `mise://env` resource show
real values: redact before sharing.

## Inspect and disable

```sh
mise env                      # shell assignments for the current directory
mise env --json               # also --dotenv
mise env --json-extended      # each variable with the file (and tool) that set it
mise exec -- sh -c 'echo "$NODE_ENV"'
mise --no-env exec -- env     # skip [env] from every config (MISE_NO_ENV=1)
MISE_SAFE=1 mise env          # ignore project [env]; never run _.source
```
