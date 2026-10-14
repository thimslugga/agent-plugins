#!/usr/bin/env bash
set -euo pipefail

# Install Shell Script Pro config templates (.shellcheckrc, .editorconfig)
# into the current project directory. Never overwrites existing files.
#
# Usage: init-configs.sh   (run from the project root)

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

agent_skills_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

copied_files=0

install_template() {
  local src_file="$1"
  local dst_file="$2"
  if [[ -e ${dst_file} ]]; then
    echo "skipping, file already exists: ${dst_file}"
    return 0
  fi
  cp -a "${src_file}" "${dst_file}"
  copied_files=$((copied_files + 1))
  echo "Created: ${dst_file}"
}

# Install editorconfig template
install_template "${agent_skills_dir}/assets/templates/editorconfig" "./.editorconfig"

# Install shellcheck config template
install_template "${agent_skills_dir}/assets/templates/shellcheckrc" "./.shellcheckrc"

echo "${SCRIPT_NAME}: finished, new file(s): ${copied_files}"
