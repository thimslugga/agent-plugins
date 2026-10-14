# Attribution

- **Upstream**: [pbakaus/impeccable](https://github.com/pbakaus/impeccable) (main branch, cloned 2026-10-08; skill built from source at v4.5.1 per SKILL.md frontmatter, engine v0.1.12 per ENGINE_VERSION).
- **Paths**: `skill/` source (`SKILL.src.md`, `reference/`, `scripts/`, `agents/`) rendered through the repo's own `bun run scripts/build.js` for the `pi` provider; engine binary fetched with the repo's own `node scripts/fetch-engine.mjs` (linux-x64, from GitHub Releases `engine-v0.1.12`).
- **License**: Apache 2.0 (upstream LICENSE kept in this port).
- **Modifications in this port**:
  - Rewrote the provider-relative scripts path `.pi/skills/impeccable/scripts` to skill-relative `scripts/` in SKILL.md and `reference/` (this harness resolves the skill by its own directory; the skill's Setup step already defines the skill base dir as primary and the resolved path as fallback).
  - Bundled the linux-x64 engine binary at `scripts/bin/linux-x64/impeccable` (the launcher's first lookup location) so the skill works on this Linux box with no first-run download.
  - `agents/` subagent files not included: the pi provider build does not ship them, and the skill carries `reference/degraded/` fallbacks for each subagent. The rendered agent files exist upstream under `skill/agents/` if ever needed.
  - Added `README.md`, `agents/openai.yaml`, and `agents/harness-notes.md` per local convention.
- **Verification**: `scripts/impeccable engine-probe` prints `impeccable-engine 0.1.12`; a detector smoke test on a fixture HTML (Inter font, purple gradient, #999-on-#eee text) reported exactly the expected three findings (`low-contrast`, `overused-font`, `ai-color-palette`); no unresolved `{{placeholders}}` remain in SKILL.md or `reference/`; every internal `reference/` link resolves.
- **Note**: the published `npx impeccable install` path was unusable from this network (the bundle download at impeccable.style does not resolve here), which is why the skill was built from the cloned source instead. The result is byte-equivalent in content to what the installer ships for the pi provider, at a newer version (4.5.1) than the npm release (4.1.0).
