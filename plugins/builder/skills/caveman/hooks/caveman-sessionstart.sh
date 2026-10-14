#!/usr/bin/env sh
# caveman-sessionstart.sh -- SessionStart hook for the caveman skill.
#
# Self-contained: no dependencies beyond POSIX sh. Resolves the default
# mode and prints the caveman ruleset for mode=caveman. Silent for
# off/manual. Fail-open: any error exits 0 with no output, so a broken
# install can never block a session.
#
# Mode resolution order (mirrors upstream):
#   1. CAVEMAN_DEFAULT_MODE environment variable
#   2. repo-local .caveman/config.json or .caveman.json (walk up to fs root)
#   3. user config: $XDG_CONFIG_HOME/caveman/config.json,
#      else ~/.config/caveman/config.json
#   4. default: caveman
#
# Valid modes in this bundle: off, manual, caveman, ultracave.
# (The Classical-Chinese megacave mode was removed by request; the
# commit/review/compress modes belong to sibling skills not installed
# here.)

# No `set -e`: every step guards its own failure and falls through to
# a silent exit 0.
set -u

SCRIPT_DIR=$(dirname -- "$0")
SKILL_MD="$SCRIPT_DIR/../SKILL.md"

caveman_canonical_mode() {
  # Print $1 lowercased when it is a known mode; fail otherwise.
  _m=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$_m" in
    off | manual | caveman | ultracave)
      printf '%s' "$_m"
      return 0
      ;;
  esac
  return 1
}

caveman_mode_from_file() {
  # Print the defaultMode from a JSON config file; fail when absent,
  # unreadable, malformed, a symlink, or not a known mode.
  [ -f "$1" ] || return 1
  [ -L "$1" ] && return 1
  _val=$(sed -n 's/.*"defaultMode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -n 1)
  [ -n "${_val:-}" ] || return 1
  caveman_canonical_mode "$_val"
}

caveman_resolve_mode() {
  if [ -n "${CAVEMAN_DEFAULT_MODE:-}" ]; then
    caveman_canonical_mode "$CAVEMAN_DEFAULT_MODE" && return 0
  fi
  _dir=$(pwd 2>/dev/null) || _dir="/"
  _i=0
  while [ "$_i" -lt 64 ]; do
    for _rel in ".caveman/config.json" ".caveman.json"; do
      if _m=$(caveman_mode_from_file "$_dir/$_rel" 2>/dev/null); then
        printf '%s' "$_m"
        return 0
      fi
    done
    _parent=$(dirname -- "$_dir")
    [ "$_parent" = "$_dir" ] && break
    _dir=$_parent
    _i=$((_i + 1))
  done
  _cfg="${XDG_CONFIG_HOME:-$HOME/.config}/caveman/config.json"
  if _m=$(caveman_mode_from_file "$_cfg" 2>/dev/null); then
    printf '%s' "$_m"
    return 0
  fi
  printf 'caveman'
}

caveman_skill_body() {
  # Print SKILL.md without its leading YAML frontmatter block.
  [ -f "$SKILL_MD" ] || return 1
  awk 'BEGIN { state = 0 }
    state == 0 {
      if ($0 ~ /^---[ \t]*$/) { state = 1; next }
      state = 2
    }
    state == 1 {
      if ($0 ~ /^---[ \t]*$/) { state = 2; next }
      next
    }
    state == 2 { print }' "$SKILL_MD"
}

caveman_main() {
  _mode=$(caveman_resolve_mode 2>/dev/null) || exit 0
  case "$_mode" in
    off | manual) exit 0 ;;
    ultracave)
      printf '%s\n' "CAVEMAN MODE ACTIVE - mode: ultracave. The ultracave sibling skill is not installed; falling back to the caveman ruleset."
      ;;
    *) printf '%s\n' "CAVEMAN MODE ACTIVE - mode: ${_mode}." ;;
  esac
  _body=$(caveman_skill_body 2>/dev/null) || exit 0
  printf '\n%s\n' "$_body"
}

caveman_main "$@" 2>/dev/null || exit 0
