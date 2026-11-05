# Claude Code on Windows — Safety Guide for the Issues That Don't Exist on macOS/Linux

A field guide to the five Windows-specific failure modes that have surfaced in the Anthropic Claude Code tracker between April and May 2026, with operator-side mitigations and a decision tree for "WSL2 vs native Windows".

## Why Windows is structurally different

macOS and Linux share a POSIX heritage: bash, fork/exec semantics, process trees, cgroups for resource caps, signals. Most Claude Code documentation and most third-party hook collections (including most of cc-safe-setup) were written and tested against these.

Windows differs in five dimensions that matter for Claude Code operators:

1. **Process model**. Windows uses Job Objects rather than cgroups; process spawning is more expensive; signals do not map cleanly.
2. **Shell ecosystem**. PowerShell is the native shell; bash exists via Git Bash (MINGW64) or WSL2, each with different limits.
3. **Memory model**. The Windows memory manager swaps and page-faults differently from Linux's OOM killer — a runaway process can take down concurrent processes before stable termination.
4. **Driver/kernel surface**. Hyper-V Code Integrity (HVCI) and other Windows security features can interact poorly with how Claude Code dispatches subprocesses.
5. **Terminal stack**. Windows Terminal, conhost, ConPTY each have distinct quirks that affect TUI and OAuth flows.

The result: several failure modes documented in the upstream tracker are Windows-only, do not reproduce on macOS or Linux, and require Windows-specific mitigations. Below are five worth knowing about.

## Five Windows-specific failure modes and what to do about them

### 1. BSOD on Windows 11 with HVCI enabled — #61614

**Symptom**. Issuing a Bash tool call (typically via the VSCode extension) triggers a `SYSTEM_SERVICE_EXCEPTION` Blue Screen of Death on Windows 11 hosts with Hyper-V Code Integrity (HVCI) enabled. The crash is at kernel level — no Claude Code transcript survives; the entire host hard-reboots.

**Root cause** (operator-side hypothesis). HVCI restricts certain kernel-mode operations. Claude Code's process spawning path interacts with a driver that is incompatible with HVCI's enforcement model. Anthropic has not yet shipped a fix.

**Operator-side mitigations**:
- **If you can disable HVCI**: Run `bcdedit /set hypervisorlaunchtype off` (admin PowerShell), restart. This eliminates the BSOD but reduces some Windows 11 security guarantees. Re-enable when not running Claude Code if needed.
- **If you cannot disable HVCI** (enterprise policy, etc.): Run Claude Code inside **WSL2** instead. The Bash tool call routes through WSL's kernel rather than the Windows kernel, bypassing the HVCI-conflicting driver path.
- **Defense-in-depth**: Take more frequent local snapshots. The crash is unannounced; if you have 30+ minutes of context worth losing, you want a way to recover. `~/.claude/projects/*/` is the transcript location.

### 2. Runaway process spawn → OOM cascade across windows — #62193

**Symptom**. A single workflow (often `ultracode` or `ultraReview`, or any subagent-orchestrated batch) fans out into thousands of subprocesses (bash on Linux, PowerShell on Windows). On Linux, the kernel OOM killer eventually terminates the offending tree. On Windows, the virtual memory exhaustion can crash *other* Claude Code windows running on the same machine before the failing tree itself dies.

**Documented reproduction**. The original Linux case (3,079 bash processes in 17 seconds, kernel OOM, hard reboot) was filed by @fdpr-H on 2026-05-25. A Windows follow-up was filed by @allenfu000 on 2026-05-29: ultracode subagents spawned nested PowerShell processes until two other Claude Code windows crashed. Both reach the failure through unbounded fan-out at the orchestration layer.

