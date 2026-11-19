# Tasks

Contents: [Choose a format](#choose-a-format) - [TOML tasks](#toml-tasks) - [Shell and failure behavior](#shell-and-failure-behavior) -
[File tasks](#file-tasks) - [Arguments with usage](#arguments-with-usage) - [Task templates](#task-templates) -
[Dependencies and order](#dependencies-and-order) - [Running tasks](#running-tasks) - [Sources, outputs, watch](#sources-outputs-watch) -
[Task environment](#task-environment) - [Discovery and sharing](#discovery-and-sharing) -
[Scaffolding tasks](#scaffolding-tasks) - [Managing tasks from the CLI](#managing-tasks-from-the-cli)

Source pages: https://mise.jdx.dev/tasks/, /tasks/toml-tasks.html, /tasks/file-tasks.html,
/tasks/templates.html, /tasks/running-tasks.html, /tasks/task-arguments.html,
/tasks/task-configuration.html, /mise-cookbook/presets.html

## Choose a format

| Format | Use it when | Where it lives |
| --- | --- | --- |
| TOML task | The command fits on a line or two, or the task mostly runs other tasks | `[tasks.<name>]` in `mise.toml` |
| File task | The script is long enough to want editor highlighting and linting | An executable script in `mise-tasks/` |

Both run with the project's tools and `[env]`, without shell activation, and install
missing tools first. Do not define one name in both places. Templates:
`assets/tasks/bash-task`, `assets/tasks/python-uv-task.py`.

## TOML tasks

```toml
[tasks]
fmt = "ruff format ."                        # shortest form

[tasks.build]
description = "Build the CLI"
alias = "b"
run = "cargo build"
sources = ["Cargo.toml", "src/**/*.rs"]
outputs = ["target/debug/mycli"]

[tasks.test]
depends = ["build"]
env = { RUST_BACKTRACE = "1" }
run = ["cargo test", "./scripts/test-e2e.sh"]   # in order; stops at the first failure
run_windows = "cargo test --features windows"

[tasks."test:unit"]                           # ":" groups tasks; quote the key
tags = ["test"]
run = "cargo test --lib"

[tasks.release]
description = "Cut a new release"
confirm = "Cut a new release?"
file = "scripts/release.sh"                   # a script instead of inline run

[tasks.dev]
alias = "default"                             # `mise run` with no name runs this
dir = "{{cwd}}"                               # run where mise was called, not the config root
run = "npm run dev"
```

Common properties: `description`, `alias`, `run`, `run_windows`, `file`, `depends`,
`depends_post`, `wait_for`, `env`, `vars`, `tools`, `dir`, `sources`, `outputs`, `shell`,
`usage`, `confirm`, `hide`, `tags`, `quiet`, `silent`, `raw`, `timeout`, `extends`.
`file` also accepts `https://...` and `git::https://host/org/repo.git//path?ref=v1.0.0`;
remote files are cached until `mise cache clear` or `mise run --no-cache`.

## Shell and failure behavior

- On Unix, inline commands run with `sh -o errexit -c`, so a script stops at the first
  failing command. Windows default is `cmd /c`.
- A custom `shell` (even `bash -c`), a shebang script, and Windows `cmd /c` do **not**
  stop at the first failure. Add `set -euo pipefail` yourself:

  ```toml
  [tasks.lint]
  run = '''
  #!/usr/bin/env bash
  set -euo pipefail
  cargo clippy
  '''
  ```

- A shebang makes the inline script run as a file, in any language:

  ```toml
  [tasks.report]
  run = '''
  #!/usr/bin/env -S uv run --script
  # /// script
  # dependencies = ["rich"]
  # ///
  from rich import print
  print("[bold]ok[/bold]")
  '''
  ```

- `shell = "node -e"`, `shell = "pwsh -Command"` and similar select an interpreter for
  `run` strings.
- A simple command with no shell syntax may be started directly without `sh`.

## File tasks

An executable script in a task directory. Its path below the directory is the name, with
`/` replaced by `:`.

```text
mise-tasks
├── build                 -> build
├── db
│   └── migrate.sh        -> db:migrate   (script extensions are dropped)
└── test
    ├── _default          -> test
    ├── integration       -> test:integration
    └── units             -> test:units
```

```bash
#!/usr/bin/env bash
#MISE description="Build the CLI"
#MISE alias="b"
#MISE sources=["Cargo.toml", "src/**/*.rs"]
#MISE outputs=["target/debug/mycli"]
#MISE env={RUST_BACKTRACE = "1"}
#MISE depends=["lint", "test"]
#MISE tools={rust="1.90"}
set -euo pipefail
cargo build
```

- Make it executable (`chmod +x`). mise lists only executable scripts.
- The marker can be `#MISE`, `# MISE`, `//MISE` (JavaScript, TypeScript, Go), `::MISE`
  (batch) or `# [MISE]`. Each line holds TOML; arrays may span lines if every line keeps
  the prefix. Dotted keys work: `#MISE tools.node="24"`.
- Headers accept every task property except `run`, `run_windows`, `file` and `usage`.
- Add a shebang even on Unix: Windows needs it for files without an executable extension.
  For one task with two scripts, put `build.sh` and `build.ps1` side by side.
- `mise run ./scripts/build.sh` runs any executable script as a task, headers included.
- `mise tasks edit <name>` creates and opens a file task; `mise tasks add --file <name> -- <cmd>`
  creates one from a command.

## Arguments with usage

Without a spec, extra arguments are forwarded: appended to the last `run` entry of an
inline command, or passed as `$1`, `$@` to a shebang script or file task. With a spec,
mise parses and validates them, adds `--help` and completions, and passes each value as a
`usage_<name>` environment variable (`-` becomes `_`).

```toml
[tasks.deploy]
usage = '''
arg "<env>" help="Target environment" { choices "staging" "prod" }
arg "[files]" var=#true help="Files to deploy"
flag "-n --dry-run" help="Print the plan only"
flag "-r --region <region>" help="AWS region" default="us-east-1" env="AWS_REGION"
flag "-v --verbose" count=#true
'''
run = 'echo "env=${usage_env?} region=${usage_region?} dry_run=${usage_dry_run:-false}"'
```

In file tasks the same lines are `#USAGE` comments (`//USAGE` in JavaScript).

| Spec | Meaning |
| --- | --- |
| `arg "<file>"` / `arg "[file]"` | Required / optional positional |
| `default="x"` | Value when not given |
| `arg "[files]" var=#true` | Zero or more values (`<files>` needs at least one) |
| `{ choices "a" "b" }` | Accept only the listed values |
| `env="API_TOKEN"` | Take the value from an environment variable |
| `flag "-f --force"` | Boolean flag |
| `flag "-o --output <file>"` | Flag with a value |
| `required=#true` | Fail unless the flag is passed |
| `count=#true` | Repeatable flag whose value is the count |
| `flag "--color" negate="--no-color" default=#true` | Boolean that `--no-color` turns off |
| `help="..."`, `long_help="..."`, `hide=#true` | Help text and visibility |
| `complete "user" run="mycli users"` | Complete from a command's output |

Reading values in Bash, so shellcheck sees the unset cases:

| Syntax | Use for |
| --- | --- |
| `${usage_x?}` | Required arguments, and anything with a `default` |
| `${usage_x:-false}` | Boolean flags without a default; compare with `= "true"` |
| `${usage_x:-}` | Optional arguments without a default |

A variadic value arrives as one shell-quoted string; `eval "files=($usage_files)"` turns
it into a Bash array. Tera `arg()`, `option()` and `flag()` inside `run` are deprecated.
Full spec: https://usage.jdx.dev/spec/

## Task templates

A template holds fields several tasks share. It is not runnable and cannot extend another
template.

```toml
[task_templates."python:test"]
tools = { python = "3.14", uv = "latest" }
env = { PYTHONPATH = "src" }
depends = ["build"]
run = "uv run pytest"

[tasks.test]
extends = "python:test"

[tasks."test:cov"]
extends = "python:test"
run = "uv run pytest --cov"        # replaces run; keeps tools, env, depends
```

File tasks use `#MISE extends="python:test"` and ignore the template's `run`.

| Property | When both set it |
| --- | --- |
| `run`, `run_windows`, `file`, `alias`, `sources`, `outputs` | The task's value replaces the template's |
| `tools`, `env`, `vars` | Merged by key; the task wins for the same key |
| `depends`, `depends_post`, `wait_for` | The task's list replaces the template's |
| `usage` | Both specs, the template's first |
| `deny_*` | On when either sets it |
| `quiet`, `hide`, `raw`, `interactive`, `extends`, `secrets` | Not accepted in templates |

An empty list on the task (`depends = []`) inherits the template's value; it does not
clear it. Parameterize with `vars`:

```toml
[task_templates.e2e]
vars = { mode = "headless" }
run = "echo --mode={{ vars.mode }}"

[tasks."e2e:headed"]
extends = "e2e"
vars = { mode = "headed" }
```

`mise tasks info <task>` shows the merged result.

## Dependencies and order

- `depends` run before the task and may run in parallel; their order in the list is not a
  sequence. If one fails, the task does not run.
- `depends_post` run after the task. `wait_for` waits for another task only if it is
  already part of the run.
- For a strict sequence, use run steps: `run = [{ task = "build" }, "./deploy.sh"]`.
- Glob patterns work in `depends`: `depends = ["lint:*"]`.
- `confirm` prompts after `depends` have already run.

## Running tasks

```sh
mise run build                       # also: mise r build; `mise build` works but avoid it in scripts
mise run                             # the task named or aliased "default", else a selector
mise run build arg1 ::: test arg2    # several tasks, each with its own arguments
mise run 'test:*'                    # quote globs: * within a group, ** across groups, {a,b}
mise run --tag lint                  # by tag
mise run --dry-run build --release   # mise's flags go before the task name
mise tasks ls --extended             # where each task is defined (--hidden for hide = true)
mise tasks deps build                # dependency tree
```

| Flag | Effect |
| --- | --- |
| `-j`, `--jobs <N>` | Run up to N tasks at once |
| `-f`, `--force` | Run even when outputs are up to date |
| `-n`, `--dry-run` | Print each command in order without running |
| `-c`, `--continue-on-error` | Keep going after a failure; exit non-zero at the end |
| `--skip-deps` | Run only the named tasks |
| `--timeout <DURATION>` | Stop the whole run after `30s`, `5m`, ... |
| `-t`, `--tool <TOOL@VERSION>` | Add a tool to the run |
| `-r`, `--raw` | Connect stdin/stdout/stderr directly; one task at a time; no redaction |
| `--output <style>` | `prefix`, `interleave`, `keep-order`, `replacing`, `summary`, `timed`, `silent` |
| `--quiet`, `--silent` | Hide mise's messages, or the tasks' output too |

Everything after the task name belongs to the task.

## Sources, outputs, watch

With `sources` and `outputs`, mise skips a task while its outputs are newer than its
sources and prints `sources up-to-date, skipping`. `mise run --force` runs it anyway. The
check compares modification times.

```sh
mise watch build              # rerun when the task's sources change
mise watch --restart dev      # restart a long-running process on change
mise watch build --once       # block until a change, run once, exit with that status
```

A task without `sources` watches the current directory.

## Task environment

| Variable | Value |
| --- | --- |
| `MISE_ORIGINAL_CWD` | The directory where mise was run |
| `MISE_CONFIG_ROOT` | Config root of the file that defines the task |
| `MISE_PROJECT_ROOT` | Root of the project that defines the task |
| `MISE_TASK_NAME` | The task's name |
| `MISE_TASK_FILE`, `MISE_TASK_DIR` | The script (or defining config file) and its directory |
| `MISE_ENV` | Active config environments, when any |
| `usage_*` | Argument and flag values |

Tasks run from the config root unless `dir` says otherwise. Global tasks run in the home
directory unless they set `dir = "{{cwd}}"`.

## Discovery and sharing

Default task directories, per config root: `mise-tasks`, `.mise-tasks`, `.mise/tasks`,
`.config/mise/tasks`, `mise/tasks`. Global file tasks: `~/.config/mise/tasks`.

```toml
[task_config]
includes = [
  "mise-tasks",                      # listing anything replaces the defaults, so re-list them
  "tasks.toml",                      # tasks written as under [tasks], without the prefix
  "git::https://github.com/myorg/shared-tasks.git//tasks?ref=v1.0.0",
]
```

Remote includes run code from that repository: pin a tag or commit. Monorepos address
tasks as `//path:task` after setting `monorepo_root = true`
(https://mise.jdx.dev/tasks/monorepo.html).

## Scaffolding tasks

A global file task can set up new projects. Save as `~/.config/mise/tasks/scaffold/python`
and `chmod +x` it; it becomes `scaffold:python` in every directory:

```bash
#!/usr/bin/env bash
#MISE description="Add Python, uv and test tasks to the current project"
#MISE dir="{{cwd}}"
#USAGE arg "[version]" default="3.14" help="Python version"
set -euo pipefail

mise use "python@${usage_version?}" uv@latest
mise tasks add sync --description "Sync locked dependencies" -- uv sync --locked
mise tasks add test --description "Run tests" -- uv run --locked pytest
```

```sh
mkdir my-project && cd my-project
mise run scaffold:python 3.13
mise exec -- uv init --bare && mise exec -- uv add --dev pytest
```

For whole-file starting points, copy a template from `assets/project/` instead.

## Managing tasks from the CLI

```sh
mise tasks add pre-commit --depends test --depends render -- echo pre-commit
mise tasks add --env local deploy --env-var STAGE=prod --tools node@24 --confirm "Deploy now?" -- ./deploy.sh
mise tasks set build --description "Build the CLI"   # change fields of an existing task
mise tasks rm old-task
mise tasks info build
mise tasks validate                                 # catches bad usage specs and references
mise generate task-docs                             # Markdown docs from the task specs
mise generate git-pre-commit --write --task=pre-commit   # git hook; staged files in $STAGED
mise generate task-stubs --mise-bin ./bin/mise      # bin/<task> wrappers for people without mise
```

`mise tasks add` replaces a task with the same name; pass `--force` to state that intent
(silent replacement is deprecated). `add`, `set` and `rm` accept `--dry-run` and `--json`.
