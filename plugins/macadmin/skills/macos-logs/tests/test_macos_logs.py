"""Regression tests; collector commands are mocked so no live logs are read."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SKILL = Path(__file__).resolve().parents[1]
COLLECTOR = SKILL / "scripts/macos-log-triage.sh"
SUMMARIZER = SKILL / "scripts/macos-log-summarize.py"

# A CLI fixture is intentional: exercise Bash exit codes, redirections, sudo
# arguments, and real filesystem permissions without accessing system evidence.
MOCK_COMMAND = r"""
import json
import os
from pathlib import Path
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["REVIEW_CALLS"], "a") as calls:
    calls.write(json.dumps([name, *args]) + "\n")
if name == "uname":
    print("Darwin")
elif name == "id":
    print(os.environ.get("REVIEW_UID", "1000"))
elif name == "sudo":
    if not args or args.pop(0) != "-n":
        sys.exit(88)
    if os.environ.get("REVIEW_SUDO_DENIED") == "1":
        print("mock: sudo authorization unavailable", file=sys.stderr)
        sys.exit(1)
    if args == ["true"]:
        sys.exit(0)
    os.environ["REVIEW_AS_ROOT"] = "1"
    os.execv(str(Path(sys.argv[0]).parent / args[0]), args)
elif name == "log":
    failure = os.environ.get("REVIEW_LOG_FAIL", "")
    if failure == "all" or (failure == "custom" and "bad predicate" in args):
        print("mock: log query failed", file=sys.stderr)
        sys.exit(65)
    if args[0] == "collect":
        archive = Path(args[args.index("--output") + 1])
        (archive / "Persist").mkdir(parents=True)
        (archive / "Persist/test.tracev3").write_bytes(b"archive evidence")
    else:
        print(json.dumps({"messageType": "Error", "process": "fixture",
                          "eventMessage": "test failure"}))
elif name == "find":
    if any("Library/Logs/DiagnosticReports" in arg for arg in args):
        sys.stdout.buffer.write(os.fsencode(os.environ["REVIEW_REPORT"]) + b"\0")
    else:
        if os.environ.get("REVIEW_HASH_REQUIRES_SUDO") == "1" and os.environ.get("REVIEW_AS_ROOT") != "1":
            print("mock: archive traversal requires privilege", file=sys.stderr)
            sys.exit(1)
        os.execv("/usr/bin/find", ["find", *args])
elif name in {"tail", "grep", "zgrep"}:
    if any(arg.startswith("/var/log/install.log") for arg in args):
        if os.environ.get("REVIEW_INSTALL_FAIL") == "1":
            print("mock: cannot read install.log", file=sys.stderr)
            sys.exit(2)
        if name in {"grep", "zgrep"} and os.environ.get("REVIEW_NO_MATCH") == "1":
            sys.exit(1)
        print("fixture installer line")
    else:
        os.execv("/usr/bin/" + name, [name, *args])
elif name == "shasum":
    if os.environ.get("REVIEW_HASH_FAIL") == "1":
        print("mock: hashing failed", file=sys.stderr)
        sys.exit(1)
    os.execv("/usr/bin/shasum", ["shasum", *args])
elif name == "head":
    os.execv("/usr/bin/head", ["head", *args])
else:
    print("fixture")
