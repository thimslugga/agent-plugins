#!/usr/bin/env bash

curl https://mise.run | sh

echo "eval $(/home/user/.local/bin/mise activate zsh)" >> "/home/user/.zshrc"
source ~/.zshrc
