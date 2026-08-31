---
name: bubblewrap
description: >
  Use this skill when the user wants to sandbox, isolate, or restrict an
  application using bubblewrap (bwrap). Trigger on mentions of "bwrap",
  "bubblewrap", "sandbox a process", "sandbox an application", "isolate
  an app", "unprivileged sandbox", "namespace isolation", "restrict
  filesystem access", or when the user wants to run untrusted code, limit
  what a program can see on the filesystem, create a minimal chroot-like
  environment without root, or write wrapper scripts that confine
  applications. Also trigger when the user asks about Flatpak's
  sandboxing internals, since Flatpak uses bwrap under the hood.
  Do NOT trigger for Docker, Podman, systemd-nspawn, Firejail, or
  toolbox/distrobox questions unless bwrap is explicitly mentioned.
compatibility: >
  Requires Linux with user namespace support (CONFIG_USER_NS=y).
  Package: bubblewrap (Fedora/Arch/Debian) or bubblewrap-suid
  (hardened kernels). bwrap binary must be in PATH.
metadata:
  author: user
  version: "1.0"
  sources:
    - https://github.com/containers/bubblewrap
    - https://wiki.archlinux.org/title/Bubblewrap
    - https://sloonz.github.io/posts/sandboxing-1/
---

# Bubblewrap (bwrap)

Bubblewrap is a low-level, unprivileged sandboxing tool. It creates an
empty filesystem namespace on a tmpfs root, then lets you construct the
sandbox's view of the world entirely through command-line options. Think
of it as building a room from scratch: you start with bare walls (empty
namespace) and bolt in only the doors and windows (bind mounts) you
choose. Nothing is visible unless you explicitly mount it.

Flatpak, GNOME, sandwine, and many ad-hoc scripts use bwrap internally.

## Mental model

bwrap does two things:

1. Creates Linux **namespaces** (mount, pid, net, ipc, uts, user, cgroup)
   to isolate the process from the host.
2. Constructs a **virtual filesystem** inside the mount namespace via
   bind mounts, tmpfs, symlinks, and overlays.

The sandboxed process sees only what you explicitly provide. There is no
default policy -- bwrap is a toolkit, not an opinionated framework.

## Core option reference

Options are processed **in order**. Later mounts can overlay earlier ones.
This ordering matters: `--tmpfs $HOME` then `--ro-bind $HOME/.config $HOME/.config`
gives a tmpfs home with only `.config` visible read-only inside it.

### Filesystem construction

```
--bind SRC DEST          # Read-write bind mount
--ro-bind SRC DEST       # Read-only bind mount
--dev-bind SRC DEST      # Bind mount allowing device access
--tmpfs DEST             # Fresh tmpfs
--dir DEST               # Create empty directory
--symlink SRC DEST       # Symlink (e.g. --symlink usr/lib /lib64)
--proc DEST              # Mount procfs
--dev DEST               # Mount devtmpfs (console, null, zero, random, etc.)
--overlay-src SRC        # Add overlay lower layer (precedes --overlay/--ro-overlay)
--overlay RW WORK DEST   # Writable overlayfs
--ro-overlay DEST        # Read-only overlayfs (needs 2+ --overlay-src)
--tmp-overlay DEST       # Overlayfs with writes going to sandbox tmpfs
--remount-ro DEST        # Remount existing mount read-only
--perms OCTAL            # Set permissions on next --tmpfs/--dir/--file
--size BYTES             # Set max size on next --tmpfs
--chmod OCTAL PATH       # Change permissions of existing path
--file FD DEST           # Copy fd content to file at DEST (mode 0666)
--bind-data FD DEST      # Copy fd content, bind-mount at DEST (mode 0600)
--ro-bind-data FD DEST   # Same as above but read-only
```

`--bind-try`, `--ro-bind-try`, `--dev-bind-try` variants silently skip
if SRC does not exist. Useful for optional paths like `/etc/localtime`.

### Namespace isolation

```
--unshare-user           # New user namespace
--unshare-pid            # New PID namespace (sandbox gets its own pid 1)
--unshare-net            # New network namespace (no network by default)
--unshare-ipc            # New IPC namespace
--unshare-uts            # New UTS namespace (needed for --hostname)
--unshare-cgroup         # New cgroup namespace
--unshare-all            # All of the above (uses -try variants where needed)
--share-net              # Re-enable network after --unshare-all
--disable-userns         # Prevent sandbox from creating nested user namespaces
```

