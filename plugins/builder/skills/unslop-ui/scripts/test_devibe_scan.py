"""Regression tests for scanner report paths."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCANNER = Path(__file__).with_name("devibe_scan.py")


class ReportPathsTest(unittest.TestCase):
    """Keep caller path spelling in JSON and text reports."""

    def test_original_path_spelling(self) -> None:
        """Preserve relative prefixes and repeated separators in finding paths."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "nested").mkdir()
            for path in [root / "fixture.html", root / "nested/fixture.html"]:
                path.write_text('<div class="bg-purple-500"></div>\n', encoding="utf-8")
            cases = [
                (".", {"./fixture.html", "./nested/fixture.html"}),
                ("./", {"./fixture.html", "./nested/fixture.html"}),
                ("./fixture.html", {"./fixture.html"}),
                ("nested//fixture.html", {"nested//fixture.html"}),
                ("./nested//", {"./nested//fixture.html"}),
                (str(root / "fixture.html"), {str(root / "fixture.html")}),
            ]
            for target, expected in cases:
                for json_output in [False, True]:
                    with self.subTest(target=target, json_output=json_output):
                        command = [sys.executable, str(SCANNER), target]
                        if json_output:
                            command.append("--json")
                        result = subprocess.run(  # noqa: S603 # Runs the local scanner on fixtures.
                            command,
                            cwd=root,
                            capture_output=True,
                            text=True,
                            check=False,
                        )
                        assert result.returncode == len(expected), result.stderr
                        if json_output:
                            report = json.loads(result.stdout)
                            assert report["path"] == target
                            assert {finding["file"] for finding in report["findings"]} == expected
                        else:
                            for file in expected:
                                assert f"{file}:1 " in result.stdout


if __name__ == "__main__":
    unittest.main()
