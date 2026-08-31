#!/usr/bin/env python3
"""Validate Request for Comments documents and their generated index."""

import argparse
import ast
import json
import re
from datetime import date
from pathlib import Path

OPEN_STATUSES = {"draft", "in-review"}
TERMINAL_STATUSES = {"approved", "rejected", "withdrawn"}
STATUSES = OPEN_STATUSES | TERMINAL_STATUSES
REQUIRED_FIELDS = (
    "id",
    "title",
    "status",
    "date",
    "updated",
    "authors",
    "reviewers",
    "adr",
    "outcome",
    "tags",
)
LIST_FIELDS = {"authors", "reviewers", "adr", "tags"}
FILENAME_RE = re.compile(r"^(\d{4})-([a-z0-9]+(?:-[a-z0-9]+)*)\.md$")
ID_RE = re.compile(r"^\d{4}$")
EXPECTED_HEADINGS = (
    (1, "RFC-{id}: {title}"),
    (2, "Summary"),
    (2, "Context and Problem Statement"),
    (2, "Goals and Non-Goals"),
    (2, "Proposed Solution"),
    (2, "Impact and Migration"),
    (2, "Drawbacks"),
    (2, "Alternatives Considered"),
    (2, "Supporting Materials"),
    (2, "Open Questions"),
    (2, "Decision"),
    (2, "References"),
)
BEGIN_MARKER = "<!-- BEGIN GENERATED INDEX - do not edit below this line -->"
END_MARKER = "<!-- END GENERATED INDEX -->"
OPEN_HEADER = "| ID | Title | Status | Updated | Reviewers |\n|----|-------|--------|---------|-----------|"
CLOSED_HEADER = "| ID | Title | Status | Updated | Outcome |\n|----|-------|--------|---------|---------|"


def add_error(errors, path, code, message):
    errors.append({"path": path, "code": code, "message": message})


