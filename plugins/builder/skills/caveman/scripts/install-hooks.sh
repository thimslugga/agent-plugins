#!/usr/bin/env bash
#
# install-hooks.sh - install the caveman SessionStart hooks for supported agents.
#
# What it does:
#   claude-code  Merge a SessionStart hook into ~/.claude/settings.json.
#                The hook resolves the default mode and injects the caveman
#                ruleset on session start. Silent for modes off/manual.
#   codex        Write .codex/hooks.json + .codex/config.toml ([features]
#                hooks = true) in the current project (project scope only,
#                mirroring upstream).
#
# Mode resolution (same order as the hook): CAVEMAN_DEFAULT_MODE env var,
# repo-local .caveman/config.json or .caveman.json, user config
# ~/.config/caveman/config.json, default caveman. Use --mode to write the
# user config. Valid modes in this bundle: off, manual, caveman, ultracave.
#
# Idempotent: re-running changes nothing unless --force is given.
#
# Examples:
#   ./scripts/install-hooks.sh --dry-run
#   ./scripts/install-hooks.sh --agent claude-code
#   ./scripts/install-hooks.sh --agent codex --mode off
#   ./scripts/install-hooks.sh --uninstall

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
SKILL_DIR="$(dirname -- "$SCRIPT_DIR")"
readonly SKILL_DIR
readonly SKILL_NAME="caveman"
readonly HOOKS_DIR="$SKILL_DIR/hooks"
readonly HOOK_MATCHER="startup|resume|clear|compact"
readonly HOOK_STATUS="Loading caveman mode"
readonly HOOK_TIMEOUT=10
readonly VALID_MODES="off manual caveman ultracave"
readonly TOML_MARKER="# managed by caveman install-hooks.sh"

DRY_RUN=0
FORCE=0
UNINSTALL=0
MODE=""
declare -a WANT_AGENTS=()

caveman_log() { printf '%s\n' "$*"; }
caveman_warn() { printf 'warning: %s\n' "$*" >&2; }
caveman_err() { printf 'error: %s\n' "$*" >&2; }
caveman_die() {
  caveman_err "$*"
  exit 1
}

caveman_usage() {
  cat <<'USAGE'
Usage: install-hooks.sh [OPTIONS]

Install the caveman SessionStart hooks for supported agents.

Options:
  --agent NAME     claude-code or codex. Repeatable. Default: all detected.
                   (codex installs at project scope: .codex/ in the cwd.)
  --mode MODE      Write the user default-mode config
                   (~/.config/caveman/config.json). One of:
                   off, manual, caveman, ultracave.
  --dry-run       Print every action. Write nothing.
  --force         Replace existing hook entries.
  --uninstall     Remove installed hooks.
  -h, --help      Print this help.

Hook behavior: the SessionStart hook prints the caveman ruleset when the
resolved default mode is caveman (or ultracave, falling back to the
caveman ruleset since that sibling skill is not installed). Modes off
and manual stay silent. Resolution order: CAVEMAN_DEFAULT_MODE,
.caveman/config.json or .caveman.json (repo-local), user config,
default caveman.
USAGE
}

caveman_detect_agents() {
  local found=()
  if [[ -d ${CLAUDE_CONFIG_DIR:-$HOME/.claude} ]] || command -v claude >/dev/null 2>&1; then
    found+=(claude-code)
  fi
  if [[ -d "$HOME/.codex" ]] || command -v codex >/dev/null 2>&1; then
    found+=(codex)
  fi
  printf '%s\n' "${found[@]}"
}

caveman_hook_command() {
  # Prefer the Node hook; fall back to POSIX sh.
  if command -v node >/dev/null 2>&1; then
    printf 'node "%s/hooks/caveman-sessionstart.mjs"' "$SKILL_DIR"
  else
    printf 'sh "%s/hooks/caveman-sessionstart.sh"' "$SKILL_DIR"
  fi
}

