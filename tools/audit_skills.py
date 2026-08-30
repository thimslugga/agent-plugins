#!/usr/bin/env python3

"""Audit Agent Skill files for hidden Unicode and suspicious instructions.

Character severity categories are inspired by:
https://github.com/dimetron/pi-go/blob/main/internal/audit/chars.go
"""

import argparse
import bisect
import json
import os
import re
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path

SEVERITY_RANK = {"info": 0, "warning": 1, "critical": 2}
EXPECTED_SEVERITIES = tuple(SEVERITY_RANK)
MAX_FILE_BYTES = 2_000_000
MAX_FINDINGS_PER_FILE = 500
EXCLUDED_DIRS = {
    ".git", ".hg", ".svn", ".mypy_cache", ".pytest_cache", ".ruff_cache",
    ".tox", ".venv", "__pycache__", "node_modules", "venv",
}
BINARY_SUFFIXES = {
    ".7z", ".avi", ".bmp", ".class", ".dll", ".doc", ".docx", ".eot",
    ".exe", ".gif", ".gz", ".ico", ".jar", ".jpeg", ".jpg", ".mov",
    ".mp3", ".mp4", ".otf", ".pdf", ".png", ".ppt", ".pptx", ".pyc",
    ".so", ".tar", ".tif", ".tiff", ".ttf", ".wav", ".webm", ".webp",
    ".woff", ".woff2", ".xls", ".xlsx", ".zip",
}
TEXT_SUFFIXES = {
    "", ".bash", ".cfg", ".conf", ".css", ".csv", ".html", ".ini",
    ".java", ".js", ".json", ".jsx", ".md", ".mjs", ".ps1", ".py",
    ".rb", ".rs", ".sh", ".toml", ".ts", ".tsx", ".txt", ".xml",
    ".yaml", ".yml",
}

UNUSUAL_WHITESPACE = {
    0x00A0, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006,
    0x2007, 0x2008, 0x2009, 0x200A, 0x202F, 0x205F, 0x3000,
}
ZERO_WIDTH = {
    0x200B: "Zero Width Space",
    0x200C: "Zero Width Non-Joiner",
    0x200D: "Zero Width Joiner",
    0xFEFF: "Byte Order Mark",
}
BIDI_CONTROLS = {
    0x202A: "Left-to-Right Embedding",
    0x202B: "Right-to-Left Embedding",
    0x202C: "Pop Directional Formatting",
    0x202D: "Left-to-Right Override",
    0x202E: "Right-to-Left Override",
    0x2066: "Left-to-Right Isolate",
    0x2067: "Right-to-Left Isolate",
    0x2068: "First Strong Isolate",
    0x2069: "Pop Directional Isolate",
}
BIDI_MARKS = {
    0x061C: "Arabic Letter Mark",
    0x200E: "Left-to-Right Mark",
    0x200F: "Right-to-Left Mark",
}
INVISIBLE_CHARACTERS = {
    0x00AD: "Soft Hyphen",
    0x180E: "Mongolian Vowel Separator",
    0x2060: "Word Joiner",
    0x2061: "Function Application",
    0x2062: "Invisible Times",
    0x2063: "Invisible Separator",
    0x2064: "Invisible Plus",
    0x2800: "Braille Pattern Blank",
    0x3164: "Hangul Filler",
    0xFFA0: "Halfwidth Hangul Filler",
    0xFFF9: "Interlinear Annotation Anchor",
    0xFFFA: "Interlinear Annotation Separator",
    0xFFFB: "Interlinear Annotation Terminator",
}
TOKEN_RE = re.compile(r"\w+", re.UNICODE)


@dataclass(frozen=True)
class StringRule:
    code: str
    severity: str
    message: str
    regex: re.Pattern


