# Troubleshooting

Contents: [Collect diagnostics](#collect-diagnostics) - [Symptom table](#symptom-table) -
[Activation and PATH](#activation-and-path) - [Versions and downloads](#versions-and-downloads) -
[Tasks](#tasks) - [Windows](#windows)

Source pages: https://mise.jdx.dev/troubleshooting.html, /errors.html, /faq.html, /cache-behavior.html

## Collect diagnostics

Run these from the directory where the problem happens:

```sh
mise --version
mise doctor               # setup problems, config files, tools, activation status
mise doctor path          # the PATH entries mise adds
mise config ls            # config files in effect, lowest precedence first
mise ls --current         # selected versions and the file that requested each
mise which <command>      # the executable this directory runs
mise tool <tool>          # backend, requested and active versions, config source
mise settings ls          # settings set in config files and where
```

- Rerun the failing command with `--verbose`, or `MISE_DEBUG=1` (`MISE_TRACE=1` for more).
  Keep a log with `MISE_LOG_FILE=mise.log MISE_LOG_FILE_LEVEL=debug`.
- `mise install --raw <tool>` installs one tool at a time with the installer attached to
  the terminal, which shows prompts and build errors the progress display hides.
- For a shell problem, compare the command in the shell with `mise exec -- <command>`.
- Logs, trace output and `mise env` output can contain secrets and private paths.
- Deleting mise's data directory or reinstalling every tool rarely fixes a
  version-selection or shell problem. Diagnose first.

## Symptom table

| Symptom | Likely cause | Check or fix |
| --- | --- | --- |
| Tool missing in an editor, script, cron job, CI or agent shell | Activation never ran there | `mise exec --`, shims in the login profile, or the agent hook (`agents-mcp-editors.md`) |
| `mise: command not found` in a startup file | `~/.local/bin` is not on `PATH` yet | Use the absolute path in the activation line |
| `No version is set for shim: <tool>` | The current directory's config does not select the tool | `mise ls --current`; `mise use <tool>` here or `mise use -g <tool>` |
| Wrong version runs | A nearer config, `MISE_<TOOL>_VERSION`, or another manager earlier on `PATH` | `mise which <cmd>`, `mise config ls`, `mise doctor path` |
| A system binary runs instead of the mise one | Shim fell back to `PATH` because the version is not installed | `mise install`; set `not_found_system_fallback = false` |
| `[env]` variable missing in the shell | Shims do not export `[env]` to the shell | `mise activate`, or `mise exec -- sh -c 'echo "$VAR"'` |
| Config ignored, or an untrusted-config error | The file needs trust | Review it, then `mise trust`; `mise trust --show` |
| New release not listed or not chosen by `latest` | 24h `minimum_release_age`, or a cached list | See [Versions and downloads](#versions-and-downloads) |
| `403 Forbidden` or rate limit on install | Unauthenticated GitHub API | Set `GITHUB_TOKEN` or `MISE_GITHUB_TOKEN` (https://mise.jdx.dev/dev-tools/github-tokens.html) |
| Typing a missing command does not install it | The tool is declared with a raw backend and never installed, or auto-install is off | `mise install`; check `not_found_auto_install` |
| `pipx:`/`pypi:` tool fails to install | No `uv`, pipx or Python | `mise use uv python` in the same config |
| `npm:` tool installs but will not run | No Node.js | Add `node` to `[tools]` |
| `cargo:` tool compiles for minutes | No prebuilt binary path | `mise use -g cargo-binstall` |
| Venv not active | Shims only, or no `uv.lock` yet | Use activation or `mise exec`; run `uv sync` once |
| Slow prompt | Heavy `_.source` scripts, `exec()` templates, hooks | `mise doctor`; time `mise hook-env`; move work into tasks |
| Task does not stop on an error | Shebang script or custom `shell` | Add `set -euo pipefail` |
| Task argument is empty or `unexpected word` | Flags placed after the task name, or no `usage` spec | mise flags go before the task name; define `usage` |
| File task not listed | Not executable, or defined twice | `chmod +x`; `mise tasks ls --extended`; `mise tasks validate` |
| Secrets visible in task output | Raw or interactive task bypasses redaction | Avoid `--raw` for tasks that print secrets |
| MCP resources are stale | The server caches config | Restart the server from the client |
| MCP `Failed to load config` | Untrusted project | `mise trust` in the project, or `MISE_SAFE=1` |
| Shims missing after an install | Rare; shims out of date | `mise reshim` |
| Old mise rejects a config | Newer syntax | Set `min_version`; `mise self-update` |

## Activation and PATH

- `mise doctor` reports `activated: yes` when the hook is loaded. If not, the activation
  line is not in the startup file this shell reads, or `mise` was not on `PATH` when it
  ran.
- Login shells read profile files (`~/.zprofile`, `~/.bash_profile`); interactive shells
  read `~/.zshrc` and `~/.bashrc`. A login bash reads only the first of
  `~/.bash_profile`, `~/.bash_login`, `~/.profile`, and `~/.bashrc` only if that file
  sources it.
- Creating `~/.bash_profile` on Ubuntu or Debian stops `~/.profile` from loading. Start
  the new file with `[[ -f ~/.profile ]] && source ~/.profile`.
- Editors and GUI programs read these files only when they start. Restart the editor, or
  log out and back in.
- In PowerShell 5.1 and Nushell, `cd dir; tool` on one line still uses the previous
  directory's tools.
- Running Intel tools on Apple silicon: set `MISE_ARCH=x64` and a separate
  `MISE_DATA_DIR`, with Rosetta installed.

## Versions and downloads

Three things can hide a release from the last day: the minimum release age (24h for most
backends; `mise ls-remote` warns about hidden releases), mise's cached version list, and
the mise-versions host that serves most lists on a schedule.

```sh
mise use node@24.11.1                                    # an exact version skips the age filter
mise upgrade --minimum-release-age 0s gh                 # one tool, one command
mise cache clear node
mise ls-remote --no-versions-host --minimum-release-age 0s node
```

A prefix whose matching releases are all hidden fails with a 404. Offline or proxied
networks: mise's HTTP client reads `HTTPS_PROXY` from the environment that starts mise,
not from `install_env`.

## Tasks

- `mise tasks validate` reports invalid usage specs and references.
- `mise run --dry-run <task>` prints the commands in order; `mise tasks info <task>` shows
  the merged definition and where it comes from; `mise tasks deps <task>` shows the tree.
- `sources up-to-date, skipping`: run with `--force`.
- A task defined in both `mise.toml` and `mise-tasks/` conflicts: keep one.

## Windows

- cmd.exe cannot be activated; put `%LOCALAPPDATA%\mise\shims` on the user `Path`.
- Long `Path` values break cmd.exe; prefer shims to many per-tool directories.
- A `bash -c` task run from PowerShell needs a POSIX bash (Git for Windows); mise never
  uses the WSL launcher at `C:\Windows\System32\bash.exe`.
- File tasks need a shebang or an extension listed in `windows_executable_extensions`.
- Keep `mise.exe` and `mise-shim.exe` together; after a partial update run
  `mise reshim --force`.
- Windows shims can leak into WSL through the inherited `PATH`; remove them from the WSL
  `PATH` or install mise inside WSL as well.
