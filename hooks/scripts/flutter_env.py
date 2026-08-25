#!/usr/bin/env python3
"""
flutter_env.py — run a Flutter command with git worktree-context cleared.

In a linked git worktree, `git commit` exports GIT_DIR and GIT_WORK_TREE into
the hook environment pointing at the worktree's metadata dir and root. Flutter's
SDK version detection reads those to resolve its own git origin, finds the app's
worktree metadata instead of the Flutter SDK checkout, and reports
`Flutter SDK version 0.0.0-unknown` — which then fails pub resolution.

This wrapper runs the Flutter command in a child environment with those two
vars removed, so Flutter resolves its own SDK checkout. Clearing them is
harmless when they are unset and aligns the local hook invocation with CI
(which never sees them); in a linked worktree it is what prevents the
SDK from being misresolved against the app checkout.

Cross-platform: resolves the command with shutil.which (PATHEXT-aware, so
`flutter` finds flutter.bat/.cmd on Windows), and uses a shell-based subprocess
branch for Windows .bat/.cmd scripts (which the OS cannot exec directly). On
Unix it preserves exec semantics. Arguments, filtered environment, inherited
stdin/stdout/stderr, and the child's exit code are all preserved.

Usage (pre-commit wires this automatically; the Flutter command follows --):
  python hooks/scripts/flutter_env.py -- flutter pub run dart_code_linter:metrics analyze lib
  python hooks/scripts/flutter_env.py -- flutter analyze --fatal-infos
  python hooks/scripts/flutter_env.py -- flutter test
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

# Git worktree-context vars that `git commit` exports into hook environments.
# When set, they redirect Flutter's SDK git detection at the wrong checkout.
GIT_WORKTREE_VARS = ("GIT_DIR", "GIT_WORK_TREE")

# Windows script extensions that the OS cannot exec() directly and must be run
# through the shell.
_WINDOWS_SCRIPT_EXTS = {".bat", ".cmd"}


def _is_windows_script(exe: str) -> bool:
    return os.path.splitext(exe)[1].lower() in _WINDOWS_SCRIPT_EXTS


def _resolve_command(name: str) -> str | None:
    """Locate [name] the same way a shell would, including PATHEXT on Windows.

    Returns the resolved path, or None if not found. On Windows this lets a
    bare `flutter` resolve to `flutter.bat` / `flutter.cmd`.
    """
    return shutil.which(name)


def main(argv: list[str]) -> int:
    if not argv or argv[0] != "--":
        print(
            "usage: flutter_env.py -- <flutter> [arg ...]\n"
            "Pass the Flutter command and its arguments after --.",
            file=sys.stderr,
        )
        return 2

    flutter_cmd = argv[1:]
    if not flutter_cmd:
        print("error: no Flutter command given after --", file=sys.stderr)
        return 2

    child_env = {k: v for k, v in os.environ.items() if k not in GIT_WORKTREE_VARS}

    # Resolve the command name so a bare `flutter` finds flutter.bat/.cmd on
    # Windows. Fall back to the raw name if not found — the OS will then produce
    # a normal "not found" error we surface below.
    resolved = _resolve_command(flutter_cmd[0]) or flutter_cmd[0]
    flutter_cmd = [resolved, *flutter_cmd[1:]]

    use_shell = os.name == "nt" and _is_windows_script(resolved)

    if use_shell:
        # Windows .bat/.cmd cannot be exec'd directly; run via the shell with the
        # filtered environment. subprocess propagates the child's exit code and
        # keeps stdin/stdout/stderr connected.
        try:
            result = subprocess.run(
                flutter_cmd,
                env=child_env,
                shell=True,
            )
            return result.returncode
        except FileNotFoundError:
            print(
                f"error: command not found: {flutter_cmd[0]}",
                file=sys.stderr,
            )
            return 127

    # Unix (or a directly-executable binary on either platform): exec the child
    # in-place with the filtered environment. Does not return on success.
    try:
        os.execvpe(flutter_cmd[0], flutter_cmd, child_env)
    except FileNotFoundError:
        print(
            f"error: command not found: {flutter_cmd[0]}",
            file=sys.stderr,
        )
        return 127
    return 1  # unreachable; execvpe does not return on success


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