def suspicious_rules():
    prompt_verbs = "(?:ig" "nore|dis" "regard|over" "ride|for" "get)"
    authority = "(?:pre" "vious|pri" "or|sys" "tem|devel" "oper|ab" "ove)"
    instruction = "instr" "uctions?"

    disclosure_verbs = "(?:re" "veal|ex" "pose|le" "ak|pr" "int|sh" "ow)"
    sensitive_targets = (
        "(?:sys" "tem prompt|devel" "oper message|se" "cret|to" "ken|"
        "cred" "ential|api[ _-]?k" "ey)"
    )

    downloaders = "(?:cu" "rl|wg" "et)"
    shells = "(?:s" "h|ba" "sh|zs" "h)"
    powershell = "power" "shell(?:\\.exe)?"
    encoded_switch = "(?:-e" "nc|-enco" "dedcommand)"

    readers = "(?:c" "at|ty" "pe|get-c" "ontent)"
    sensitive_files = "(?:\\.s" "sh[/\\\\]|\\.e" "nv\\b|cred" "entials?)"

    executors = "(?:ex" "ec|ev" "al|i" "ex|os\\.sys" "tem)"
    decoders = "(?:b64d" "ecode|frombase64s" "tring|base64\\s+-d)"

    return (
        StringRule(
            "prompt.override",
            "critical",
            "Instruction attempts to supersede higher-priority guidance",
            re.compile(
                prompt_verbs + r"[\s\S]{0,100}" + authority
                + r"[\s\S]{0,60}" + instruction,
                re.IGNORECASE,
            ),
        ),
        StringRule(
            "prompt.secret_disclosure",
            "critical",
            "Instruction requests disclosure of prompts, secrets, or credentials",
            re.compile(
                disclosure_verbs + r"[\s\S]{0,100}" + sensitive_targets,
                re.IGNORECASE,
            ),
        ),
        StringRule(
            "execution.download_pipe",
            "critical",
            "Downloaded content is piped directly to a shell",
            re.compile(
                downloaders + r"[^\n|]{0,240}\|\s*" + shells + r"\b",
                re.IGNORECASE,
            ),
        ),
        StringRule(
            "execution.powershell_encoded",
            "critical",
            "PowerShell encoded-command execution",
            re.compile(
                powershell + r"[^\n]{0,160}" + encoded_switch + r"\b",
                re.IGNORECASE,
            ),
        ),
        StringRule(
            "execution.encoded_payload",
            "critical",
            "Decoded data is passed to a dynamic execution primitive",
            re.compile(
                r"(?:" + executors + r"[\s\S]{0,120}" + decoders + r"|"
                + decoders + r"[\s\S]{0,120}" + executors + r")",
                re.IGNORECASE,
            ),
        ),
        StringRule(
            "filesystem.destructive_root",
            "critical",
            "Command can recursively destroy a root or system directory",
            re.compile(
                r"(?:r" "m\\s+-[a-z]*r[a-z]*f[a-z]*\\s+/(?:\\s|$)|"
                r"for" "mat\\s+[a-z]:|"
                r"del\\s+/[a-z]*[sq][a-z]*[\\s\\S]{0,80}\\b(?:win" "dows|us" "ers)\\b)",
                re.IGNORECASE,
            ),
        ),
        StringRule(
            "credentials.read",
            "warning",
            "Command reads a common secret or credential file",
            re.compile(
                readers + r"[^\n]{0,140}" + sensitive_files,
                re.IGNORECASE,
            ),
        ),
        StringRule(
            "network.cloud_metadata",
            "critical",
            "Cloud instance metadata endpoint reference",
            re.compile(r"(?:169\.254\.169\.254|metadata\.google\.internal)", re.IGNORECASE),
        ),
    )


SUSPICIOUS_RULES = suspicious_rules()


def make_finding(path, line, column, code, severity, message, match=None):
    finding = {
        "path": path,
        "line": line,
        "column": column,
        "code": code,
        "severity": severity,
        "message": message,
    }
    if match:
        finding["match"] = match
    return finding