### Identity and environment

```
--uid UID                # Custom UID inside sandbox (needs --unshare-user)
--gid GID                # Custom GID inside sandbox (needs --unshare-user)
--hostname NAME          # Custom hostname (needs --unshare-uts)
--chdir DIR              # Working directory inside sandbox
--setenv VAR VALUE       # Set environment variable
--unsetenv VAR           # Unset environment variable
--clearenv               # Wipe all env vars except PWD and subsequent --setenv
```

### Security hardening

```
--new-session            # setsid() -- prevents TIOCSTI terminal injection (CVE-2017-5226)
--die-with-parent        # SIGKILL sandbox when parent dies
--seccomp FD             # Load compiled seccomp-bpf rules from fd
--add-seccomp-fd FD      # Stack multiple seccomp filters
--cap-add CAP            # Add capability (privileged only)
--cap-drop CAP           # Drop capability (ALL to drop everything, which is the default)
```

### Monitoring

```
--info-fd FD             # Write sandbox info JSON to fd
--json-status-fd FD      # Write child-pid and exit-code JSON lines to fd
--lock-file DEST         # Hold lock while sandbox runs
--sync-fd FD             # Keep fd open while sandbox runs
--block-fd FD            # Block sandbox start until fd has data
```

## Building a sandbox step by step

Start permissive, then tighten. The workflow:

### Step 1: No-op baseline

Bind the entire host read-only to confirm the app runs at all:

```bash
bwrap \
  --ro-bind / / \
  --dev /dev \
  --proc /proc \
  /usr/bin/myapp
```

### Step 2: Minimal filesystem

Replace the full bind with only what the app needs. Use `strace` to
discover required paths:

```bash
strace -e trace=open,openat,stat,access -f bwrap \
  --ro-bind / / \
  /usr/bin/myapp 2>&1 | grep -v ENOENT
```

Then build a targeted mount set:

```bash
bwrap \
  --ro-bind /usr /usr \
  --symlink usr/bin /bin \
  --symlink usr/sbin /sbin \
  --symlink usr/lib /lib \
  --symlink usr/lib64 /lib64 \
  --ro-bind /etc /etc \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  --tmpfs /var \
  /usr/bin/myapp
```

On merged-usr distros (Fedora, recent Arch, Debian 12+), `/bin`,
`/lib`, `/lib64`, `/sbin` are already symlinks into `/usr`. Create
matching symlinks inside the sandbox.

### Step 3: Isolate namespaces

```bash
bwrap \
  --ro-bind /usr /usr \
  --symlink usr/bin /bin \
  --symlink usr/sbin /sbin \
  --symlink usr/lib /lib \
  --symlink usr/lib64 /lib64 \
  --ro-bind /etc /etc \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  --tmpfs /var \
  --unshare-all \
  --share-net \
  --new-session \
  --die-with-parent \
  /usr/bin/myapp
```

Drop `--share-net` if the app doesn't need network access.

### Step 4: Handle the home directory

Three strategies:

```bash
# A) No home at all (app has no access to user data)
# Simply don't bind $HOME -- it won't exist in the sandbox.

# B) Tmpfs home (app can write but nothing persists)
--tmpfs "$HOME"

# C) Dedicated persistent home (app sees a separate directory as $HOME)
--bind "$HOME/sandboxes/myapp" "$HOME"

# D) Read-only home with specific writable dirs
--tmpfs "$HOME" \
--ro-bind "$HOME/.config/myapp" "$HOME/.config/myapp" \
--bind "$HOME/Documents" "$HOME/Documents"
```

### Step 5: Desktop integration (GUI apps)

For Wayland:
```bash
--ro-bind "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" \
--setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY" \
--setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR"
```

For X11 (note: X11 socket forwarding is NOT a security boundary --
any X11 client can keylog other clients. Use Xephyr or xpra for real
isolation):
```bash
--ro-bind /tmp/.X11-unix/X0 /tmp/.X11-unix/X0 \
--ro-bind "$HOME/.Xauthority" "$HOME/.Xauthority" \
--setenv DISPLAY "$DISPLAY"
```

