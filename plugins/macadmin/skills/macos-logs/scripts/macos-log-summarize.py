#!/usr/bin/env python3

"""Summarize Apple Unified Log output produced by ``log show --style ndjson``.

The unified log routinely returns tens of thousands of records for even a short
window. Reading them linearly is hopeless; this collapses them into "who is
talking, about what, and what is failing" so an investigation has a starting
point.

Usage
-----
    log show --last 1h --info --style ndjson | python3 macos-log-summarize.py
    python3 macos-log-summarize.py /tmp/window.ndjson --top 25
    python3 macos-log-summarize.py /tmp/window.ndjson --level error --json

Accepts newline-delimited JSON (``--style ndjson``) or a single JSON array
(``--style json``). Standard library only; no third-party dependencies.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass
from itertools import chain
from pathlib import Path
from typing import Any, Iterator, Sequence, TextIO

# Message levels that indicate something went wrong, lowercased for comparison.
PROBLEM_LEVELS = frozenset({"error", "fault"})
PatternKey = tuple[str, str, str]


@dataclass
class ParseStats:
    """Track input loss independently of message-level filtering."""

    skipped_records: int = 0
    failed_files: int = 0


# Substitutions applied in order to collapse variable parts of a message so that
# "connection 4821 failed" and "connection 4822 failed" count as one pattern.
NORMALIZERS: tuple[tuple[re.Pattern[str], str], ...] = (
    (
        re.compile(
            r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
            r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
        ),
        "<UUID>",
    ),
    (re.compile(r"\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b"), "<IP>"),
    (re.compile(r"0x[0-9a-fA-F]+"), "<HEX>"),
    (re.compile(r"/(?:[\w.\-+@]+/)+[\w.\-+@]*"), "<PATH>"),
    (re.compile(r"\b\d+\b"), "<N>"),
    (re.compile(r"\s+"), " "),
)


def normalize(message: str) -> str:
    """Collapse variable substrings so recurring messages group together."""
    text = message.strip()
    for pattern, replacement in NORMALIZERS:
        text = pattern.sub(replacement, text)
    return text[:160]


def iter_records(stream: TextIO, stats: ParseStats) -> Iterator[dict[str, Any]]:
    """Yield log records from an ndjson stream or a single JSON array."""
    first = stream.read(1)
    while first and first.isspace():
        first = stream.read(1)
    if not first:
        return
    if first == "[":
        payload = json.loads(first + stream.read())
        for record in payload:
            if isinstance(record, dict):
                yield record
            else:
                stats.skipped_records += 1
        return
    for line in chain([first + stream.readline()], stream):
        line = line.strip()
        if not line:
            continue
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            stats.skipped_records += 1
            continue
        if isinstance(record, dict):
            # Native log show ends NDJSON output with a completion marker,
            # including when no events matched. It is not a log record.
            if record.get("finished") == 1 and record.keys() <= {"count", "finished"}:
                continue
            yield record
        else:
            stats.skipped_records += 1


def process_name(record: dict[str, Any]) -> str:
    """Best-effort process name; ``log`` populates these fields inconsistently."""
    name = record.get("process")
    if not name:
        image = record.get("processImagePath") or ""
        name = Path(image).name if image else ""
    return name or "<unknown>"


def level_of(record: dict[str, Any]) -> str:
    return str(record.get("messageType") or "Default").lower()


def summarize(
    records: Iterator[dict[str, Any]],
    level_filter: str | None = None,
) -> dict[str, Any]:
    """Build counters over the record stream in a single pass."""
    processes: Counter[str] = Counter()
    subsystems: Counter[str] = Counter()
    levels: Counter[str] = Counter()
    problem_patterns: Counter[PatternKey] = Counter()
    problem_examples: dict[PatternKey, dict[str, str]] = {}
    total = 0
    first_ts: str | None = None
    last_ts: str | None = None

    for record in records:
        level = level_of(record)
        if level_filter and level != level_filter:
            continue
        total += 1

        timestamp = record.get("timestamp")
        if isinstance(timestamp, str):
            if first_ts is None:
                first_ts = timestamp
            last_ts = timestamp

        levels[level] += 1
        processes[process_name(record)] += 1
        subsystem = record.get("subsystem")
        if subsystem:
            subsystems[str(subsystem)] += 1

        if level in PROBLEM_LEVELS:
            message = str(record.get("eventMessage") or "")
            if message:
                pattern = normalize(message)
                key = (process_name(record), str(subsystem or ""), pattern)
                problem_patterns[key] += 1
                problem_examples.setdefault(
                    key,
                    {
                        "process": process_name(record),
                        "subsystem": str(subsystem or ""),
                        "message": message[:300],
                        "timestamp": str(timestamp or ""),
                    },
                )

    return {
        "total_records": total,
        "time_range": {"first": first_ts, "last": last_ts},
        "levels": dict(levels.most_common()),
        "processes": processes,
        "subsystems": subsystems,
        "problem_patterns": problem_patterns,
        "problem_examples": problem_examples,
    }


def render_table(title: str, counter: Counter[str], top: int, total: int) -> list[str]:
    if not counter:
        return [f"{title}: none"]
    lines = [title, "-" * len(title)]
    width = max((len(name) for name, _ in counter.most_common(top)), default=10)
    for name, count in counter.most_common(top):
        share = (count / total * 100) if total else 0.0
        lines.append(f"  {name:<{width}}  {count:>7,}  {share:5.1f}%")
    return lines


def render(summary: dict[str, Any], top: int) -> str:
    total = int(summary["total_records"])
    out: list[str] = []
    out.append("=" * 72)
    out.append("Apple Unified Log summary")
    out.append("=" * 72)
    out.append(f"Records analyzed : {total:,}")
    time_range = summary["time_range"]
    if time_range["first"]:
        out.append(f"First record     : {time_range['first']}")
        out.append(f"Last record      : {time_range['last']}")
    if summary["levels"]:
        breakdown = "  ".join(f"{k}={v:,}" for k, v in summary["levels"].items())
        out.append(f"Message levels   : {breakdown}")
    out.append("")

    out.extend(render_table("Top processes", summary["processes"], top, total))
    out.append("")
    out.extend(render_table("Top subsystems", summary["subsystems"], top, total))
    out.append("")

    patterns: Counter[PatternKey] = summary["problem_patterns"]
    examples: dict[PatternKey, dict[str, str]] = summary["problem_examples"]
    heading = "Recurring error and fault messages"
    out.append(heading)
    out.append("-" * len(heading))
    if not patterns:
        out.append("  none")
    else:
        for key, count in patterns.most_common(top):
            process, subsystem, pattern = key
            example = examples.get(key, {})
            source = f"{process} [{subsystem}]" if subsystem else process
            out.append(f"  [{count:>5,}x] {source}")
            out.append(f"          {pattern}")
            sample = example.get("message", "")
            if sample and sample.rstrip() != pattern.rstrip():
                out.append(f"          e.g. {sample}")
    out.append("")
    return "\n".join(out)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Summarize 'log show --style ndjson' output.",
    )
    parser.add_argument(
        "files",
        nargs="*",
        help="ndjson files to read; reads standard input when omitted.",
    )
    parser.add_argument(
        "--top",
        type=int,
        default=15,
        help="Entries per section (default: 15).",
    )
    parser.add_argument(
        "--level",
        choices=["default", "info", "debug", "error", "fault"],
        help="Restrict the summary to a single message level.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON instead of a report.",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.top < 1:
        parser.error("--top must be a positive integer")
    stats = ParseStats()

    def all_records() -> Iterator[dict[str, Any]]:
        if not args.files:
            try:
                yield from iter_records(sys.stdin, stats)
            except (OSError, UnicodeError, json.JSONDecodeError) as error:
                stats.failed_files += 1
                print(f"warning: cannot parse stdin: {error}", file=sys.stderr)
            return
        for name in args.files:
            path = Path(name)
            try:
                with path.open("r", encoding="utf-8") as handle:
                    yield from iter_records(handle, stats)
            except (OSError, UnicodeError, json.JSONDecodeError) as error:
                stats.failed_files += 1
                print(f"warning: cannot read {path}: {error}", file=sys.stderr)

    summary = summarize(all_records(), level_filter=args.level)
    if stats.skipped_records:
        print(
            f"warning: skipped {stats.skipped_records} malformed or non-object records; "
            "summary is incomplete",
            file=sys.stderr,
        )

    if summary["total_records"] == 0:
        print(
            "No records parsed. Confirm the input came from 'log show --style ndjson' "
            "and that the query returned results (try adding --info).",
            file=sys.stderr,
        )
        return 1

    if args.json:
        payload = {
            "total_records": summary["total_records"],
            "skipped_records": stats.skipped_records,
            "failed_files": stats.failed_files,
            "time_range": summary["time_range"],
            "levels": summary["levels"],
            "top_processes": summary["processes"].most_common(args.top),
            "top_subsystems": summary["subsystems"].most_common(args.top),
            "problem_patterns": [
                {
                    "process": key[0],
                    "subsystem": key[1],
                    "pattern": key[2],
                    "count": count,
                    "example": summary["problem_examples"].get(key, {}),
                }
                for key, count in summary["problem_patterns"].most_common(args.top)
            ],
        }
        print(json.dumps(payload, indent=2))
    else:
        print(render(summary, args.top))
    return 1 if stats.skipped_records or stats.failed_files else 0


if __name__ == "__main__":
    # Output is routinely piped into head/less. Restore the default SIGPIPE
    # behaviour so the process exits quietly instead of raising BrokenPipeError.
    try:
        import signal

        signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    except (ImportError, AttributeError, ValueError):  # pragma: no cover
        pass
    sys.exit(main())