# Merge (or remove) the SessionStart hook entry in a Claude Code settings.json.
# Args: settings_path command uninstall(0/1)
caveman_merge_settings() {
  local settings_path="$1" command="$2" uninstall="$3"
  python3 - "$settings_path" "$command" "$SKILL_NAME" "$HOOK_MATCHER" \
    "$HOOK_STATUS" "$HOOK_TIMEOUT" "$uninstall" "$FORCE" <<'EOF'
import json, sys

settings_path, command, skill, matcher, status, timeout, uninstall, force = sys.argv[1:9]
uninstall = uninstall == "1"
force = force == "1"

try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

hooks = settings.setdefault("hooks", {})
entries = hooks.setdefault("SessionStart", [])
existing = [e for e in entries if e.get("_skill") == skill]

if uninstall:
    kept = [e for e in entries if e.get("_skill") != skill]
    changed = len(kept) != len(entries)
elif force or not existing:
    entry = {
        "matcher": matcher,
        "hooks": [
            {
                "type": "command",
                "command": command,
                "timeout": int(timeout),
                "statusMessage": status,
            }
        ],
        "_skill": skill,
    }
    kept = [e for e in entries if e.get("_skill") != skill] + [entry]
    changed = True
else:
    kept = entries  # already installed: leave the existing entry untouched
    changed = False

hooks["SessionStart"] = kept
if changed:
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
print("changed" if changed else "unchanged")
EOF
}

caveman_install_claude_code() {
  local claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  local settings="$claude_dir/settings.json"
  local command
  command="$(caveman_hook_command)"
  if ((DRY_RUN)); then
    caveman_log "[dry-run] would merge SessionStart hook into $settings"
    caveman_log "[dry-run]   command: $command"
    return 0
  fi
  command -v python3 >/dev/null 2>&1 || caveman_die "python3 is required to merge $settings"
  mkdir -p "$claude_dir"
  local result
  result="$(caveman_merge_settings "$settings" "$command" 0)"
  caveman_log "claude-code: SessionStart hook $result in $settings"
}

caveman_uninstall_claude_code() {
  local claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  local settings="$claude_dir/settings.json"
  if ((DRY_RUN)); then
    caveman_log "[dry-run] would remove the $SKILL_NAME hook entry from $settings"
    return 0
  fi
  [[ -f $settings ]] || {
    caveman_log "claude-code: $settings not present, nothing to do"
    return 0
  }
  command -v python3 >/dev/null 2>&1 || caveman_die "python3 is required to edit $settings"
  local result
  result="$(caveman_merge_settings "$settings" "" 1)"
  caveman_log "claude-code: hook entry $result in $settings"
}

# Ensure .codex/config.toml enables hooks. Returns 0 always; prints status.
caveman_ensure_codex_toml() {
  local toml="$1" uninstall="$2"
  python3 - "$toml" "$uninstall" "$TOML_MARKER" "$FORCE" <<'EOF'
import sys

toml_path, uninstall, marker, force = sys.argv[1:5]
uninstall = uninstall == "1"
force = force == "1"

try:
    with open(toml_path) as f:
        text = f.read()
except FileNotFoundError:
    text = ""

if uninstall:
    # Only strip the hooks line when we own it (marker present).
    if marker in text:
        lines = [l for l in text.splitlines(keepends=True)
                 if l.strip() != "hooks = true" and l.rstrip("\n") != marker]
        text = "".join(lines)
        changed = True
    else:
        changed = False
else:
    if "hooks = true" in text and not force:
        changed = False
    else:
        if "[features]" not in text:
            if text and not text.endswith("\n"):
                text += "\n"
            text += "[features]\n"
        # insert hooks = true right after [features] if not present
        out = []
        done = False
        for line in text.splitlines(keepends=True):
            out.append(line)
            if not done and line.strip() == "[features]":
                out.append("hooks = true\n")
                out.append(marker + "\n")
                done = True
        text = "".join(out)
        changed = True

if changed:
    with open(toml_path, "w") as f:
        f.write(text)
print("changed" if changed else "unchanged")
EOF
}

caveman_install_codex() {
  local codex_dir="$PWD/.codex"
  local hooks_json="$codex_dir/hooks.json"
  local toml="$codex_dir/config.toml"
  local command
  command="$(caveman_hook_command)"
  if ((DRY_RUN)); then
    caveman_log "[dry-run] would write $hooks_json"
    caveman_log "[dry-run]   command: $command"
    caveman_log "[dry-run] would ensure [features] hooks = true in $toml"
    return 0
  fi
  command -v python3 >/dev/null 2>&1 || caveman_die "python3 is required to write $hooks_json"
  mkdir -p "$codex_dir"
  if [[ -f $hooks_json ]] && ! ((FORCE)); then
    if grep -qF "$SKILL_DIR" "$hooks_json"; then
      caveman_log "codex: $hooks_json already references this skill"
    else
      caveman_warn "$hooks_json exists and does not reference this skill; use --force to replace"
      return 0
    fi
  else
    python3 - "$hooks_json" "$command" "$HOOK_MATCHER" "$HOOK_STATUS" "$HOOK_TIMEOUT" <<'EOF'
import json, sys
hooks_path, command, matcher, status, timeout = sys.argv[1:6]
doc = {"hooks": {"SessionStart": [{
    "matcher": matcher,
    "hooks": [{
        "type": "command",
        "command": command,
        "timeout": int(timeout),
        "statusMessage": status,
    }],
}]}}
with open(hooks_path, "w") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
EOF
    caveman_log "codex: wrote $hooks_json"
  fi
  local result
  result="$(caveman_ensure_codex_toml "$toml" 0)"
  caveman_log "codex: $toml hooks feature $result"
}