def character_finding(path, line, column, character):
    codepoint = ord(character)
    label = f"U+{codepoint:04X}"
    name = unicodedata.name(character, "unnamed character")

    if 0xE0001 <= codepoint <= 0xE007F:
        return make_finding(path, line, column, "unicode.tag", "critical", f"Unicode tag character {label}")
    if codepoint in BIDI_CONTROLS:
        return make_finding(path, line, column, "unicode.bidi_control", "critical", f"{BIDI_CONTROLS[codepoint]} ({label})")
    if 0xE0100 <= codepoint <= 0xE01EF:
        return make_finding(path, line, column, "unicode.variation_selector_supplement", "critical", f"Variation Selector Supplement character {label}")
    if codepoint == 0 or 0xFDD0 <= codepoint <= 0xFDEF or codepoint & 0xFFFF in {0xFFFE, 0xFFFF}:
        return make_finding(path, line, column, "unicode.noncharacter", "critical", f"NUL or Unicode noncharacter {label}")
    if codepoint in ZERO_WIDTH:
        return make_finding(path, line, column, "unicode.zero_width", "warning", f"{ZERO_WIDTH[codepoint]} ({label})")
    if codepoint in BIDI_MARKS:
        return make_finding(path, line, column, "unicode.bidi_mark", "warning", f"{BIDI_MARKS[codepoint]} ({label})")
    if codepoint in INVISIBLE_CHARACTERS:
        return make_finding(path, line, column, "unicode.invisible", "warning", f"{INVISIBLE_CHARACTERS[codepoint]} ({label})")
    if codepoint == 0xFFFD:
        return make_finding(path, line, column, "unicode.replacement", "warning", f"Unicode Replacement Character ({label})")
    if 0xFE00 <= codepoint <= 0xFE0F:
        return make_finding(path, line, column, "unicode.variation_selector", "info", f"Variation selector {label}")

    category = unicodedata.category(character)
    if category == "Cc" and character not in "\t\r\n":
        return make_finding(path, line, column, "unicode.control", "warning", f"Control character {name} ({label})")
    if category == "Cf":
        return make_finding(path, line, column, "unicode.format", "warning", f"Unicode format character {name} ({label})")
    if category == "Co":
        return make_finding(path, line, column, "unicode.private_use", "warning", f"Private-use character {label}")
    if codepoint in UNUSUAL_WHITESPACE:
        return make_finding(path, line, column, "unicode.unusual_whitespace", "info", f"Unusual whitespace {name} ({label})")

    normalized = unicodedata.normalize("NFKC", character)
    if normalized != character and normalized.isascii() and normalized.isprintable():
        return make_finding(path, line, column, "unicode.compatibility", "info", f"Compatibility character {name} ({label}) normalizes to {normalized!r}")
    return None


def line_starts(text):
    starts = [0]
    starts.extend(match.end() for match in re.finditer("\n", text))
    return starts


def offset_position(starts, offset):
    line_index = bisect.bisect_right(starts, offset) - 1
    return line_index + 1, offset - starts[line_index] + 1


def clean_match(value):
    compact = " ".join(value.split())
    return compact[:160] + ("..." if len(compact) > 160 else "")


def scan_suspicious_strings(text, path):
    findings = []
    starts = line_starts(text)
    for rule in SUSPICIOUS_RULES:
        for match in rule.regex.finditer(text):
            line, column = offset_position(starts, match.start())
            findings.append(make_finding(
                path, line, column, rule.code, rule.severity, rule.message,
                clean_match(match.group(0)),
            ))
    return findings


def script_name(character):
    name = unicodedata.name(character, "")
    if name.startswith("CYRILLIC "):
        return "Cyrillic"
    if name.startswith("GREEK "):
        return "Greek"
    return None


def scan_mixed_scripts(text, path):
    findings = []
    starts = line_starts(text)
    for match in TOKEN_RE.finditer(text):
        token = match.group(0)
        if not any("A" <= character <= "Z" or "a" <= character <= "z" for character in token):
            continue
        scripts = sorted({script_name(character) for character in token} - {None})
        if scripts:
            line, column = offset_position(starts, match.start())
            findings.append(make_finding(
                path,
                line,
                column,
                "unicode.mixed_script",
                "warning",
                f"ASCII token mixes in {', '.join(scripts)} characters",
                token,
            ))
    return findings


def scan_text(text, path):
    findings = scan_suspicious_strings(text, path)
    findings.extend(scan_mixed_scripts(text, path))

    for line_number, line in enumerate(text.splitlines(keepends=True), 1):
        for column, character in enumerate(line, 1):
            current = character_finding(path, line_number, column, character)
            if current:
                findings.append(current)
            if len(findings) >= MAX_FINDINGS_PER_FILE:
                findings = findings[:MAX_FINDINGS_PER_FILE]
                findings.append(make_finding(
                    path,
                    0,
                    0,
                    "scan.finding_limit",
                    "critical",
                    f"Stopped reporting after {MAX_FINDINGS_PER_FILE} findings",
                ))
                return findings
    return findings


def scan_path_name(relative_path):
    path_text = relative_path.as_posix()
    findings = []
    for column, character in enumerate(path_text, 1):
        current = character_finding(path_text, 0, column, character)
        if current:
            current["message"] = "File path contains " + current["message"].lower()
            findings.append(current)
    for current in scan_mixed_scripts(path_text, path_text):
        current["line"] = 0
        current["message"] = "File path contains mixed-script text"
        findings.append(current)
    return findings


