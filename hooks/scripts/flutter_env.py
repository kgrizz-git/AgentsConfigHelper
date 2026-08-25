#!/usr/bin/env python3
"""
flutter_env.py — run an approved Flutter hook task with git worktree-context
cleared.

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

Cross-platform: the hook selects one of the fixed task definitions below; it
never forwards an arbitrary command or argument vector. This keeps the
Windows launcher avoids requesting a command shell while preserving the three
hook behaviors that CI runs. On Unix it preserves exec semantics; on Windows it
propagates the child exit code with inherited stdin/stdout/stderr.

Usage (pre-commit wires this automatically):
  python hooks/scripts/flutter_env.py metrics
  python hooks/scripts/flutter_env.py analyze
  python hooks/scripts/flutter_env.py test
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

# Git worktree-context vars that `git commit` exports into hook environments.
# When set, they redirect Flutter's SDK git detection at the wrong checkout.
GIT_WORKTREE_VARS = ("GIT_DIR", "GIT_WORK_TREE")

TASKS: dict[str, tuple[str, ...]] = {
    "metrics": (
        "pub",
        "run",
        "dart_code_linter:metrics",
        "analyze",
        "lib",
        "--set-exit-on-violation-level=warning",
    ),
    "analyze": ("analyze", "--fatal-infos"),
    "test": ("test",),
}


def filtered_environment() -> dict[str, str]:
    """Return the child environment without git's worktree-context variables."""
    return {k: v for k, v in os.environ.items() if k not in GIT_WORKTREE_VARS}


def flutter_command(task: str) -> list[str]:
    """Build a fixed task command, resolving Flutter's Windows batch launcher."""
    return [shutil.which("flutter") or "flutter", *TASKS[task]]


def main(argv: list[str]) -> int:
    if len(argv) != 1 or argv[0] not in TASKS:
        print(
            "usage: flutter_env.py <task>\n"
            f"Choose one of: {', '.join(TASKS)}.",
            file=sys.stderr,
        )
        return 2

    flutter_cmd = flutter_command(argv[0])
    child_env = filtered_environment()

    if os.name == "nt":
        try:
            result = subprocess.run(
                flutter_cmd,
                env=child_env,
                check=False,
            )
            return result.returncode
        except FileNotFoundError:
            print(
                f"error: command not found: {flutter_cmd[0]}",
                file=sys.stderr,
            )
            return 127

    # Unix: exec the child in-place with the filtered environment. Does not
    # return on success.
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
