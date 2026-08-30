#!/usr/bin/env python3

"""Read-only preflight check for a Linux host baseline.

Reports the Linux variant, deployment state, SELinux mode, and free space,
then exits 0 if the baseline is satisfiable or 1 if any blocker is present.

Features:
    - Standard library only, so it runs on a freshly imaged host with nothing
installed.
    - Never mutates system state.

Usage:
    python3 preflight.py
    python3 preflight.py --json
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

MIN_FREE_GIB = 5.0

# (name, is_blocker) — warnings inform, blockers stop the bootstrap.
BLOCKER = True
WARNING = False


def read_os_release() -> dict[str, str]:
    """Parse /etc/os-release into a dict. Returns {} if unreadable."""
    path = Path("/etc/os-release")
    if not path.is_file():
        return {}
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, raw = line.partition("=")
        values[key.strip()] = raw.strip().strip('"').strip("'")
    return values


def run(*argv: str) -> tuple[int, str]:
    """Run a command, returning (returncode, combined output).

    Returns (127, "") when the binary is absent, matching shell convention.
    """
    if shutil.which(argv[0]) is None:
        return 127, ""
    try:
        proc = subprocess.run(
            argv,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 1, str(exc)
    return proc.returncode, (proc.stdout + proc.stderr).strip()


def check_os_variant(report: dict) -> list[tuple[str, bool]]:
    os_release = read_os_release()
    variant = os_release.get("VARIANT_ID", "unknown")
    report["distro"] = os_release.get("NAME", "unknown")
    report["version_id"] = os_release.get("VERSION_ID", "unknown")
    report["variant_id"] = variant
    report["image_based"] = Path("/usr/bin/rpm-ostree").exists()

    if os_release.get("ID") != "fedora":
        return [(f"not a Fedora host (ID={os_release.get('ID')!r})", BLOCKER)]
    if variant not in {"silverblue", "iot", "server", "workstation", "coreos"}:
        return [(f"unrecognized VARIANT_ID {variant!r}; verify manually", WARNING)]
    return []


def check_selinux_status(report: dict) -> list[tuple[str, bool]]:
    code, out = run("getenforce")
    mode = out if code == 0 else "unknown"
    report["selinux"] = mode
    if mode == "Enforcing":
        return []
    if mode == "unknown":
        return [("could not determine SELinux mode", WARNING)]
    return [(f"SELinux is {mode}, expected Enforcing", BLOCKER)]


def check_rootfs_usage(report: dict) -> list[tuple[str, bool]]:
    usage = shutil.disk_usage("/")
    free_gib = usage.free / (1024**3)
    report["free_gib_root"] = round(free_gib, 2)
    if free_gib < MIN_FREE_GIB:
        return [
            (f"only {free_gib:.1f} GiB free on /, need {MIN_FREE_GIB:.0f} GiB", BLOCKER)
        ]
    return []


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--json", action="store_true", help="emit machine-readable JSON"
    )
    args = parser.parse_args()

    report: dict = {}
    findings: list[tuple[str, bool]] = []
    for check in (check_os_variant, check_selinux_status, check_rootfs_usage):
        findings.extend(check(report))

    blockers = [msg for msg, is_blocker in findings if is_blocker]
    warnings = [msg for msg, is_blocker in findings if not is_blocker]
    report["blockers"] = blockers
    report["warnings"] = warnings
    report["ok"] = not blockers

    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print(f"{report['distro']} {report['version_id']} ({report['variant_id']})")
        print(f"  image-based:  {report['image_based']}")
        print(f"  selinux:      {report['selinux']}")
        print(f"  free on /:    {report['free_gib_root']} GiB")
        if report["pending_deployment"] is not None:
            print(f"  pending depl: {report['pending_deployment']}")
        for msg in warnings:
            print(f"  WARN     {msg}")
        for msg in blockers:
            print(f"  BLOCKER  {msg}")
        print("  OK" if report["ok"] else "  NOT READY")

    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
