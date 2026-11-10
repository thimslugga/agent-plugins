#!/usr/bin/env bash
set -euo pipefail

# Install Shell Script Pro config templates (.shellcheckrc, .editorconfig)
# into the current project directory. Never overwrites existing files.
#
# Usage: init-configs.sh   (run from the project root)

SCRIPT_NAME="${BASH_SOURCE[0]##*/}"
readonly SCRIPT_NAME

# Directory holding this script; "." when invoked as `bash init-configs.sh`.
script_dir="${BASH_SOURCE[0]%/*}"
if [[ ${script_dir} == "${BASH_SOURCE[0]}" ]]; then
  script_dir='.'
fi
AGENT_SKILLS_DIR="$(cd "${script_dir}/.." && pwd)"
readonly AGENT_SKILLS_DIR

copied_files=0

#######################################
# Copy a template into place unless the destination already exists.
# Globals:
#   copied_files
# Arguments:
#   $1 - source template path.
#   $2 - destination path.
# Outputs:
#   Reports the created or skipped file on stdout.
#######################################
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

main() {
  install_template "${AGENT_SKILLS_DIR}/assets/editorconfig" "./.editorconfig"
  install_template "${AGENT_SKILLS_DIR}/assets/shellcheckrc" "./.shellcheckrc"

  echo "${SCRIPT_NAME}: finished, new file(s): ${copied_files}"
}

main "$@"
