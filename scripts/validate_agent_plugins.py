#!/usr/bin/env python3

"""Validate an Agent Plugins 1.0.0 package.

Checks the portable core (plugin.json, skills/, mcp.json) against the published
schema rules, and additionally lints the dev.kiro/ client extension: steering
front matter, inclusion modes, and required fields per mode.

Standard library only. Runs offline — the manifest rules are encoded here rather
than fetched, so CI does not depend on network access.

    python3 tools/validate_plugin.py
    python3 tools/validate_plugin.py --path ./fedora-ops
    python3 tools/validate_plugin.py --strict     # warnings become failures

Exit codes: 0 clean, 1 errors found, 2 could not run.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SCHEMA_URL = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"
MCP_SCHEMA_URL = "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json"

# From the published plugin.schema.json.
NAME_RE = re.compile(r"^(?!.*(?:--|\.\.))[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$")
MANIFEST_KEYS = {
    "$schema",
    "name",
    "version",
    "description",
    "author",
    "homepage",
    "repository",
    "license",
    "keywords",
    "extensions",
}
AUTHOR_KEYS = {"name", "email", "url"}

# Keys some clients accept at the manifest top level but the spec does not.
FORBIDDEN_TOP_LEVEL = {"hooks", "agents", "skills", "mcpServers", "commands", "lsp"}

MCP_TRANSPORTS = {"stdio", "streamable-http", "sse"}

# Kiro steering inclusion modes, per kiro.dev/docs/steering.
INCLUSION_MODES = {"always", "auto", "fileMatch", "manual"}

EXTENSION_NS_RE = re.compile(r"^[a-z0-9]+(\.[a-z0-9-]+)+$")


class Report:
    """Collects errors and warnings and prints them grouped by file."""

    def __init__(self) -> None:
        self.errors: list[tuple[str, str]] = []
        self.warnings: list[tuple[str, str]] = []

    def error(self, where: str, message: str) -> None:
        self.errors.append((where, message))

    def warn(self, where: str, message: str) -> None:
        self.warnings.append((where, message))

    def emit(self, strict: bool) -> int:
        for where, message in self.warnings:
            print(f"WARN   {where}: {message}")
        for where, message in self.errors:
            print(f"ERROR  {where}: {message}")

        n_err, n_warn = len(self.errors), len(self.warnings)
        if not n_err and not n_warn:
            print("OK     plugin is valid")
            return 0
        print(f"\n{n_err} error(s), {n_warn} warning(s)")
        if n_err or (strict and n_warn):
            return 1
        return 0


def load_json(path: Path, report: Report) -> dict | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        report.error(path.name, f"invalid JSON: {exc}")
    except OSError as exc:
        report.error(path.name, f"unreadable: {exc}")
    return None


def parse_front_matter(text: str) -> tuple[dict[str, object] | None, str]:
    """Extract YAML front matter without a YAML dependency.

    Handles the subset the spec and Kiro use: scalars, and block or flow
    sequences of scalars. Returns (mapping, error_message).
    """
    if not text.startswith("---"):
        return None, "missing front matter (file must begin with ---)"

    lines = text.splitlines()
    try:
        end = next(i for i in range(1, len(lines)) if lines[i].strip() == "---")
    except StopIteration:
        return None, "front matter is not terminated by a closing ---"

    data: dict[str, object] = {}
    current_key: str | None = None
    for raw in lines[1:end]:
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue

        if raw.lstrip().startswith("- ") and current_key:
            item = raw.lstrip()[2:].strip().strip("\"'")
            bucket = data.setdefault(current_key, [])
            if isinstance(bucket, list):
                bucket.append(item)
            continue

        if ":" not in raw:
            continue
        key, _, value = raw.partition(":")
        key, value = key.strip(), value.strip()
        if not value:
            data[key] = []
            current_key = key
            continue
        if value.startswith("[") and value.endswith("]"):
            inner = value[1:-1].strip()
            data[key] = [
                v.strip().strip("\"'") for v in inner.split(",") if v.strip()
            ] if inner else []
        else:
            data[key] = value.strip("\"'")
        current_key = None

    return data, ""


def check_manifest(root: Path, report: Report) -> None:
    path = root / "plugin.json"
    where = "plugin.json"
    if not path.is_file():
        report.error(where, "missing — every Agent Plugin requires it at the root")
        return

    data = load_json(path, report)
    if data is None:
        return

    if data.get("$schema") != SCHEMA_URL:
        report.error(where, f"$schema must be exactly {SCHEMA_URL}")

    name = data.get("name")
    if not isinstance(name, str) or not name:
        report.error(where, "name is required and must be a non-empty string")
    else:
        if not NAME_RE.match(name):
            report.error(
                where,
                f"name {name!r} is invalid: lowercase alphanumerics, dots and "
                "hyphens only, no leading/trailing separator, no '--' or '..'",
            )
        if len(name) > 64:
            report.error(where, "name exceeds 64 characters")
        if name != root.name:
            report.warn(
                where,
                f"name {name!r} differs from directory {root.name!r}; harmless "
                "but confusing for anyone installing from a local path",
            )

    unknown = set(data) - MANIFEST_KEYS
    for key in sorted(unknown):
        if key in FORBIDDEN_TOP_LEVEL:
            report.error(
                where,
                f"{key!r} is a client-specific field and is not permitted at the "
                "manifest top level; move it under extensions.<namespace>",
            )
        else:
            report.error(
                where,
                f"unknown key {key!r} (manifest schema sets additionalProperties: false)",
            )

    author = data.get("author")
    if author is not None:
        if not isinstance(author, dict):
            report.error(where, "author must be an object")
        else:
            for key in sorted(set(author) - AUTHOR_KEYS):
                report.error(where, f"author.{key} is not an allowed field")
            if "name" not in author:
                report.warn(where, "author.name is expected by Kiro's power registry")

    if isinstance(data.get("keywords"), list):
        if not data["keywords"]:
            report.warn(where, "keywords is empty; Kiro uses it for activation")
    elif "keywords" in data:
        report.error(where, "keywords must be an array of strings")
    else:
        report.warn(where, "no keywords; the power will not activate by keyword in Kiro")

    extensions = data.get("extensions")
    if extensions is not None:
        if not isinstance(extensions, dict):
            report.error(where, "extensions must be an object")
        else:
            for ns, value in extensions.items():
                if not EXTENSION_NS_RE.match(ns):
                    report.error(
                        where,
                        f"extension namespace {ns!r} is not reverse-domain form",
                    )
                if not isinstance(value, dict):
                    report.error(where, f"extensions.{ns} must be an object")


def check_skills(root: Path, report: Report) -> int:
    skills_dir = root / "skills"
    if not skills_dir.is_dir():
        return 0

    count = 0
    for entry in sorted(skills_dir.iterdir()):
        if entry.name.startswith("."):
            continue
        if not entry.is_dir():
            report.warn(
                f"skills/{entry.name}",
                "only directories are discovered under skills/; this file is ignored",
            )
            continue

        skill_md = entry / "SKILL.md"
        where = f"skills/{entry.name}/SKILL.md"
        if not skill_md.is_file():
            report.error(f"skills/{entry.name}", "missing SKILL.md")
            continue

        count += 1
        front, err = parse_front_matter(skill_md.read_text(encoding="utf-8"))
        if front is None:
            report.error(where, err)
            continue

        name = front.get("name")
        if not name:
            report.error(where, "front matter is missing required field 'name'")
        elif name != entry.name:
            report.error(
                where,
                f"name {name!r} must match its directory {entry.name!r}",
            )
        elif isinstance(name, str) and not NAME_RE.match(name):
            report.error(where, f"name {name!r} violates the naming rules")

        description = front.get("description")
        if not description:
            report.error(where, "front matter is missing required field 'description'")
        elif isinstance(description, str) and len(description) < 30:
            report.warn(
                where,
                "description is very short; clients match it against user requests, "
                "so it should say both what the skill does and when to use it",
            )

        for sub in ("scripts", "references"):
            sub_path = entry / sub
            if sub_path.is_dir() and not any(sub_path.iterdir()):
                report.warn(f"skills/{entry.name}/{sub}", "directory is empty")

    return count


def check_mcp(root: Path, report: Report) -> None:
    path = root / "mcp.json"
    if not path.is_file():
        return

    where = "mcp.json"
    data = load_json(path, report)
    if data is None:
        return

    if data.get("$schema") != MCP_SCHEMA_URL:
        report.error(where, f"$schema must be exactly {MCP_SCHEMA_URL}")

    servers = data.get("mcpServers")
    if not isinstance(servers, dict) or not servers:
        report.error(where, "mcpServers must be a non-empty object")
        return

    for name, cfg in servers.items():
        loc = f"{where}:{name}"
        if not isinstance(cfg, dict):
            report.error(loc, "server config must be an object")
            continue

        transport = cfg.get("type")
        if transport not in MCP_TRANSPORTS:
            report.error(
                loc,
                f"type must be one of {sorted(MCP_TRANSPORTS)}; an explicit "
                "transport is required in v1.0.0",
            )
        if transport == "stdio" and not cfg.get("command"):
            report.error(loc, "stdio servers require 'command'")
        if transport in {"streamable-http", "sse"} and not cfg.get("url"):
            report.error(loc, f"{transport} servers require 'url'")

        for key, value in (cfg.get("env") or {}).items():
            if isinstance(value, str) and not value.startswith("${"):
                if any(
                    hint in key.upper()
                    for hint in ("KEY", "TOKEN", "SECRET", "PASSWORD")
                ):
                    report.error(
                        loc,
                        f"env.{key} looks like a literal secret; use ${{{key}}} "
                        "so the value comes from the environment",
                    )


def check_kiro_extension(root: Path, report: Report) -> int:
    ext_dir = root / "dev.kiro"
    if not ext_dir.is_dir():
        return 0

    steering_dir = ext_dir / "steering"
    if not steering_dir.is_dir():
        report.warn(
            "dev.kiro/",
            "extension directory exists but has no steering/ subdirectory",
        )
        return 0

    count = 0
    for md in sorted(steering_dir.glob("*.md")):
        where = f"dev.kiro/steering/{md.name}"
        count += 1
        text = md.read_text(encoding="utf-8")

        front, err = parse_front_matter(text)
        if front is None:
            report.warn(
                where,
                f"{err}; Kiro treats a steering file without front matter as "
                "inclusion: always",
            )
            continue

        mode = front.get("inclusion")
        if mode is None:
            report.warn(where, "no inclusion mode declared; defaults to 'always'")
            mode = "always"
        elif mode not in INCLUSION_MODES:
            report.error(
                where,
                f"inclusion {mode!r} is not one of {sorted(INCLUSION_MODES)}",
            )

        if mode == "fileMatch":
            patterns = front.get("fileMatchPattern")
            if not patterns:
                report.error(
                    where, "inclusion: fileMatch requires fileMatchPattern"
                )
        if mode == "auto":
            for field in ("name", "description"):
                if not front.get(field):
                    report.error(
                        where, f"inclusion: auto requires front matter field {field!r}"
                    )
            if front.get("name") and front["name"] != md.stem:
                report.warn(
                    where,
                    f"name {front['name']!r} differs from filename {md.stem!r}; "
                    "the slash command uses the name field",
                )
        if mode == "always":
            body = text.split("---", 2)[-1]
            if len(body) > 4000:
                report.warn(
                    where,
                    f"{len(body)} chars of always-on steering is charged against "
                    "every request; consider inclusion: auto or a skill",
                )

    return count


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--path",
        default=".",
        help="plugin root directory (default: current directory)",
    )
    parser.add_argument(
        "--strict", action="store_true", help="treat warnings as failures"
    )
    args = parser.parse_args()

    root = Path(args.path).resolve()
    if not root.is_dir():
        print(f"ERROR  {root} is not a directory", file=sys.stderr)
        return 2

    print(f"Validating {root}\n")
    report = Report()
    check_manifest(root, report)
    n_skills = check_skills(root, report)
    check_mcp(root, report)
    n_steering = check_kiro_extension(root, report)

    print(
        f"Found {n_skills} skill(s), "
        f"{n_steering} Kiro steering file(s), "
        f"mcp.json {'present' if (root / 'mcp.json').is_file() else 'absent'}\n"
    )
    return report.emit(args.strict)


if __name__ == "__main__":
    sys.exit(main())
