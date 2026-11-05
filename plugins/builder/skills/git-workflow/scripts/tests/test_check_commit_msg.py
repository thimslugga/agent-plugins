#!/usr/bin/env python3
"""Tests for scripts/check-commit-msg. Run: python3 -m unittest discover -s tests"""

import importlib.machinery
import importlib.util
import io
import os
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

_SCRIPT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "check-commit-msg")
)
_loader = importlib.machinery.SourceFileLoader("check_commit_msg", _SCRIPT)
_spec = importlib.util.spec_from_loader("check_commit_msg", _loader)
assert _spec is not None
_mod = importlib.util.module_from_spec(_spec)
_loader.exec_module(_mod)
main, validate = _mod.main, _mod.validate


class ValidateTest(unittest.TestCase):
    def test_valid_simple(self):
        self.assertEqual(validate("docs: correct spelling of CHANGELOG"), [])

    def test_valid_scoped(self):
        self.assertEqual(validate("feat(lang): add Polish language"), [])

    def test_valid_breaking_bang(self):
        self.assertEqual(validate("feat!: drop support for Node 6"), [])

    def test_valid_breaking_scoped_bang(self):
        self.assertEqual(
            validate("feat(api)!: send an email to the customer when shipped"), []
        )

    def test_valid_body_and_footers(self):
        msg = (
            "fix: prevent racing of requests\n"
            "\n"
            "Introduce a request id and a reference to latest request.\n"
            "\n"
            "Reviewed-by: Z\n"
            "Refs: #123\n"
        )
        self.assertEqual(validate(msg), [])

    def test_valid_breaking_footer(self):
        msg = (
            "feat: allow provided config object to extend other configs\n"
            "\n"
            "BREAKING CHANGE: `extends` key is now used for extending other configs\n"
        )
        self.assertEqual(validate(msg), [])

    def test_valid_unknown_type_warns_not_fails(self):
        with redirect_stderr(io.StringIO()):
            self.assertEqual(validate("wip: experimenting"), [])

    def test_empty_message(self):
        self.assertEqual(len(validate("")), 1)

    def test_missing_type_prefix(self):
        errors = validate("just a sentence with no type")
        self.assertTrue(any("must match" in e for e in errors))

    def test_missing_colon_space(self):
        errors = validate("feat no colon here")
        self.assertTrue(any("must match" in e for e in errors))

    def test_empty_description(self):
        errors = validate("feat: ")
        self.assertTrue(errors)

    def test_trailing_period(self):
        errors = validate("fix: correct the typo.")
        self.assertTrue(any("period" in e for e in errors))

    def test_body_without_blank_line(self):
        errors = validate("feat: add thing\nbody starts immediately")
        self.assertTrue(any("blank line" in e for e in errors))

    def test_lowercase_breaking_change_footer(self):
        errors = validate("feat: change thing\n\nbreaking change: stuff breaks")
        self.assertTrue(any("uppercase" in e for e in errors))


class MainTest(unittest.TestCase):
    def run_main(self, argv):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = main(argv)
        return code, out.getvalue(), err.getvalue()

    def test_message_flag_valid(self):
        code, out, _ = self.run_main(["--message", "feat: add thing"])
        self.assertEqual(code, 0)
        self.assertIn("valid", out)

    def test_message_flag_invalid(self):
        code, _, err = self.run_main(["--message", "no type here"])
        self.assertEqual(code, 1)
        self.assertIn("error", err)

    def test_file_arg(self):
        with tempfile.NamedTemporaryFile(
            "w", suffix=".txt", delete=False
        ) as fh:
            fh.write("fix(auth): refresh token expiry\n")
            path = fh.name
        try:
            code, _, _ = self.run_main([path])
            self.assertEqual(code, 0)
        finally:
            os.unlink(path)

    def test_strips_git_comments(self):
        msg = "feat: add thing\n# Please enter the commit message\n# with lines starting"
        code, _, _ = self.run_main(["--message", msg])
        self.assertEqual(code, 0)

    def test_missing_file(self):
        code, _, err = self.run_main(["/nonexistent/msg.txt"])
        self.assertEqual(code, 2)
        self.assertIn("cannot read", err)


if __name__ == "__main__":
    unittest.main()