caveman_uninstall_codex() {
  local codex_dir="$PWD/.codex"
  local hooks_json="$codex_dir/hooks.json"
  local toml="$codex_dir/config.toml"
  if ((DRY_RUN)); then
    caveman_log "[dry-run] would remove $hooks_json (if it references this skill)"
    caveman_log "[dry-run] would remove our hooks line from $toml"
    return 0
  fi
  if [[ -f $hooks_json ]]; then
    if grep -qF "$SKILL_DIR" "$hooks_json"; then
      rm -f "$hooks_json"
      caveman_log "codex: removed $hooks_json"
    else
      caveman_log "codex: $hooks_json does not reference this skill, left alone"
    fi
  fi
  if [[ -f $toml ]]; then
    local result
    result="$(caveman_ensure_codex_toml "$toml" 1)"
    caveman_log "codex: $toml hooks line $result"
  fi
}

caveman_user_config() {
  printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/caveman/config.json"
}

caveman_apply_mode() {
  [[ -n $MODE ]] || return 0
  local cfg
  cfg="$(caveman_user_config)"
  if ((DRY_RUN)); then
    caveman_log "[dry-run] would write {\"defaultMode\": \"$MODE\"} to $cfg"
    return 0
  fi
  command -v python3 >/dev/null 2>&1 || caveman_die "python3 is required to write $cfg"
  mkdir -p "$(dirname -- "$cfg")"
  python3 - "$cfg" "$MODE" <<'EOF'
import json, sys
cfg, mode = sys.argv[1:3]
try:
    with open(cfg) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}
data["defaultMode"] = mode
with open(cfg, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
EOF
  caveman_log "default mode written: $MODE -> $cfg"
}

caveman_parse_args() {
  while (($#)); do
    case "$1" in
      --agent)
        [[ $# -ge 2 ]] || caveman_die "--agent needs a value"
        case "$2" in
          claude-code | codex) WANT_AGENTS+=("$2") ;;
          *) caveman_die "unknown agent: $2 (expected claude-code or codex)" ;;
        esac
        shift 2
        ;;
      --mode)
        [[ $# -ge 2 ]] || caveman_die "--mode needs a value"
        case " $VALID_MODES " in
          *" $2 "*) MODE="$2" ;;
          *) caveman_die "unknown mode: $2 (expected one of: $VALID_MODES)" ;;
        esac
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --force)
        FORCE=1
        shift
        ;;
      --uninstall)
        UNINSTALL=1
        shift
        ;;
      -h | --help)
        caveman_usage
        exit 0
        ;;
      *) caveman_die "unknown option: $1 (see --help)" ;;
    esac
  done
}

caveman_main() {
  caveman_parse_args "$@"
  [[ -d $HOOKS_DIR ]] || caveman_die "hooks dir missing: $HOOKS_DIR"
  if ((${#WANT_AGENTS[@]} == 0)); then
    mapfile -t WANT_AGENTS < <(caveman_detect_agents)
    ((${#WANT_AGENTS[@]})) || caveman_die "no supported agents detected; pass --agent claude-code and/or --agent codex"
  fi
  for agent in "${WANT_AGENTS[@]}"; do
    case "$agent" in
      claude-code)
        if ((UNINSTALL)); then caveman_uninstall_claude_code; else caveman_install_claude_code; fi
        ;;
      codex)
        if ((UNINSTALL)); then caveman_uninstall_codex; else caveman_install_codex; fi
        ;;
    esac
  done
  if ! ((UNINSTALL)); then
    caveman_apply_mode
  fi
  caveman_log "done."
}

caveman_main "$@"
