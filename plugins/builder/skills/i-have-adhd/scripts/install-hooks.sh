#!/usr/bin/env bash
#
# install-hooks.sh - install the i-have-adhd always-on hooks for supported agents.
#
# What it does:
#   claude-code  Merge a SessionStart hook into ~/.claude/settings.json.
#                The hook injects the full ruleset on session start when the
#                flag file ~/.claude/.i-have-adhd-always exists.
#                Use --enable / --disable to create or remove the flag file.
#   codex        Append the always-on snippet to ~/.codex/AGENTS.md
#                (upstream documents no hook route for Codex for this skill).
#
# Idempotent: re-running changes nothing unless --force is given.
# Never blocks: --dry-run prints every action first.
#
# Examples:
#   ./scripts/install-hooks.sh --dry-run
#   ./scripts/install-hooks.sh --agent claude-code --enable
#   ./scripts/install-hooks.sh --agent codex
#   ./scripts/install-hooks.sh --uninstall

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
SKILL_DIR="$(dirname -- "$SCRIPT_DIR")"
readonly SKILL_DIR
readonly SKILL_NAME="i-have-adhd"
readonly HOOKS_DIR="$SKILL_DIR/hooks"
readonly HOOK_MATCHER="startup|resume|clear|compact"
readonly HOOK_STATUS="Checking i-have-adhd always-on flag..."
readonly HOOK_TIMEOUT=30
readonly AGENTS_SNIPPET_START="<!-- i-have-adhd always-on: start -->"
readonly AGENTS_SNIPPET_END="<!-- i-have-adhd always-on: end -->"

DRY_RUN=0
FORCE=0
UNINSTALL=0
ENABLE_FLAG=0
DISABLE_FLAG=0
declare -a WANT_AGENTS=()

adhd_log() { printf '%s\n' "$*"; }
adhd_warn() { printf 'warning: %s\n' "$*" >&2; }
adhd_err() { printf 'error: %s\n' "$*" >&2; }
adhd_die() {
  adhd_err "$*"
  exit 1
}

adhd_usage() {
  cat <<'USAGE'
Usage: install-hooks.sh [OPTIONS]

Install the i-have-adhd always-on hooks for supported agents.

Options:
  --agent NAME     claude-code or codex. Repeatable. Default: all detected.
  --enable        Create the always-on flag file (~/.claude/.i-have-adhd-always).
  --disable       Remove the always-on flag file.
  --dry-run       Print every action. Write nothing.
  --force         Replace existing hook entries / snippet blocks.
  --uninstall     Remove installed hooks and snippet blocks.
  -h, --help      Print this help.

Agents:
  claude-code  SessionStart hook merged into ~/.claude/settings.json.
               Fires only when the flag file exists.
  codex        Always-on snippet appended to ~/.codex/AGENTS.md.
USAGE
}

adhd_detect_agents() {
  local found=()
  if [[ -d ${CLAUDE_CONFIG_DIR:-$HOME/.claude} ]] || command -v claude >/dev/null 2>&1; then
    found+=(claude-code)
  fi
  if [[ -d "$HOME/.codex" ]] || command -v codex >/dev/null 2>&1; then
    found+=(codex)
  fi
  printf '%s\n' "${found[@]}"
}

adhd_hook_command() {
  # Prefer the Node hook; fall back to POSIX sh (macOS/Linux/Git Bash).
  if command -v node >/dev/null 2>&1; then
    printf 'node "%s/hooks/always-on.mjs"' "$SKILL_DIR"
  else
    printf 'sh "%s/hooks/always-on.sh"' "$SKILL_DIR"
  fi
}

