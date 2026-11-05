#!/usr/bin/env python3

"""devibe_scan.py - scan a web codebase for "vibe-coded" / AI-generated design tells.

Plain Python, standard library only. Detection patterns and their severity come from a
Reddit analysis (~3.2M posts / 3,033 on-topic comments across 47 subreddits) of what
people actually flag as making a site look AI-generated. Severity follows how often each
tell is named in that data, so the report tells you where to spend effort.

Usage:
    python3 devibe_scan.py <path>                 # scan a dir or file
    python3 devibe_scan.py <path> --severity high # only high-signal tells
    python3 devibe_scan.py <path> --json          # machine-readable (for CI)
    python3 devibe_scan.py <path> --max 8         # cap examples shown per rule

Exit code is the number of HIGH-severity findings (0 = none), so CI can gate on it.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING, TypedDict

if TYPE_CHECKING:
    from collections.abc import Iterator

EXTS = {
    ".html", ".htm", ".css", ".scss", ".sass", ".less", ".js", ".jsx",
    ".ts", ".tsx", ".vue", ".svelte", ".astro", ".mdx",
}  # fmt: skip

SKIP_DIRS = {
    "node_modules", ".git", "dist", "build", ".next", "out", "vendor",
    "coverage", ".svelte-kit", ".astro", ".turbo", ".cache", "__pycache__",
}  # fmt: skip

W = {"high": 3, "medium": 2, "low": 1}
SEV_ORDER = ["high", "medium", "low"]

MINIFIED_LINE_LEN = 5000  # a single line longer than this is treated as minified
SNIPPET_LEN = 160

# verdict() thresholds: (high-severity count, weighted score)
STRONG_HIGH, STRONG_SCORE = 3, 15
SOME_HIGH, SOME_SCORE = 1, 6


class _RuleBase(TypedDict):
    id: str
    label: str
    sev: str
    fix: str
    pats: list[str]


class Rule(_RuleBase, total=False):
    """A detection rule; `suppress` skips lines that match it."""

    suppress: str


class Finding(TypedDict):
    """One matched line. Keys are the --json output schema."""

    rule: str
    label: str
    sev: str
    fix: str
    file: str
    line: int
    snippet: str


@dataclass(frozen=True)
class CompiledRule:
    """A rule with its patterns compiled."""

    rule: Rule
    rx: list[re.Pattern[str]]
    suppress_rx: re.Pattern[str] | None


# Each rule: id, label, severity, fix, and patterns (compiled case-insensitive).
# Keep patterns specific enough to avoid drowning the report in false positives.
RULES: list[Rule] = [
    # ---- HIGH: the top concrete tells ----
    {
        "id": "shadcn-default-card",
        "label": "Untouched shadcn default Card / theme",
        "sev": "high",
        "fix": "Theme the tokens (primary, radius, neutrals, spacing). "
        "Stock defaults are the giveaway, not shadcn.",
        "pats": [
            r"rounded-lg\s+border\s+bg-card\s+text-card-foreground\s+shadow-sm",
            r"\"baseColor\"\s*:\s*\"(slate|zinc|gray|neutral|stone)\"",
            r"--radius\s*:\s*0\.5rem",
        ],
    },
    {
        "id": "ai-purple",
        "label": "AI purple / indigo / violet as primary color",
        "sev": "high",
        "fix": "Pick a brand color outside the violet/indigo/purple band. "
        "It is Tailwind's default, so it reads as 'nobody chose this'.",
        "pats": [
            r"\b(bg|text|from|via|to|border|ring|fill|stroke|decoration|outline)-"
            r"(indigo|violet|purple|fuchsia)-(400|500|600|700|800)\b",
            r"#(6366f1|4f46e5|818cf8|7c3aed|6d28d9|8b5cf6|a855f7|9333ea|7e22ce|c026d3|d946ef)\b",
        ],
    },
    {
        "id": "gradient-text",
        "label": "Gradient-filled text (heading/hero)",
        "sev": "high",
        "fix": "Solid color on headings and copy. "
        "Gradient body text is one of the strongest AI tells.",
        "pats": [
            r"bg-clip-text\s+[^\"'`]*text-transparent",
            r"text-transparent\s+[^\"'`]*bg-clip-text",
            r"-webkit-background-clip\s*:\s*text",
            r"\bbackground-clip\s*:\s*text",
        ],
    },
    {
        "id": "purple-blue-gradient",
        "label": "Purple-to-blue/pink gradient",
        "sev": "high",
        "fix": "Default to solid fills. If you must gradient, keep stops analogous and "
        "low-contrast, never the rainbow purple-to-blue.",
        "pats": [
            r"from-(purple|violet|indigo|fuchsia)-\d+\s+(via-[a-z]+-\d+\s+)?"
            r"to-(blue|indigo|pink|cyan|sky)-\d+",
            r"linear-gradient\([^)]*#(6366f1|7c3aed|8b5cf6|a855f7)[^)]*\)",
        ],
    },
    {
        "id": "claude-default-look",
        "label": "The 'tasteful default' look (cream background + serif display)",
        "sev": "high",
        "fix": "This is the 2026 tell, not the fix. Anchor color and type to the real brand "
        "or a reference. If cream + serif is a genuine decision, mark the line unslop-ignore.",
        "pats": [
            r"#(faf8f5|f5f1e8|f3eee3|fdfbf7|f7f3ec|faf6ef|f6f1e7|fbf7f0|f4efe4)\b",
            r"\bbg-(stone|amber|orange)-(50|100)\b",
            r"\b(Instrument\s*Serif|Fraunces|Playfair\s*Display|Cormorant|Spectral|DM\s*Serif)\b",
        ],
    },
    # ---- MEDIUM ----
    {
        "id": "hero-three-cards",
        "label": "Centered hero + three-feature-card grid skeleton",
        "sev": "medium",
        "fix": "Break the grid. Asymmetric hero with a real screenshot; "
        "vary sections instead of stacked 3-up icon cards.",
        "pats": [r"grid-cols-1\s+(sm:grid-cols-2\s+)?md:grid-cols-3"],
    },
    {
        "id": "rounded-everything",
        "label": "Large rounded corners / pill buttons everywhere",
        "sev": "medium",
        "fix": "Use a small, intentional radius scale by role. "
        "Not everything maximally rounded; pills only occasionally.",
        "pats": [r"\brounded-(2xl|3xl|full)\b", r"border-radius\s*:\s*(999\d*px|9999px)"],
        # rounded-full on a small sized box is a status dot / avatar / icon, not a pill button.
        # Skip those.
        "suppress": r"\b[hw]-(\d|10|11|12|14|16)(\.5)?\b",
    },
    {
        "id": "fade-in-animations",
        "label": "Boilerplate fade-in / hover-grow / scroll animation",
        "sev": "medium",
        "fix": "Motion only when it communicates something; gate behind "
        "prefers-reduced-motion. Minor tell, noisier signal.",
        "pats": [
            r"initial=\{\{\s*opacity:\s*0",
            r"whileInView",
            r"whileHover=\{\{\s*scale",
            r"data-aos\s*=",
            r"\bhover:scale-1\d{2}\b",
        ],
    },
    {
        "id": "neon-glow",
        "label": "Unprompted neon glow shadow",
        "sev": "medium",
        "fix": "Remove glow you did not deliberately design. "
        "Dark mode should rely on contrast, not glow.",
        "pats": [
            r"shadow-\[0_0_",
            r"drop-shadow-\[0_0_",
            r"text-shadow\s*:[^;]*\d+px[^;]*(rgba|#|hsl)",
            r"box-shadow\s*:[^;]*\b0\s+0\s+\d{2,}px",
        ],
    },
    {
        "id": "emoji-as-icons",
        "label": "Emoji used as icons / section bullets",
        "sev": "medium",
        "fix": "Use a real SVG icon set (Lucide/Phosphor/Heroicons) or none. "
        "Emoji-as-UI signals low effort.",
        "pats": [
            r"[\U0001F680✨⚡\U0001F525\U0001F4A1\U0001F512✅\U0001F3AF\U0001F31F"
            r"\U0001F6E1\U0001F4C8\U0001F511\U0001F389\U0001F680]"
        ],
    },
    {
        "id": "generic-font",
        "label": "Generic default font (Inter / Geist / Roboto / system)",
        "sev": "medium",
        "fix": "Choose a typeface with character and pair a display + body face. "
        "The starter font reads as 'no choice made'.",
        "pats": [
            r"font-family\s*:\s*['\"]?(Inter|Geist|Roboto)\b",
            r"\b(Inter|Geist|Geist_Mono|Roboto)\s*\(",
            r"fontFamily\s*:\s*\{[^}]*['\"](Inter|Geist|Roboto)",
        ],
    },
    # ---- LOW: copy + minor ----
    {
        "id": "hype-copy",
        "label": "Generated marketing copy cliche",
        "sev": "low",
        "fix": "Say what the product literally does, with specifics. Cut the template hype words.",
        "pats": [
            r"\bTransform your\b",
            r"\bSupercharge\b",
            r"\bUnleash\b",
            r"\bEffortlessly\b",
            r"\breimagined\b",
            r"take your [^.]{0,30}to the next level",
            r"\bGame-?changer\b",
        ],
    },
    {
        "id": "stock-illustration",
        "label": "Generic blob / stock illustration source",
        "sev": "low",
        "fix": "Use real screenshots or commissioned art instead of undraw-style blobs.",
        "pats": [r"undraw", r"storyset", r"\bdrawkit\b"],
    },
]


def compile_rule(rule: Rule) -> CompiledRule:
    """Compile one rule's patterns case-insensitively."""
    suppress = rule.get("suppress")
    return CompiledRule(
        rule=rule,
        rx=[re.compile(p, re.IGNORECASE) for p in rule["pats"]],
        suppress_rx=re.compile(suppress, re.IGNORECASE) if suppress else None,
    )