For PulseAudio:
```bash
--ro-bind "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse"
```

For PipeWire:
```bash
--ro-bind "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0"
```

For D-Bus (use xdg-dbus-proxy to filter, raw socket = sandbox escape):
```bash
# Filtered D-Bus (recommended)
xdg-dbus-proxy "$DBUS_SESSION_BUS_ADDRESS" /run/user/$UID/bus-proxy \
  --filter --talk=org.freedesktop.Notifications &
PROXY_PID=$!
bwrap ... \
  --ro-bind /run/user/$UID/bus-proxy /run/user/$UID/bus \
  --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=/run/user/$UID/bus" \
  /usr/bin/myapp
kill $PROXY_PID
```

### Step 6: GPU access (for OpenGL/Vulkan)

```bash
--dev-bind /dev/dri /dev/dri \
--ro-bind /sys/dev/char /sys/dev/char \
--ro-bind /sys/devices/pci0000:00 /sys/devices/pci0000:00
```

## Wrapper script pattern

The standard approach is a shell script that replaces or wraps the
real binary:

```bash
#!/bin/sh
# ~/.local/bin/myapp-sandboxed
exec bwrap \
  --ro-bind /usr /usr \
  --symlink usr/bin /bin \
  --symlink usr/sbin /sbin \
  --symlink usr/lib /lib \
  --symlink usr/lib64 /lib64 \
  --ro-bind /etc /etc \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  --tmpfs /var \
  --dir /run --dir "/run/user/$(id -u)" \
  --tmpfs "$HOME" \
  --unshare-all \
  --share-net \
  --new-session \
  --die-with-parent \
  --clearenv \
  --setenv HOME "$HOME" \
  --setenv USER "$USER" \
  --setenv PATH "/usr/bin:/usr/sbin" \
  --setenv TERM "$TERM" \
  /usr/bin/myapp "$@"
```

For detailed reference on specific desktop app sandboxing (Transmission,
MuPDF, Steam, browsers), see `references/app-examples.md`.

## Gotchas

- **Order matters.** `--tmpfs $HOME --ro-bind $HOME/.config $HOME/.config`
  works. Reverse the order and `.config` is hidden by the tmpfs.
- **--new-session breaks shell job control.** The `bg`, `fg`, and `Ctrl-Z`
  won't work for processes launched with `--new-session`. This is a
  trade-off for TIOCSTI protection. Always use it unless you have a
  specific reason not to (and then use seccomp to block TIOCSTI instead).
- **--unshare-net creates a namespace with only loopback.** The app gets
  no network at all unless you `--share-net`.
- **Merged-usr symlinks.** On Fedora/Arch/Debian 12+, you need
  `--symlink usr/bin /bin` etc. or programs that reference `/bin/sh` will
  fail. Don't bind `/bin` directly -- it's already a symlink on the host.
- **D-Bus = sandbox escape.** Binding the session bus socket directly
  lets the sandbox call arbitrary D-Bus methods (including systemd's
  `StartTransientUnit`). Use xdg-dbus-proxy with `--filter`.
- **X11 = sandbox escape.** Any X11 client can read keystrokes from
  any other. Use Wayland, Xephyr, or xpra for real GUI isolation.
- **Files owned by root appear as nobody.** When `--unshare-user` is
  active, UIDs/GIDs outside your mapping show as `nobody:nogroup`.
  This is cosmetic but may confuse apps that check ownership.
- **sudo/su won't work inside the sandbox.** The user namespace maps
  only your UID/GID. Privileged operations are not possible by design.
- **Chromium/Firefox nested sandboxes.** These browsers have their own
  seccomp sandboxing. Inside bwrap, the nested sandbox may fail.
  Pass `--disable-gpu-sandbox` or set environment variables like
  `CHROME_FLAGS="--no-sandbox"` for the inner layer. The outer bwrap
  sandbox still provides confinement.
- **strace is your best friend.** When an app fails silently, run it
  under `strace -e trace=open,openat,stat,access -f` to see which
  files it's looking for and can't find.
- **`--die-with-parent` uses PDEATHSIG.** It fires SIGKILL when the
  direct parent of bwrap dies. If bwrap is started from a subshell or
  pipeline, the "parent" may not be what you expect.
