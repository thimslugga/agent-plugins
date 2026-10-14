# Harness notes (Muse)

- Invoke by reading `SKILL.md` and following its workflow. A user request like "help me frame this product problem" or "audit this checkout flow" maps to the entry point skill, which routes to the right specialist.
- "Invoke `/strategize`" (and friends) in the text means: read `skills/strategize/SKILL.md` relative to this skill's root. All cross-references are already rewritten that way.
- Start UX work at the root skill so project context gets established once, then follow its routing. Skipping straight to a specialist is fine when the user names the job directly.
- To work as an upstream agent persona (Noor, Ember, Wren, Vigil, Rune, Sage), spawn a subagent with the corresponding `upstream-agents/<name>.md` as its system prompt and the relevant skill file(s) as context.
- The wireframe skill ships a self-contained HTML viewer under `skills/wireframe/references/`; it can be opened as a file, not served.
- Nothing here executes: no launcher, no hooks, no downloads. Keep `.intent` working files (if any get created) out of git.