def compile_rules(min_sev: str) -> list[CompiledRule]:
    """Compile every rule at or above `min_sev`."""
    floor = SEV_ORDER.index(min_sev) if min_sev else len(SEV_ORDER) - 1
    return [compile_rule(r) for r in RULES if SEV_ORDER.index(r["sev"]) <= floor]


def iter_files(path: str) -> Iterator[str]:
    """Yield `path` itself if it is a file, else every scannable file beneath it."""
    if Path(path).is_file():
        yield path
        return
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.endswith((".min.js", ".min.css")):
                continue
            file_path = Path(root) / f
            if file_path.suffix.lower() in EXTS:
                yield os.path.join(root, f)  # noqa: PTH118,TID251 # Keep caller path spelling.


def scan_lines(file: str, lines: list[str], rules: list[CompiledRule]) -> list[Finding]:
    """Return the first matching pattern per rule for each line of one file."""
    findings: list[Finding] = []
    for i, line in enumerate(lines, 1):
        if "unslop-ignore" in line.lower():  # respect intentional choices
            continue
        for cr in rules:
            if cr.suppress_rx and cr.suppress_rx.search(line):
                continue
            if any(rx.search(line) for rx in cr.rx):
                findings.append(
                    {
                        "rule": cr.rule["id"],
                        "label": cr.rule["label"],
                        "sev": cr.rule["sev"],
                        "fix": cr.rule["fix"],
                        "file": file,
                        "line": i,
                        "snippet": line.strip()[:SNIPPET_LEN],
                    }
                )
    return findings


