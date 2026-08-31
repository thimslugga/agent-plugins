# Portability

Decide the target before writing, because the target decides the syntax.

## Choosing the shebang

The style guide mandates `#!/bin/bash` with minimal flags, and allows an
exception where the target environment forces one.

| Shebang               | Use when                                              | Cost                                                      |
| --------------------- | ----------------------------------------------------- | --------------------------------------------------------- |
| `#!/bin/bash`         | Default. One known image, any Linux fleet, containers | Picks the system bash, which on macOS is 3.2              |
| `#!/usr/bin/env bash` | The exception: macOS in scope, or a Homebrew bash     | Depends on `PATH`; passing flags after it is not portable |
| `#!/bin/sh`           | POSIX portability is an actual requirement            | No arrays, no `[[`, no `local`, no `pipefail`             |

Put shell options on a `set` line rather than in the shebang. Two reasons: the
guide requires it, and `#!/usr/bin/env bash -e` does not work reliably, since
many kernels pass `bash -e` as a single argument.

## Bash version gates

```bash
if (( BASH_VERSINFO[0] < 4 )); then
  die "bash 4 or newer required, found ${BASH_VERSION}"
fi
```

| Needs                                                               | Introduced in |
| ------------------------------------------------------------------- | ------------- |
| `mapfile` / `readarray`, associative arrays, `${var^^}`, `globstar` | 4.0           |
| `declare -g`, negative array indices                                | 4.2           |
| `local -n` namerefs                                                 | 4.3           |
| Empty `"${arr[@]}"` safe under `set -u`, `${var@Q}`                 | 4.4           |
| `EPOCHSECONDS`, `EPOCHREALTIME`                                     | 5.0           |

macOS ships bash 3.2 and will not update it, so anything in this table breaks there unless the user installed a newer bash from Homebrew.

## Bash versus POSIX sh

Writing `#!/bin/sh` means giving up:

| bash                 | POSIX sh replacement                                    |
| -------------------- | ------------------------------------------------------- |
| `[[ "$a" == "$b" ]]` | `[ "$a" = "$b" ]`                                       |
| `[[ "$s" =~ re ]]`   | `expr` or `case`, or `grep -q`                          |
| `arr=(a b c)`        | Positional parameters, or a delimited string            |
| `local var`          | Widely supported in practice, not in the standard       |
| `set -o pipefail`    | Not available, check `${PIPESTATUS}` equivalent by hand |
| `$(( ))` with `++`   | `n=$(( n + 1 ))`                                        |
| `source file`        | `. file`                                                |
| `function name() {}` | `name() {}`                                             |

A trap worth knowing: on Red Hat family systems, including Amazon Linux 2023, `/bin/sh` is bash running in POSIX mode. Bashisms in a `#!/bin/sh` script therefore work fine there and then fail on Alpine, whose `/bin/sh` is BusyBox `ash`. Test `#!/bin/sh` scripts with `dash` or `busybox sh`, not with the local `/bin/sh`.

## GNU versus BSD tools

Linux ships GNU coreutils, macOS ships BSD versions with the same names and different flags.

| Task               | GNU                   | BSD / macOS            | Portable option                  |
| ------------------ | --------------------- | ---------------------- | -------------------------------- |
| Edit in place      | `sed -i 's/a/b/'`     | `sed -i '' 's/a/b/'`   | Write to a temp file and `mv`    |
| Relative date      | `date -d '1 day ago'` | `date -v-1d`           | Compute from `date +%s`          |
| Resolve symlink    | `readlink -f "$p"`    | Missing on older macOS | `cd "$(dirname "$p")" && pwd -P` |
| File size          | `stat -c %s`          | `stat -f %z`           | `wc -c < "$file"`                |
| Skip empty input   | `xargs -r`            | Default behaviour      | Guard with `[[ -s "$list" ]]`    |
| Perl regex         | `grep -P`             | Not available          | `grep -E`                        |
| Single-line base64 | `base64 -w0`          | `base64`               | `base64 \| tr -d '\n'`           |
| Find with format   | `find -printf`        | Not available          | `find -exec`                     |

`sed -E` for extended regex works on both. `sed -r` is GNU only.

## Locale

Sorting and character classes follow the locale, which makes output differ between a laptop and a CI runner:

```bash
export LC_ALL=C   # byte order sorting, predictable ranges, faster grep
```

Set it when the script compares or sorts data. Leave it unset when the script prints text for humans in other languages.

## Amazon Linux 2023

- `dnf` is the package manager on the full image; the minimal variant ships a reduced package set and expects `microdnf`. Verify with `command -v` rather than assuming.
- Bash 5.2 and GNU coreutils, so the GNU column above applies.
- `/bin/sh` is bash in POSIX mode. See the trap noted earlier.
- Minimal images drop things that scripts casually assume: full `curl`, `tar`, `ps`, `which`, and `hostname` are all worth checking before use. Install them explicitly in the Dockerfile rather than discovering the gap at runtime.
- Scripts that run at build time should pin package versions, since a rebuilt image otherwise picks up new ones silently.

Start every script that runs inside a container with an explicit dependency check:

```bash
require_cmd curl tar jq
```

## Container entrypoints

```bash
#!/bin/bash
#
# Container entrypoint: prepare state, then hand off to the real process.

set -Eeuo pipefail

# Configuration, migrations, and permission fixes go here.

exec "$@"
```

Two details decide whether `docker stop` is graceful or takes ten seconds and a kill:

1. Use the exec form in the Dockerfile: `ENTRYPOINT ["/entrypoint.sh"]`. The shell form wraps the script in `/bin/sh -c`, adding a process that does not forward signals.
2. End with `exec "$@"` so the real process replaces the shell and becomes PID 1 itself. Without `exec`, bash stays PID 1, and a process running as PID 1 ignores signals that have no handler installed, so SIGTERM goes nowhere.

When the entrypoint genuinely needs to keep running alongside the workload, install traps explicitly and forward the signal to the child, or use a small init such as `tini`.

## Bash on Windows

Git Bash and WSL both convert paths in ways that surprise scripts. Anything that runs on Windows should be Python or Go instead.
