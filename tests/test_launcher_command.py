#!/usr/bin/env python3
"""Static checks for the macOS launcher and icon helper (shell behavior is manual).

Run:
  python3 -m unittest tests.test_launcher_command -v
"""

from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAUNCHER = ROOT / "Launch_AgentsConfigHelper.command"
HELPER = ROOT / "scripts" / "ensure_launcher_icon.sh"


def launcher_text() -> str:
    return LAUNCHER.read_text(encoding="utf-8")


def helper_text() -> str:
    return HELPER.read_text(encoding="utf-8")


class LauncherCommandTests(unittest.TestCase):
    def test_launcher_exists_at_repo_root(self) -> None:
        self.assertTrue(LAUNCHER.is_file())

    def test_launcher_is_lf_only(self) -> None:
        self.assertNotIn(b"\r", LAUNCHER.read_bytes())

    def test_launcher_is_executable(self) -> None:
        if os.name == "posix":
            self.assertTrue(os.access(LAUNCHER, os.X_OK))
        out = subprocess.run(
            ["git", "ls-files", "-s", "Launch_AgentsConfigHelper.command"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        ).stdout
        if not out.strip():
            self.skipTest("launcher is not tracked yet")
        self.assertTrue(out.startswith("100755"), out)

    def test_launcher_calls_icon_helper(self) -> None:
        self.assertIn("scripts/ensure_launcher_icon.sh", launcher_text())

    def test_launcher_opens_the_product_bundle(self) -> None:
        self.assertIn("agents_config_helper.app", launcher_text())

    def test_helper_resource_fork_guard_precedes_set_icon(self) -> None:
        text = helper_text()
        self.assertLess(
            text.index("com.apple.ResourceFork"),
            text.index("setIconForFileOptions"),
        )

    def test_helper_never_exits_nonzero(self) -> None:
        text = helper_text()
        self.assertNotIn("exit 1", text)
        self.assertIn("trap 'exit 0' EXIT", text)

    def test_no_setfile_anywhere(self) -> None:
        for path in (LAUNCHER, HELPER):
            self.assertNotIn("SetFile", path.read_text(encoding="utf-8"))

    def test_failure_sentinel_is_gitignored(self) -> None:
        gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
        self.assertIn(".agents-config-helper-launcher-icon-failed", gitignore)


if __name__ == "__main__":
    unittest.main()
