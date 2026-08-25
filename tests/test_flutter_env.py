#!/usr/bin/env python3
"""Tests for hooks/scripts/flutter_env.py — the Flutter worktree-context wrapper.

Run:
  python3 -m unittest tests.test_flutter_env -v
"""

from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WRAPPER = ROOT / "hooks" / "scripts" / "flutter_env.py"

# A portable probe command: print the child's environment as KEY=VALUE lines,
# using the Python interpreter running the tests (works on macOS/Linux/Windows,
# unlike POSIX `env`). Probe scripts write to a temp file because capturing
# combined env output via subprocess is simpler than platform-specific flags.
_PROBE_ENV = (
    "import os;"
    "import sys;"
    "f=open(sys.argv[1],'w');"
    "f.write('\\n'.join(f'{k}={v}' for k,v in sorted(os.environ.items())));"
    "f.close()"
)


def _probe_file(tmpdir: Path) -> Path:
    return tmpdir / "env.txt"


def run_wrapper(
    *args: str, env: dict[str, str] | None = None, cwd: Path | None = None
) -> subprocess.CompletedProcess[str]:
    base = os.environ.copy()
    if env is not None:
        base.update(env)
    cmd = [sys.executable, str(WRAPPER), *args]
    return subprocess.run(cmd, cwd=str(cwd or ROOT), capture_output=True, text=True, env=base)


def _parse_env_blob(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.splitlines():
        if "=" in line:
            k, _, v = line.partition("=")
            out[k] = v
    return out


class FlutterEnvTests(unittest.TestCase):
    def test_no_args_exits_two(self):
        result = run_wrapper()
        self.assertEqual(result.returncode, 2)
        self.assertIn("usage:", result.stderr)

    def test_no_command_after_separator_exits_two(self):
        result = run_wrapper("--")
        self.assertEqual(result.returncode, 2)
        self.assertIn("no Flutter command", result.stderr)

    def test_clears_git_worktree_vars_from_child_env(self):
        """The wrapper must run the child without GIT_DIR/GIT_WORK_TREE.

        Uses a portable Python probe (not POSIX `env`) to dump the child env.
        """
        import tempfile

        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            probe = _probe_file(tmp)
            result = run_wrapper(
                "--",
                sys.executable,
                "-c",
                _PROBE_ENV,
                str(probe),
                env={
                    "GIT_DIR": "/fake/worktree",
                    "GIT_WORK_TREE": "/fake/root",
                    "PATH": os.environ.get("PATH", ""),
                },
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            child_vars = _parse_env_blob(probe.read_text())
            self.assertNotIn("GIT_DIR", child_vars)
            self.assertNotIn("GIT_WORK_TREE", child_vars)

    def test_preserves_other_env_vars(self):
        """Non-git vars must pass through to the child unchanged."""
        import tempfile

        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            probe = _probe_file(tmp)
            result = run_wrapper(
                "--",
                sys.executable,
                "-c",
                _PROBE_ENV,
                str(probe),
                env={
                    "GIT_DIR": "/fake",
                    "MY_CUSTOM_VAR": "keep-me",
                    "PATH": os.environ.get("PATH", ""),
                },
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            child_vars = _parse_env_blob(probe.read_text())
            self.assertEqual(child_vars.get("MY_CUSTOM_VAR"), "keep-me")
            self.assertNotIn("GIT_DIR", child_vars)

    def test_passes_arguments_through(self):
        """Arguments after -- must reach the child command verbatim."""
        import tempfile

        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            probe = tmp / "args.txt"
            result = run_wrapper(
                "--",
                sys.executable,
                "-c",
                "import sys; open(sys.argv[1],'w').write(' '.join(sys.argv[2:]))",
                str(probe),
                "hello",
                "world",
                env={"PATH": os.environ.get("PATH", "")},
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("hello world", probe.read_text())

    def test_propagates_child_exit_code(self):
        """A failing child command must propagate its non-zero exit code."""
        result = run_wrapper(
            "--",
            sys.executable,
            "-c",
            "import sys; sys.exit(7)",
            env={"PATH": os.environ.get("PATH", "")},
        )
        self.assertEqual(result.returncode, 7)

    def test_missing_command_exits_127_with_message(self):
        """An unresolvable command must exit 127 with a clear error."""
        result = run_wrapper(
            "--",
            "this-command-definitely-does-not-exist-xyz",
            env={"PATH": os.environ.get("PATH", "")},
        )
        self.assertEqual(result.returncode, 127, result.stderr)
        self.assertIn("command not found", result.stderr)

    def test_real_flutter_version_under_hook_env(self):
        """End-to-end: `flutter --version` must report a real SDK version even
        when the parent sets the git worktree vars a `git commit` hook exports.

        This is the regression guard for the linked-worktree hook failure.
        Skipped if Flutter is not installed on the machine running the tests.
        """
        import shutil as _shutil

        if _shutil.which("flutter") is None:
            self.skipTest("flutter not installed; skipping end-to-end guard")

        result = run_wrapper(
            "--",
            "flutter",
            "--version",
            env={
                "GIT_DIR": str(ROOT / ".git"),
                "GIT_WORK_TREE": str(ROOT),
                "PATH": os.environ.get("PATH", ""),
            },
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        # A healthy Flutter reports its channel/version; the broken state
        # reports 0.0.0-unknown.
        self.assertNotIn("0.0.0-unknown", result.stdout)
        self.assertIn("Flutter", result.stdout)


if __name__ == "__main__":
    unittest.main()
