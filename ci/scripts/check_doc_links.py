#!/usr/bin/env python3
"""
check_doc_links.py — keep documentation links and tool catalogs from rotting.

Three checks, two of which run offline and are cheap enough for CI on every push:

1. Internal links  — every relative markdown link resolves to a file that exists.
                     Catches renamed/moved docs and wrong `../` depth, the most common
                     rot in a repo whose entire value is cross-linked guidance.
2. Link liveness   — external links in tool catalogs still resolve (network).
                     404/410 = gone; a GitHub redirect = renamed or transferred.
3. Catalog review  — files carrying `Catalog reviewed through: YYYY-MM-DD` must refresh it
                     more often than the prose window, because the *menu* goes stale faster
                     than the *description*. An entry can read perfectly while the project
                     behind it has been archived.

Checks 2 and 3 are advisory: they report, a human decides whether a tool was replaced,
is merely quiet, or should be dropped. Automating that judgement is how inventories
fill with noise. Check 1 is mechanical and safe to gate on.

The supported-tool catalog (``docs/supported-tools.md``) is the curated public record
of what the app discovers. Because it is hand-maintained evidence rather than generated
output, it is checked explicitly — not merely as another ``inventory/`` file. Under
``--catalog-strict`` (part of the routine PR CI command, activated only after the catalog
review marker is truthfully added) the checker additionally requires:

* a present and valid (well-formed, parseable) ``Catalog reviewed through: YYYY-MM-DD``
  marker, and
* that the catalog evidence table has exactly one row for every registry tool display name.

A stale review date (``check_catalog_date``) is always **advisory**, never a strict
failure — per the plan, date staleness feeds the monthly advisory/review process
(Phase 3), not the PR gate. A missing, malformed, or future-dated marker is strict.

Registry coverage parses only the ``Tool`` column of the committed ``## Catalog evidence``
table; it does not parse Dart. The expected names are enumerated in ``REGISTRY_NAMES``
below and must be kept in sync with ``lib/catalog/tool_descriptor_registry.dart``.

Usage:
  python3 ci/scripts/check_doc_links.py                    # everything, incl. network
  python3 ci/scripts/check_doc_links.py --offline          # internal links + dates only
  python3 ci/scripts/check_doc_links.py --internal-only    # just check 1
  python3 ci/scripts/check_doc_links.py --strict           # exit 1 on findings
  python3 ci/scripts/check_doc_links.py --catalog-strict   # exit 1 on broken links, missing/malformed marker, or missing/duplicate registry row (PR gate)
  python3 ci/scripts/check_doc_links.py docs/NAVIGATION.md

Exit codes: 0 = ok (or advisory), 1 = findings under --strict, 2 = usage error.
"""

from __future__ import annotations

import argparse
import concurrent.futures
from collections import Counter
import re
import sys
import urllib.error
import urllib.request
from datetime import date
from pathlib import Path
from urllib.parse import urlsplit

CATALOG_WINDOW_DAYS = 120  # tighter than the 180-day prose window on purpose

# Catalog scope is explicit. ``docs/supported-tools.md`` is the curated public catalog
# and is always treated as a catalog file regardless of its directory. ``inventory/``
# entries that carry a review marker are still checked for staleness.
CATALOG_PATHS: tuple[Path, ...] = (Path("docs/supported-tools.md"),)
CATALOG_DIRS = ("inventory",)

# Expected registry tool display names (from lib/catalog/tool_descriptor_registry.dart).
# Used by --catalog-strict to confirm the catalog evidence table has exactly one row for
# every registered tool. Does not parse Dart sources.
REGISTRY_NAMES = (
    "Claude Code",
    "Codex",
    "Opencode",
    "Paseo",
    "Cursor IDE",
    "Cursor Agent",
    "Kiro",
    "Devin",
    "Antigravity IDE",
    "Antigravity App",
    "Antigravity CLI",
    "Agy-ACP",
    "Kilo",
    "Cline",
    "LM Studio",
    "GitHub Copilot",
    "AGENTS.md (shared)",
)

LINK_RE = re.compile(r"\[[^\]]*\]\(\s*([^)\s]+?)\s*\)")
CATALOG_RE = re.compile(r"^Catalog reviewed through:\s*(\d{4}-\d{2}-\d{2})\s*$", re.MULTILINE)
CODE_FENCE_RE = re.compile(r"^```.*?^```", re.MULTILINE | re.DOTALL)
CATALOG_EVIDENCE_HEADING = "## Catalog evidence"
CATALOG_EVIDENCE_COLUMNS = (
    "Tool",
    "Discovery coverage",
    "Primary evidence",
    "Schema evidence",
    "Fixture/reference",
    "Reviewed",
)

