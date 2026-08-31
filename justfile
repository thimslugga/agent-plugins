#!/usr/bin/env -S just --justfile
# vim:set ft=just ts=2 sts=4 sw=2 et:

# Use with https://github.com/casey/just

set positional-arguments

# Load .env file into environment for all recipes.
set dotenv-load

# Use bash in strict mode (-u = error on unset vars, -c = command string).
# This gives consistent behavior across macOS/Linux regardless of login shell.
set shell := ["bash", "-euo", "pipefail", "-c"]

# Windows equivalent (only takes effect on Windows, ignored elsewhere).
set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]

just_bin := just_executable()
justfile_dir := justfile_directory()
project_name := file_name(justfile_directory())
project_version := `git describe --tags --always 2>/dev/null || echo "dev"`
python_version := "3.12"
venv_dir := ".venv"
ruff_version := `sed -n 's/^    "ruff==\([0-9.]*\)",$/\1/p' pyproject.toml`

_cyan := '\033[0;36m'
_red := '\033[0;31m'
_green := '\033[0;32m'
_nc := '\033[0m'

# Show available recipes
[private]
default:
    @just --list

# lists the tasks
@_list:
    just --list

help:
    @just --list

alias sysinfo := system-info

system-info:
    @echo "This is an {{ arch() }} machine".

# The `-` prefix ignores errors (e.g., dir doesn't exist). Keeps going.
[group('util')]
clean:
    -rm -rf .mypy_cache
    -rm -rf .pytest_cache
    -rm -rf .ruff_cache
    -rm -rf .rumdl_cache
    -rm -rf htmlcov
    -rm -f .coverage
    -rm -rf dist
    -rm -rf build
    @echo "Cache directories cleaned"

# [confirm(...)] prompts for Y/n before running — safety net for destructive ops.
[group('util')]
[confirm("Remove all build artifacts, caches, and virtual environment?")]
nuke:
    @echo "Nuke everything..."
    -rm -rf .mypy_cache .pytest_cache .ruff_cache .rumdl_cache htmlcov dist build
    -rm -f .coverage
    -rm -rf .venv
    @echo "Nuke complete!"

[group('setup')]
setup:
    @echo "Setting up development environment..."
    uv sync --all-extras
    @echo "Setup complete!"

venv-init:
    @echo "🏗️ Creating virtual environment with recommended uv tool:"
    uv venv {{ venv_dir }} --clear --python {{ python_version }} --seed
    @echo "✅ Python {{ python_version }} virtual environment created at {{ venv_dir }}"

# Lint the justfile itself (fails if 'just --fmt' would reformat it; run 'just just-fmt' to fix)
just-lint:
    {{ just_executable() }} --fmt --check

# Format the justfile in place
just-fmt:
    {{ just_executable() }} --fmt

yaml-lint:
	yamllint .

python-lint:
	ruff check . && ruff format --check .

python-fmt:
	ruff format .

go-lint:
	golangci-lint run ./...

go-fmt:
	gofmt -w . && goimports -w .

rust-fmt:
    find {{invocation_directory()}} -name \*.rs -exec rustfmt {} \;

# assume reasonably pre-commit is a safe dependency given its wide support (e.g. GitHub Actions integration)
[private]
ensure-prek:
    @if ! command -v prek > /dev/null; then \
        echo "prek required for commits prior to pull requests. Using uv tool to install prek."; \
        uv tool install prek; \
    fi
