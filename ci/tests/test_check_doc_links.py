#!/usr/bin/env python3
"""Tests for the deterministic (offline, internal) behavior of check_doc_links.py.

Runs under the Python stdlib unittest (no third-party test dependency). These
tests never make network requests. They cover the behaviors called out in
plans/active/tool-catalog-integrity.md Phase 2:

* tmp/ (and other skip dirs) are excluded
* docs/supported-tools.md is explicitly catalog-checked (path-form normalized)
* valid / stale / malformed catalog review dates (staleness is ALWAYS advisory)
* internal relative links (broken vs. resolvable)
* external links are advisory (non-fatal) under default/offline runs
* --catalog-strict fails on a missing or malformed marker, registry tool, or catalog file,
  but a stale date remains advisory (does not fail)
* REGISTRY_NAMES stays in sync with the Dart registry's displayName values
"""

from __future__ import annotations

import contextlib
import io
import os
import re
import subprocess
import sys
import textwrap
import unittest
from datetime import date, timedelta
from pathlib import Path

# Import the module under test. The script lives at ci/scripts/check_doc_links.py
# relative to the repo root; tests run from the repo root (either via
# `python3 ci/tests/test_check_doc_links.py` or unittest discovery).
_SCRIPT = Path(__file__).resolve().parents[2] / "ci" / "scripts" / "check_doc_links.py"
sys.path.insert(0, str(_SCRIPT.parent))
import check_doc_links as cd  # noqa: E402


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _write(tmp_path: Path, rel: str, body: str) -> Path:
    target = tmp_path / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(textwrap.dedent(body), encoding="utf-8")
    return target


def _run(cwd: Path, *args: str) -> tuple[int, str, str]:
    """Run the CLI in an isolated subprocess so argparse/sys.exit behave normally."""
    proc = subprocess.run(
        [sys.executable, str(_SCRIPT), *args],
        cwd=str(cwd),
        capture_output=True,
        text=True,
        check=False,
    )
    return proc.returncode, proc.stdout, proc.stderr


# ---------------------------------------------------------------------------
# Unit tests for pure helpers
# ---------------------------------------------------------------------------


class PureHelperTests(unittest.TestCase):
    def test_strip_code_blanks_fenced_blocks(self):
        src = "before\n```\n[link](ignored.md)\n```\nafter"
        self.assertNotIn("ignored", cd.strip_code(src))

    def test_find_external_collects_unique_http_links(self):
        text = "see [a](https://example.com) and [b](https://example.com) and [c](http://other)"
        self.assertEqual(set(cd.find_external(text)), {"https://example.com", "http://other"})

    def test_find_external_ignores_relative_and_mailto(self):
        text = "[rel](foo.md)[mailto](mailto:x@y)[anchor](#frag)"
        self.assertEqual(cd.find_external(text), [])


class CatalogDateTests(unittest.TestCase):
    """Date handling: staleness is always advisory, never a hard failure."""

    def _today(self) -> str:
        return date.today().isoformat()

    def _stale(self) -> str:
        return (date.today() - timedelta(days=cd.CATALOG_WINDOW_DAYS + 1)).isoformat()

    def test_none_when_no_marker(self):
        self.assertIsNone(cd.check_catalog_date("no marker here"))

    def test_stale_returns_advisory_string(self):
        text = f"Catalog reviewed through: {self._stale()}\n"
        result = cd.check_catalog_date(text)
        self.assertIsNotNone(result)
        self.assertIn("days ago", result)

    def test_ok_when_within_window(self):
        self.assertIsNone(cd.check_catalog_date(f"Catalog reviewed through: {self._today()}\n"))

    def test_unparseable(self):
        text = "Catalog reviewed through: 2026-13-99\n"
        result = cd.check_catalog_date(text)
        self.assertIsNotNone(result)
        self.assertIn("unparseable", result)


class CatalogMarkerTests(unittest.TestCase):
    def test_marker_missing(self):
        self.assertIn("missing required", cd.check_catalog_marker("no marker"))

    def test_marker_malformed(self):
        self.assertIn("malformed", cd.check_catalog_marker("Catalog reviewed through: 2026-13-99"))

    def test_marker_valid(self):
        today = date.today().isoformat()
        self.assertIsNone(cd.check_catalog_marker(f"Catalog reviewed through: {today}"))


