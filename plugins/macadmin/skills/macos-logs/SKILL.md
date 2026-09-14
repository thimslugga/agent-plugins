---
name: macos-logs
description: >-
  Read, filter, collect, and analyze macOS Unified Logs, legacy log files, crash
  reports, and .logarchive bundles. Use for requests to check or collect Mac logs,
  investigate crashes or unexpected restarts, trace a specific incident through
  logs, or construct macOS log show, stream, and collect commands.
---

# macOS Logs Skill

## Overview

macOS logging is two systems layered on top of each other.

1. **The Apple Unified Log (AUL)** - since macOS 10.12 Sierra, nearly everything the system
   records goes here. It is a compressed binary store in `/var/db/diagnostics` (the
   `.tracev3` data) and `/var/db/uuidtext` (the string catalogs). You never read these files
   directly; you query them with the `log` command. This is where the answer usually is.
2. **Legacy log files** - Can be found in `/var/log` and `~/Library/Logs`. Most were
   redirected into the AUL, but a few were not and remain independently valuable —
   `install.log` above all.

Note: `/var/log/system.log` is *not* where the interesting content lives on a current macOS system.
Do not start there and do not conclude "nothing was logged" from it.

## Picking a source

| Question | Go to |
|---|---|
| Why did a macOS or app update fail? | `/var/log/install.log` first, then AUL `softwareupdated` / `installd` |
| Did an app crash, and where? | `~/Library/Logs/DiagnosticReports/*.ips` and `/Library/Logs/DiagnosticReports` |
| Why did the Mac reboot or shut down? | `log`, predicate on `"Previous shutdown cause"` |
| Who logged in, when, and how? | `log`, predicate on `loginwindow`, `logind`, `sshd`, `screensharingd` |
| Permissions / TCC prompt denials | `log`, predicate on `process == "tccd"` |
| Gatekeeper or XProtect blocked something | `log`, predicate on `syspolicyd`, `com.apple.xprotect` |
| Anything else on a live Mac | `log`, via `log show` |
| Anything on a disk image or captured evidence | Reconstruct a `.logarchive` — see `references/forensics-and-incident-response.md` |

## Operating rules for running `log` commands in an agent shell

These exist because the failure modes are expensive.

Create a private working directory before saving diagnostic output. Keep it for the
investigation and use its path in the examples below:

```bash
umask 077
LOG_WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/macos-logs.XXXXXX")
```

- **Bound the time range to the incident.** Use `--last` or `--start`/`--end` for
  live queries. Start with the known incident time; use `--last 15m` only when no
  time is known. Widen when relevant evidence is missing, even if unrelated events
  are present, and stop at the available retention boundary. A deliberately requested
  full export of an existing archive is an exception; see the forensic reference.
- **Bound live streams.** On versions supporting it, use the native timeout:

  ```bash
  log stream --timeout 30 --predicate 'process == "sshd"' --style ndjson > "$LOG_WORKDIR/sshd-stream.ndjson"
  ```

  Check `log help stream` on the target Mac. If `--timeout` is unavailable, use a
  process runner that terminates and waits for the stream on timeout or interruption.
  Avoid unattended background streams. Prefer `log show` for events that already happened.
- **Redirect to a file, then read selectively.** Pipe through `head`, `wc -l`, or the bundled
  summarizer rather than letting raw output land in context.
  ```bash
  log show --last 1h --style ndjson --predicate 'subsystem == "com.apple.TimeMachine"' > "$LOG_WORKDIR/tm.ndjson"
  wc -l "$LOG_WORKDIR/tm.ndjson"
  ```
- **Use `--style ndjson` when anything will parse the output**; one JSON object per line, so
  `jq`, Python, or `scripts/macos-log-summarize.py` can parse it incrementally. Use
  `--style syslog` or `--style compact` only when a human is reading directly.
- **Prefer `sudo`.** Some entries are withheld from unprivileged callers. Reading
  `/var/db/diagnostics` directly additionally needs Full Disk Access for the calling terminal
  or agent binary — a common silent cause of thin or empty results on managed Macs.
- **Info and debug levels are excluded by default.** If a query returns nothing, re-run with
  `--info` before concluding the event wasn't logged. Debug messages are generally *not
  persisted to disk at all*, so they cannot be recovered retroactively — see "Message levels"
  below.

## The `log` command

Four subcommands carry almost all real work.

- `log show` — query what already happened
- `log stream` — follow a live event
- `log collect` — archive logs for offline analysis
- `log config` — configure log settings

### `log show` — query what already happened