"""


class CollectorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="macos-logs-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.output = self.root / "output with spaces"
        self.calls = self.root / "calls.ndjson"
        self.report = self.root / "report with\na newline.ips"
        self.report.write_text('{"app_name":"fixture"}\n{}\n')
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        mock = bin_dir / "mock"
        mock.write_text(f"#!{sys.executable}\n" + MOCK_COMMAND)
        mock.chmod(0o700)
        for name in (
            "uname",
            "id",
            "sudo",
            "log",
            "find",
            "tail",
            "grep",
            "zgrep",
            "head",
            "shasum",
            "sw_vers",
            "sysctl",
            "last",
            "hostname",
            "uptime",
            "df",
        ):
            (bin_dir / name).symlink_to(mock)
        self.env = dict(
            os.environ,
            PATH=f"{bin_dir}:/usr/bin:/bin:/usr/sbin:/sbin",
            REVIEW_CALLS=str(self.calls),
            REVIEW_REPORT=str(self.report),
        )

    def collect(self, *args: str, **settings: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["/bin/bash", str(COLLECTOR), "-o", str(self.output), *args],
            env=dict(self.env, **settings),
            capture_output=True,
            text=True,
            timeout=30,
        )

    def manifest(self) -> str:
        return (self.output / "MANIFEST.txt").read_text()

    def test_complete_bundle_is_private_and_hashes_nested_archive(self) -> None:
        result = self.collect("-a", REVIEW_HASH_REQUIRES_SUDO="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Collection status: complete", self.manifest())
        self.assertIn("Window    : 6h", self.manifest())
        self.assertEqual(self.output.stat().st_mode & 0o777, 0o700)
        digest = hashlib.sha256(b"archive evidence").hexdigest()
        self.assertIn(digest, self.manifest())
        self.assertIn("Persist/test.tracev3", self.manifest())
        self.assertIn("macos-log-summarize.py", result.stdout)
        for path in self.output.rglob("*"):
            self.assertEqual(path.stat().st_mode & 0o077, 0, str(path))

    def test_existing_directory_preserves_files_and_symlink_target(self) -> None:
        self.output.mkdir()
        target = self.root / "original.txt"
        target.write_text("original evidence")
        (self.output / "00-system-facts.txt").symlink_to(target)
        result = self.collect()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(target.read_text(), "original evidence")
        self.assertFalse((self.output / "MANIFEST.txt").exists())

    def test_existing_output_symlink_is_rejected(self) -> None:
        target = self.root / "existing"
        target.mkdir()
        self.output.symlink_to(target, target_is_directory=True)
        self.assertEqual(self.collect().returncode, 1)
        self.assertEqual(list(target.iterdir()), [])

    def test_all_log_failures_are_reported_and_stderr_preserved(self) -> None:
        result = self.collect(REVIEW_LOG_FAIL="all", REVIEW_SUDO_DENIED="1")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Collection status: failed", self.manifest())
        self.assertIn("Privileged: no", self.manifest())
        self.assertIn("failed (exit 65)", self.manifest())
        error = self.output / "03-errors-faults.ndjson.stderr.txt"
        self.assertIn("mock: log query failed", error.read_text())
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        shows = [call for call in calls if call[:2] == ["log", "show"]]
        self.assertTrue(shows)
        self.assertTrue(all("--predicate" in call for call in shows))

    def test_unprivileged_success_is_marked_partial(self) -> None:
        result = self.collect(REVIEW_SUDO_DENIED="1")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Collection status: partial", self.manifest())
        self.assertIn("Privileged: no", self.manifest())

    def test_partial_query_failure(self) -> None:
        result = self.collect("-p", "bad predicate", REVIEW_LOG_FAIL="custom")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Collection status: partial", self.manifest())
        self.assertIn("05-custom-predicate.ndjson: failed (exit 65)", self.manifest())

    def test_install_read_error_is_partial(self) -> None:
        self.assertEqual(self.collect(REVIEW_INSTALL_FAIL="1").returncode, 1)
        self.assertIn("02-install-log.txt: failed", self.manifest())

    def test_grep_no_matches_is_success(self) -> None:
        result = self.collect(REVIEW_NO_MATCH="1")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_hash_failure_is_partial(self) -> None:
        self.assertEqual(self.collect(REVIEW_HASH_FAIL="1").returncode, 1)
        self.assertIn("manifest hashing: failed", self.manifest())
        self.assertIn("Collection status: partial", self.manifest())

    def test_root_never_calls_sudo(self) -> None:
        result = self.collect(REVIEW_UID="0")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertFalse(any(call[0] == "sudo" for call in calls))
        self.assertIn("Privileged: yes (root)", self.manifest())

    def test_invalid_arguments_create_no_output(self) -> None:
        for args in (("-t", "0"), ("-t", "00"), ("-t", "-1"), ("-t", "abc"), ("-t",), ("extra",)):
            with self.subTest(args=args):
                self.assertEqual(self.collect(*args).returncode, 2)
                self.assertFalse(self.output.exists())

    def test_help_and_direct_execution(self) -> None:
        result = subprocess.run([str(COLLECTOR), "-h"], capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0)
        self.assertIn("default: 6", result.stdout)
        self.assertNotIn("HOURS=", result.stdout)


class SummarizerTests(unittest.TestCase):
    def summarize(self, data: str, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SUMMARIZER), *args],
            input=data,
            capture_output=True,
            text=True,
            timeout=5,
        )

    def records(self) -> list[dict[str, str]]:
        return [
            {
                "process": "appA",
                "subsystem": "one",
                "messageType": "Error",
                "eventMessage": "connection 1 failed",
            },
            {
                "process": "appA",
                "subsystem": "one",
                "messageType": "Error",
                "eventMessage": "connection 2 failed",
            },
            {
                "process": "appB",
                "subsystem": "one",
                "messageType": "Error",
                "eventMessage": "connection 3 failed",
            },
            {
                "process": "appA",
                "subsystem": "two",
                "messageType": "Fault",
                "eventMessage": "connection 4 failed",
            },
        ]

    def test_pattern_attribution_for_both_formats(self) -> None:
        records = self.records()
        for data in (json.dumps(records), "\n".join(map(json.dumps, records))):
            with self.subTest(data=data):
                result = self.summarize(data, "--json")
                self.assertEqual(result.returncode, 0, result.stderr)
                payload = json.loads(result.stdout)
                patterns = payload["problem_patterns"]
                counts = {(item["process"], item["subsystem"]): item["count"] for item in patterns}
                self.assertEqual(
                    counts, {("appA", "one"): 2, ("appB", "one"): 1, ("appA", "two"): 1}
                )
                self.assertEqual(payload["skipped_records"], 0)

    def test_text_output_identifies_process_and_subsystem(self) -> None:
        result = self.summarize(json.dumps(self.records()))
        self.assertEqual(result.returncode, 0)
        self.assertIn("appA [one]", result.stdout)
        self.assertIn("appA [two]", result.stdout)
        self.assertIn("appB [one]", result.stdout)

    def test_native_completion_marker_is_not_an_event_or_parse_error(self) -> None:
        data = json.dumps(self.records()[0]) + '\n{"count":1,"finished":1}\n'
        result = self.summarize(data, "--json")
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["total_records"], 1)
        self.assertEqual(payload["skipped_records"], 0)
        self.assertEqual(payload["levels"], {"error": 1})

    def test_empty_native_query_reports_no_records(self) -> None:
        result = self.summarize('{"count":0,"finished":1}\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn("No records parsed", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_malformed_records_produce_partial_summary_and_nonzero_exit(self) -> None:
        data = json.dumps(self.records()[0]) + "\n{truncated\n42\n"
        result = self.summarize(data, "--json")
        self.assertEqual(result.returncode, 1)
        self.assertIn("skipped 2", result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["total_records"], 1)
        self.assertEqual(payload["skipped_records"], 2)

    def test_nonobject_array_items_are_counted(self) -> None:
        result = self.summarize(json.dumps([self.records()[0], None]), "--json")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)["skipped_records"], 1)

    def test_broken_json_array_has_no_traceback(self) -> None:
        result = self.summarize('[{"broken":')
        self.assertEqual(result.returncode, 1)
        self.assertIn("cannot parse stdin", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_missing_file_does_not_hide_valid_file_results(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            valid = Path(temporary) / "valid.ndjson"
            valid.write_text(json.dumps(self.records()[0]))
            result = self.summarize("", str(valid), str(Path(temporary) / "missing"), "--json")
        self.assertEqual(result.returncode, 1)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["total_records"], 1)
        self.assertEqual(payload["failed_files"], 1)

    def test_level_filter_and_process_path_fallback(self) -> None:
        records = self.records()
        records[3].pop("process")
        records[3]["processImagePath"] = "/Applications/App.app/Contents/MacOS/App"
        result = self.summarize(json.dumps(records), "--level", "fault", "--json")
        self.assertEqual(result.returncode, 0)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["total_records"], 1)
        self.assertEqual(payload["top_processes"], [["App", 1]])

    def test_top_must_be_positive(self) -> None:
        self.assertEqual(self.summarize("", "--top", "0").returncode, 2)


if __name__ == "__main__":
    unittest.main()
