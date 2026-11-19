#!/usr/bin/env python3
"""Add the mise SessionStart hook to a Claude Code settings.json.

The hook appends ``eval "$(mise hook-env -s <shell>)"`` to the file named by
``$CLAUDE_ENV_FILE``, which Claude Code sources before each Bash command. The
agent's non-interactive shell then gets the project's mise tools and ``[env]``
without wrapping every command in ``mise exec --``.

The script is idempotent, keeps every other key in the file, and writes a
``.bak`` copy before it changes an existing file. Standard library only.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any

MARKER = "mise hook-env"


def build_command(mise_bin: str, shell: str) -> str:
    """Return the hook command for one shell."""
    line = f'eval "$({mise_bin} hook-env -s {shell})"'
    return f'[ -n "$CLAUDE_ENV_FILE" ] && echo \'{line}\' >> "$CLAUDE_ENV_FILE"; true'


def load_settings(path: Path) -> dict[str, Any]:
    """Read settings.json, returning an empty mapping when it does not exist."""
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        msg = f"{path} is not valid JSON: {exc}"
        raise SystemExit(msg) from exc
    if not isinstance(data, dict):
        msg = f"{path} must contain a JSON object"
        raise SystemExit(msg)
    return data


def has_mise_hook(settings: dict[str, Any]) -> bool:
    """Report whether a SessionStart hook already runs mise hook-env."""
    hooks = settings.get("hooks")
    if not isinstance(hooks, dict):
        return False
    groups = hooks.get("SessionStart")
    if not isinstance(groups, list):
        return False
    for group in groups:
        if not isinstance(group, dict):
            continue
        for hook in group.get("hooks", []):
            if isinstance(hook, dict) and MARKER in str(hook.get("command", "")):
                return True
    return False


def add_hook(settings: dict[str, Any], command: str) -> dict[str, Any]:
    """Return settings with the mise SessionStart hook appended."""
    hooks = settings.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        msg = '"hooks" must be a JSON object'
        raise SystemExit(msg)
    groups = hooks.setdefault("SessionStart", [])
    if not isinstance(groups, list):
        msg = '"hooks.SessionStart" must be a JSON array'
        raise SystemExit(msg)
    groups.append({"hooks": [{"type": "command", "command": command}]})
    return settings


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse the command line."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument(
        "--project",
        type=Path,
        metavar="DIR",
        help="write DIR/.claude/settings.json (default: the current directory)",
    )
    scope.add_argument(
        "--user",
        action="store_true",
        help="write ~/.claude/settings.json instead of a project file",
    )
    parser.add_argument(
        "--shell",
        choices=("bash", "zsh"),
        default="bash",
        help="shell Claude Code runs commands in (default: bash)",
    )
    parser.add_argument(
        "--mise-bin",
        default="mise",
        metavar="PATH",
        help="mise executable; use an absolute path if mise is not on the agent's PATH",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="print the result and write nothing"
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the command line interface."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    base = Path.home() if args.user else (args.project or Path.cwd())
    path = base / ".claude" / "settings.json"

    settings = load_settings(path)
    if has_mise_hook(settings):
        print(f"already configured: {path}", file=sys.stderr)
        return 0

    settings = add_hook(settings, build_command(args.mise_bin, args.shell))
    text = json.dumps(settings, indent=2) + "\n"
    if args.dry_run:
        print(f"would write {path}:", file=sys.stderr)
        sys.stdout.write(text)
        return 0

    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        shutil.copy2(path, path.with_name(path.name + ".bak"))
    path.write_text(text, encoding="utf-8")
    print(f"wrote {path}; restart the Claude Code session to load it", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
