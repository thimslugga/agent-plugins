#!/bin/bash

curl -fsSL https://get.docker.com | sudo REPO_ONLY=1 sh
sudo apt-get install docker-sbx
sudo usermod -aG kvm $USER
newgrp kvm

# Rquires login to sbx first...
#sbx login

#sbx policy allow network prove-npcomplete "localhost:11434,pi.dev,iojs.org,raw.githubusercontent.com,registry.npmjs.org,api.github.com,nodejs.org,iojs.org"

#sbx run shell . --name=prove-npcomplete