TIMEOUT = 10
USER_AGENT = "template-repo-doc-link-check/1.0"

SKIP_DIRS = {
    ".git",
    "node_modules",
    "__pycache__",
    ".pytest_cache",
    ".ruff_cache",
    "tmp",
    "worktrees",
}

# Hosts that reject automated HEAD requests; a failure there is not evidence of rot.
SKIP_HOSTS = ("twitter.com", "x.com", "linkedin.com", "reddit.com")

# Relative targets that are generated at runtime and correctly absent from the template.
EXPECTED_ABSENT = (".context/",)


def _is_within_repo(path: Path, root: Path) -> bool:
    try:
        return path.resolve().is_relative_to(root.resolve())
    except OSError:
        return False


def _is_eligible_markdown(path: Path) -> bool:
    return (
        path.suffix == ".md"
        and path.exists()
        and not (SKIP_DIRS & set(path.parts))
    )


def iter_markdown(paths: list[Path]) -> list[Path]:
    """
    Collect eligible Markdown files from the supplied paths or the repository.
    
    Parameters:
    	paths (list[Path]): Markdown paths to validate explicitly. An empty list triggers recursive discovery from the current directory.
    
    Returns:
    	list[Path]: Eligible Markdown files, sorted when discovered recursively.
    """
    if paths:
        root = Path.cwd()
        valid = []
        for p in paths:
            if not _is_eligible_markdown(p):
                continue
            if not _is_within_repo(p, root):
                print(f"[links] SKIP   {p}: outside repo root, refusing to read", file=sys.stderr)
                continue
            valid.append(p)
        return valid
    found = []
    for path in Path(".").rglob("*.md"):
        if not _is_eligible_markdown(path):
            continue
        found.append(path)
    return sorted(found)


def _is_catalog(path: Path) -> bool:
    """A file is a catalog when it is an explicit catalog path or lives in a catalog dir.

    Matches against the path as-is and resolved against cwd, so explicit catalog
    paths match regardless of whether they are invoked as ``docs/supported-tools.md``,
    ``./docs/supported-tools.md``, or an absolute path.
    """
    if _is_catalog_strict(path):
        return True
    return bool(set(path.parts) & set(CATALOG_DIRS))


def _is_catalog_strict(path: Path) -> bool:
    """
    Determine whether a path identifies an explicit primary catalog file.
    
    Returns:
        bool: `True` if the path resolves to a primary catalog path, `False` otherwise.
    """
    candidates = {path}
    try:
        candidates.add(path.resolve())
        candidates.add((Path.cwd() / path).resolve())
    except OSError:
        pass
    try:
        resolved_candidates = {c.resolve() for c in candidates}
    except OSError:
        resolved_candidates = candidates
    resolved_catalog = {p.resolve() for p in CATALOG_PATHS}
    return bool(resolved_candidates & resolved_catalog)


def strip_code(text: str) -> str:
    """
    Replace fenced code blocks with blank lines so their contents are ignored during Markdown link analysis.
    
    Parameters:
    	text (str): Markdown content that may contain fenced code blocks.
    
    Returns:
    	str: The content with fenced code blocks replaced by blank lines.
    """
    return CODE_FENCE_RE.sub(lambda m: "\n" * m.group(0).count("\n"), text)


def check_internal(path: Path, text: str) -> list[str]:
    problems = []
    for match in LINK_RE.finditer(text):
        target = match.group(1)
        if target.startswith(("http://", "https://", "mailto:", "#", "<")):
            continue
        clean = target.split("#", 1)[0].split("?", 1)[0]
        if not clean:
            continue
        if any(frag in clean for frag in EXPECTED_ABSENT):
            continue
        if not (path.parent / clean).resolve().exists():
            line = text[: match.start()].count("\n") + 1
            problems.append(f"{path}:{line}: broken relative link → {target}")
    return problems


def find_external(text: str) -> list[str]:
    seen: dict[str, None] = {}
    for match in LINK_RE.finditer(text):
        url = match.group(1)
        if url.startswith(("http://", "https://")):
            seen.setdefault(url.rstrip("."), None)
    return list(seen)


def _host_matches(host: str, domains: tuple[str, ...]) -> bool:
    """True when [host] equals one of [domains] or is a subdomain of it.

    Compares the parsed host rather than doing a substring check, so a domain
    cannot match at an arbitrary position (e.g. 'github.com' in a path or a
    look-alike host like 'github.com.evil.example').
    """
    return any(host == d or host.endswith("." + d) for d in domains)


