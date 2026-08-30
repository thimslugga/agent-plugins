#!/usr/bin/env bash

git init
git branch -M main
git remote add origin https://github.com/"$org_name"/"$repo_name".git
git fetch origin
git add README.md plugin.json mcp.json skills/ dev.kiro/
git commit -m "feat: initial commit"
git push -u origin main
