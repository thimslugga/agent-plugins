# FHS 3.0 layout, FHS 2.3 differences, immutable and sandboxed systems

| Path | Purpose |
|---|---|
| `/etc` | Host-specific configuration. No binaries. |
| `/etc/opt/<pkg>` | Config for `/opt` packages. |
| `/usr/bin`, `/usr/sbin` | Distribution-managed commands. |
| `/usr/lib`, `/usr/lib<qual>` | Libraries and package internals. |
| `/usr/libexec` | Helper binaries not meant to be run directly (FHS 3.0). |
| `/usr/share` | Architecture-independent read-only data. |
| `/usr/local` | Admin-installed software; the package manager must not touch it. |
| `/opt/<pkg>` | Self-contained add-on packages. |
| `/var/lib/<pkg>` | Persistent variable state. |
| `/var/cache/<pkg>` | Regenerable cache. |
| `/var/log` | Logs. |
| `/var/spool` | Queued work. |
| `/var/tmp` | Temp files kept across reboots. |
| `/tmp` | Temp files; may be cleared at boot. |
| `/run` | Runtime data since boot (FHS 3.0). `/var/run` is a compatibility path to it. |
| `/srv` | Data served by this host. |
| `/media`, `/mnt` | Removable media; temporary admin mounts. |
| `/home`, `/root` | User homes; root's home. |
| `/boot`, `/dev`, `/proc`, `/sys` | Boot loader files, devices, kernel interfaces. |

The FHS sorts files on two axes: **shareable vs unshareable** (can another host use it?) and **static vs variable** (does it change without admin action?). `/usr` is shareable and static, `/etc` unshareable and static, `/var/lib` unshareable and variable. This is the reasoning behind read-only `/usr` systems.

**FHS 2.3 to 3.0:** 3.0 adds `/run`, `/usr/libexec` and `/sys`, and turns `/var/run` into a compatibility location. 2.3 has `/var/run` as a required directory and knows nothing of `/run`. Code that writes pid files to `/var/run` still works through the symlink, but new code should use `/run`.

**Beyond the FHS on modern distros (not in the standard):** merged `/usr` (next section), and vendor defaults in `/usr/lib/<pkg>` or `/usr/share/<pkg>` with `/etc` holding only overrides.

## Merged /usr

FHS 3.0 still describes `/bin`, `/sbin` and `/lib` as directories on the root filesystem. Almost every current distribution instead moves their contents into `/usr` and leaves symlinks behind:

| Path | Points to |
|---|---|
| `/bin` | `/usr/bin` |
| `/sbin` | `/usr/sbin` |
| `/lib` | `/usr/lib` |
| `/lib64` | `/usr/lib64` |

Fedora did this first, in Fedora 17. systemd 255 removed support for both unmerged `/usr` (separate `/bin` and `/usr/bin`) and split `/usr` (a separate `/usr` partition mounted late in boot instead of by the initramfs). Fedora 42 goes one step further: `/usr/sbin` becomes a symlink to `bin` and is dropped from the default `PATH`. Systems upgraded from Fedora 41 keep a real `/usr/sbin` until it holds only symlinks.

**Why:** the split dates from about 1971, when Unix outgrew its first 1.5 MB RK05 disk pack on the PDP-11 and spilled into the second disk mounted at `/usr`. The rule that early-boot tools must stay off `/usr` was specific to that setup. Shared libraries already made `/lib` and `/usr` impossible to upgrade separately, and today the initramfs mounts `/usr` before switching to the real root. With all vendor files under one directory, `/usr` can be made read-only, snapshotted or shared across hosts and containers as a single unit, and `/` shrinks to host-specific config and state. This is what ostree, bootc and the other image-based systems below build on.

**For code and packages:**

- `/bin/foo` and `/usr/bin/foo` are the same file. Install only into `/usr/bin`, `/usr/lib` and so on; a package that ships files under `/bin` or `/lib` collides with the symlink.
- `realpath /bin/sh` returns `/usr/bin/sh`. Compare paths with `[ file1 -ef file2 ]` or inode checks, not as strings.
- Keep `#!/bin/sh` and `#!/usr/bin/env <cmd>` in scripts. They work on merged and unmerged systems, while `#!/usr/bin/sh` fails on systems that still keep `sh` only in `/bin`.
- Package databases record the path the package declared. `dpkg -S` or `rpm -qf` may find `/usr/bin/foo` but not `/bin/foo` (or the reverse), so try both before concluding a file is unowned.
- On Fedora 42+, put commands in `/usr/bin` even if they are admin-only, and don't rely on `/usr/sbin` being in `PATH` as a separate directory.