def check_link(url: str) -> tuple[str, str] | None:
    """Return (url, problem) when the link looks dead or moved, else None."""
    # Parse once, inside a guard: urlsplit()/.hostname raise ValueError on
    # malformed netlocs (e.g. bad IPv6 brackets), which must become a per-link
    # result rather than crash the whole run.
    try:
        parts = urlsplit(url)
        host = (parts.hostname or "").lower()
    except ValueError as error:
        return (url, f"invalid URL: {error}")

    if _host_matches(host, SKIP_HOSTS):
        return None
    # Only ever fetch http(s). urllib also understands file://, ftp://, etc., so
    # guard the scheme at the sink even though callers already pass http(s) URLs —
    # defense in depth against a dynamic value reaching urlopen.
    if parts.scheme not in ("http", "https"):
        return (url, "unsupported URL scheme — only http/https are checked")
    request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": USER_AGENT})
    try:
        # Scheme restricted to http/https above; this is a documentation link
        # from a tracked markdown file, not user input.
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:  # nosemgrep: dynamic-urllib-use-detected
            final = response.geturl()
            # A GitHub repo redirect means the project was renamed or transferred.
            if host == "github.com" and final.rstrip("/") != url.rstrip("/"):
                return (url, f"redirects to {final} — renamed or transferred?")
        return None
    except urllib.error.HTTPError as error:
        if error.code in (404, 410):
            return (url, f"HTTP {error.code} — gone")
        if error.code in (401, 403, 405, 429):
            return None  # auth walls, method rejection, and rate limits are not rot
        return (url, f"HTTP {error.code}")
    except (urllib.error.URLError, TimeoutError, ValueError) as error:
        return (url, f"unreachable: {error}")


def check_catalog_date(text: str) -> str | None:
    """
    Check whether a catalog review marker contains a valid, current date.
    
    Parameters:
    	text (str): Markdown content that may include a catalog review marker.
    
    Returns:
    	str | None: A finding describing an invalid, future, or stale review date; otherwise, `None`.
    """
    match = CATALOG_RE.search(text)
    if not match:
        return None  # marker is opt-in; only files claiming a catalog review are checked
    try:
        reviewed = date.fromisoformat(match.group(1))
    except ValueError:
        return f"unparseable 'Catalog reviewed through' date: {match.group(1)}"
    if reviewed > date.today():
        return f"catalog review date {reviewed} is in the future"
    age = (date.today() - reviewed).days
    if age > CATALOG_WINDOW_DAYS:
        return (
            f"catalog last reviewed {reviewed} ({age} days ago, window {CATALOG_WINDOW_DAYS}). "
            "Re-ask whether this is still the right menu, then refresh the date."
        )
    return None


def check_catalog_marker(text: str) -> str | None:
    """
    Validate the catalog review marker's presence, format, and date.
    
    Parameters:
        text (str): Catalog text to inspect.
    
    Returns:
        str | None: An error message for a missing, malformed, or future review marker; otherwise, None.
    """
    match = CATALOG_RE.search(text)
    if not match:
        return "missing required 'Catalog reviewed through: YYYY-MM-DD' marker"
    try:
        reviewed = date.fromisoformat(match.group(1))
    except ValueError:
        return f"malformed 'Catalog reviewed through' date: {match.group(1)}"
    if reviewed > date.today():
        return f"future 'Catalog reviewed through' date: {reviewed}"
    return None


def catalog_evidence_tool_rows(text: str) -> tuple[list[str] | None, str | None]:
    """
    Extracts tool names from the catalog evidence table.
    
    Parameters:
        text (str): Markdown content containing the catalog evidence section.
    
    Returns:
        tuple[list[str] | None, str | None]: The Tool-column values and no error, or `None` and an error description when the section or table is invalid.
    """
    lines = text.splitlines()
    try:
        start = lines.index(CATALOG_EVIDENCE_HEADING)
    except ValueError:
        return None, f"missing {CATALOG_EVIDENCE_HEADING!r} section"

    header_index = next(
        (
            index
            for index in range(start + 1, len(lines))
            if _markdown_table_cells(lines[index]) == list(CATALOG_EVIDENCE_COLUMNS)
        ),
        None,
    )
    if header_index is None:
        return None, "missing six-column catalog evidence table header"
    if header_index + 1 >= len(lines) or not _is_markdown_table_delimiter(lines[header_index + 1]):
        return None, "catalog evidence table is missing its delimiter row"

    rows: list[str] = []
    for line in lines[header_index + 2 :]:
        cells = _markdown_table_cells(line)
        if cells is None:
            break
        if len(cells) != len(CATALOG_EVIDENCE_COLUMNS) or any(not cell for cell in cells):
            return None, "catalog evidence table has an incomplete row"
        rows.append(cells[0])
    if not rows:
        return None, "catalog evidence table has no rows"
    return rows, None