**Operator-side mitigations**:
- **Wrap Claude Code in a Windows Job Object** with a process-count ceiling. Tools: [`procgov`](https://github.com/lowleveldesign/process-governor) (MIT, open-source) or a custom Win32 API wrapper. When the limit is hit, the Job Object terminates the tree, not the host. This is the Windows equivalent of `systemd-run --user --scope -p TasksMax=200` on Linux.
- **Install [`nested-spawn-inflight-guard.sh`](https://github.com/yurukusa/cc-safe-setup/blob/main/examples/nested-spawn-inflight-guard.sh)** (cc-safe-setup PR #474, MIT). PreToolUse hook on `Task` / `Agent` / `SendMessage`. Reads the actual transcript at dispatch time and refuses new subagent dispatches when in-flight count exceeds `CC_NESTED_SPAWN_BUDGET` (default 5). Transcript-based — no stale counter issues.
- **Run inside WSL2** with a `systemd-run` scope. Combines the bash-fanout protection of [`bash-fanout-bounded-rewriter.sh`](https://github.com/yurukusa/cc-safe-setup/blob/main/examples/bash-fanout-bounded-rewriter.sh) (PR #440) with cgroup-level kernel enforcement.

### 3. Bash commands produce no output on Windows 11 — #62970

**Symptom**. Claude Code invokes the Bash tool. The command appears to execute (no error returned), but the tool result is empty. Claude then proceeds as if the command had output nothing, which often leads to incorrect inferences ("the file does not exist", "the directory is empty") and incorrect follow-up actions.

**Root cause** (likely). Output buffer routing through Windows pipe semantics differs from POSIX. Certain command output never reaches the tool result channel.

**Operator-side mitigations**:
- **Prefer PowerShell over Bash** when running on native Windows. PowerShell tool output has been more reliable in production.
- **For Bash-dependent workflows**: Switch to WSL2. WSL2's bash routes through Linux pipes and produces normal output.
- **Detection hook**: Watch for empty `tool_result` after Bash invocations. If the next assistant turn says "the directory is empty" but `ls` was the command, you have likely hit this bug.

### 4. PowerShell tool disabled under MINGW64 / Git Bash — #63514

**Symptom**. When Claude Code runs inside a Git Bash (MINGW64) terminal on Windows, the PowerShell tool becomes unavailable. PowerShell commands return errors or are silently skipped. This is particularly painful for operators who prefer Git Bash for general work but need PowerShell for Windows-specific automation.

**Operator-side mitigations**:
- **Launch Claude Code from Windows Terminal or PowerShell**, not from Git Bash. The shell context Claude Code inherits determines which tools are available.
- **For mixed workflows**: Run two Claude Code sessions — one in Git Bash for unix-style work, one in Windows Terminal for PowerShell-needing work. Avoid mixing tool types in a single session.
- **Workaround inside Git Bash**: Invoke PowerShell explicitly via `powershell.exe -Command "..."` from within a Bash tool call. The command will execute but escaping rules differ from native PowerShell tool invocations.

### 5. OAuth manual code paste freezes Windows Terminal — #58949

**Symptom**. During Claude Code authentication, the OAuth flow asks for a code paste. Pasting the code into Windows Terminal causes the terminal to freeze (becomes unresponsive). Authentication appears to hang.

**Root cause** (likely). Windows Terminal's paste handler interacts poorly with Claude Code's input reading state during the OAuth code-entry phase.

**Operator-side mitigations**:
- **Use conhost (legacy Windows Console) for the initial authentication**, not Windows Terminal. After authentication is complete, switch to Windows Terminal for normal use.
- **If you must use Windows Terminal**: Type the code manually rather than pasting. Slower but does not trigger the freeze.
- **One-time setup**: Authenticate once via conhost, then the session token in `~/.claude/` works across both conhost and Windows Terminal for subsequent sessions.

## The "WSL2 or native Windows" decision tree

Several mitigations above route through WSL2. Whether to standardize on WSL2 for all Claude Code work depends on operator constraints:

**Prefer WSL2 if**:
- You hit BSOD with HVCI (and cannot disable HVCI).
- Your workflows depend on unix-style shell utilities (sed, awk, grep, jq).
- You want kernel-enforced resource caps (`systemd-run`, cgroups).
- You run other tools that prefer Linux paths (most data science tools, most CI runners).

**Prefer native Windows if**:
- Your workflows require PowerShell-specific cmdlets (`Get-Service`, `Invoke-WebRequest`, Windows-only DSCs).
- You need direct access to Windows-specific APIs (Win32, .NET, Active Directory).
- Your project lives on a Windows-native filesystem path that crosses the WSL boundary expensively (`\\wsl$\` paths or `/mnt/c/`).
- You need GUI tool integration that doesn't bridge cleanly (some IDE features, screen-reader integration, certain Windows accessibility paths).

**Run both** (split-session approach):
- One Claude Code session in WSL2 for unix-style work (most code editing, git operations, npm/pip/cargo).
- One Claude Code session in Windows Terminal native for Windows-specific work (PowerShell automation, .NET tools, registry edits).
- Use separate project directories to avoid context bleed.

## What cc-safe-setup currently covers on Windows

cc-safe-setup ships ~800 hooks, but their Windows coverage is uneven. The hooks that work uniformly across platforms are the transcript-based ones (read JSONL, parse JSON, no platform-specific shell calls):

- [`nested-spawn-inflight-guard.sh`](https://github.com/yurukusa/cc-safe-setup/blob/main/examples/nested-spawn-inflight-guard.sh) — works on Windows under WSL2 or Git Bash. Counts in-flight subagents from transcript. Recommended as the highest-priority install for Windows operators.
- [`bash-fanout-bounded-rewriter.sh`](https://github.com/yurukusa/cc-safe-setup/blob/main/examples/bash-fanout-bounded-rewriter.sh) — works on Windows when the shell is bash (Git Bash or WSL2). Catches fan-out patterns inside single Bash tool calls.

Hooks that **do not yet have Windows equivalents** (gap, not bug):
- PowerShell-specific fan-out detection (the PowerShell equivalent of `bash-fanout-bounded-rewriter`). Currently a known gap. If you encounter PowerShell fan-out patterns, please file a thin issue against `yurukusa/cc-safe-setup` describing the pattern.
- Windows Job Object integration (would automate the procgov wrap). Future work.
- HVCI compatibility detection (could warn at SessionStart if HVCI is enabled and the BSOD-prone driver is loaded). Future work.

## Where to read more

- **Free**: [cc-safe-setup](https://github.com/yurukusa/cc-safe-setup) — the underlying hook collection (MIT, ~1,000 unique users per 14-day window).
