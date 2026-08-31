---
inclusion: always
---

# Global Conventions

Workflow and session rules for the main (orchestrator-level) agent.

- Language and code-quality rules live in `code-conventions.md` — always loaded alongside this file, and also attached to delegation workers via their agent-spec `resources`.

## Communication & Output Style

- **No preamble or filler:** Start directly with the answer, command, code, or action. Skip conversational pleasantries ("Sure, I can help with that", "Let's think about this").
- **Lead with the action:** Put actionable commands, file links, and key conclusions first; background explanations come after, if at all.
- **Suppress tangents:** Focus strictly on the user's objective. Do not append unsolicited advice, style commentary, or unrelated findings; if a secondary issue is critical, surface it in one concise note at the end.
- **Numbered, bounded steps:** Use concise, numbered lists for multi-step workflows (one action per step).
- **Crisp completion state:** State clearly what was done, which files changed, and the single immediate next action if anything remains open.

## Task Execution & Subagent Routing

The orchestrator chooses between three execution modes based on task scope and requirements:

| Mode                  | Trigger                                                                         | Strategy                                                                                                                                        |
| :-------------------- | :------------------------------------------------------------------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------- |
| Inline Execution      | < 2 files, minor bug fixes, questions, localized refactors.                     | Work inline in the main chat session. Lowest latency.                                                                                           |
| Ad-Hoc Delegation     | Bulk log parsing, broad repo search, 1-shot parallel subtasks across modules.   | Apply `delegation-core` (`ai/delegation/core.md`). Spawn `worker-cheap` or `worker-standard` with `[WORKER-BRIEF v1]`.                          |
| Digital Team Pipeline | New feature requests, complex multi-component changes, strict TDD requirements. | Apply `digital-team` (`ai/digital-team/workflow.md`). 5-step pipeline: Feature Plan → Plan Challenge → TDD Worker → Code Reviewer → Dual Loops. |

- Shared tier worker definitions live in `ai/agents/`.
- Runtime mechanics and tier→model mappings live in `delegation/adapters/`.

## Asynchronous Tasks & Background Execution

- **Reactive Wakeup (Never Poll):** Background processes, subagents (`invoke_subagent`), and async commands automatically send notifications to the orchestrator upon completion.
- You MUST NOT poll or loop on task status (e.g. repeated `status` checks or `sleep` loops). Once an asynchronous command or subagent is dispatched, simply stop calling tools — the system automatically resumes execution when results are ready.

## Working With Files

- **Use Dedicated Read & Edit Tools:** Agents have first-class tools for file inspection and modification (`view_file`, `replace_file_content`, `write_to_file` / `read`, `edit`, `write`). Do NOT rely on shell commands like `cat`, `head`, `grep`, `sed`, `awk`, or heredocs (`cat << 'EOF' > file`) to read or edit files when dedicated tools exist. Reserve terminal/shell commands strictly for running builds, test suites, git commands, and process management.
- Re-read files fresh from disk before acting on them — never rely on a cached/prior version. External processes may have modified them since the last read.
