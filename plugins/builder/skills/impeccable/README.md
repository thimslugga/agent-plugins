# impeccable

Design guidance for AI coding agents: one skill, 24 design commands, and a deterministic detector for AI-generated frontend slop. Upstream: [pbakaus/impeccable](https://github.com/pbakaus/impeccable) (Apache 2.0). This is a faithful port of the upstream skill, built from source at v4.5.1 and adapted for this workspace. See Attribution below for provenance and the exact modifications.

## What it does

- Gives the agent a shared design vocabulary with the user: `craft`, `shape`, `critique`, `audit`, `polish`, `bolder`, `quieter`, `distill`, `harden`, `onboard`, `animate`, `colorize`, `typeset`, `layout`, `delight`, `overdrive`, `clarify`, `adapt`, `optimize`, `live`, `generate`, `init`, `document`, `extract` (24 commands, all through the one skill).
- Records durable product truth in `PRODUCT.md` (`init`) so later commands know audience, purpose, constraints, and voice without confusing them with visual direction.
- Ships 59 deterministic detector rules (no LLM, no API key) that catch the classic AI-slop tells: purple gradients, Inter-everywhere, nested cards, gray text on colored backgrounds, bounce easing, low contrast, cramped touch targets, and more.

## Layout

- `SKILL.md` — the skill: description, setup, design principles, visitor modes, commands table. Invoke by reading it and following the workflow; there is no slash-command runner in this harness.
- `reference/` — one playbook per command (`audit.md`, `polish.md`, `critique.md`, ...), plus platform guides (`ios.md`, `android.md`), `craft-floor.md` (quality floor and absolute bans, read immediately before any UI edit), `hooks.md`, and `degraded/` fallbacks for the subagents.
- `scripts/impeccable` — POSIX launcher for the engine (plus `impeccable.cmd` for Windows shells). Runs the self-contained engine binary: the linux-x64 binary is bundled at `scripts/bin/linux-x64/`; on other platforms it downloads once into `~/.impeccable/bin/`.
- `agents/openai.yaml` — Codex UI metadata.

## Usage

Run the setup step once per session from the user's project directory:

```sh
~/workspace/skills/impeccable/scripts/impeccable context
```

Then follow the SKILL.md workflow (load the command's reference playbook, inspect the target, read `reference/craft-floor.md` before editing). Standalone detector scans need no session setup:

```sh
~/workspace/skills/impeccable/scripts/impeccable detect src/
~/workspace/skills/impeccable/scripts/impeccable detect index.html
~/workspace/skills/impeccable/scripts/impeccable detect --json .
```

The hook manifests (PostToolUse/Stop detector runs) are a Claude Code / Cursor / Codex / Copilot / Grok feature and are not installed here; run `detect` explicitly instead.

## Harness notes

- No `/impeccable` slash command: a request like "audit the landing page" or "make this bolder" is the trigger. `argument-hint` lists the 24 commands by category; pass the command name and target as plain text.
- The frontmatter `allowed-tools` entries (`Bash(npx impeccable *)`, `Bash(scripts/impeccable *)`) are Claude Code permission patterns; treat them as "these shell commands are permitted", not literal tool names.
- `pin`/`unpin` create harness slash-command shortcuts; they don't apply here, skip them.
- The upstream subagents (asset-producer, documenter, finish-reviewer, manual-edit-applier) are not bundled; `reference/degraded/` carries an inline fallback for each.
- Live mode (`live`, `generate`) needs a local dev server and a real Chrome/Chromium/Edge; verify one is installed before offering it. It never injects into production sites.
- Image generation is not assumed: comp-first flows degrade to code-first when the harness has no image model.
- URL scans in `detect` use the engine's bundled browser driver scripts, not the harness browser.
- Keep `.impeccable/` working files out of git (see upstream's gitignore block).

## Testing

- `scripts/impeccable engine-probe` prints `impeccable-engine 0.1.12` (verified).
- Detector smoke test: a fixture HTML with Inter, a purple gradient, and #999-on-#eee text produced exactly the expected three findings (`low-contrast`, `overused-font`, `ai-color-palette`).
- `grep -rn "{{" SKILL.md reference/` returns no unresolved `{{placeholders}}` (all resolved at build time).
- Every `reference/*.md` link target inside the skill resolves.

## Attribution

- Upstream: [pbakaus/impeccable](https://github.com/pbakaus/impeccable), built from source at v4.5.1.
- License: Apache 2.0 (`LICENSE` kept).
- Known differences from upstream: no slash-command surface; the upstream subagents are not bundled (`reference/degraded/` fallbacks instead); hook manifests are not installed; the linux-x64 engine binary is bundled. Added `README.md` and `agents/openai.yaml`. A complete modification list was never recorded.
