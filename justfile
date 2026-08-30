#!/usr/bin/env -S just --justfile
# vim:set ft=just ts=2 sts=4 sw=2 et:

set shell := ["bash", "-euo", "pipefail", "-c"]

# List available recipes
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
