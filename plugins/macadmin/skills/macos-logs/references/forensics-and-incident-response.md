# Forensics and Incident Response

Acquiring the unified log as evidence, working with archives, and knowing what you can expect
to still be there.

## Contents

- [Architecture worth knowing](#architecture-worth-knowing)
- [Volume and retention](#volume-and-retention)
- [Acquisition from a live Mac](#acquisition-from-a-live-mac)
- [Reconstructing an archive from a disk image](#reconstructing-an-archive-from-a-disk-image)
- [Analyzing an archive](#analyzing-an-archive)
- [Scoping a query efficiently](#scoping-a-query-efficiently)
- [Third-party parsers](#third-party-parsers)
- [Chain of custody notes](#chain-of-custody-notes)

## Architecture worth knowing

Two daemons handle the unified log, and the split explains what is recoverable:

- **`logd`** pulls messages from each process's buffer, compresses them, checks the message
  level, and writes to disk or memory according to the level table. This is the path that
  produces durable evidence.
- **`diagnosticd`** serves live subscribers — this is what `log stream` talks to. Nothing here
  is persisted by virtue of being streamed.

Consequence: if a message level routes to memory or is disabled, no amount of later querying
recovers it. Default, error, and fault go to disk. Info goes to memory. Debug is off.

Legacy APIs — `NSLog`, `asl`, `syslog` — were redirected into the AUL, so old application code
still lands here. A specific set of logs was *not* redirected and remains independent evidence:
`audit.log`, `system.log`, `daily.out`, `weekly.out`, `monthly.out`, `wifi.log`, `install.log`,
CUPS, and most third-party application logs. Collect those separately.

## Volume and retention

Rough expectations, for planning storage and setting expectations with the person asking:

| | Unified log | ASL (legacy) | system.log (legacy) |
|---|---|---|---|
| Retention | ~7–30 days, scaled to disk | 7 days full / 1 year limited | 7–14 days |
| Records | 30–50 million | 200K–500K | 200K–400K |
| Size | 400–800 MB as `.logarchive`; 2–9 GB as plaintext | 40–60 MB | 30–60 MB |

The compression ratio is the operative fact: exporting everything to text inflates it by
roughly an order of magnitude. That is why predicate filtering at query time beats
`grep`-ing an exported dump, and why exporting "just in case" on a fleet is impractical.

Retention scales with free space, so a nearly full disk may hold only a few days. Check the
available time range before assuming an incident is in range. For a collected archive,
inspect `log stats --archive /path/to/incident.logarchive --overview`. Do not use
`log show | head -1` for this: the first line may be a header rather than a record.

## Acquisition from a live Mac

Prefer `log collect` — it produces a portable, analyzable bundle rather than a text dump.

```bash
# Bounded by time
sudo log collect --last 4h --output ~/Desktop/host-$(date +%Y%m%d-%H%M%S).logarchive

# Bounded by a start point
sudo log collect --start "2026-09-13 18:00:00" --output ~/Desktop/incident.logarchive

# Bounded by size, when sampling
sudo log collect --size 200m --output ~/Desktop/sample.logarchive
```

Also collect the files that never entered the AUL:

```bash
DEST=~/Desktop/evidence
umask 077
mkdir -m 700 "$DEST" || exit 1
sudo cp -p /var/log/install.log "$DEST"/
sudo cp -p /var/log/install.log.*.gz "$DEST"/
sudo cp -Rp ~/Library/Logs/DiagnosticReports "$DEST"/user-DiagnosticReports
sudo cp -Rp /Library/Logs/DiagnosticReports "$DEST"/system-DiagnosticReports
sudo cp -Rp /var/audit "$DEST"/audit
```

`sysdiagnose` gathers a broad bundle including a `system_logs.logarchive`, at the cost of size
and time:

```bash
sudo sysdiagnose -u          # no UI prompt; output lands in /var/tmp
```

The bundled `scripts/macos-log-triage.sh` collects bounded log slices, install excerpts,
a crash inventory, and an optional archive. It does not copy full crash reports or BSM
audit trails; collect those separately when required. Missing optional sources should be
recorded as absent; retain permission and copy errors rather than treating them as absence.

## Reconstructing an archive from a disk image

From a mounted image or exported file set, the two source directories together *are* the
archive — the extension is what makes tools recognize it.

```bash
mkdir -p /evidence/host01.logarchive
cp -Rp /Volumes/MacintoshHD/private/var/db/diagnostics/* /evidence/host01.logarchive/
cp -Rp /Volumes/MacintoshHD/private/var/db/uuidtext/*    /evidence/host01.logarchive/

log show --archive /evidence/host01.logarchive --style syslog --last 7d | head
```

Both directories are required. `.tracev3` files alone contain references into the `uuidtext`
catalogs; without them, messages cannot be rendered and output will be unusable or empty.

Analyze on a macOS version at or above the source system's. Parsing a newer archive on an older
macOS can fail or silently drop records.

## Analyzing an archive

Time and predicate filters also work against an archive. Use a known incident window by
default. A full export is appropriate only when explicitly requested for an existing archive:
check free space, save to a private destination, and expect potentially gigabytes of output.
This is the deliberate exception to the live-query time-bound rule.

```bash
ARCHIVE=/evidence/host01.logarchive

# Full plaintext export with everything included — expect gigabytes
log show "$ARCHIVE" --info --debug --backtrace --loss --signpost --style syslog > /evidence/host01-full.txt

# Targeted: a keyword in the final hour of the archive
log show "$ARCHIVE" --last 1h --info --style syslog --predicate 'eventMessage CONTAINS[c] "remote"' > /evidence/host01-remote.txt

# Targeted: a time slice
log show "$ARCHIVE" --start "2026-09-13 20:00:00" --end "2026-09-13 23:00:00" --info --style ndjson > /evidence/host01-window.ndjson
```

`--loss` reports
gaps where records were dropped — worth including, since a gap around the incident time is
itself a finding.

## Scoping a query efficiently

The instinct to export everything and `grep` it does not survive contact with a 30-million
record log, and it fails completely across a fleet. Work in this order instead:

1. **Time** — narrow to the window you care about with `--start`/`--end`.
2. **Process or subsystem** — the predicates in `references/log-predicate-cookbook.md` cover most
   of the high-yield ones.
3. **Message content** — `eventMessage CONTAINS[c] "..."` last, once volume is manageable.
4. **Pivot** — take IP addresses, usernames, PIDs, or bundle identifiers found in step 3 and go
   back to step 1 with a new filter.

High-yield starting predicates for an intrusion question: `sudo`, `logind`, `tccd`, `sshd`,
`kextd`/`sysextd`, `screensharingd`, `loginwindow` + `Security`, and `securityd` session
events. Each maps to an attacker behaviour — privilege escalation, access, persistence,
lateral movement, credential access.

## Third-party parsers

Useful when analysis must happen off a Mac, or must integrate with a wider disk-analysis
workflow.

| Tool | Notes |
|---|---|
| [mandiant/macos-UnifiedLogs](https://github.com/mandiant/macos-UnifiedLogs) | Rust library and CLI for parsing `.tracev3` directly. Cross-platform, good for pipelines. |
| [ydkhatri/UnifiedLogReader](https://github.com/ydkhatri/UnifiedLogReader) | Archived legacy Python parser. Its maintainer recommends mandiant/macos-UnifiedLogs instead; see the linked README. |
| [ydkhatri/mac_apt](https://github.com/ydkhatri/mac_apt) | Full macOS artifact suite — unified logs plus users, sessions, shell history. |

```bash
# mac_apt examples
python /opt/mac_apt/mac_apt.py -o /analysis --xlsx -d MOUNTED /Volumes/MacintoshHD UNIFIEDLOGS
python /opt/mac_apt/mac_apt.py -o /analysis --csv -d E01 /images/disk.E01 UTMPX USERS TERMSESSIONS
python /opt/mac_apt/mac_apt.py -o /analysis --csv -d DD /images/disk.dd FAST
```

Expect minor record-count differences between parsers. Native `log show` tends to surface a
handful of extra entries — typically timesync records tied to boot and clock adjustment — that
third-party tools omit. The discrepancy is small and rarely material, but note it if record
counts are being compared across tools in a report.

## Chain of custody notes

- Hash archives immediately after collection, recursively including their contents. In Bash,
  enable `set -o pipefail`, then run
  `find incident.logarchive -type f -print0 | xargs -0 shasum -a 256 > incident.sha256`.
  Keep the hash manifest outside the archive and check the pipeline exit status. Alternatively,
  hash a tarball of the complete bundle. Hashes detect later changes; they do not prove complete acquisition.
- Record the collecting host's macOS version and time zone (`sw_vers`, `systemsetup -gettimezone`).
  `log show --start` interprets timestamps in the *local* time zone of the analyzing machine,
  which silently shifts results when analyst and subject are in different zones. State the zone
  explicitly in any report.
- `log collect` on a live system is a *modification* of that system — it writes a file. Note it.
- Prefer imaging-then-reconstructing over live collection when the evidentiary bar is high.
