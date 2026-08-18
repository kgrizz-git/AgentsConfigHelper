#!/usr/bin/env python3
"""Smoke tests for policy hook scripts and CI usage helper.

Run:
  python3 -m unittest tests.test_policy_hooks_smoke -v
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(script: str, *args: str) -> subprocess.CompletedProcess[str]:
    cmd = [sys.executable, str(ROOT / "hooks" / "scripts" / script), *args]
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)


class TodoLimitsTests(unittest.TestCase):
    def tearDown(self) -> None:
        backlog = ROOT / "to_do.md"
        if backlog.exists():
            backlog.unlink()

    def test_todo_limits_soft_warn(self) -> None:
        backlog = ROOT / "to_do.md"
        backlog.write_text("\n".join(str(i) for i in range(160)) + "\n", encoding="utf-8")
        result = run("check_todo_limits.py", str(backlog))
        self.assertEqual(result.returncode, 0)
        self.assertIn("WARN", result.stderr)

    def test_todo_limits_hard_error(self) -> None:
        backlog = ROOT / "to_do.md"
        backlog.write_text("\n".join(str(i) for i in range(310)) + "\n", encoding="utf-8")
        result = run("check_todo_limits.py", str(backlog))
        self.assertEqual(result.returncode, 1)
        self.assertIn("ERROR", result.stderr)


class FileSizeTests(unittest.TestCase):
    def test_file_size_script_runs_on_self(self) -> None:
        target = ROOT / "hooks" / "scripts" / "check_file_size.py"
        result = run("check_file_size.py", str(target))
        self.assertEqual(result.returncode, 0)


class ScanGateHookTests(unittest.TestCase):
    def init_repo(self, directory: Path) -> None:
        subprocess.run(["git", "init", "-q", str(directory)], check=True)

    def stage(self, directory: Path) -> None:
        subprocess.run(["git", "-C", str(directory), "add", "-A"], check=True)

    def test_gitignore_protected_blocks_removed_rule(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.init_repo(root)
            (root / ".gitignore-protected").write_text("data/\nexports/\n", encoding="utf-8")
            (root / ".gitignore").write_text("data/\nexports/\n", encoding="utf-8")
            self.stage(root)
            ok = run("check_gitignore_protected.py", "--repo-root", str(root))
            self.assertEqual(ok.returncode, 0)

            (root / ".gitignore").write_text("data/\n", encoding="utf-8")  # exports/ removed
            self.stage(root)
            bad = run("check_gitignore_protected.py", "--repo-root", str(root))
            self.assertEqual(bad.returncode, 1)
            self.assertIn("exports/", bad.stderr)

    def test_forbidden_paths_blocks_tracked_match(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.init_repo(root)
            (root / ".forbidden-paths").write_text("data/\n*.dcm\n", encoding="utf-8")
            self.stage(root)
            self.assertEqual(run("check_forbidden_paths.py", "--repo-root", str(root)).returncode, 0)

            data = root / "data"
            data.mkdir()
            (data / "records.csv").write_text("x\n", encoding="utf-8")
            subprocess.run(["git", "-C", str(root), "add", "-f", "data/records.csv"], check=True)
            bad = run("check_forbidden_paths.py", "--repo-root", str(root))
            self.assertEqual(bad.returncode, 1)
            self.assertIn("data/records.csv", bad.stderr)

    def test_scan_contract_never_recorded_then_record_then_stale(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.init_repo(root)
            (root / ".scan-contract.json").write_text(
                json.dumps({
                    "version": 1,
                    "scanners": [{"id": "phi-scan", "paths": ["**/*.py"], "record_command": "record phi-scan"}],
                }),
                encoding="utf-8",
            )
            (root / "mod.py").write_text("print('hi')\n", encoding="utf-8")
            self.stage(root)
            never = run("check_scan_contract.py", "--repo-root", str(root))
            self.assertEqual(never.returncode, 1)
            self.assertIn("never been recorded", never.stderr)

            recorded = run("check_scan_contract.py", "--repo-root", str(root), "record", "phi-scan")
            self.assertEqual(recorded.returncode, 0)
            self.stage(root)
            self.assertEqual(run("check_scan_contract.py", "--repo-root", str(root)).returncode, 0)

            (root / "mod.py").write_text("print('changed')\n", encoding="utf-8")
            self.stage(root)
            stale = run("check_scan_contract.py", "--repo-root", str(root))
            self.assertEqual(stale.returncode, 1)
            self.assertIn("stale", stale.stderr)

    def test_scan_contract_inert_without_config(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.init_repo(root)
            self.assertEqual(run("check_scan_contract.py", "--repo-root", str(root)).returncode, 0)


class GhaUsageScriptTests(unittest.TestCase):
    def test_help_exits_zero(self) -> None:
        cmd = [sys.executable, str(ROOT / "ci" / "scripts" / "check_gha_usage.py"), "--help"]
        result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("Actions", result.stdout)


class OpenPrsScriptTests(unittest.TestCase):
    def test_help_exits_zero(self) -> None:
        cmd = [sys.executable, str(ROOT / "ci" / "scripts" / "check_open_prs.py"), "--help"]
        result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("open", result.stdout.lower())

    def test_once_per_day_skips_when_stamp_fresh(self) -> None:
        stamp = ROOT / ".context" / "open-prs-check-test.stamp"
        stamp.parent.mkdir(parents=True, exist_ok=True)
        stamp.write_text("fresh\n", encoding="utf-8")
        cmd = [
            sys.executable,
            str(ROOT / "ci" / "scripts" / "check_open_prs.py"),
            "--once-per-day",
            "--stamp-file",
            str(stamp),
            "--max-age-hours",
            "24",
        ]
        result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("skipped", result.stdout.lower())
        if stamp.exists():
            stamp.unlink()


if __name__ == "__main__":
    unittest.main()