def scan(path: str, min_sev: str) -> list[Finding]:
    """Scan every file under `path` and return all findings at or above `min_sev`."""
    rules = compile_rules(min_sev)
    findings: list[Finding] = []
    for fp in iter_files(path):
        try:
            with Path(fp).open(encoding="utf-8", errors="ignore") as fh:
                lines = fh.readlines()
        except OSError:
            continue  # unreadable (permissions, broken symlink): skip quietly
        if len(lines) == 1 and len(lines[0]) > MINIFIED_LINE_LEN:  # likely minified
            continue
        findings.extend(scan_lines(fp, lines, rules))
    return findings


def tally(findings: list[Finding]) -> tuple[dict[str, int], int]:
    """Count findings per severity and compute the weighted vibe score."""
    by_sev: dict[str, int] = {}
    for f in findings:
        by_sev[f["sev"]] = by_sev.get(f["sev"], 0) + 1
    return by_sev, sum(W[s] * n for s, n in by_sev.items())


def verdict(by_sev: dict[str, int], weighted: int) -> str:
    """Summarize the counts as a one-line verdict."""
    high = by_sev.get("high", 0)
    if high >= STRONG_HIGH or weighted >= STRONG_SCORE:
        return "STRONG AI-default look"
    if high >= SOME_HIGH or weighted >= SOME_SCORE:
        return "Some AI defaults present"
    if weighted > 0:
        return "Mostly clean, minor tells"
    return "Clean, no tells detected"


