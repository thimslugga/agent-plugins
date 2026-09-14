# macOS Log Locations

Where things actually live, what state they're in on current macOS, and what each is worth.

## Contents

- [Unified log storage](#unified-log-storage)
- [Legacy flat files in /var/log](#legacy-flat-files-in-varlog)
- [Application logs](#application-logs)
- [Crash and diagnostic reports](#crash-and-diagnostic-reports)
- [BSM audit logs](#bsm-audit-logs)
- [Configuration files](#configuration-files)
- [Access requirements](#access-requirements)

## Unified log storage

| Path | Content | Notes |
|---|---|---|
| `/var/db/diagnostics` | `.tracev3` binary log data | The log itself. Never parse by hand — use `log show`. High IR value. |
| `/var/db/uuidtext` | Format-string and UUID catalogs | Required to resolve messages into readable text. Copying `.tracev3` files without this directory produces unreadable output. |
| `/var/db/diagnostics/Persist` | Persisted (disk-backed) entries | Default / error / fault levels |
| `/var/db/diagnostics/Special` | Short-lived entries | |
| `/var/db/diagnostics/Signpost` | Signpost / performance instrumentation | Surfaced with `log show --signpost` |
| `/var/db/diagnostics/logdata.LiveData.tracev3` | In-flight buffer | Present on live systems |

Both directories together, renamed with a `.logarchive` extension, form a portable archive.
See `forensics-and-incident-response.md`.

## Legacy flat files in /var/log

| Path | Content | State on current macOS |
|---|---|---|
| `/var/log/install.log` | macOS and package installation, software update | **Live and valuable.** Not redirected into the AUL. First stop for update failures. |
| `/var/log/system.log` | General system messages | Mostly empty. Retained for compatibility. Low value. |
| `/var/log/wifi.log` | Wi-Fi association, known networks | Present on some versions; increasingly sparse |
| `/var/log/appfirewall.log` | Application firewall events | Live when the firewall logs are enabled |
| `/var/log/fsck_apfs.log` | Filesystem check results | Live; useful after dirty shutdowns |
| `/var/log/DiskUtility.log` | Disk mount / erase / partition operations | Live |
| `/var/log/DiagnosticMessages/` | Binary diagnostic message archives | Low direct value |
| `/var/log/asl/*.asl` | Apple System Log | **Removed.** Deprecated and gone on modern releases. |
| `/var/log/kernel.log` | Kernel messages | **Does not exist.** Kernel logging goes to the AUL. |
| `/var/log/daily.out`, `weekly.out`, `monthly.out` | Periodic maintenance script output | Present, rarely interesting |

Rotated copies appear as `install.log.0.gz`, `install.log.1.gz`, and so on. Search them with
`zgrep` / `gzcat`, not `grep`:

```bash
zgrep -iE "softwareupdate|installer" /var/log/install.log.*.gz
```

Logs explicitly *not* redirected into the AUL — meaning they are independent evidence rather
than duplicates: `audit.log`, `system.log`, `daily.out`, `weekly.out`, `monthly.out`,
`wifi.log`, `install.log`, CUPS logs, and most third-party application logs.

## Application logs

| Path | Scope |
|---|---|
| `~/Library/Logs/` | Per-user application logs. High value — third-party apps write plaintext here. |
| `/Library/Logs/` | System-wide application logs |
| `/Library/Application Support/<App>/` | App-specific logs, format varies |
| `~/Library/Containers/<bundle-id>/Data/Library/Logs/` | Sandboxed app logs. Easy to miss. |
| `/Applications/<App>/Contents/.../Logs/` | Bundled app logs, uncommon |

Sweep for recent activity rather than guessing paths:

```bash
find ~/Library/Logs /Library/Logs -type f -mtime -2 -size +0 2>/dev/null | head -50
```

## Crash and diagnostic reports

| Path | Contents |
|---|---|
| `~/Library/Logs/DiagnosticReports/` | User-space app crashes, hangs, spindumps |
| `/Library/Logs/DiagnosticReports/` | System-level crashes and **kernel panics** |
| `/Library/Logs/DiagnosticReports/*.panic` | Panic reports on some releases |

Modern reports use the `.ips` extension: line 1 is a JSON header, the remainder is a JSON body.

```bash
ls -lt ~/Library/Logs/DiagnosticReports | head -20
for f in ~/Library/Logs/DiagnosticReports/*.ips; do
  printf '%s: ' "$(basename "$f")"
  head -1 "$f" | jq -r '"\(.app_name // "?") \(.app_version // "") @ \(.timestamp // "?")"'
done
```

Older `.crash` and `.hang` files are plaintext and can be read directly. Kernel panic reports
identify the faulting kext in the `panic_string` / backtrace fields — start there.

## BSM audit logs

The Basic Security Module (TrustedBSD lineage) writes binary audit trails to `/var/audit`.

**Status:** Apple deprecated `auditd` in macOS 11 and it is disabled or absent on current
releases. Check before relying on it; Endpoint Security is the modern replacement.

```bash
ls -l /var/audit 2>/dev/null
sudo launchctl list | grep -i auditd
```

File naming:

| Pattern | Meaning |
|---|---|
| `YYYYMMDDHHMMSS.YYYYMMDDHHMMSS` | Completed trail, start and end timestamps |
| `current` | Symlink to the active trail |
| `*.not_terminated` | Trail not closed cleanly — crash or abrupt shutdown |
| `*.crash_recovery` | Written after an audit or system crash |

Reading them:

```bash
sudo praudit /var/audit/current | less
sudo praudit -l /var/audit/20260914*           # one record per line
sudo auditreduce -c fr -d 20260914 /var/audit/* | praudit -l   # file-read events for a date
```

## Configuration files

| Path | Purpose |
|---|---|
| `/etc/security/audit_control` | Audit policy, flags, retention, rotation size |
| `/etc/security/audit_user` | Per-user audit overrides |
| `/etc/security/audit_class` | Audit event class definitions |
| `/etc/security/audit_event` | Event-to-class mapping |
| `/etc/asl.conf`, `/etc/asl/` | Legacy ASL routing rules; largely vestigial |
| `/etc/newsyslog.conf`, `/etc/newsyslog.d/` | Rotation rules for remaining flat files |
| `/Library/Preferences/Logging/Subsystems/*.plist` | Per-subsystem unified log settings, including persistence and private-data policy |

Unified log retention is managed automatically and scales with available disk space — there is
no fixed size knob equivalent to `newsyslog.conf`. Influence it per subsystem with
`log config` or a configuration profile instead.

## Access requirements

- `log show` / `log stream` work unprivileged but withhold some entries. Use `sudo`.
- Reading `/var/db/diagnostics` or `/var/audit` directly requires root **and** Full Disk Access
  for the calling binary (Terminal, iTerm, an SSH session's shell, or an agent host process).
  Missing FDA usually presents as empty results or `Operation not permitted` rather than a
  clear error — verify before troubleshooting the query itself.
- Grant FDA under System Settings → Privacy & Security → Full Disk Access.
- Remote SSH sessions need FDA granted to `sshd-keygen-wrapper` (or `sshd`) to reach
  protected paths.
