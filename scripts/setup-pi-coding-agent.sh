#!/usr/bin/env bash

# https://github.com/can1357/oh-my-pi

#dnf install -y bubblewrap
#apt-get install -y bubblewrap
#sudo loginctl enable-linger $USER

uv venv agents --python 3.13 --seed
source agents/bin/activate
uv pip install nodejs-wheel # node + npm + npx into .venv/bin
uv pip install openshell

export NPM_CONFIG_PREFIX="${VIRTUAL_ENV}" # ← without this, it goes to ~/.local/npm-global
#export PI_CODING_AGENT_DIR="${VIRTUAL_ENV}/pi/agent"

npm install -g --ignore-scripts --min-release-age=4 @earendil-works/pi-coding-agent
#bun add -g --ignore-scripts @earendil-works/pi-coding-agent
#curl -fsSL https://pi.dev/install.sh | sh

# pi
# /login

mkdir -p ~/.pi/agent/{skills,prompts,themes,extensions,agents,subagent}

cat <<'EOF' | tee ~/.pi/agent/mcp.json
{
  "settings": {
    "toolPrefix": "mcp",
    "idleTimeout": 10
  },
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest", "--browserUrl", "http://127.0.0.1:9222"],
      "lifecycle": "lazy"
    }
  }
}
EOF

cat <<'EOF' | tee ~/.pi/agent/trust.json
{}
EOF

# install extension packages
pi install npm:pi-mcp-adapter
pi install npm:pi-subagents
pi install npm:pi-background-tasks
pi install npm:pi-web-access
pi install npm:pi-smart-fetch      # lets the agent read web pages
pi install npm:pi-smart-web-search # lets the agent search the web
pi install npm:pi-lens
#pi install npm:pi-memory
pi install npm:pi-observational-memory
pi install npm:pi-goal
pi install npm:pi-simplify
pi install npm:context-mode
pi install npm:pi-caveman
pi install npm:@dietrichgebert/ponytail
pi install npm:@narumitw/pi-lsp
pi install npm:@narumitw/pi-btw
pi install npm:@gotgenes/pi-permission-system
pi install npm:@upstash/context7-pi
pi install npm:@ff-labs/pi-fff
#pi install npm:pi-rtk-optimizer
pi install npm:@erichll/pi-sandbox
pi install npm:@juicesharp/rpiv-i18n
pi install npm:@juicesharp/rpiv-ask-user-question
pi install npm:@juicesharp/rpiv-todo

#pi install npm:pi-llama-cpp         # connects pi to the llama.cpp server
#pi install npm:pi-lmstudio

npm install -g pi-acp
#NPM_CONFIG_PREFIX="${VIRTUAL_ENV}" npm install -g pi-acp

#npm install -D typescript @types/node tsx

#npx ctx7 setup

#pi -c                  # Continue most recent session
#pi -r                  # Browse previous sessions
#pi --name "my task"    # Set session display name at startup
#pi --session <path|id> # Open a specific session

#skill.sh install pi https://raw.githubusercontent.com/user/repo/main/skill.md