def print_report(path: str, files_scanned: int, findings: list[Finding], max_examples: int) -> None:
    """Print the human-readable report, grouped by rule, most severe first."""
    by_sev, weighted = tally(findings)
    by_rule: dict[str, list[Finding]] = {}
    for f in findings:
        by_rule.setdefault(f["rule"], []).append(f)
    rule_ids = sorted(
        by_rule,
        key=lambda rid: (SEV_ORDER.index(by_rule[rid][0]["sev"]), -len(by_rule[rid])),
    )

    print(f"\n  unslop-ui scan: {path}")
    print(f"  files scanned: {files_scanned}   findings: {len(findings)}   vibe score: {weighted}")
    print(f"  verdict: {verdict(by_sev, weighted)}")
    print(
        f"  high: {by_sev.get('high', 0)}   medium: {by_sev.get('medium', 0)}"
        f"   low: {by_sev.get('low', 0)}\n"
    )
    if not findings:
        print(
            "  Nothing flagged. Either it is clean or the tells are layout/motion ones a regex"
            "\n  cannot see. Eyeball the hero layout and animations against references/tells.md.\n"
        )
        return
    for rid in rule_ids:
        items = by_rule[rid]
        f0 = items[0]
        tag = f0["sev"].upper()
        print(f"  [{tag}] {f0['label']}  ({len(items)} hit{'s' if len(items) != 1 else ''})")
        print(f"        fix: {f0['fix']}")
        for it in items[:max_examples]:
            print(f"        {it['file']}:{it['line']}  {it['snippet']}")
        if len(items) > max_examples:
            print(f"        ... +{len(items) - max_examples} more")
        print()
    top = [by_rule[rid][0]["label"] for rid in rule_ids[:3]]
    print("  Top things to change: " + "; ".join(top))
    print("  Layout and motion tells need eyes too. See references/tells.md.\n")


def main() -> int:
    """Run the CLI; return the number of high-severity findings."""
    ap = argparse.ArgumentParser(description="Scan a web codebase for vibe-coded design tells.")
    ap.add_argument("path")
    ap.add_argument(
        "--severity",
        choices=SEV_ORDER,
        default="low",
        help="minimum severity to report (default: low = everything)",
    )
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    ap.add_argument("--max", type=int, default=10, help="max examples shown per rule (text mode)")
    args = ap.parse_args()

    path = Path(args.path)
    if not path.exists():
        print(f"path not found: {args.path}", file=sys.stderr)
        return 2

    findings = scan(args.path, args.severity)
    by_sev, weighted = tally(findings)
    files_scanned = sum(1 for _ in iter_files(args.path))

    if args.json:
        report = {
            "path": args.path,
            "files_scanned": files_scanned,
            "counts": by_sev,
            "vibe_score": weighted,
            "verdict": verdict(by_sev, weighted),
            "findings": findings,
        }
        print(json.dumps(report, indent=2))
    else:
        print_report(args.path, files_scanned, findings, args.max)
    return by_sev.get("high", 0)


if __name__ == "__main__":
    sys.exit(main())
