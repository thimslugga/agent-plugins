# shellcheck shell=sh
# /etc/profile.d/50-example.sh -- system-wide login environment.
#
# Sourced by /etc/profile (login shells), in sh syntax, for every user.
# Fedora/RHEL also source it for interactive non-login Bash via /etc/bashrc.
# Zsh sees it only where the global zprofile sources /etc/profile.
# Install: sudo install -m 0644 profile.d-example.sh /etc/profile.d/50-example.sh
#
# sh syntax only. No output. Must be safe to source more than once.

case ":${PATH}:" in
  *":/opt/example/bin:"*) ;;
  *) PATH="${PATH}:/opt/example/bin" ;;
esac
export PATH

export EXAMPLE_HOME=/opt/example
