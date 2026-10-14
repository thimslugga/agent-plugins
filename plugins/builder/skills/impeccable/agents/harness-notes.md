# Harness notes (Muse)

- Invoke by reading `SKILL.md` and following the workflow. There is no `/impeccable` slash command in this harness; treat a user request like "audit the landing page" or "make this bolder" as the skill trigger per its description.
- Run `<skill-dir>/scripts/impeccable context` once per session with cwd at the user's project before design work. The launcher is POSIX sh and needs no Node.
- The engine binary for this Linux box is bundled at `scripts/bin/linux-x64/impeccable`; the launcher finds it without any download.
- No hook surface here: nothing runs the detector automatically on file edits. Run `scripts/impeccable detect <target>` explicitly after UI changes, mirroring what the Claude Code PostToolUse hook would do.
- `pin`/`unpin` create harness slash-command shortcuts; those do not apply here, skip them.
- Live mode (`live`, `generate`) needs a local dev server and a real Chromium; verify one is installed before offering it.
- Keep `.impeccable/` working files out of git per the README's gitignore block when using the skill inside a repo.