class RegistryCoverageTests(unittest.TestCase):
    def test_detects_missing(self):
        path = Path("docs/supported-tools.md")
        problems = cd.check_registry_coverage(path, "Only Claude Code is here.\n")
        self.assertTrue(all("not found" in p for p in problems))
        missing_names = {p.split("'")[1] for p in problems}
        self.assertIn("Codex", missing_names)
        self.assertNotIn("Claude Code", missing_names)

    def test_passes_when_all_present(self):
        body = "\n".join(cd.REGISTRY_NAMES) + "\n"
        path = Path("docs/supported-tools.md")
        self.assertEqual(cd.check_registry_coverage(path, body), [])


# ---------------------------------------------------------------------------
# Skip-dir / eligibility tests
# ---------------------------------------------------------------------------


class SkipDirTests(unittest.TestCase):
    def test_iter_markdown_excludes_skip_dirs(self):
        with _tmp_cwd() as tmp:
            _write(tmp, "ok.md", "ok")
            _write(tmp, "tmp/junk.md", "junk")
            _write(tmp, "node_modules/pkg/readme.md", "junk")
            _write(tmp, "real/tmp.md", "real but named tmp at depth")  # not a skip dir
            found = {p.name for p in cd.iter_markdown([])}
            self.assertNotIn("junk.md", found)
            self.assertNotIn("readme.md", found)
            self.assertIn("ok.md", found)
            self.assertIn("tmp.md", found)  # only the *dir* tmp is skipped

    def test_iter_markdown_excludes_files_outside_root(self):
        with _tmp_cwd() as tmp:
            outside = tmp.parent / "outside.md"
            outside.write_text("outside", encoding="utf-8")
            try:
                found = [str(p) for p in cd.iter_markdown([outside])]
                self.assertEqual(found, [])
            finally:
                outside.unlink()


# ---------------------------------------------------------------------------
# Internal link checks
# ---------------------------------------------------------------------------


class InternalLinkTests(unittest.TestCase):
    def test_broken_link(self):
        with _tmp_cwd() as tmp:
            path = _write(tmp, "sub/page.md", "[missing](nope.md)\n")
            problems = cd.check_internal(path, path.read_text())
            self.assertEqual(len(problems), 1)
            self.assertIn("broken relative link", problems[0])

    def test_anchor_only_is_ok(self):
        with _tmp_cwd() as tmp:
            path = _write(tmp, "page.md", "[sec](#section)\n")
            self.assertEqual(cd.check_internal(path, path.read_text()), [])

    def test_expected_absent_is_ok(self):
        # .context/ is generated at runtime and intentionally absent.
        with _tmp_cwd() as tmp:
            path = _write(tmp, "page.md", "[ctx](.context/something.md)\n")
            self.assertEqual(cd.check_internal(path, path.read_text()), [])


# ---------------------------------------------------------------------------
# Catalog detection (path-form normalized)
# ---------------------------------------------------------------------------


class CatalogDetectionTests(unittest.TestCase):
    def test_matches_explicit_supported_tools(self):
        with _tmp_cwd() as tmp:
            self.assertTrue(cd._is_catalog(Path("docs/supported-tools.md")))
            self.assertTrue(cd._is_catalog(Path("inventory/tools-index.md")))
            self.assertFalse(cd._is_catalog(Path("docs/other.md")))

    def test_matches_with_leading_dot_slash(self):
        """Explicit catalog paths must match even when invoked as `./docs/...`."""
        self.assertTrue(cd._is_catalog(Path("./docs/supported-tools.md")))

    def test_matches_absolute_path(self):
        """Explicit catalog paths must match when given as absolute paths."""
        abs_path = Path.cwd() / "docs" / "supported-tools.md"
        self.assertTrue(cd._is_catalog(abs_path))


# ---------------------------------------------------------------------------
# External link handling — deterministic, no network
# ---------------------------------------------------------------------------


