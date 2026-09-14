# macOS Log Predicate Cookbook

Copy-paste predicates for the unified log, grouped by what you're trying to find out. All work
with both `log show` (past) and `log stream` (live) — swap the subcommand as needed.

## Contents

- [Syntax reminders](#syntax-reminders)
- [Authentication and sessions](#authentication-and-sessions)
- [Remote access](#remote-access)
- [Privilege and permissions](#privilege-and-permissions)
- [Software updates and installs](#software-updates-and-installs)
- [Security subsystems](#security-subsystems)
- [Hardware, power, and boot](#hardware-power-and-boot)
- [Networking](#networking)
- [Backup, MDM, and sharing](#backup-mdm-and-sharing)
- [Known subsystems and categories](#known-subsystems-and-categories)
- [Discovering new filters](#discovering-new-filters)

## Syntax reminders

Wrap the predicate in single quotes, use double quotes inside. Add `[c]` for case-insensitive
string comparison and `[cd]` to also ignore diacritics.

```bash
sudo log show --last 1h --info --style syslog --predicate '<PREDICATE>'
```

Fields: `eventMessage`, `messageType`, `eventType`, `process`, `processImagePath`,
`processIdentifier`, `sender`, `senderImagePath`, `subsystem`, `category`, `threadIdentifier`.

`eventType` values: `logEvent`, `activityCreateEvent`, `activityTransitionEvent`, `traceEvent`,
`signpostEvent`, `stateEvent`, `timesyncEvent`, `userActionEvent`.

Multiple values without chaining `OR`:

```bash
'process IN {"sshd", "logind", "loginwindow", "screensharingd"}'
```

## Authentication and sessions

```bash
# Console / GUI login activity
'process == "loginwindow"'

# Login and session lifecycle daemon
'process == "logind"'

# Keychain unlock events at login
'process == "loginwindow" AND sender == "Security"'

# Session creation and destruction
'process == "securityd" AND eventMessage CONTAINS "Session " AND subsystem == "com.apple.securityd"'

# Open Directory authentication outcomes (usernames appear as <private> unless unmasked)
'subsystem == "com.apple.opendirectoryd" AND category == "auth"'

# Any authentication failure, broad sweep
'eventMessage CONTAINS[c] "authentication" AND eventMessage CONTAINS[c] "fail"'

# Touch ID / biometric
'subsystem == "com.apple.BiometricKit"'
```

## Remote access

```bash
# All SSH activity — successes, failures, key exchange
'process == "sshd"'

# SSH failures only
'process == "sshd" AND eventMessage CONTAINS[c] "failed"'

# Screen Sharing / VNC — successful logins
'process == "screensharingd" AND eventMessage CONTAINS "Authentication: SUCCEEDED"'

# Screen Sharing / VNC — failed logins
'process == "screensharingd" AND eventMessage CONTAINS "Authentication: FAILED"'

# Both Screen Sharing daemons
'process IN {"screensharingd", "ScreensharingAgent"}'

# Remote Apple Events / remote management
'process IN {"ARDAgent", "eppc"}'
```

A successful `screensharingd` entry includes the source address, e.g. a "Guest Request for
Control" succeeding from `192.168.107.153` — that address is the pivot point for the rest of an
investigation.

## Privilege and permissions

```bash
# Commands run with elevated privileges
'process == "sudo"'

# TCC — privacy permission grants and denials (camera, mic, disk, automation)
'process == "tccd"'

# TCC denials specifically
'process == "tccd" AND eventMessage CONTAINS[c] "denied"'

# Kernel extension load attempts
'process == "kextd" AND sender == "IOKit"'

# System extensions (the modern replacement for kexts)
'subsystem == "com.apple.sysextd"'

# Authorization database decisions
'process == "authd"'
```

## Software updates and installs

```bash
# Software update daemon
'process == "softwareupdated"'

# The full update-related process set
'process IN {"softwareupdated", "installd", "system_installd", "SoftwareUpdateNotificationManager"}'

# Update subsystems
'subsystem IN {"com.apple.SoftwareUpdate", "com.apple.mac.install", "com.apple.SoftwareUpdateMacController", "com.apple.mobileassetd"}'

# A specific update by identifier
'process == "mdmclient" AND subsystem == "com.apple.ManagedClient" AND category == "OSUpdate" AND eventMessage CONTAINS "MSU_UPDATE_21E258_patch_12.3.1"'

# App Store and package installation
'process IN {"appstoreagent", "storedownloadd", "installer"}'
```

Pair these with `/var/log/install.log`, which records installer work performed during reboots
when nothing else was observing.

## Security subsystems

```bash
# Gatekeeper evaluation
'process == "syspolicyd" OR subsystem == "com.apple.syspolicy.exec"'

# XProtect malware signature matches
'subsystem == "com.apple.xprotect"'

# XProtect Remediator scan results
'subsystem == "com.apple.XProtectFramework.PluginAPI"'

# Certificate revocation checks
'subsystem == "com.apple.securityd" AND category == "ocsp"'

# Broad security subsystem sweep
'subsystem BEGINSWITH "com.apple.security"'

# Quarantine attribute handling on downloaded files
'eventMessage CONTAINS[c] "quarantine"'
```

## Hardware, power, and boot

```bash
# Why the machine shut down or rebooted — see troubleshooting-playbooks.md for the code table
'eventMessage CONTAINS "Previous shutdown cause"'

# Sleep and wake transitions
'subsystem == "com.apple.powerd"'

# Wake reasons
'eventMessage CONTAINS[c] "wake reason"'

# Thermal pressure
'eventMessage CONTAINS[c] "thermal"'

# Disk and filesystem errors
'process IN {"diskarbitrationd", "fseventsd"} OR eventMessage CONTAINS[c] "I/O error"'

# Boot-time activity: bound by time window rather than predicate, then read chronologically
```

## Networking

```bash
# Network stack
'subsystem == "com.apple.network"'

# Connection establishment and TLS
'subsystem == "com.apple.network" AND category IN {"connection", "boringssl"}'

# DNS resolution
'process == "mDNSResponder"'

# VPN
'process IN {"nesessionmanager", "neagent"} OR subsystem == "com.apple.networkextension"'

# DHCP and interface configuration
'process == "configd"'

# Application firewall
'process == "socketfilterfw"'
```

## Backup, MDM, and sharing

```bash
# Time Machine — the --info flag is required or most entries are hidden
'subsystem == "com.apple.TimeMachine"'

# MDM client activity
'process == "mdmclient" AND subsystem == "com.apple.ManagedClient"'

# Configuration profile installation
'process == "profiles" OR subsystem == "com.apple.ManagedConfiguration"'

# AirDrop
'subsystem == "com.apple.sharing" AND category == "AirDrop"'

# Apple Watch auto-unlock
'subsystem == "com.apple.sharing" AND category == "AutoUnlock"'

# Push notification service
'process == "apsd" OR subsystem == "com.apple.apsd"'

# Content caching
'subsystem == "com.apple.AssetCache"'

# Activation Lock / DEP enrollment
'process == "mobileactivationd" OR subsystem == "com.apple.MobileActivation"'

# iCloud
'subsystem BEGINSWITH "com.apple.cloudd"'
```

## Known subsystems and categories

Apple changes these without notice; verify against live output rather than trusting the table
when something returns empty.

| Area | Process | Subsystem | Category |
|---|---|---|---|
| AirDrop | — | `com.apple.sharing` | `AirDrop` |
| Watch unlock | — | `com.apple.sharing` | `AutoUnlock` |
| APNs | `apsd` | `com.apple.apsd` | |
| Content caching | | `com.apple.AssetCache` | |
| Gatekeeper | `syspolicyd` | `com.apple.syspolicy.exec` | |
| Install / update | `softwareupdated` | `com.apple.SoftwareUpdate`, `com.apple.mac.install`, `com.apple.mobileassetd` | |
| MDM | `mdmclient` | `com.apple.ManagedClient` | `OSUpdate` |
| Mobile activation | `mobileactivationd` | `com.apple.MobileActivation` | |
| Networking | | `com.apple.network` | `connection`, `boringssl` |
| OCSP | | `com.apple.securityd` | `ocsp` |
| Open Directory | `opendirectoryd` | `com.apple.opendirectoryd`, `com.apple.AccountPolicy` | `auth` |
| User login | `loginwindow` | `com.apple.login` | |
| XProtect | | `com.apple.xprotect` | |
| Time Machine | `backupd` | `com.apple.TimeMachine` | |

## Discovering new filters

When the subsystem for some feature is unknown, reproduce the behaviour while streaming
a short capture, then inspect the recorded process, subsystem, and category fields.
Create `LOG_WORKDIR` using the private-directory setup in `SKILL.md` first.

```bash
# Trigger the behaviour in another terminal while this bounded capture runs.
sudo log stream --timeout 20 --level debug --style ndjson > "$LOG_WORKDIR/discover.ndjson"

# Rank subsystems by volume to spot the relevant one
python3 "<skill-path>/scripts/macos-log-summarize.py" "$LOG_WORKDIR/discover.ndjson" --top 20
```

In a `--style syslog` line such as:

```
mdmclient: [com.apple.ManagedClient:OSUpdate] Mapped status SU: [phase: downloading; ...]
```

`mdmclient` is the process, `com.apple.ManagedClient` the subsystem, `OSUpdate` the category,
and the remainder is the `eventMessage`. Build the predicate from those four pieces.

Third-party vendors publish their own identifiers — for example a security agent logging under
`com.crowdstrike.falcon` with categories like `falcon_detections`. Ask the vendor or grep their
binary's `Info.plist` when it isn't documented.