def collect_files(root):
    if not root.exists():
        raise ValueError(f"path does not exist: {root}")
    if root.is_symlink():
        raise ValueError("root path must not be a symbolic link")
    if root.is_file():
        return root.parent, [root], []
    if not root.is_dir():
        raise ValueError(f"path is not a file or directory: {root}")

    files = []
    symlinks = []
    for current_root, dir_names, file_names in os.walk(root, followlinks=False):
        dir_names[:] = sorted(name for name in dir_names if name not in EXCLUDED_DIRS)
        current_path = Path(current_root)
        for name in list(dir_names):
            candidate = current_path / name
            if candidate.is_symlink():
                symlinks.append(candidate)
                dir_names.remove(name)
        for name in sorted(file_names):
            candidate = current_path / name
            if candidate.is_symlink():
                symlinks.append(candidate)
            else:
                files.append(candidate)
    return root, files, symlinks


def scan_file(file_path, base_path):
    relative = file_path.relative_to(base_path)
    relative_text = relative.as_posix()
    findings = scan_path_name(relative)

    if file_path.suffix.lower() in BINARY_SUFFIXES:
        return findings, False, True
    size = file_path.stat().st_size
    if size > MAX_FILE_BYTES:
        findings.append(make_finding(
            relative_text,
            0,
            0,
            "file.too_large",
            "warning",
            f"File exceeds {MAX_FILE_BYTES} bytes and was not scanned",
        ))
        return findings, False, False

    data = file_path.read_bytes()
    if b"\x00" in data[:8192] and file_path.suffix.lower() not in TEXT_SUFFIXES:
        return findings, False, True
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as error:
        findings.append(make_finding(
            relative_text,
            0,
            error.start + 1,
            "encoding.invalid_utf8",
            "critical",
            f"File is not valid UTF-8 at byte {error.start}",
        ))
        return findings, False, False

    findings.extend(scan_text(text, relative_text))
    return findings, True, False


def finding_key(item):
    return (
        item["path"], item["line"], item["column"],
        -SEVERITY_RANK[item["severity"]], item["code"], item.get("match", ""),
    )


def audit(root):
    base_path, files, symlinks = collect_files(root)
    findings = []
    scanned_files = 0
    binary_files = 0

    for link in symlinks:
        relative = link.relative_to(base_path).as_posix()
        findings.append(make_finding(
            relative,
            0,
            0,
            "file.symlink",
            "warning",
            "Symbolic link was not followed",
        ))

    for file_path in files:
        file_findings, scanned, binary = scan_file(file_path, base_path)
        findings.extend(file_findings)
        scanned_files += int(scanned)
        binary_files += int(binary)

    findings.sort(key=finding_key)
    counts = {
        severity: sum(item["severity"] == severity for item in findings)
        for severity in EXPECTED_SEVERITIES
    }
    return {
        "files_scanned": scanned_files,
        "binary_files_skipped": binary_files,
        "findings": findings,
        "counts": counts,
    }


def main(argv=None):
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure:
            reconfigure(errors="backslashreplace")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path, help="skill directory or individual file")
    parser.add_argument("--json", action="store_true", dest="json_output")
    parser.add_argument(
        "--fail-on",
        choices=EXPECTED_SEVERITIES,
        default="warning",
        help="lowest severity that produces exit 1 (default: warning)",
    )
    args = parser.parse_args(argv)

    try:
        result = audit(args.path)
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2

    threshold = SEVERITY_RANK[args.fail_on]
    result["threshold"] = args.fail_on
    result["passed"] = not any(
        SEVERITY_RANK[item["severity"]] >= threshold
        for item in result["findings"]
    )

    if args.json_output:
        print(json.dumps(result, indent=2, ensure_ascii=True))
    else:
        for item in result["findings"]:
            location = f"{item['path']}:{item['line']}:{item['column']}"
            suffix = f" [{item['match']}]" if item.get("match") else ""
            print(
                f"{location}: {item['severity'].upper()} {item['code']}: "
                f"{item['message']}{suffix}"
            )
        status = "PASS" if result["passed"] else "FAIL"
        print(
            f"{status}: {len(result['findings'])} finding(s); "
            f"{result['files_scanned']} text file(s) scanned; "
            f"{result['binary_files_skipped']} binary file(s) skipped"
        )
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