Useful flags: `--info` and `--debug` (include those levels), `--style default|compact|syslog|json|ndjson`,
`--archive <path>`, `--color none` (strip ANSI when redirecting), `--signpost`, `--loss`,
`--backtrace`.

```bash
# Last 15 minutes, human-readable
sudo log show --last 15m --style syslog

# A specific window (interpreted in the machines local time zone)
sudo log show --start "2026-09-13 22:00:00" --end "2026-09-14 02:00:00" --style syslog

# One process, including info-level messages, saved for analysis
sudo log show --last 2h --info --style ndjson --predicate 'process == "softwareupdated"' > "$LOG_WORKDIR/su.ndjson"

# Read a previously collected archive instead of the live system
log show --archive ~/Desktop/device.logarchive --last 1h --style syslog
```

### `log stream` — watch it happen

```bash
sudo log stream --timeout 30 --level info --predicate 'subsystem == "com.apple.sharing" AND category == "AirDrop"'
```

`--level default|info|debug` controls verbosity. `--timeout 30` ends the stream after 30 seconds.

### `log collect` — snapshot the log for later or elsewhere

```bash
sudo log collect --last 2h --output ~/Desktop/device.logarchive
```

The resulting `.logarchive` is portable: hand it to another Mac, a forensics tool, or attach
it to a support case. Bound it with `--last`/`--start` or `--size`, or it will be enormous.
`sysdiagnose` produces one automatically at `system_logs.logarchive` inside its output bundle.

### `log config` — change what gets recorded

```bash
# Save the existing settings before changing this subsystem
sudo log config --status --subsystem com.apple.TimeMachine > "$LOG_WORKDIR/timemachine-config-before.txt"

# After identifying how to restore the saved configuration, enable debug and reproduce
sudo log config --mode "level:debug" --subsystem com.apple.TimeMachine
```

Restore each changed setting to its recorded value after reproduction, including on failure.
`log config --reset` restores defaults; it does not undo the last command. Use a subsystem
reset only if that subsystem had no preexisting custom configuration. Preserve other
categories and any existing configuration profiles. Verify the restored state with `--status`.

Scope changes to a single subsystem; system-wide debug logging degrades performance and
burns through retention. Logging modes include `level:<default|info|debug>` and
`persist:<level>`; inspect the target Mac's `log help config` before changing them.

## Log predicate filtering

Log predicates are `NSPredicate` expressions and are the difference between a five-second answer
and a five-minute one. Filtering with a predicate is dramatically cheaper than piping
everything through `grep` or `rg`, because the filter is applied before decompression and formatting.

**Fields:** `eventMessage`, `messageType`, `eventType`, `process`, `processImagePath`,
`processIdentifier`, `sender`, `senderImagePath`, `subsystem`, `category`, `threadIdentifier`.

**Operators:** `==` `!=` `<` `>` `<=` `>=`, `AND`/`&&`, `OR`/`||`, `NOT`/`!`, `CONTAINS`,
`BEGINSWITH`, `ENDSWITH`, `LIKE`, `MATCHES`, `IN`.

String comparisons are case- and diacritic-sensitive by default. Append `[c]`, `[d]`, or
`[cd]` to relax that — `eventMessage CONTAINS[c] "failed"` is usually what you actually want.

```bash
# Combine fields with AND
sudo log show --last 24h --predicate 'process == "screensharingd" AND eventMessage CONTAINS "Authentication: FAILED"'

# Case-insensitive substring across everything
sudo log show --last 30m --info --predicate 'eventMessage CONTAINS[c] "certificate"'

# Several processes at once
sudo log show --last 1h --predicate 'process IN {"sshd", "logind", "loginwindow"}'
```

Quote the whole predicate in single quotes and use double quotes inside it, so the shell
leaves it alone.

If a predicate is rejected, the exit status is non-zero and the message says so — test new
predicates against `--last 1m` before committing to a long window, and consult `man log` and
`man 5 NSPredicate`-style docs rather than guessing.

### Message levels

| Level | Enabled by default | Destination |
|---|---|---|
| Default | Always | Disk |
| Info | Yes | Memory (persisted only in some cases) |
| Debug | No | Not stored |
| Error | Always | Disk |
| Fault | Always | Disk |

This table explains two recurring surprises: info-level messages may age out of memory before
you query, and debug messages are simply absent unless you enabled them with `log config`
*before* the event, or you were watching with `log stream --level debug` at the time.

Use numeric message types for error/fault filtering:

```bash
--predicate 'messageType == 16 OR messageType == 17'
```

