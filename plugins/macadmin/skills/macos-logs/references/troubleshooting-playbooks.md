# macOS Troubleshooting Playbooks

Ordered procedures for the investigations that come up most. Each starts narrow and widens only
if needed, because unified log queries get expensive fast. Create `LOG_WORKDIR` using
the private-directory setup in `SKILL.md` before running file-output examples.

## Contents

- [Unexpected reboot or shutdown](#unexpected-reboot-or-shutdown)
- [Kernel panic](#kernel-panic)
- [Failed macOS or app update](#failed-macos-or-app-update)
- [Application crash or hang](#application-crash-or-hang)
- [Login failure or slow login](#login-failure-or-slow-login)
- [Unexplained wake from sleep](#unexplained-wake-from-sleep)
- [Time Machine failure](#time-machine-failure)
- [Slow boot](#slow-boot)
- [Network or VPN problem](#network-or-vpn-problem)
- [Permission denied with no obvious cause](#permission-denied-with-no-obvious-cause)

## Unexpected reboot or shutdown

1. Start around the known incident time. Widen only while relevant retained data remains;
   an absent shutdown-cause message does not establish why the Mac restarted.

   ```bash
   sudo log show --last 72h --predicate 'eventMessage CONTAINS "Previous shutdown cause"' --style syslog
   ```

2. Cross-check reboot times independently:

   ```bash
   last reboot | head -10
   uptime
   ```

3. Look at the minutes before the recorded shutdown time:

   ```bash
   sudo log show --start "2026-09-13 22:55:00" --end "2026-09-13 23:05:00" --info --style syslog > "$LOG_WORKDIR/preshutdown.log"
   ```

4. Check for a panic report in `/Library/Logs/DiagnosticReports/`.

### Shutdown cause codes

Code 5 is the normal case. Negative codes generally indicate hardware or firmware involvement.
These are community-compiled and vary across models; treat them as a strong hint, not proof.

| Code | Meaning |
|---|---|
| `5` | Clean, OS-initiated shutdown — normal |
| `3` | Hard shutdown: power button held, or power lost |
| `0` | Power removed / cause not recorded |
| `-3` | Multiple temperature sensors exceeded limits |
| `-20` | Unknown; often seen around firmware updates |
| `-60` | Bad master directory block |
| `-61` | Watchdog timeout |
| `-62` | Restart following a panic |
| `-64` / `-65` | Kernel panic |
| `-71` | Memory (SO-DIMM) temperature |
| `-74` | Battery temperature |
| `-75` | Power adapter communication failure |
| `-78` | Incorrect current from adapter |
| `-79` | Incorrect current from battery |
| `-86` | Proximity temperature sensor |
| `-95` | CPU overtemperature |
| `-100` | Power supply fault |
| `-103` | Battery cell under-voltage |
| `-127` | PMU forced shutdown |
| `-128` | Unknown |

Fuller lists are maintained at <https://georgegarside.com/blog/macos/shutdown-causes/>.

## Kernel panic

1. Find the report:

   ```bash
   ls -lt /Library/Logs/DiagnosticReports/*.panic /Library/Logs/DiagnosticReports/*.ips 2>/dev/null | head
   ```

2. Extract the panic string and backtrace — the faulting kernel extension is usually named
   there:

   ```bash
   tail -n +2 /Library/Logs/DiagnosticReports/Kernel-2026-09-13-*.ips | jq -r '.panicString' | head -40
   ```

3. Inventory third-party kexts and system extensions, the usual culprits:

   ```bash
   kmutil showloaded --list-only | grep -v "com.apple"
   systemextensionsctl list
   ```

4. Check the log immediately before the panic timestamp using the window technique above.

## Failed macOS or app update

1. `install.log` first — it captures work done during reboots:

   ```bash
   grep -iE "softwareupdate|installer|PackageKit|error|fail" /var/log/install.log | tail -100
   zgrep -iE "error|fail" /var/log/install.log.*.gz | tail -50
   ```

2. Surrounding system context from the unified log:

   ```bash
   sudo log show --last 6h --info --style syslog \
     --predicate 'process IN {"softwareupdated", "installd", "system_installd"}' \
     > "$LOG_WORKDIR/update.log"
   ```

3. If the Mac is managed, check whether MDM drove the update:

   ```bash
   sudo log show --last 6h --info \
     --predicate 'process == "mdmclient" AND category == "OSUpdate"' --style syslog
   ```

4. Confirm free space and staged assets — updates commonly fail on space, not on logic:

   ```bash
   df -h /
   ls -la /System/Volumes/Update/ 2>/dev/null
   ```

## Application crash or hang

1. Inventory recent reports:

   ```bash
   ls -lt ~/Library/Logs/DiagnosticReports/ | head -20
   ```

2. Read the header and the failure detail:

   ```bash
   f="/path/to/one-selected-report.ips"
   head -1 "$f" | jq
   tail -n +2 "$f" | jq '{exception, termination, faultingThread}'
   ```

3. Get what the app logged in the run-up:

   ```bash
   sudo log show --last 30m --info --style syslog --predicate 'process == "AppName"' > "$LOG_WORKDIR/app.log"
   ```

4. Also check `~/Library/Logs/<AppName>/` and the sandboxed path
   `~/Library/Containers/<bundle-id>/Data/Library/Logs/`.

## Login failure or slow login

```bash
# The login path, one query
sudo log show --last 1h --info --style syslog --predicate 'process IN {"loginwindow", "logind", "opendirectoryd", "authd", "securityd"}' > "$LOG_WORKDIR/login.log"
```

Then narrow to failures:

```bash
grep -iE "fail|denied|error|timeout" "$LOG_WORKDIR/login.log" | head -40
```

For slow logins, look for network-bound work: directory service lookups, mounting network
homes, or login items reaching out. Sort the log by timestamp and find the gap.

Usernames are `<private>` by default. Unmask `com.apple.opendirectoryd` with a configuration
profile only if the identity actually matters, then remove it.

## Unexplained wake from sleep

```bash
# What woke it
sudo log show --last 24h --style syslog --predicate 'eventMessage CONTAINS[c] "wake reason" OR subsystem == "com.apple.powerd"' | head -60

# Scheduled wakes and assertions currently preventing sleep
pmset -g log | grep -iE "wake|sleep" | tail -40
pmset -g assertions
```

## Time Machine failure

`--info` is mandatory here; without it most Time Machine entries are invisible.

```bash
sudo log show --last 12h --info --style syslog --predicate 'subsystem == "com.apple.TimeMachine"' > "$LOG_WORKDIR/tm.log"

grep -iE "error|fail|unable|abort" "$LOG_WORKDIR/tm.log" | head -40
tmutil listbackups 2>/dev/null | tail -5
tmutil status
```

## Slow boot

1. Establish the boot window, then read it in order:

   ```bash
   sysctl -n kern.boottime
   sudo log show --start "<boot time>" --end "<boot time + 3m>" --info --style syslog > "$LOG_WORKDIR/boot.log"
   ```

2. Rank processes by log volume to identify leads, then verify timing separately;
   log volume alone does not identify the slowest process:

   ```bash
   sudo log show --start "<boot time>" --end "<boot time + 3m>" --info --style ndjson | python3 "<skill-path>/scripts/macos-log-summarize.py" --top 20
   ```

3. Check launchd services that failed or retried:

   ```bash
   sudo log show --start "<boot time>" --end "<boot time + 3m>" --info --predicate 'process == "launchd"' --style syslog | grep -iE "exit|fail|throttl"
   ```

## Network or VPN problem

```bash
# Reproduce in another terminal during this bounded capture
sudo log stream --timeout 45 --level info --style compact --predicate 'subsystem == "com.apple.network" OR process IN {"mDNSResponder", "configd", "neagent"}' > "$LOG_WORKDIR/net.log"
```

Complement with `scutil --nc list`, `ifconfig`, `networksetup -getinfo "Wi-Fi"`, and
`sudo dscacheutil -statistics`.

## Permission denied with no obvious cause

Most "it just won't let me" problems on modern macOS are TCC or Gatekeeper, not POSIX modes.

```bash
# Privacy (TCC) denials
sudo log show --last 15m --info --style syslog --predicate 'process == "tccd"' | tail -40

# Gatekeeper / notarization
sudo log show --last 15m --info --style syslog --predicate 'process == "syspolicyd" OR subsystem == "com.apple.syspolicy.exec"' | tail -40

# Quarantine attribute on the file itself
xattr -l /path/to/file
```

If the calling process is your own shell or agent, the fix is usually granting Full Disk
Access to the host application rather than changing anything about the target file.
