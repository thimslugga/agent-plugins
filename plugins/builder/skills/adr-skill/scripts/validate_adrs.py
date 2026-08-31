#!/usr/bin/env python3

"""Validate Architecture Decision Records and their generated index."""

import argparse
import ast
import json
import re
from datetime import date
from pathlib import Path

STATUSES = {"proposed", "accepted", "rejected", "deprecated", "superseded"}
REQUIRED_FIELDS = (
    "id",
    "title",
    "status",
    "date",
    "deciders",
    "tags",
    "supersedes",
    "superseded_by",
)
LIST_FIELDS = {"deciders", "tags", "supersedes", "superseded_by"}
FILENAME_RE = re.compile(r"^(\d{4})-([a-z0-9]+(?:-[a-z0-9]+)*)\.md$")
ID_RE = re.compile(r"^\d{4}$")
EXPECTED_HEADINGS = (
    (1, "ADR-{id}: {title}"),
    (2, "Context"),
    (2, "Decision"),
    (2, "Alternatives Considered"),
    (2, "Consequences"),
    (3, "Positive"),
    (3, "Negative"),
    (3, "Neutral"),
    (2, "Compliance and Verification"),
    (2, "Revisit When"),
)
LEAF_HEADINGS = {
    "Context",
    "Decision",
    "Alternatives Considered",
    "Positive",
    "Negative",
    "Neutral",
    "Compliance and Verification",
    "Revisit When",
}


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
            add_error(
                errors,
                path,
                "frontmatter.duplicate",
                f"duplicate field: {key}",
            )
            continue
        try:
            metadata[key] = (
                parse_inline_list(raw_value)
                if key in LIST_FIELDS
                else parse_scalar(raw_value)
            )
        except (SyntaxError, ValueError) as error:
            add_error(
                errors,
                path,
                "frontmatter.value",
                f"invalid {key}: {error}",
            )

    for field in REQUIRED_FIELDS:
        if field not in metadata:
            add_error(
                errors,
                path,
                "frontmatter.required",
                f"missing required field: {field}",
            )
    return metadata, "\n".join(lines[closing + 1 :])


def validate_headings(body, metadata, path, errors):
    headings = []
    matches = list(re.finditer(r"^(#{1,6})\s+(.+?)\s*$", body, re.MULTILINE))
    for match in matches:
        headings.append((len(match.group(1)), match.group(2)))

    expected = [
        (level, title.format(id=metadata.get("id", "????"), title=metadata.get("title", "")))
        for level, title in EXPECTED_HEADINGS
    ]
    if headings != expected:
        add_error(
            errors,
            path,
            "headings.structure",
            "headings must match the ADR template exactly and in order",
        )
        return

    for index, match in enumerate(matches):
        title = match.group(2)
        if title not in LEAF_HEADINGS:
            continue
        end = matches[index + 1].start() if index + 1 < len(matches) else len(body)
        if not body[match.end() : end].strip():
            add_error(
                errors,
                path,
                "section.empty",
                f"section must not be empty: {title}",
            )


def validate_document(file_path):
    errors = []
    path = file_path.name
    filename_match = FILENAME_RE.fullmatch(path)
    if not filename_match:
        add_error(
            errors,
            path,
            "filename.invalid",
            "expected NNNN-lowercase-kebab-title.md",
        )

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

    document_date = metadata.get("date")
    try:
        if not isinstance(document_date, str) or date.fromisoformat(document_date).isoformat() != document_date:
            raise ValueError
    except ValueError:
        add_error(errors, path, "date.invalid", "date must be a real YYYY-MM-DD date")

    for field in LIST_FIELDS:
        if field in metadata and not isinstance(metadata[field], list):
            add_error(errors, path, "list.invalid", f"{field} must be an inline list")

    for field in ("supersedes", "superseded_by"):
        for referenced_id in metadata.get(field, []):
            if not ID_RE.fullmatch(referenced_id):
                add_error(
                    errors,
                    path,
                    "reference.invalid",
                    f"{field} contains invalid ADR id: {referenced_id}",
                )
            elif referenced_id == document_id:
                add_error(errors, path, "reference.self", f"{field} cannot reference itself")

    validate_headings(body, metadata, path, errors)
    return metadata, errors