# Merge (or remove) the SessionStart hook entry in a Claude Code settings.json.
# Args: settings_path command uninstall(0/1)
adhd_merge_settings() {
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

adhd_install_claude_code() {
  local claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  local settings="$claude_dir/settings.json"
  local command
  command="$(adhd_hook_command)"
  if ((DRY_RUN)); then
    adhd_log "[dry-run] would merge SessionStart hook into $settings"
    adhd_log "[dry-run]   command: $command"
    return 0
  fi
  command -v python3 >/dev/null 2>&1 || adhd_die "python3 is required to merge $settings"
  mkdir -p "$claude_dir"
  local result
  result="$(adhd_merge_settings "$settings" "$command" 0)"
  adhd_log "claude-code: SessionStart hook $result in $settings"
}

adhd_uninstall_claude_code() {
  local claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  local settings="$claude_dir/settings.json"
  if ((DRY_RUN)); then
    adhd_log "[dry-run] would remove the $SKILL_NAME hook entry from $settings"
    return 0
  fi
  [[ -f $settings ]] || {
    adhd_log "claude-code: $settings not present, nothing to do"
    return 0
  }
  command -v python3 >/dev/null 2>&1 || adhd_die "python3 is required to edit $settings"
  local result
  result="$(adhd_merge_settings "$settings" "" 1)"
  adhd_log "claude-code: hook entry $result in $settings"
}

adhd_snippet_block() {
  cat <<EOF
$AGENTS_SNIPPET_START
## Output style

The reader has ADHD. Shape every response so it can be acted on:

1. Lead with the answer or next action: command, path, or snippet first.
2. Number multi-step work; one bounded action per step.
3. End with one next action doable in under two minutes.
4. Finish the current issue before raising a new one.
5. Restate progress each turn ("step 3 of 5 done").
6. Give time estimates in concrete units, never "a bit".
7. After a change, show what now works.
8. Errors: state location, cause, and fix. No drama.
9. Cap lists at 5 items.
10. No preamble, no recaps, no closers.

Exceptions: explain fully when asked to explain. Confirm before destructive actions. After three failed fixes, stop and name the doubtful assumption. If the request is ambiguous, ask one short question.
$AGENTS_SNIPPET_END
EOF
}

adhd_install_codex() {
  local agents_md="$HOME/.codex/AGENTS.md"
  if ((DRY_RUN)); then
    adhd_log "[dry-run] would append the always-on snippet to $agents_md"
    return 0
  fi
  mkdir -p "$(dirname -- "$agents_md")"
  touch "$agents_md"
  if grep -qF "$AGENTS_SNIPPET_START" "$agents_md"; then
    if ((FORCE)); then
      adhd_uninstall_codex_block "$agents_md"
    else
      adhd_log "codex: snippet already present in $agents_md"
      return 0
    fi
  fi
  {
    printf '\n'
    adhd_snippet_block
  } >>"$agents_md"
  adhd_log "codex: always-on snippet appended to $agents_md"
}

adhd_uninstall_codex_block() {
  local agents_md="$1"
  local tmp
  tmp="$(mktemp)"
  local result
  result="$(
    python3 - "$agents_md" "$AGENTS_SNIPPET_START" "$AGENTS_SNIPPET_END" "$tmp" <<'EOF'
import sys
src, start, end, tmp = sys.argv[1:5]
with open(src) as f:
    lines = f.readlines()
out, skipping, changed = [], False, False
for line in lines:
    if not skipping and line.rstrip("\n") == start:
        skipping, changed = True, True
        continue
    if skipping and line.rstrip("\n") == end:
        skipping = False
        continue
    if not skipping:
        out.append(line)
with open(tmp, "w") as f:
    f.writelines(out)
print("changed" if changed else "unchanged")
EOF
  )"
  mv "$tmp" "$agents_md"
  printf '%s' "$result"
}

adhd_uninstall_codex() {
  local agents_md="$HOME/.codex/AGENTS.md"
  if ((DRY_RUN)); then
    adhd_log "[dry-run] would remove the always-on snippet from $agents_md"
    return 0
  fi
  [[ -f $agents_md ]] || {
    adhd_log "codex: $agents_md not present, nothing to do"
    return 0
  }
  local result
  result="$(adhd_uninstall_codex_block "$agents_md")"
  adhd_log "codex: snippet $result in $agents_md"
}

adhd_flag_file() {
  printf '%s' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.i-have-adhd-always"
}

adhd_apply_flag() {
  local flag
  flag="$(adhd_flag_file)"
  if ((ENABLE_FLAG)); then
    if ((DRY_RUN)); then
      adhd_log "[dry-run] would create flag file $flag"
    else
      mkdir -p "$(dirname -- "$flag")"
      touch "$flag"
      adhd_log "flag file created: $flag (always-on active for Claude Code)"
    fi
  fi
  if ((DISABLE_FLAG)); then
    if ((DRY_RUN)); then
      adhd_log "[dry-run] would remove flag file $flag"
    elif [[ -f $flag ]]; then
      rm -f "$flag"
      adhd_log "flag file removed: $flag"
    else
      adhd_log "flag file not present: $flag"
    fi
  fi
}

adhd_parse_args() {
  while (($#)); do
    case "$1" in
      --agent)
        [[ $# -ge 2 ]] || adhd_die "--agent needs a value"
        case "$2" in
          claude-code | codex) WANT_AGENTS+=("$2") ;;
          *) adhd_die "unknown agent: $2 (expected claude-code or codex)" ;;
        esac
        shift 2
        ;;
      --enable)
        ENABLE_FLAG=1
        shift
        ;;
      --disable)
        DISABLE_FLAG=1
        shift
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
        adhd_usage
        exit 0
        ;;
      *) adhd_die "unknown option: $1 (see --help)" ;;
    esac
  done
  if ((ENABLE_FLAG && DISABLE_FLAG)); then
    adhd_die "--enable and --disable are mutually exclusive"
  fi
}

adhd_main() {
  adhd_parse_args "$@"
  [[ -d $HOOKS_DIR ]] || adhd_die "hooks dir missing: $HOOKS_DIR"
  if ((${#WANT_AGENTS[@]} == 0)); then
    mapfile -t WANT_AGENTS < <(adhd_detect_agents)
    ((${#WANT_AGENTS[@]})) || adhd_die "no supported agents detected; pass --agent claude-code and/or --agent codex"
  fi
  for agent in "${WANT_AGENTS[@]}"; do
    case "$agent" in
      claude-code)
        if ((UNINSTALL)); then adhd_uninstall_claude_code; else adhd_install_claude_code; fi
        ;;
      codex)
        if ((UNINSTALL)); then adhd_uninstall_codex; else adhd_install_codex; fi
        ;;
    esac
  done
  if ((UNINSTALL)); then
    # Uninstalling also drops the flag file: no hook, no flag.
    local flag
    flag="$(adhd_flag_file)"
    if ((DRY_RUN)); then
      adhd_log "[dry-run] would remove flag file $flag"
    elif [[ -f $flag ]]; then
      rm -f "$flag"
      adhd_log "flag file removed: $flag"
    fi
  else
    adhd_apply_flag
  fi
  adhd_log "done."
}

adhd_main "$@"
