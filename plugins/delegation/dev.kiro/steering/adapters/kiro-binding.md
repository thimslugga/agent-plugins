---
inclusion: always
---

# Delegation Binding (kiro-cli)

Spawn workers via the `subagent` tool. Tier→role is 1:1 — never substitute:

- `tier=cheap` → role `worker-cheap` (file reads, search, extraction, classification — haiku)
- `tier=cheap` → role `worker-research` (web/wiki/code search) (haiku)
- `tier=standard` → role `worker-standard` (ONLY when the brief edits files — sonnet)
- `tier=reviewer` → role `reviewer` (correctness-critical verification — opus)

Default to `worker-cheap`; a read-only brief on `worker-standard` is a bug. Full spawn
mechanics and caveats: ~/terminal-setup/ai/delegation/adapters/kiro.md — read it
before your first spawn of a session.