BEGIN_MARKER = "<!-- BEGIN GENERATED INDEX - do not edit below this line -->"
END_MARKER = "<!-- END GENERATED INDEX -->"
INDEX_HEADER = "| ID | Title | Status | Date |\n|----|-------|--------|------|"


def validate_references(records, errors):
    for document_id in sorted(records):
        record = records[document_id]
        metadata = record["metadata"]
        path = record["path"]
        supersedes = metadata.get("supersedes", [])
        superseded_by = metadata.get("superseded_by", [])

        for field, references in (
            ("supersedes", supersedes),
            ("superseded_by", superseded_by),
        ):
            if len(references) != len(set(references)):
                add_error(errors, path, "reference.duplicate", f"{field} contains duplicates")
            for referenced_id in references:
                if referenced_id not in records:
                    add_error(
                        errors,
                        path,
                        "reference.missing",
                        f"{field} references missing ADR {referenced_id}",
                    )

        if metadata.get("status") == "superseded" and not superseded_by:
            add_error(
                errors,
                path,
                "supersession.missing",
                "superseded ADR must set superseded_by",
            )
        if metadata.get("status") != "superseded" and superseded_by:
            add_error(
                errors,
                path,
                "supersession.status",
                "ADR with superseded_by must have status superseded",
            )

        for old_id in supersedes:
            if old_id not in records:
                continue
            old_metadata = records[old_id]["metadata"]
            if document_id not in old_metadata.get("superseded_by", []):
                add_error(
                    errors,
                    path,
                    "supersession.reciprocal",
                    f"ADR {old_id} must list {document_id} in superseded_by",
                )
            if old_metadata.get("status") != "superseded":
                add_error(
                    errors,
                    path,
                    "supersession.status",
                    f"ADR {old_id} must have status superseded",
                )

        for new_id in superseded_by:
            if new_id in records and document_id not in records[new_id]["metadata"].get(
                "supersedes", []
            ):
                add_error(
                    errors,
                    path,
                    "supersession.reciprocal",
                    f"ADR {new_id} must list {document_id} in supersedes",
                )


def expected_index_block(records):
    rows = []
    for document_id in sorted(records):
        record = records[document_id]
        metadata = record["metadata"]
        rows.append(
            f"| [{document_id}]({record['path']}) | {metadata.get('title', '')} | "
            f"{metadata.get('status', '')} | {metadata.get('date', '')} |"
        )
    table = INDEX_HEADER
    if rows:
        table += "\n" + "\n".join(rows)
    return "\n\n" + table + "\n\n"


def validate_index(directory, records, errors):
    index_path = directory / "INDEX.md"
    if not index_path.is_file():
        add_error(errors, "INDEX.md", "index.missing", "ADR index does not exist")
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
            "generated block must exactly match ADR metadata in ascending ID order",
        )


def validate_directory(directory):
    errors = []
    records = {}
    if not directory.is_dir():
        add_error(errors, ".", "directory.missing", "ADR directory does not exist")
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

    validate_references(records, errors)
    validate_index(directory, records, errors)
    errors.sort(key=lambda item: (item["path"], item["code"], item["message"]))
    return records, errors


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", default="docs/adr")
    parser.add_argument("--json", action="store_true", dest="json_output")
    args = parser.parse_args(argv)

    records, errors = validate_directory(Path(args.directory))
    result = {"valid": not errors, "documents": len(records), "errors": errors}
    if args.json_output:
        print(json.dumps(result, indent=2))
    elif errors:
        for error in errors:
            print(f"{error['path']}: {error['code']}: {error['message']}")
        print(f"INVALID: {len(errors)} error(s) across {len(records)} ADR(s)")
    else:
        print(f"VALID: {len(records)} ADR(s)")
    return 0 if result["valid"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