def parse_scalar(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        parsed = ast.literal_eval(value)
        if not isinstance(parsed, str):
            raise ValueError("expected a string")
        return parsed
    return value


def parse_inline_list(value):
    value = value.strip()
    if not (value.startswith("[") and value.endswith("]")):
        raise ValueError("expected an inline list such as [] or [item, item]")
    inner = value[1:-1].strip()
    if not inner:
        return []
    return [parse_scalar(item) for item in inner.split(",")]


def parse_frontmatter(text, path, errors):
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        add_error(errors, path, "frontmatter.missing", "file must start with ---")
        return {}, ""
    try:
        closing = lines.index("---", 1)
    except ValueError:
        add_error(errors, path, "frontmatter.unclosed", "missing closing ---")
        return {}, ""

    metadata = {}
    for line_number, line in enumerate(lines[1:closing], 2):
        if not line.strip():
            continue
        if line[:1].isspace() or ":" not in line:
            add_error(
                errors,
                path,
                "frontmatter.syntax",
                f"line {line_number} must be a top-level key: value pair",
            )
            continue
        key, raw_value = line.split(":", 1)
        key = key.strip()
        if key in metadata:
            add_error(errors, path, "frontmatter.duplicate", f"duplicate field: {key}")
            continue
        try:
            metadata[key] = (
                parse_inline_list(raw_value)
                if key in LIST_FIELDS
                else parse_scalar(raw_value)
            )
        except (SyntaxError, ValueError) as error:
            add_error(errors, path, "frontmatter.value", f"invalid {key}: {error}")

    for field in REQUIRED_FIELDS:
        if field not in metadata:
            add_error(
                errors,
                path,
                "frontmatter.required",
                f"missing required field: {field}",
            )
    return metadata, "\n".join(lines[closing + 1 :])


def meaningful_content(content):
    return re.sub(r"<!--.*?-->", "", content, flags=re.DOTALL).strip()


def validate_headings(body, metadata, path, errors):
    matches = list(re.finditer(r"^(#{1,6})\s+(.+?)\s*$", body, re.MULTILINE))
    headings = [(len(match.group(1)), match.group(2)) for match in matches]
    expected = [
        (
            level,
            title.format(
                id=metadata.get("id", "????"),
                title=metadata.get("title", ""),
            ),
        )
        for level, title in EXPECTED_HEADINGS
    ]
    if headings != expected:
        add_error(
            errors,
            path,
            "headings.structure",
            "headings must match the RFC template exactly and in order",
        )
        return

    sections = {}
    for index, match in enumerate(matches[1:], 1):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(body)
        sections[match.group(2)] = meaningful_content(body[match.end() : end])

    for heading, content in sections.items():
        if heading != "Decision" and not content:
            add_error(errors, path, "section.empty", f"section must not be empty: {heading}")

    status = metadata.get("status")
    decision = sections.get("Decision", "")
    if status in OPEN_STATUSES and decision:
        add_error(
            errors,
            path,
            "decision.open",
            "Decision must remain empty while status is draft or in-review",
        )
    if status in TERMINAL_STATUSES and not decision:
        add_error(
            errors,
            path,
            "decision.missing",
            "Decision must be populated for a terminal RFC",
        )


def validate_date(metadata, field, path, errors):
    value = metadata.get(field)
    try:
        if not isinstance(value, str) or date.fromisoformat(value).isoformat() != value:
            raise ValueError
    except ValueError:
        add_error(errors, path, f"{field}.invalid", f"{field} must be a real YYYY-MM-DD date")
        return None
    return value


def validate_document(file_path):
    errors = []
    path = file_path.name
    filename_match = FILENAME_RE.fullmatch(path)
    if not filename_match:
        add_error(errors, path, "filename.invalid", "expected NNNN-lowercase-kebab-title.md")

    try:
        text = file_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        add_error(errors, path, "file.read", str(error))
        return None, errors

    metadata, body = parse_frontmatter(text, path, errors)
    document_id = metadata.get("id")
    if not isinstance(document_id, str) or not ID_RE.fullmatch(document_id):
        add_error(errors, path, "id.invalid", "id must contain exactly four digits")
    elif filename_match and document_id != filename_match.group(1):
        add_error(errors, path, "id.filename", "id must match the filename prefix")

    title = metadata.get("title")
    if not isinstance(title, str) or not title.strip():
        add_error(errors, path, "title.invalid", "title must be a non-empty string")
    elif "|" in title:
        add_error(errors, path, "title.invalid", "title cannot contain a table separator (|)")

    status = metadata.get("status")
    if status not in STATUSES:
        add_error(
            errors,
            path,
            "status.invalid",
            f"status must be one of: {', '.join(sorted(STATUSES))}",
        )

    created = validate_date(metadata, "date", path, errors)
    updated = validate_date(metadata, "updated", path, errors)
    if created and updated and updated < created:
        add_error(errors, path, "updated.order", "updated cannot be earlier than date")

    for field in LIST_FIELDS:
        value = metadata.get(field)
        if field in metadata and not isinstance(value, list):
            add_error(errors, path, "list.invalid", f"{field} must be an inline list")
    for field in ("authors", "reviewers"):
        values = metadata.get(field, [])
        if isinstance(values, list) and not any(value.strip() for value in values):
            add_error(errors, path, f"{field}.empty", f"{field} must contain at least one name")
        if isinstance(values, list) and any("|" in value for value in values):
            add_error(errors, path, f"{field}.invalid", f"{field} cannot contain a table separator (|)")

    adr_ids = metadata.get("adr", [])
    if isinstance(adr_ids, list):
        if len(adr_ids) != len(set(adr_ids)):
            add_error(errors, path, "adr.duplicate", "adr contains duplicate IDs")
        for adr_id in adr_ids:
            if not ID_RE.fullmatch(adr_id):
                add_error(errors, path, "adr.invalid", f"invalid ADR id: {adr_id}")
        if status == "approved" and not adr_ids:
            add_error(errors, path, "adr.missing", "approved RFC must reference at least one ADR")
        if status != "approved" and adr_ids:
            add_error(errors, path, "adr.status", "only approved RFCs may reference ADRs")

    outcome = metadata.get("outcome")
    if not isinstance(outcome, str):
        outcome = ""
    if "|" in outcome:
        add_error(errors, path, "outcome.invalid", "outcome cannot contain a table separator (|)")
    if status in {"rejected", "withdrawn"} and not outcome.strip():
        add_error(errors, path, "outcome.missing", f"{status} RFC must provide outcome")
    if status not in {"rejected", "withdrawn"} and outcome.strip():
        add_error(errors, path, "outcome.status", "outcome is only used for rejected or withdrawn RFCs")

    validate_headings(body, metadata, path, errors)
    return metadata, errors


def resolve_adr_links(directory, records, errors):
    adr_directory = directory.parent / "adr"
    for document_id in sorted(records):
        record = records[document_id]
        metadata = record["metadata"]
        record["adr_links"] = []
        if metadata.get("status") != "approved":
            continue
        for adr_id in metadata.get("adr", []):
            matches = sorted(adr_directory.glob(f"{adr_id}-*.md")) if adr_directory.is_dir() else []
            if len(matches) != 1:
                add_error(
                    errors,
                    record["path"],
                    "adr.resolve",
                    f"ADR {adr_id} must resolve to exactly one sibling docs/adr file",
                )
                continue
            record["adr_links"].append(f"[ADR-{adr_id}](../adr/{matches[0].name})")


def expected_index_block(records):
    open_records = [
        (document_id, record)
        for document_id, record in records.items()
        if record["metadata"].get("status") in OPEN_STATUSES
    ]
    closed_records = [
        (document_id, record)
        for document_id, record in records.items()
        if record["metadata"].get("status") in TERMINAL_STATUSES
    ]
    open_records.sort(
        key=lambda item: (item[1]["metadata"].get("updated", ""), item[0]),
        reverse=True,
    )
    closed_records.sort(key=lambda item: (item[1]["metadata"].get("updated", ""), item[0]))

    open_rows = []
    for document_id, record in open_records:
        metadata = record["metadata"]
        reviewers = ", ".join(metadata.get("reviewers", [])) or "-"
        open_rows.append(
            f"| [{document_id}]({record['path']}) | {metadata.get('title', '')} | "
            f"{metadata.get('status', '')} | {metadata.get('updated', '')} | {reviewers} |"
        )

    closed_rows = []
    for document_id, record in closed_records:
        metadata = record["metadata"]
        if metadata.get("status") == "approved":
            outcome = ", ".join(record.get("adr_links", [])) or "-"
        else:
            outcome = metadata.get("outcome", "") or "-"
        closed_rows.append(
            f"| [{document_id}]({record['path']}) | {metadata.get('title', '')} | "
            f"{metadata.get('status', '')} | {metadata.get('updated', '')} | {outcome} |"
        )

    open_table = OPEN_HEADER + ("\n" + "\n".join(open_rows) if open_rows else "")
    closed_table = CLOSED_HEADER + ("\n" + "\n".join(closed_rows) if closed_rows else "")
    return f"\n\n## Open\n\n{open_table}\n\n## Closed\n\n{closed_table}\n\n"


def validate_index(directory, records, errors):
    index_path = directory / "INDEX.md"
    if not index_path.is_file():
        add_error(errors, "INDEX.md", "index.missing", "RFC index does not exist")
        return
    try:
        text = index_path.read_text(encoding="utf-8").replace("\r\n", "\n")
    except (OSError, UnicodeError) as error:
        add_error(errors, "INDEX.md", "index.read", str(error))
        return

    if (
        text.count(BEGIN_MARKER) != 1
        or text.count(END_MARKER) != 1
        or text.find(BEGIN_MARKER) > text.find(END_MARKER)
    ):
        add_error(
            errors,
            "INDEX.md",
            "index.markers",
            "index must contain one ordered BEGIN marker and END marker",
        )
        return
    generated = text.split(BEGIN_MARKER, 1)[1].split(END_MARKER, 1)[0]
    if generated != expected_index_block(records):
        add_error(
            errors,
            "INDEX.md",
            "index.generated",
            "generated block must exactly match RFC metadata and canonical ordering",
        )


def validate_directory(directory):
    errors = []
    records = {}
    if not directory.is_dir():
        add_error(errors, ".", "directory.missing", "RFC directory does not exist")
        return records, errors

    for file_path in sorted(directory.glob("*.md"), key=lambda path: path.name):
        if file_path.name == "INDEX.md":
            continue
        metadata, document_errors = validate_document(file_path)
        errors.extend(document_errors)
        if metadata and ID_RE.fullmatch(str(metadata.get("id", ""))):
            document_id = metadata["id"]
            if document_id in records:
                add_error(
                    errors,
                    file_path.name,
                    "id.duplicate",
                    f"duplicate id also used by {records[document_id]['path']}",
                )
            else:
                records[document_id] = {"path": file_path.name, "metadata": metadata}

    resolve_adr_links(directory, records, errors)
    validate_index(directory, records, errors)
    errors.sort(key=lambda item: (item["path"], item["code"], item["message"]))
    return records, errors


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", default="docs/rfc")
    parser.add_argument("--json", action="store_true", dest="json_output")
    args = parser.parse_args(argv)

    records, errors = validate_directory(Path(args.directory))
    result = {"valid": not errors, "documents": len(records), "errors": errors}
    if args.json_output:
        print(json.dumps(result, indent=2))
    elif errors:
        for error in errors:
            print(f"{error['path']}: {error['code']}: {error['message']}")
        print(f"INVALID: {len(errors)} error(s) across {len(records)} RFC(s)")
    else:
        print(f"VALID: {len(records)} RFC(s)")
    return 0 if result["valid"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
