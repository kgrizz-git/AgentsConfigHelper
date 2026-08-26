#!/usr/bin/env python3
"""Tests for hooks/scripts/flutter_env.py — the Flutter worktree-context wrapper.

Run:
  python3 -m unittest tests.test_flutter_env -v
"""

from __future__ import annotations

import os
import sys
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "hooks" / "scripts"))
import flutter_env as fe  # noqa: E402


class FlutterEnvTests(unittest.TestCase):
    def test_missing_task_exits_two(self):
        with mock.patch("sys.stderr"):
            self.assertEqual(fe.main([]), 2)

    def test_unknown_task_exits_two_before_launching_a_process(self):
        with mock.patch("sys.stderr"), mock.patch("subprocess.run") as run:
            self.assertEqual(fe.main(["test&untrusted"]), 2)
        run.assert_not_called()

    def test_filtered_environment_clears_only_worktree_vars(self):
        with mock.patch.dict(
            os.environ,
            {"GIT_DIR": "/fake/worktree", "GIT_WORK_TREE": "/fake/root", "KEEP": "yes"},
            clear=True,
        ):
            child_env = fe.filtered_environment()
        self.assertNotIn("GIT_DIR", child_env)
        self.assertNotIn("GIT_WORK_TREE", child_env)
        self.assertEqual(child_env["KEEP"], "yes")

    def test_tasks_are_exact_ci_equivalents(self):
        self.assertEqual(
            fe.TASKS["metrics"],
            (
                "pub",
                "run",
                "dart_code_linter:metrics",
                "analyze",
                "lib",
                "--set-exit-on-violation-level=warning",
            ),
        )
        self.assertEqual(fe.TASKS["analyze"], ("analyze", "--fatal-infos"))
        self.assertEqual(fe.TASKS["test"], ("test",))

    def test_windows_launch_is_shell_free_and_uses_fixed_task(self):
        completed = mock.Mock(returncode=7)
        with (
            mock.patch.object(fe.os, "name", "nt"),
            mock.patch.object(fe, "filtered_environment", return_value={"KEEP": "yes"}),
            mock.patch.object(fe.shutil, "which", return_value="flutter.bat"),
            mock.patch.object(fe.subprocess, "run", return_value=completed) as run,
        ):
            self.assertEqual(fe.main(["test"]), 7)
        run.assert_called_once_with(
            ["flutter.bat", "test"],
            env={"KEEP": "yes"},
            check=False,
        )

    def test_windows_missing_flutter_exits_127(self):
        with (
            mock.patch.object(fe.os, "name", "nt"),
            mock.patch.object(fe.subprocess, "run", side_effect=FileNotFoundError),
            mock.patch("sys.stderr"),
        ):
            self.assertEqual(fe.main(["analyze"]), 127)

    def test_unix_exec_uses_fixed_task_and_filtered_environment(self):
        with (
            mock.patch.object(fe.os, "name", "posix"),
            mock.patch.object(fe, "filtered_environment", return_value={"KEEP": "yes"}),
            mock.patch.object(fe.shutil, "which", return_value="/opt/flutter/bin/flutter"),
            mock.patch.object(fe.os, "execvpe", side_effect=FileNotFoundError) as execute,
            mock.patch("sys.stderr"),
        ):
            self.assertEqual(fe.main(["analyze"]), 127)
        execute.assert_called_once_with(
            "/opt/flutter/bin/flutter",
            ["/opt/flutter/bin/flutter", "analyze", "--fatal-infos"],
            {"KEEP": "yes"},
        )


if __name__ == "__main__":
    unittest.main()
