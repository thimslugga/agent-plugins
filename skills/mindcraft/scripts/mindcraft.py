#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///

"""mindcraft — mine closed work items for skill opportunities.

Standard library only, so it runs under any python3.11+ without a venv.

Subcommands
-----------
normalize   Map an export from GitHub / Linear / Jira / generic into
            normalized work-record JSONL.
signals     Compute mechanical repetition signals over normalized records:
            n-grams, rework markers, path churn, cycle-time and comment
            outliers. Finds lexical repetition; semantic clustering is the
            reader's job.
inventory   Scan skill directories for name + description, for deduping
            candidates against skills that already exist.
score       Apply gates and the scoring model to candidate patterns.
report      Render a markdown findings report from scored candidates.

Typical pipeline
----------------
    python3 mindcraft.py normalize --source github-prs \\
        --input raw/prs.json --output work/records.jsonl
    python3 mindcraft.py signals --input work/records.jsonl \\
        --output work/signals.json
    python3 mindcraft.py inventory --path ~/.agents/skills \\
        --output work/inventory.json
    python3 mindcraft.py score --input work/candidates.json \\
        --output work/scored.json
    python3 mindcraft.py report --input work/scored.json \\
        --signals work/signals.json --output findings.md
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable, Iterator

__version__ = "1.0.0"

# --------------------------------------------------------------------------
# constants
# --------------------------------------------------------------------------

DIMENSIONS = (
    "frequency",
    "toil",
    "rework",
    "determinism",
    "actionability",
    "stability",
)

IMPACT_WEIGHTS = {"frequency": 0.40, "toil": 0.35, "rework": 0.25}
FEASIBILITY_WEIGHTS = {"determinism": 0.40, "actionability": 0.40, "stability": 0.20}

MIN_EVIDENCE = 3
MIN_FREQUENCY = 2
MIN_ACTIONABILITY = 2

TIERS = (  # (inclusive lower bound, tier name)
    (15.0, "build-now"),
    (9.0, "backlog"),
    (4.0, "monitor"),
    (0.0, "drop"),
)

_TZ_FIX = re.compile(r"([+-]\d{2})(\d{2})$")

# Each mapping: normalized field -> dotted path into the source object.
SOURCE_MAPS: dict[str, dict[str, str]] = {
    "github-issues": {
        "id": "number",
        "title": "title",
        "state": "state",
        "url": "url",
        "opened_at": "createdAt",
        "closed_at": "closedAt",
        "labels": "labels[].name",
        "assignees": "assignees[].login",
        "body": "body",
    },
    "github-prs": {
        "id": "number",
        "title": "title",
        "state": "state",
        "url": "url",
        "opened_at": "createdAt",
        "closed_at": "mergedAt",
        "labels": "labels[].name",
        "assignees": "assignees[].login",
        "body": "body",
        "files": "files[].path",
    },
    "linear": {
        "id": "identifier",
        "title": "title",
        "state": "state.name",
        "url": "url",
        "opened_at": "createdAt",
        "closed_at": "completedAt",
        "labels": "labels.nodes[].name",
        "assignees": "assignee.name",
        "body": "description",
    },
    "jira": {
        "id": "key",
        "title": "fields.summary",
        "state": "fields.status.name",
        "url": "self",
        "opened_at": "fields.created",
        "closed_at": "fields.resolutiondate",
        "labels": "fields.labels",
        "assignees": "fields.assignee.displayName",
        "body": "fields.description",
        "type": "fields.issuetype.name",
    },
    "generic": {},
}

COMMENT_MAPS: dict[str, tuple[str, str, str]] = {
    # source -> (path to comment list, author subpath, body subpath)
    "github-issues": ("comments[]", "author.login", "body"),
    "github-prs": ("comments[]", "author.login", "body"),
    "linear": ("comments.nodes[]", "user.name", "body"),
    "jira": ("fields.comment.comments[]", "author.displayName", "body"),
}

DEFAULT_TYPES = {
    "github-issues": "issue",
    "github-prs": "pr",
    "linear": "issue",
    "jira": "issue",
    "generic": "task",
}

ID_PREFIX = {"github-issues": "#", "github-prs": "#"}
GENERIC_FIELDS = {
    "id", "source", "type", "title", "state", "url", "opened_at", "closed_at",
    "cycle_time_hours", "labels", "assignees", "body", "comments",
    "comment_count", "files", "reopened_count", "linked",
}

STOPWORDS = frozenset("""
a an the and or but if then than that this these those for from with without
into onto over under about after before during while when where which who whom
whose what why how all any both each few more most other some such only own
same too very can will just should now not no nor only its it is are was were
be been being have has had do does did doing would could may might must shall
to of in on at by as we you they he she i our your their my me us them there
add adds added adding fix fixes fixed fixing update updates updated updating
make makes made making use uses used using new old get gets got set sets
issue issues ticket pr prs bug feature task chore wip draft revert test tests
""".split())

REWORK_MARKERS: dict[str, str] = {
    "revert": r"\brevert(ed|ing)?\b",
    "rollback": r"\broll(ed)?[\s-]?back\b",
    "hotfix": r"\bhot[\s-]?fix\b",
    "reopened": r"\bre[\s-]?open(ed|ing)?\b",
    "regression": r"\bregress(ion|ed)\b",
    "follow-up": r"\bfollow[\s-]?up\b",
    "again": r"\b(happened|broke|failed)\s+again\b",
    "forgot": r"\bforg(ot|otten)\b|\bmissed\s+(the|a)\b",
    "as-discussed": r"\bas\s+(we\s+)?discussed\b|\blike\s+last\s+time\b",
    "how-do-i": r"\bhow\s+do\s+(i|we|you)\b|\bwhere\s+(is|does|do)\b",
    "manual-toil": r"\bmanual(ly)?\b|\bby\s+hand\b|\btoil\b",
    "same-as": r"\bsame\s+as\b|\bduplicate\s+of\b",
    "runbook": r"\brun[\s-]?book\b|\bstep[\s-]?by[\s-]?step\b",
}

FRONTMATTER = re.compile(r"^---\s*\n(.*?)\n---", re.DOTALL)


class MindcraftError(Exception):
    """User-facing error: bad input, not a bug."""


# --------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------


def _dig(obj: Any, path: str) -> Any:
    """Resolve a dotted path against nested dicts/lists.

    Supports a ``[]`` segment meaning "map the rest of the path over this
    list": ``labels[].name`` against ``{"labels": [{"name": "bug"}]}``
    yields ``["bug"]``. Missing keys resolve to None rather than raising,
    because exports are irregular and a missing field is normal.
    """
    if obj is None or not path:
        return obj
    head, _, tail = path.partition(".")
    if head.endswith("[]"):
        key = head[:-2]
        seq = obj.get(key) if isinstance(obj, dict) else None
        if not isinstance(seq, list):
            return None
        if not tail:
            return seq
        out = [_dig(item, tail) for item in seq]
        return [v for v in out if v is not None]
    if not isinstance(obj, dict):
        return None
    value = obj.get(head)
    return _dig(value, tail) if tail else value




def parse_ts(value: Any) -> datetime | None:
    """Parse an ISO 8601 timestamp leniently. Returns None on anything odd."""
    if not isinstance(value, str) or not value.strip():
        return None
    text = value.strip().replace("Z", "+00:00")
    text = _TZ_FIX.sub(r"\1:\2", text)  # Jira's +0000 -> +00:00
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def cycle_time_hours(opened: Any, closed: Any) -> float | None:
    start, end = parse_ts(opened), parse_ts(closed)
    if start is None or end is None:
        return None
    if (start.tzinfo is None) != (end.tzinfo is None):
        return None
    delta = (end - start).total_seconds() / 3600.0
    return round(delta, 2) if delta >= 0 else None


def as_text(value: Any) -> str:
    """Coerce a body field to text. Jira ADF bodies arrive as nested dicts."""
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        if isinstance(value.get("text"), str):
            return value["text"]
        return " ".join(as_text(v) for v in value.get("content", []))
    if isinstance(value, list):
        return " ".join(as_text(v) for v in value)
    return str(value)


def as_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [as_text(v) for v in value if v is not None]
    return [as_text(value)]


def percentile(values: list[float], pct: float) -> float | None:
    """Nearest-rank percentile. pct in [0, 100]."""
    if not values:
        return None
    ordered = sorted(values)
    idx = max(0, min(len(ordered) - 1, round(pct / 100.0 * len(ordered) + 0.5) - 1))
    return round(ordered[idx], 2)


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise MindcraftError(f"input not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise MindcraftError(f"{path} is not valid JSON: {exc}") from exc


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError as exc:
        raise MindcraftError(f"input not found: {path}") from exc
    for n, line in enumerate(lines, 1):
        line = line.strip()
        if not line:
            continue
        try:
            records.append(json.loads(line))
        except json.JSONDecodeError as exc:
            raise MindcraftError(f"{path}:{n} is not valid JSON: {exc}") from exc
    return records


def write_out(path: Path | None, text: str) -> None:
    if path is None:
        sys.stdout.write(text if text.endswith("\n") else text + "\n")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text if text.endswith("\n") else text + "\n", encoding="utf-8")
    print(f"wrote {path}", file=sys.stderr)


# --------------------------------------------------------------------------
# normalize
# --------------------------------------------------------------------------

# Each mapping: normalized field -> dotted path into the source object.






def normalize_record(raw: dict[str, Any], source: str) -> dict[str, Any]:
    if source == "generic":
        record = {k: v for k, v in raw.items() if k in GENERIC_FIELDS}
        extra = {k: v for k, v in raw.items() if k not in GENERIC_FIELDS}
        if extra:
            record["extra"] = extra
        record.setdefault("source", "generic")
        record.setdefault("type", DEFAULT_TYPES["generic"])
    else:
        mapping = SOURCE_MAPS[source]
        record = {"source": source}
        for field, path in mapping.items():
            value = _dig(raw, path)
            if value is None or value == [] or value == "":
                continue
            if field in {"labels", "assignees", "files"}:
                record[field] = as_list(value)
            elif field in {"title", "body", "state", "url", "type"}:
                record[field] = as_text(value)
            else:
                record[field] = value
        record.setdefault("type", DEFAULT_TYPES[source])
        if "id" in record:
            record["id"] = f"{ID_PREFIX.get(source, '')}{record['id']}"

        path_spec = COMMENT_MAPS.get(source)
        if path_spec:
            list_path, author_path, body_path = path_spec
            raw_comments = _dig(raw, list_path) or []
            comments = [
                {
                    "author": as_text(_dig(c, author_path)) or "unknown",
                    "body": as_text(_dig(c, body_path)),
                }
                for c in raw_comments
                if isinstance(c, dict)
            ]
            if comments:
                record["comments"] = comments

        reviews = _dig(raw, "reviews[]")
        if isinstance(reviews, list) and reviews:
            record["review_comments"] = len(reviews)

    if isinstance(record.get("comments"), list):
        record["comment_count"] = len(record["comments"])
    hours = cycle_time_hours(record.get("opened_at"), record.get("closed_at"))
    if hours is not None:
        record["cycle_time_hours"] = hours
    if "id" not in record:
        record["id"] = f"{source}-unknown"
    record.setdefault("title", "")
    return record


def iter_source_records(data: Any) -> Iterator[dict[str, Any]]:
    """Accept a bare array, or a wrapper like {"issues": [...]}"""
    if isinstance(data, list):
        items: Iterable[Any] = data
    elif isinstance(data, dict):
        for key in ("issues", "items", "nodes", "records", "data", "values"):
            if isinstance(data.get(key), list):
                items = data[key]
                break
        else:
            items = [data]
    else:
        raise MindcraftError("expected a JSON array or object of work items")
    for item in items:
        if isinstance(item, dict):
            yield item


def cmd_normalize(args: argparse.Namespace) -> int:
    if args.source not in SOURCE_MAPS:
        raise MindcraftError(
            f"unknown source {args.source!r}; choose from {', '.join(SOURCE_MAPS)}"
        )
    data = read_json(Path(args.input))
    records = [normalize_record(r, args.source) for r in iter_source_records(data)]
    if not records:
        raise MindcraftError("no work items found in input")
    body = "\n".join(json.dumps(r, ensure_ascii=False) for r in records)
    write_out(Path(args.output) if args.output else None, body)
    print(f"normalized {len(records)} records from {args.source}", file=sys.stderr)
    return 0


# --------------------------------------------------------------------------
# signals
# --------------------------------------------------------------------------




def tokenize(text: str) -> list[str]:
    words = re.split(r"[^a-z0-9]+", text.lower())
    return [w for w in words if len(w) > 2 and not w.isdigit() and w not in STOPWORDS]


def ngrams(tokens: list[str], n: int) -> list[str]:
    return [" ".join(tokens[i : i + n]) for i in range(len(tokens) - n + 1)]


def record_text(record: dict[str, Any]) -> str:
    parts = [as_text(record.get("title")), as_text(record.get("body"))]
    parts += [as_text(c.get("body")) for c in record.get("comments", []) or []]
    return "\n".join(p for p in parts if p)


def compute_signals(
    records: list[dict[str, Any]], top: int = 25, min_count: int = 2
) -> dict[str, Any]:
    ngram_ids: dict[str, set[str]] = defaultdict(set)
    label_ids: dict[str, set[str]] = defaultdict(set)
    path_ids: dict[str, set[str]] = defaultdict(set)
    marker_ids: dict[str, set[str]] = defaultdict(set)
    cycle_times: list[float] = []
    comment_counts: list[tuple[str, int]] = []

    for record in records:
        rid = str(record.get("id", "?"))
        tokens = tokenize(as_text(record.get("title")))
        for n in (1, 2, 3):
            for gram in ngrams(tokens, n):
                ngram_ids[gram].add(rid)
        for label in record.get("labels", []) or []:
            label_ids[str(label).lower()].add(rid)
        for path in record.get("files", []) or []:
            path_ids[str(path)].add(rid)
        haystack = record_text(record).lower()
        for name, pattern in REWORK_MARKERS.items():
            if re.search(pattern, haystack):
                marker_ids[name].add(rid)
        if isinstance(record.get("cycle_time_hours"), (int, float)):
            cycle_times.append(float(record["cycle_time_hours"]))
        comment_counts.append((rid, int(record.get("comment_count", 0) or 0)))

    def rank(mapping: dict[str, set[str]], limit: int) -> list[dict[str, Any]]:
        rows = [
            {"term": term, "count": len(ids), "items": sorted(ids)[:8]}
            for term, ids in mapping.items()
            if len(ids) >= min_count
        ]
        rows.sort(key=lambda r: (-r["count"], r["term"]))
        return rows[:limit]

    comment_counts.sort(key=lambda t: -t[1])
    counts_only = [c for _, c in comment_counts]
    p90_comments = percentile([float(c) for c in counts_only], 90) or 0.0

    return {
        "corpus": {
            "records": len(records),
            "with_comments": sum(1 for r in records if r.get("comments")),
            "with_files": sum(1 for r in records if r.get("files")),
            "sources": sorted({str(r.get("source", "unknown")) for r in records}),
        },
        "title_ngrams": rank(ngram_ids, top),
        "labels": rank(label_ids, top),
        "path_churn": rank(path_ids, top),
        "rework_markers": [
            {"marker": name, "count": len(ids), "items": sorted(ids)[:12]}
            for name, ids in sorted(
                marker_ids.items(), key=lambda kv: (-len(kv[1]), kv[0])
            )
        ],
        "cycle_time_hours": {
            "n": len(cycle_times),
            "p50": percentile(cycle_times, 50),
            "p75": percentile(cycle_times, 75),
            "p90": percentile(cycle_times, 90),
            "max": round(max(cycle_times), 2) if cycle_times else None,
        },
        "comment_outliers": [
            {"id": rid, "comments": count}
            for rid, count in comment_counts[:10]
            if count and count >= p90_comments
        ],
        "hint": (
            "These are lexical signals only. Cluster semantically by reading the "
            "high-signal items; two tickets worded differently can be one pattern."
        ),
    }


def cmd_signals(args: argparse.Namespace) -> int:
    records = read_jsonl(Path(args.input))
    if not records:
        raise MindcraftError("no records in input")
    result = compute_signals(records, top=args.top, min_count=args.min_count)
    write_out(
        Path(args.output) if args.output else None,
        json.dumps(result, indent=2, ensure_ascii=False),
    )
    return 0


# --------------------------------------------------------------------------
# inventory
# --------------------------------------------------------------------------



def parse_frontmatter(text: str) -> dict[str, str]:
    """Extract name/description without a YAML dependency.

    Handles plain scalars and folded multi-line values, which covers every
    skill frontmatter in practice.
    """
    match = FRONTMATTER.match(text)
    if not match:
        return {}
    fields: dict[str, str] = {}
    key: str | None = None
    for line in match.group(1).splitlines():
        header = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if header:
            key = header.group(1)
            fields[key] = header.group(2).strip().strip("'\"")
        elif key and line.strip():
            fields[key] = (fields[key] + " " + line.strip()).strip()
    return fields


def scan_skills(paths: list[Path]) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    seen: set[Path] = set()
    for root in paths:
        root = root.expanduser()
        if not root.exists():
            print(f"note: {root} does not exist, skipping", file=sys.stderr)
            continue
        for skill_md in sorted(root.rglob("SKILL.md")):
            resolved = skill_md.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            try:
                fields = parse_frontmatter(skill_md.read_text(encoding="utf-8"))
            except (OSError, UnicodeDecodeError) as exc:
                print(f"note: cannot read {skill_md}: {exc}", file=sys.stderr)
                continue
            found.append(
                {
                    "name": fields.get("name", skill_md.parent.name),
                    "description": fields.get("description", ""),
                    "path": str(skill_md),
                }
            )
    return found


def cmd_inventory(args: argparse.Namespace) -> int:
    skills = scan_skills([Path(p) for p in args.path])
    result = {"count": len(skills), "skills": skills}
    write_out(
        Path(args.output) if args.output else None,
        json.dumps(result, indent=2, ensure_ascii=False),
    )
    print(f"found {len(skills)} existing skills", file=sys.stderr)
    return 0


# --------------------------------------------------------------------------
# score
# --------------------------------------------------------------------------


def tier_for(priority: float) -> str:
    for threshold, name in TIERS:
        if priority >= threshold:
            return name
    return "drop"


def validate_candidate(candidate: Any, index: int) -> dict[str, Any]:
    where = f"candidate[{index}]"
    if not isinstance(candidate, dict):
        raise MindcraftError(f"{where} is not an object")
    name = candidate.get("name") or candidate.get("id")
    if not name:
        raise MindcraftError(f"{where} needs a 'name' (or 'id')")
    scores = candidate.get("scores")
    if not isinstance(scores, dict):
        raise MindcraftError(f"{where} ({name}) needs a 'scores' object")
    missing = [d for d in DIMENSIONS if d not in scores]
    if missing:
        raise MindcraftError(
            f"{where} ({name}) missing score(s): {', '.join(missing)}"
        )
    for dim in DIMENSIONS:
        value = scores[dim]
        if not isinstance(value, (int, float)) or isinstance(value, bool):
            raise MindcraftError(f"{where} ({name}) score {dim!r} must be numeric")
        if not 0 <= value <= 5:
            raise MindcraftError(
                f"{where} ({name}) score {dim!r}={value} out of range 0-5"
            )
    if not isinstance(candidate.get("evidence", []), list):
        raise MindcraftError(f"{where} ({name}) 'evidence' must be a list")
    return candidate


def gate_candidate(candidate: dict[str, Any]) -> list[str]:
    scores = candidate["scores"]
    reasons: list[str] = []
    if len(candidate.get("evidence", [])) < MIN_EVIDENCE:
        reasons.append("insufficient-evidence")
    if scores["frequency"] < MIN_FREQUENCY:
        reasons.append("too-rare")
    if scores["actionability"] < MIN_ACTIONABILITY:
        reasons.append("not-agent-actionable")
    if candidate.get("duplicate_of"):
        reasons.append("duplicate")
    return reasons


def score_candidate(candidate: dict[str, Any]) -> dict[str, Any]:
    scores = candidate["scores"]
    impact = sum(w * scores[d] for d, w in IMPACT_WEIGHTS.items())
    feasibility = sum(w * scores[d] for d, w in FEASIBILITY_WEIGHTS.items())
    priority = impact * feasibility
    rejected = gate_candidate(candidate)
    result = dict(candidate)
    result["name"] = candidate.get("name") or candidate.get("id")
    result["impact"] = round(impact, 2)
    result["feasibility"] = round(feasibility, 2)
    result["priority"] = round(priority, 2)
    result["tier"] = "rejected" if rejected else tier_for(priority)
    result["rejected_reasons"] = rejected
    result.setdefault("artifact", "skill")
    return result


def cmd_score(args: argparse.Namespace) -> int:
    data = read_json(Path(args.input))
    raw = data.get("candidates") if isinstance(data, dict) else data
    if not isinstance(raw, list):
        raise MindcraftError(
            "expected a JSON array of candidates, or an object with a "
            "'candidates' array"
        )
    scored = [score_candidate(validate_candidate(c, i)) for i, c in enumerate(raw)]
    accepted = [c for c in scored if c["tier"] != "rejected"]
    rejected = [c for c in scored if c["tier"] == "rejected"]
    accepted.sort(key=lambda c: (-c["priority"], c["name"]))
    rejected.sort(key=lambda c: c["name"])

    counts = Counter(c["tier"] for c in scored)
    result = {
        "summary": {
            "total": len(scored),
            "accepted": len(accepted),
            "rejected": len(rejected),
            "by_tier": dict(sorted(counts.items())),
        },
        "candidates": accepted,
        "rejected": rejected,
        "model": {
            "impact_weights": IMPACT_WEIGHTS,
            "feasibility_weights": FEASIBILITY_WEIGHTS,
            "priority": "impact * feasibility (0-25)",
            "gates": {
                "min_evidence": MIN_EVIDENCE,
                "min_frequency": MIN_FREQUENCY,
                "min_actionability": MIN_ACTIONABILITY,
            },
            "tiers": {name: threshold for threshold, name in TIERS},
        },
    }
    write_out(
        Path(args.output) if args.output else None,
        json.dumps(result, indent=2, ensure_ascii=False),
    )
    print(
        f"scored {len(scored)} candidates: "
        + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())),
        file=sys.stderr,
    )
    return 0


# --------------------------------------------------------------------------
# report
# --------------------------------------------------------------------------


def _evidence_cell(candidate: dict[str, Any], show: int = 3) -> str:
    evidence = [str(e) for e in candidate.get("evidence", [])]
    if not evidence:
        return "—"
    head = ", ".join(evidence[:show])
    rest = len(evidence) - show
    return f"{head} (+{rest})" if rest > 0 else head


def _score_line(candidate: dict[str, Any]) -> str:
    scores = candidate.get("scores", {})
    return " · ".join(f"{d} {scores.get(d, '?')}" for d in DIMENSIONS)


def render_report(scored: dict[str, Any], signals: dict[str, Any] | None) -> str:
    accepted = scored.get("candidates", [])
    rejected = scored.get("rejected", [])
    lines: list[str] = ["# Skill mining review", ""]

    if signals:
        corpus = signals.get("corpus", {})
        lines += [
            "## Corpus",
            "",
            f"- Records analyzed: **{corpus.get('records', '?')}**",
            f"- Sources: {', '.join(corpus.get('sources', [])) or '—'}",
            f"- With discussion threads: {corpus.get('with_comments', 0)}",
            f"- With file-level data: {corpus.get('with_files', 0)}",
            "",
            "> Replace this block with how the corpus was selected and sampled,",
            "> and what was excluded. The numbers above are records seen by the",
            "> tooling, not items read closely.",
            "",
        ]

    summary = scored.get("summary", {})
    lines += [
        "## Summary",
        "",
        f"{summary.get('total', 0)} candidate patterns evaluated: "
        f"{summary.get('accepted', 0)} accepted, {summary.get('rejected', 0)} "
        "rejected at the gates.",
        "",
        "> Replace this line with the actual finding: what the closed work shows.",
        "",
    ]

    if accepted:
        lines += [
            "| # | Candidate | Artifact | Priority | Tier | Evidence |",
            "|---|---|---|---|---|---|",
        ]
        for i, c in enumerate(accepted, 1):
            lines.append(
                f"| {i} | {c['name']} | {c.get('artifact', 'skill')} | "
                f"{c['priority']} | {c['tier']} | {_evidence_cell(c)} |"
            )
        lines.append("")

    for tier, heading in (
        ("build-now", "## Build now"),
        ("backlog", "## Backlog"),
        ("monitor", "## Monitor"),
        ("drop", "## Documented, not recommended for build"),
    ):
        group = [c for c in accepted if c["tier"] == tier]
        if not group:
            continue
        lines += [heading, ""]
        for c in group:
            lines += [
                f"### {c['name']} — priority {c['priority']} "
                f"({c.get('artifact', 'skill')})",
                "",
                f"**Pattern.** {c.get('pattern', '_describe the procedure_')}",
                "",
                f"**Evidence.** {', '.join(str(e) for e in c.get('evidence', [])) or '—'}",
                "",
                f"**Scores.** {_score_line(c)} → impact {c['impact']}, "
                f"feasibility {c['feasibility']}",
                "",
            ]
            if c.get("trigger_language"):
                phrases = "; ".join(f'"{p}"' for p in c["trigger_language"])
                lines += [f"**Trigger language from the corpus.** {phrases}", ""]
            if c.get("notes"):
                lines += [f"**Notes.** {c['notes']}", ""]
            if c.get("open_questions"):
                lines.append("**Open questions.**")
                lines += [f"- {q}" for q in c["open_questions"]]
                lines.append("")

    if rejected:
        lines += ["## Not recommended", "", "| Candidate | Reason | Detail |", "|---|---|---|"]
        for c in rejected:
            reasons = ", ".join(c.get("rejected_reasons", [])) or "—"
            detail = (c.get("notes") or c.get("pattern") or "").replace("|", "\\|")
            lines.append(f"| {c['name']} | {reasons} | {detail} |")
        lines.append("")

    if signals:
        lines += ["## Signals appendix", ""]
        markers = [m for m in signals.get("rework_markers", []) if m["count"]]
        if markers:
            lines += ["**Rework markers**", "", "| Marker | Items | Examples |", "|---|---|---|"]
            for m in markers:
                lines.append(
                    f"| {m['marker']} | {m['count']} | {', '.join(m['items'][:6])} |"
                )
            lines.append("")
        grams = signals.get("title_ngrams", [])[:15]
        if grams:
            lines += ["**Repeated title phrases**", "", "| Phrase | Items |", "|---|---|"]
            for g in grams:
                lines.append(f"| {g['term']} | {g['count']} |")
            lines.append("")
        churn = signals.get("path_churn", [])[:10]
        if churn:
            lines += ["**Path churn**", "", "| Path | Items |", "|---|---|"]
            for p in churn:
                lines.append(f"| `{p['term']}` | {p['count']} |")
            lines.append("")
        cycle = signals.get("cycle_time_hours", {})
        if cycle.get("n"):
            lines += [
                "**Cycle time (hours)**",
                "",
                f"n={cycle['n']} · p50={cycle.get('p50')} · p75={cycle.get('p75')} "
                f"· p90={cycle.get('p90')} · max={cycle.get('max')}",
                "",
            ]

    lines += [
        "---",
        "",
        "_Generated by skillmine. Every candidate above must cite at least "
        f"{MIN_EVIDENCE} source items; anything that cannot is in the rejected "
        "table, not omitted._",
    ]
    return "\n".join(lines)


def cmd_report(args: argparse.Namespace) -> int:
    scored = read_json(Path(args.input))
    if not isinstance(scored, dict) or "candidates" not in scored:
        raise MindcraftError(
            "input must be the output of `skillmine.py score` "
            "(an object with a 'candidates' array)"
        )
    signals = read_json(Path(args.signals)) if args.signals else None
    write_out(Path(args.output) if args.output else None, render_report(scored, signals))
    return 0


# --------------------------------------------------------------------------
# cli
# --------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="skillmine",
        description="Mine closed work items for skill opportunities.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--version", action="version", version=f"skillmine {__version__}")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("normalize", help="map a source export to work-record JSONL")
    p.add_argument("--source", required=True, choices=sorted(SOURCE_MAPS))
    p.add_argument("--input", required=True)
    p.add_argument("--output", help="output .jsonl path (default: stdout)")
    p.set_defaults(func=cmd_normalize)

    p = sub.add_parser("signals", help="compute repetition signals over records")
    p.add_argument("--input", required=True, help="normalized .jsonl")
    p.add_argument("--output", help="output .json path (default: stdout)")
    p.add_argument("--top", type=int, default=25, help="rows per ranking (default 25)")
    p.add_argument(
        "--min-count", type=int, default=2, help="minimum item count to rank (default 2)"
    )
    p.set_defaults(func=cmd_signals)

    p = sub.add_parser("inventory", help="list existing skills for deduping")
    p.add_argument("--path", action="append", required=True, help="repeatable")
    p.add_argument("--output", help="output .json path (default: stdout)")
    p.set_defaults(func=cmd_inventory)

    p = sub.add_parser("score", help="gate and score candidate patterns")
    p.add_argument("--input", required=True, help="candidates .json")
    p.add_argument("--output", help="output .json path (default: stdout)")
    p.set_defaults(func=cmd_score)

    p = sub.add_parser("report", help="render a markdown findings report")
    p.add_argument("--input", required=True, help="scored .json from `score`")
    p.add_argument("--signals", help="signals .json from `signals`")
    p.add_argument("--output", help="output .md path (default: stdout)")
    p.set_defaults(func=cmd_report)

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return int(args.func(args))
    except MindcraftError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    except BrokenPipeError:
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
