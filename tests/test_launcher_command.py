#!/usr/bin/env python3
"""Checks for the macOS launcher and icon helper.

Static checks pin the committed script. Behavior checks copy the launcher
into a temp tree and stub ``uname``, ``open``, and ``flutter`` so the
selection, build, and pause paths run without launching the app.

Run:
  python3 -m unittest tests.test_launcher_command -v
"""

from __future__ import annotations

import os
import shutil
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
        result = subprocess.run(
            ["git", "ls-files", "-s", "Launch_AgentsConfigHelper.command"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(
            result.stdout.startswith("100755"),
            result.stdout or result.stderr,
        )

    def test_launcher_calls_icon_helper(self) -> None:
        self.assertIn("scripts/ensure_launcher_icon.sh", launcher_text())

    def test_dev_sh_resolves_root_without_cdpath_noise(self) -> None:
        text = (ROOT / "dev.sh").read_text(encoding="utf-8")
        root_cd = "script_dir=\"$(CDPATH='' cd --"
        self.assertLess(text.index(root_cd), text.index("ensure_launcher_icon"))

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
        self.assertIn(".agents-config-helper-launcher-icon-stamp", gitignore)
        self.assertIn(".agents-config-helper-launcher-build.lock", gitignore)

    def test_helper_tries_every_icon_before_the_sentinel(self) -> None:
        text = helper_text()
        self.assertLess(text.index("for candidate in"), text.rindex("note_failure"))
        failure = text.split("note_failure() {", 1)[1].split("apply_candidate()", 1)[0]
        self.assertLess(failure.index("associated"), failure.index('touch "$sentinel"'))
        self.assertIn("STAMP_NAME", text)


def _write_executable(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf-8")
    path.chmod(0o755)


def _product_executable(root: Path, configuration: str) -> Path:
    return (
        root
        / "build/macos/Build/Products"
        / configuration
        / "agents_config_helper.app/Contents/MacOS/agents_config_helper"
    )


class LauncherBehaviorTests(unittest.TestCase):
    """Run the launcher with stubbed commands. Nothing here starts the app."""

    def setUp(self) -> None:
        name = self.id().rsplit(".", 1)[-1]
        self.root = ROOT / "tmp" / "launcher-behavior" / name
        if self.root.exists():
            shutil.rmtree(self.root)
        (self.root / "scripts").mkdir(parents=True)
        launcher = self.root / "Launch_AgentsConfigHelper.command"
        shutil.copyfile(LAUNCHER, launcher)
        launcher.chmod(0o755)
        _write_executable(
            self.root / "scripts" / "ensure_launcher_icon.sh",
            "#!/bin/sh\nexit 0\n",
        )
        self.bindir = self.root / "bin"
        self.open_log = self.root / "open.log"
        self.flutter_log = self.root / "flutter.log"
        _write_executable(
            self.bindir / "uname",
            "#!/bin/sh\n"
            'if [ "$1" = "-s" ]; then printf "%s\\n" Darwin; exit 0; fi\n'
            'exec /usr/bin/uname "$@"\n',
        )
        _write_executable(
            self.bindir / "open",
            "#!/bin/sh\n"
            'printf "%s\\n" "$*" >> "$OPEN_LOG"\n'
            'exit "${OPEN_STATUS:-0}"\n',
        )
        _write_executable(
            self.bindir / "flutter",
            "#!/bin/sh\n"
            'printf "%s\\n" "$*" >> "$FLUTTER_LOG"\n'
            'if [ "${FLUTTER_STATUS:-0}" -ne 0 ]; then exit "$FLUTTER_STATUS"; fi\n'
            'if [ "${FLUTTER_SLEEP:-0}" -ne 0 ]; then sleep "$FLUTTER_SLEEP"; fi\n'
            'if [ -n "${FLUTTER_MAKE_BUNDLE:-}" ]; then\n'
            '  mkdir -p "$(dirname "$FLUTTER_MAKE_BUNDLE")"\n'
            '  printf "%s\\n" "#!/bin/sh" "exit 0" > "$FLUTTER_MAKE_BUNDLE"\n'
            '  chmod +x "$FLUTTER_MAKE_BUNDLE"\n'
            "fi\n"
            "exit 0\n",
        )
        self.env = {
            "PATH": f"{self.bindir}{os.pathsep}/usr/bin{os.pathsep}/bin",
            "HOME": str(self.root),
            "OPEN_LOG": str(self.open_log),
            "FLUTTER_LOG": str(self.flutter_log),
            "LANG": "C",
        }

    def tearDown(self) -> None:
        shutil.rmtree(self.root, ignore_errors=True)

    def _run(self, stdin: str = "", extra_env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
        env = dict(self.env)
        if extra_env:
            env.update(extra_env)
        return subprocess.run(
            ["bash", str(self.root / "Launch_AgentsConfigHelper.command")],
            cwd=self.root,
            env=env,
            input=stdin,
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )

    def _opened(self) -> str:
        if not self.open_log.is_file():
            return ""
        return self.open_log.read_text(encoding="utf-8")

    def _make_bundle(self, configuration: str) -> None:
        _write_executable(_product_executable(self.root, configuration), "#!/bin/sh\nexit 0\n")

    def test_prefers_release_when_both_bundles_are_launchable(self) -> None:
        self._make_bundle("Release")
        self._make_bundle("Debug")
        result = self._run()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "build/macos/Build/Products/Release/agents_config_helper.app",
            self._opened(),
        )
        self.assertNotIn("Debug/agents_config_helper.app", self._opened())
        self.assertFalse(self.flutter_log.exists())

    def test_falls_back_to_debug_when_release_is_missing(self) -> None:
        self._make_bundle("Debug")
        result = self._run()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "build/macos/Build/Products/Debug/agents_config_helper.app",
            self._opened(),
        )

    def test_skips_an_incomplete_release_bundle(self) -> None:
        incomplete = self.root / "build/macos/Build/Products/Release/agents_config_helper.app"
        incomplete.mkdir(parents=True)
        self._make_bundle("Debug")
        result = self._run()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Debug/agents_config_helper.app", self._opened())
        self.assertNotIn("Release/agents_config_helper.app", self._opened())

    def test_builds_release_when_no_usable_bundle_exists(self) -> None:
        result = self._run(
            extra_env={
                "FLUTTER_MAKE_BUNDLE": str(
                    _product_executable(self.root, "Release")
                ),
            }
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("build macos --release", self.flutter_log.read_text(encoding="utf-8"))
        self.assertIn("Release/agents_config_helper.app", self._opened())

    def test_pause_when_the_build_fails(self) -> None:
        result = self._run(stdin="\n", extra_env={"FLUTTER_STATUS": "1"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("flutter build macos --release failed", result.stderr)
        self.assertIn("Press Return to close", result.stderr)
        self.assertFalse(self.open_log.exists())

    def test_pause_when_flutter_is_not_on_path(self) -> None:
        # `command -v` still finds a non-executable PATH entry, so remove the stub.
        (self.bindir / "flutter").unlink()
        result = self._run(stdin="\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("path_helper", result.stderr)
        self.assertIn("Press Return to close", result.stderr)

    def test_pause_when_open_fails(self) -> None:
        self._make_bundle("Release")
        result = self._run(stdin="\n", extra_env={"OPEN_STATUS": "1"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Could not open", result.stderr)
        self.assertIn("Press Return to close", result.stderr)

    def test_second_launcher_waits_instead_of_building_twice(self) -> None:
        bundle = _product_executable(self.root, "Release")
        env = dict(self.env)
        env["FLUTTER_SLEEP"] = "1"
        env["FLUTTER_MAKE_BUNDLE"] = str(bundle)
        command = ["bash", str(self.root / "Launch_AgentsConfigHelper.command")]
        first = subprocess.Popen(
            command,
            cwd=self.root,
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        second = subprocess.Popen(
            command,
            cwd=self.root,
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        first_out, first_err = first.communicate(timeout=30)
        second_out, second_err = second.communicate(timeout=30)
        self.assertEqual(first.returncode, 0, first_err)
        self.assertEqual(second.returncode, 0, second_err)
        builds = [
            line
            for line in self.flutter_log.read_text(encoding="utf-8").splitlines()
            if "build macos --release" in line
        ]
        self.assertEqual(builds, ["build macos --release"])
        self.assertEqual(self._opened().count("Release/agents_config_helper.app"), 2)
        self.assertIn("Opened", first_out + second_out)


if __name__ == "__main__":
    unittest.main()