class ExternalLinkTests(unittest.TestCase):
    """External-link parsing is exercised without any network access.

    We verify the pure URL-classification logic (find_external) and the
    scheme/host guards in check_link using inputs that resolve without I/O
    (unsupported scheme, skip-listed host). No urlopen is performed.
    """

    def test_find_external_basic(self):
        text = "[a](https://example.com/a) [b](http://example.com/b)"
        urls = cd.find_external(text)
        self.assertEqual(len(urls), 2)

    def test_check_link_unsupported_scheme_returns_tuple_without_io(self):
        # file:// is not http/https → handled by the scheme guard, no socket.
        result = cd.check_link("file:///etc/passwd")
        self.assertIsNotNone(result)
        self.assertIn("unsupported URL scheme", result[1])

    def test_check_link_skip_host_returns_none_without_io(self):
        # Skip-listed hosts short-circuit before any network access.
        self.assertIsNone(cd.check_link("https://twitter.com/whatever"))
        self.assertIsNone(cd.check_link("https://x.com/whatever"))

    def test_check_link_malformed_url_returns_tuple_without_io(self):
        # Malformed netloc → urlsplit raises ValueError, caught internally.
        result = cd.check_link("https://[bad")
        self.assertIsNotNone(result)
        self.assertIn("invalid URL", result[1])


# ---------------------------------------------------------------------------
# End-to-end CLI behavior via main()
# ---------------------------------------------------------------------------


class CliTests(unittest.TestCase):
    def test_internal_only_passes_on_clean_tree(self):
        with _tmp_cwd() as tmp:
            _write(tmp, "docs/supported-tools.md", "# Supported Tools\n")
            _write(tmp, "docs/other.md", "[link](supported-tools.md)\n")
            code, out, _ = _run(tmp, "--internal-only")
            self.assertEqual(code, 0, out)
            self.assertIn("0 broken", out)

    def test_internal_only_fails_on_broken_link_under_strict(self):
        with _tmp_cwd() as tmp:
            _write(tmp, "docs/supported-tools.md", "# Supported Tools\n")
            _write(tmp, "docs/other.md", "[missing](does-not-exist.md)\n")
            code, out, _ = _run(tmp, "--internal-only", "--strict")
            self.assertEqual(code, 1, out)
            self.assertIn("BROKEN", out)

    def test_catalog_strict_fails_on_missing_marker(self):
        with _tmp_cwd() as tmp:
            _write(tmp, "docs/supported-tools.md", "# Supported Tools\n")
            code, out, _ = _run(tmp, "--internal-only", "--catalog-strict")
            self.assertEqual(code, 1, out)
            self.assertIn("missing required", out)

    def test_catalog_strict_fails_when_primary_catalog_is_missing(self):
        with _tmp_cwd() as tmp:
            _write(tmp, "docs/other.md", "# Other documentation\n")
            code, out, _ = _run(tmp, "--internal-only", "--catalog-strict")
            self.assertEqual(code, 1, out)
            self.assertIn("required catalog file was not found", out)

    def test_catalog_strict_fails_on_malformed_date(self):
        with _tmp_cwd() as tmp:
            _write(tmp, "docs/supported-tools.md", "Catalog reviewed through: 2026-99-99\n")
            code, out, _ = _run(tmp, "--internal-only", "--catalog-strict")
            self.assertEqual(code, 1, out)
            self.assertIn("malformed", out)

    def test_catalog_strict_fails_on_missing_registry_tool(self):
        today = date.today().isoformat()
        with _tmp_cwd() as tmp:
            _write(
                tmp,
                "docs/supported-tools.md",
                f"Catalog reviewed through: {today}\n\n# Empty catalog\n",
            )
            code, out, _ = _run(tmp, "--internal-only", "--catalog-strict")
            self.assertEqual(code, 1, out)
            self.assertIn("not found in catalog body", out)

    def test_catalog_strict_passes_on_well_formed_catalog(self):
        today = date.today().isoformat()
        body = f"Catalog reviewed through: {today}\n\n" + "\n".join(cd.REGISTRY_NAMES) + "\n"
        with _tmp_cwd() as tmp:
            _write(tmp, "docs/supported-tools.md", body)
            code, out, _ = _run(tmp, "--internal-only", "--catalog-strict")
            self.assertEqual(code, 0, out)

    def test_ci_command_passes_against_real_supported_tools(self):
        """The exact CI command (--internal-only --catalog-strict) must pass against the real,
        committed docs/supported-tools.md. Guards the now-wired catalog gate: the file must
        carry a valid 'Catalog reviewed through:' marker and name every registry tool, or CI fails.
        Runs from the repo root so the committed file is read (not a temp copy)."""
        repo_root = Path(__file__).resolve().parents[2]
        real_file = repo_root / "docs" / "supported-tools.md"
        self.assertTrue(real_file.is_file(), f"missing {real_file}")
        code, out, _ = _run(repo_root, "--internal-only", "--catalog-strict", "docs/supported-tools.md")
        self.assertEqual(code, 0, f"CI catalog gate failed against real file: {out}")

    # --- B2 regression: staleness must remain advisory even under --catalog-strict ---

    def test_catalog_strict_stale_date_is_advisory_not_failure(self):
        """A stale review date is advisory (Phase 3 monthly), never a strict failure.

        --catalog-strict must exit 0 when the marker is present and parseable but
        stale, and the catalog names every registry tool. Only missing/malformed
        markers and missing tools are strict failures.
        """
        stale = (date.today() - timedelta(days=cd.CATALOG_WINDOW_DAYS + 1)).isoformat()
        body = f"Catalog reviewed through: {stale}\n\n" + "\n".join(cd.REGISTRY_NAMES) + "\n"
        with _tmp_cwd() as tmp:
            _write(tmp, "docs/supported-tools.md", body)
            code, out, _ = _run(tmp, "--internal-only", "--catalog-strict")
            self.assertEqual(code, 0, f"stale date should be advisory, not fatal: {out}")
            # The stale date should still be *reported* as advisory output.
            self.assertIn("STALE", out)

    def test_external_links_are_advisory_not_fatal(self):
        """Under --offline, external links are not probed at all (no DEAD line).

        External liveness is advisory only and requires network access, so the
        deterministic offline run must neither probe them nor fail. We assert
        exit 0 and that no DEAD finding is emitted.
        """
        with _tmp_cwd() as tmp:
            _write(
                tmp,
                "docs/supported-tools.md",
                "See [docs](https://example.com/docs) for details.\n",
            )
            code, out, _ = _run(tmp, "--offline")
            self.assertEqual(code, 0, out)
            # Under --offline the external link must not be probed at all.
            self.assertNotIn("DEAD", out)