def _markdown_table_cells(line: str) -> list[str] | None:
    """
    Parse a pipe-delimited Markdown table row into trimmed cell values.
    
    Parameters:
    	line (str): The table row text to parse.
    
    Returns:
    	list[str] | None: The trimmed cell values, or `None` if the input is not enclosed by pipe characters.
    """
    stripped = line.strip()
    if not (stripped.startswith("|") and stripped.endswith("|")):
        return None
    return [cell.strip() for cell in stripped.strip("|").split("|")]


def _is_markdown_table_delimiter(line: str) -> bool:
    """Determine whether a line is a valid six-column Markdown table delimiter."""
    cells = _markdown_table_cells(line)
    return bool(cells) and len(cells) == len(CATALOG_EVIDENCE_COLUMNS) and all(
        re.fullmatch(r":?-{3,}:?", cell) for cell in cells
    )


def check_registry_coverage(path: Path, text: str) -> list[str]:
    """Confirm the catalog evidence table contains each registry tool exactly once."""
    rows, error = catalog_evidence_tool_rows(text)
    if error:
        return [f"{path}: {error}"]

    counts = Counter(rows)
    problems: list[str] = []
    for name in REGISTRY_NAMES:
        if counts[name] == 0:
            problems.append(f"{path}: registry tool {name!r} has no catalog evidence row")
        elif counts[name] > 1:
            problems.append(f"{path}: registry tool {name!r} has duplicate catalog evidence rows")
    return problems


def main() -> int:
    """
    Run the Markdown link and tool-catalog checks for the selected files.
    
    Parameters:
        None
    
    Returns:
        int: Exit code 2 when no Markdown files are found, 1 when enabled strict checks fail, or 0 otherwise.
    """
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("files", nargs="*", type=Path, help="markdown files (default: all)")
    parser.add_argument("--offline", action="store_true", help="skip network checks")
    parser.add_argument("--internal-only", action="store_true", help="only check relative links")
    parser.add_argument("--strict", action="store_true", help="exit 1 when findings exist")
    parser.add_argument(
        "--catalog-strict",
        action="store_true",
        help="exit 1 when the supported-tool catalog is missing or has a malformed "
        "'Catalog reviewed through' marker, or omits/duplicates an expected registry tool row. "
        "A stale date is advisory only (does not fail).",
    )
    args = parser.parse_args()

    paths = iter_markdown(args.files)
    if not paths:
        print("No markdown files found.", file=sys.stderr)
        return 2

    broken = 0
    advisory = 0
    catalog_findings = 0
    primary_catalog_seen = False
    network = not (args.offline or args.internal_only)

    for path in paths:
        if _is_catalog_strict(path):
            primary_catalog_seen = True
        raw = path.read_text(encoding="utf-8", errors="ignore")
        text = strip_code(raw)

        for problem in check_internal(path, text):
            print(f"[links] BROKEN {problem}")
            broken += 1

        if _is_catalog(path):
            stale = check_catalog_date(raw)
            if stale:
                print(f"[links] STALE  {path}: {stale}")
                advisory += 1

            if args.catalog_strict and _is_catalog_strict(path):
                marker_problem = check_catalog_marker(raw)
                if marker_problem:
                    print(f"[links] CATALOG {path}: {marker_problem}")
                    catalog_findings += 1
                for problem in check_registry_coverage(path, raw):
                    print(f"[links] CATALOG {problem}")
                    catalog_findings += 1

        if not (network and _is_catalog(path)):
            continue
        urls = find_external(text)
        if not urls:
            continue
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            for result in pool.map(check_link, urls):
                if result:
                    url, problem = result
                    print(f"[links] DEAD   {path}: {url} — {problem}")
                    advisory += 1

    if args.catalog_strict and not primary_catalog_seen:
        print(
            "[links] CATALOG docs/supported-tools.md: required catalog file was not found"
        )
        catalog_findings += 1

    mode = " (internal only)" if args.internal_only else " (offline)" if args.offline else ""
    print(f"\nChecked {len(paths)} file(s){mode}: {broken} broken, {advisory} advisory.")
    if broken:
        print("Broken relative links are mechanical — fix the path or remove the link.")
    if advisory:
        print(
            "A dead link, rename, or stale catalog date is a prompt to re-evaluate the entry, "
            "not to delete it automatically. Record the outcome and refresh the review date."
        )
    if catalog_findings:
        print(
            "Catalog gaps (missing/malformed marker, or missing/duplicate registry tool row) "
            "must be resolved before merge."
        )

    if args.strict and broken:
        return 1
    if args.catalog_strict and (broken or catalog_findings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