Values are 0 default, 1 info, 2 debug, 16 error, and 17 fault. Check `log help predicates`
on the target Mac. A successful command exit alone does not prove that a predicate matched
the intended records. Preserve query errors; do not automatically replace a rejected filter
with a much larger unfiltered export. The summarizer also groups error/fault records from a
mixed-level NDJSON input.

## Private data redaction

Entries containing user names, hostnames, paths, or other identifying values are redacted to
`<private>` by default. This is deliberate, and it is the single most common reason a log line
looks useless.

To unmask, install a configuration profile enabling private data logging for the *specific
subsystem* under investigation, reproduce the issue, then remove the profile. Do not leave it
on system-wide.

## Legacy flat files still worth reading

`install.log` is the important one — it survives reboots and records installer work performed
while nothing else was watching.

```bash
# Update-related entries, including rotated history
grep -iE "softwareupdate|installer|PackageKit" /var/log/install.log
zgrep -iE "softwareupdate|installer" /var/log/install.log.*.gz

# To watch an install as it runs
tail -f /var/log/install.log
```

Others that still carry content: `wifi.log`, `appfirewall.log`, `fsck_apfs.log`,
`DiskUtility.log`. Full map with forensic value ratings in `references/macos-log-locations.md`.

## Crash reports

`.ips` files in `~/Library/Logs/DiagnosticReports/` (user) and
`/Library/Logs/DiagnosticReports/` (system, includes kernel panics). Each file is a one-line
JSON header followed by a JSON body — parse the two halves separately:

```bash
head -1 report.ips | jq '{app: .app_name, version: .app_version, ts: .timestamp}'
tail -n +2 report.ips | jq '.exception, .termination'
```

## Bundled resources

Read these when the task goes past the basics above:

- `references/macos-log-locations.md` — full filesystem map of log paths, what each contains, which
  are legacy, and BSM audit logs in `/var/audit`.
- `references/log-predicate-cookbook.md` — ready-to-run predicates by task: authentication, SSH,
  Screen Sharing, sudo, TCC, kernel extensions, MDM, Gatekeeper, networking, updates, plus the
  known subsystem/category names worth memorizing.
- `references/troubleshooting-playbooks.md` — step-by-step investigations for the recurring
  cases: unexpected reboot, failed update, app crash, login failure, slow boot, Time Machine.
  Includes the shutdown-cause code table.
- `references/forensics-and-incident-response.md` — acquisition from live systems and disk images,
  reconstructing a `.logarchive`, retention and volume expectations, third-party parsers.

Scripts (run them, don't read them, unless modifying):

- `scripts/macos-log-triage.sh` — bounded triage collector. Gathers system facts, shutdown
  causes, install.log excerpts, error/fault slices, and crash report inventory into one
  new private directory. Run `bash "<skill-path>/scripts/macos-log-triage.sh" -t 6 -o ~/Desktop/triage`
  (`-t` hours, default 6; `-a` to also build a `.logarchive`; `-p` for an extra predicate).
  The output must not exist and its parent must exist. Shutdown causes and crash inventory
  cover seven days; install excerpts are limited by line count. Run as the affected user;
  for privileged collection, authenticate with `sudo -v` first in an interactive terminal.
  Without cached privilege the script collects unprivileged data and marks it partial.
  `MANIFEST.txt` records step outcomes, collection status, and recursive hashes including the
  archive. Exit 0 means complete execution, 1 means partial/failed, and 2 means invalid arguments.
  A successful query does not guarantee retention, Full Disk Access, or unredacted data.
- `scripts/macos-log-summarize.py` — reads `log show --style ndjson` output and reports the top
  processes, subsystems, and recurring error/fault messages grouped by process and subsystem.
  Standard library only. Malformed records and unreadable files produce warnings and exit 1;
  any valid records still produce a partial summary. JSON output includes `skipped_records`
  and `failed_files`. JSON arrays are also accepted but loaded into memory.
  `log show --last 1h --style ndjson | python3 scripts/macos-log-summarize.py --top 15`

## Traps that repeatedly cost time

- Querying `/var/log/system.log` on a modern Mac and finding it empty. Expected. Use the AUL.
- Assuming `/var/log/kernel.log` or `/var/log/asl/` exist. They do not on current macOS.
- Concluding "nothing was logged" after querying without `--info`.
- Expecting debug messages retroactively. They were never written.
- `grep`-ing gigabytes of `log show` output instead of using a predicate.
- Forgetting retention: the unified log typically covers only the last ~7–30 days, scaled to
  disk size. If the incident is older, the data is gone unless an archive was collected.
- Treating `<private>` as a bug rather than a policy.
- Reading a `.logarchive` collected from a much newer macOS on a much older one — parsing can
  fail or silently drop records.