# ---------------------------------------------------------------------------
# M1: registry displayName drift test (offline, parses Dart source text)
# ---------------------------------------------------------------------------


class RegistryDriftTests(unittest.TestCase):
    """REGISTRY_NAMES must equal the displayName values in the Dart registry.

    This is an offline text extraction from lib/catalog/tool_descriptor_registry.dart;
    it does not run the Dart toolchain. It fails loudly if a tool is added or
    renamed in Dart without a matching update to REGISTRY_NAMES.
    """

    def test_registry_names_match_dart_display_names(self):
        registry = (
            Path(__file__).resolve().parents[2]
            / "lib"
            / "catalog"
            / "tool_descriptor_registry.dart"
        )
        text = registry.read_text(encoding="utf-8", errors="ignore")
        # Extract every displayName: '<value>' literal.
        dart_names = re.findall(r"displayName:\s*'([^']*)'", text)
        expected = sorted(set(dart_names))
        actual = sorted(cd.REGISTRY_NAMES)
        self.assertEqual(
            actual,
            expected,
            f"REGISTRY_NAMES is out of sync with {registry.name}. "
            f"Missing: {set(expected) - set(actual)}; "
            f"Extra: {set(actual) - set(expected)}",
        )


# ---------------------------------------------------------------------------
# Test scaffolding
# ---------------------------------------------------------------------------


@contextlib.contextmanager
def _tmp_cwd():
    """Context manager yielding a temp dir with cwd restored afterwards."""
    prev = Path.cwd()
    import tempfile

    tmp = Path(tempfile.mkdtemp())
    os.chdir(tmp)
    try:
        yield tmp
    finally:
        os.chdir(prev)


if __name__ == "__main__":
    unittest.main()