Sources: [The Case for the /usr Merge (systemd.io)](https://systemd.io/THE_CASE_FOR_THE_USR_MERGE/) (also on the [freedesktop.org wiki](https://www.freedesktop.org/wiki/Software/systemd/TheCaseForTheUsrMerge/)), [Rob Landley on the bin/sbin/usr split (busybox list, 2010)](https://lists.busybox.net/pipermail/busybox/2010-December/074114.html), [systemd 255 NEWS](https://raw.githubusercontent.com/systemd/systemd/v255-rc1/NEWS), [Fedora Changes/Unify bin and sbin](https://fedoraproject.org/wiki/Changes/Unify_bin_and_sbin).

## Containers

- **Containers:** `HOME` may be unset or `/`, and `XDG_RUNTIME_DIR` is normally absent. Handle both.

## Immutable systems

### ostree: Fedora Atomic Desktops (Silverblue, Kinoite...), Fedora IoT, Fedora CoreOS

The running system is a *deployment*: a checkout of an ostree commit under `/ostree/deploy/<stateroot>/deploy/<checksum>`, booted into like a chroot. The physical root filesystem is mounted at `/sysroot` (read-only since Fedora 37), `/ostree` is a symlink to `/sysroot/ostree`, and the object store is `/ostree/repo`.

`/` and `/usr` are read-only. Only `/etc` and `/var` are writable and kept across upgrades, so the FHS directories that normally hold local state are symlinks into `/var`:

| Path | Points to |
|---|---|
| `/home` | `/var/home` (mount a separate home partition on `/var/home`) |
| `/opt` | `/var/opt` |
| `/srv` | `/var/srv` |
| `/root` | `/var/roothome` |
| `/usr/local` | `/var/usrlocal` |
| `/mnt` | `/var/mnt` |
| `/tmp` | `/sysroot/tmp` |

- **`/etc`:** each deployment has its own copy. An upgrade takes the new image's default `/etc` and reapplies local changes on top (a 3-way merge), so new defaults arrive unless the file was changed locally. Ownership and xattr changes count as local changes. `ostree admin config-diff` lists what differs from the defaults.
- **`/var`:** there is exactly one, shared by all deployments. Upgrades and rollbacks never touch it. `/var` content shipped in an image is unpacked only at first install, so create directories at boot with `tmpfiles.d` or a unit's `StateDirectory=`.
- **`/boot`, `/boot/efi`:** still writable but managed by rpm-ostree and bootupd; never run `grub2-mkconfig`. Fedora plans to mount `/boot` read-only and stop mounting `/boot/efi` ([#21](https://gitlab.com/fedora/ostree/sig/-/work_items/21), [#22](https://gitlab.com/fedora/ostree/sig/-/work_items/22)).
- **Packages and users:** the RPM database is in `/usr/share/rpm` (read-only). `rpm-ostree install <pkg>` builds a new deployment that takes effect on reboot (`-A` live-applies pure additions). `rpm-ostree usroverlay` gives a writable `/usr` until the next reboot. System users come from `/usr/lib/passwd` through nss-altfiles, so prefer `DynamicUser=yes` or `sysusers.d` over `useradd` in scripts.

For path code: use `$HOME`, never a literal `/home/<user>`. `realpath ~` returns `/var/home/<user>`, so don't compare canonicalised paths against `/home`. Put user tools in `~/.local/bin` and system state in `/etc` or `/var` (or the symlinked directories above). Writes anywhere else fail, and changes made under `usroverlay` are gone after a reboot.

### bootc (image mode)

bootc boots OCI container images and uses ostree underneath, so `/sysroot`, the `/etc` merge and the single shared `/var` work as above. Differences from the ostree defaults:

- With composefs, which bootc recommends, all of `/` is read-only, including `/opt` and any extra top-level directory baked into the image.
- `/usr/local` is a normal directory that belongs to the image, not a symlink to `/var/usrlocal`. Final images may add the symlink.
- For software that writes into `/opt`, symlink only the writable subdirectories into `/var`, or enable `ostree-state-overlay@opt.service` (changes persist, but the next update overwrites them).
- `/usr/lib/ostree/prepare-root.conf` can set `root.transient` (writable `/` that resets at reboot) and `etc.transient` (`/etc` resets at reboot). Regenerate the initramfs after changing it.
- Never write to `/usr/etc`; it is ostree's internal copy of the image's default `/etc`. `systemd-sysext` and `systemd-confext` are not supported.
- During a container build the filesystem is fully writable; the rules above apply only once the image is deployed.

Sources: [Fedora Atomic Desktops filesystem layout](https://docs.fedoraproject.org/en-US/atomic-desktops/technical-information/#filesystem-layout), [ostree: adapting existing distributions](https://ostreedev.github.io/ostree/adapting-existing/), [ostree introduction](https://ostreedev.github.io/ostree/introduction/), [rpm-ostree administrator handbook](https://github.com/coreos/rpm-ostree/blob/main/docs/administrator-handbook.md), [bootc-filesystem(7)](https://bootc.dev/bootc/bootc-filesystem.7.html).

## Sandboxes

- **Flatpak:** the sandbox always sets `XDG_CONFIG_HOME=~/.var/app/<app-id>/config`, `XDG_DATA_HOME=~/.var/app/<app-id>/data`, `XDG_CACHE_HOME=~/.var/app/<app-id>/cache` and, from Flatpak 1.13, `XDG_STATE_HOME=~/.var/app/<app-id>/.local/state`, overriding host values. The host's values are available as `HOST_XDG_CONFIG_HOME` and the like. Apps that follow the spec work unchanged; apps with hardcoded `~/.config` do not. The app's own files live under `/app` inside the sandbox. Exported `.desktop` files and icons land in `~/.local/share/flatpak/exports/share` (user installs) or `/var/lib/flatpak/exports/share` (system installs), which the distribution adds to `XDG_DATA_DIRS`. Source: [Flatpak conventions](https://docs.flatpak.org/en/latest/conventions.html).
