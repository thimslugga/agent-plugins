# Reference implementations (sh, Python, Go, Rust)

All of these apply the unset/empty and absolute-path rules. Reuse them instead of writing a quick `os.path.expanduser("~/.config")`.

## POSIX sh

```sh
# Return $1 if it is an absolute path, otherwise the default in $2.
xdg_dir() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s\n' "$2" ;;
  esac
}

config_home=$(xdg_dir "${XDG_CONFIG_HOME:-}" "$HOME/.config")
data_home=$(xdg_dir "${XDG_DATA_HOME:-}" "$HOME/.local/share")
state_home=$(xdg_dir "${XDG_STATE_HOME:-}" "$HOME/.local/state")
cache_home=$(xdg_dir "${XDG_CACHE_HOME:-}" "$HOME/.cache")

# Print the first readable match for a relative path such as myapp/config.toml.
find_config() {
  _old_ifs=$IFS; IFS=:
  for _d in "$config_home" ${XDG_CONFIG_DIRS:-/etc/xdg}; do
    IFS=$_old_ifs
    case "$_d" in /*) ;; *) continue ;; esac
    if [ -r "$_d/$1" ]; then printf '%s\n' "$_d/$1"; return 0; fi
  done
  IFS=$_old_ifs
  return 1
}

# Create a writable app directory without touching an existing one's mode.
[ -d "$state_home/myapp" ] || mkdir -p -m 0700 "$state_home/myapp"
```

## Python (stdlib only)

```python
from __future__ import annotations

import os
from pathlib import Path


def _home(var: str, default: str) -> Path:
    raw = os.environ.get(var, "")
    path = Path(raw)
    return path if raw and path.is_absolute() else Path.home() / default


def _dirs(var: str, default: str) -> list[Path]:
    raw = os.environ.get(var) or default
    return [Path(p) for p in raw.split(os.pathsep) if p and Path(p).is_absolute()]


CONFIG_HOME = _home("XDG_CONFIG_HOME", ".config")
DATA_HOME = _home("XDG_DATA_HOME", ".local/share")
STATE_HOME = _home("XDG_STATE_HOME", ".local/state")
CACHE_HOME = _home("XDG_CACHE_HOME", ".cache")
CONFIG_DIRS = _dirs("XDG_CONFIG_DIRS", "/etc/xdg")
DATA_DIRS = _dirs("XDG_DATA_DIRS", "/usr/local/share/:/usr/share/")


def find_config(relpath: str) -> Path | None:
    """Return the highest-priority existing config file, or None."""
    for base in (CONFIG_HOME, *CONFIG_DIRS):
        candidate = base / relpath
        if candidate.is_file():
            return candidate
    return None


def writable_dir(base: Path, app: str) -> Path:
    """Create base/app with 0700 if missing; leave an existing dir alone."""
    path = base / app
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    return path
```

`platformdirs` is the usual third-party choice when Windows and macOS native paths are also wanted. Note that it does **not** read `XDG_*` on macOS by default.

## Go (`github.com/adrg/xdg`)

```go
import "github.com/adrg/xdg"

// Path for writing; parent directories are created.
cfgPath, err := xdg.ConfigFile("myapp/config.yaml")

// Search ConfigHome, then ConfigDirs, for an existing file.
found, err := xdg.SearchConfigFile("myapp/config.yaml")

// Same pattern: DataFile/SearchDataFile, StateFile/SearchStateFile,
// CacheFile/SearchCacheFile, RuntimeFile/SearchRuntimeFile.
// Variables: xdg.ConfigHome, DataHome, StateHome, CacheHome, RuntimeDir,
// ConfigDirs, DataDirs, BinHome, Home, FontDirs, ApplicationDirs.
// User dirs: xdg.UserDirs.Download, .Documents, .Desktop, .Music,
// .Pictures, .Videos, .Templates, .PublicShare, .Projects.
```

adrg/xdg defaults per OS (when the `XDG_*` variable is not set):

| Variable | Linux/BSD | macOS | Windows |
|---|---|---|---|
| ConfigHome | `~/.config` | `~/Library/Application Support` | `%LOCALAPPDATA%` |
| DataHome | `~/.local/share` | `~/Library/Application Support` | `%LOCALAPPDATA%` |
| StateHome | `~/.local/state` | `~/Library/Application Support` | `%LOCALAPPDATA%` |
| CacheHome | `~/.cache` | `~/Library/Caches` | `%LOCALAPPDATA%\cache` |
| RuntimeDir | `/run/user/$UID` | `~/Library/Application Support` | `%LOCALAPPDATA%` |
| BinHome | `~/.local/bin` | `~/.local/bin` | `%LOCALAPPDATA%\Programs` |

With Koanf, load in rising priority: built-in defaults, each `SearchConfigFile` hit from lowest to highest priority directory, then environment, then flags (Kong).

## Rust

The Arch Wiki lists two Rust libraries: `xdg` (rust-xdg), which implements the spec directly and suits Linux-first CLI tools, and `directories` (directories-rs), which uses native macOS and Windows locations. The `etcetera` crate is a third option with an explicit XDG strategy on every OS. Check the crate's current docs before pinning.
