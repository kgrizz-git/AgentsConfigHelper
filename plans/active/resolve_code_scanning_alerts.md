# Plan: Resolve open GitHub code-scanning alerts

**Repo:** `kgrizz-git/AgentsConfigHelper`
**Status (via `gh api /repos/kgrizz-git/AgentsConfigHelper/code-scanning/alerts`):** 3 open (`#5`, `#3`, `#2`), 1 already fixed (`#1`).
**Dependabot alerts:** none. **Secret scanning:** none.

## Background / root cause

CI runs `semgrep scan --config p/default` (`.github/workflows/ci.yml:108`) and uploads
SARIF to the Security tab. Alert `#5` stays open despite an existing `# nosemgrep` comment
on line 152 — most likely because the bare `# nosemgrep` (without a rule ID) is unreliable
with managed rulesets. Specifying the rule ID (`# nosemgrep: dynamic-urllib-use-detected`)
is the standard fix. A `.semgrepignore` already exists but only excludes vendored/generated
paths; it does not cover `ci/`.

### Alert `#5` — `dynamic-urllib-use-detected` (`ci/scripts/check_doc_links.py:152`)

- Low-confidence false positive. Already defensively written:
  - Scheme guard at line 146 restricts fetches to `http`/`https` (the rule's real worry is
    `file://` arbitrary file read).
  - URLs come from *tracked markdown in the repo*, not untrusted user input.
- Decision: **not** refactoring to `requests`. That only swaps one flagged pattern for an
  unflagged one (still a dynamic URL), adds a third-party dependency for a single stdlib
  `HEAD` call, and breaks the repo's stdlib-only CI-script convention. The suppression
  approach is cleaner and auditable.

### Alerts `#3` & `#2` — `dependabot-missing-cooldown` (`.github/dependabot.yml:9` and `:3`)

- Both `pub` and `github-actions` ecosystems lack a `cooldown` block. Adding it silences
  the policy rule with no behavioral downside.

## Steps

### Step 1 — Fix Dependabot cooldown (alerts `#2`, `#3`)

Edit `.github/dependabot.yml` to add a `cooldown` block to each `updates` entry.
The `cooldown` key requires a `default` sub-key (and optionally semver-specific overrides).

```yaml
version: 2
updates:
  - package-ecosystem: "pub"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    cooldown:
      default:
        days: 7

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    cooldown:
      default:
        days: 7
```

### Step 2 — Resolve the urllib alert (`#5`)

**Preferred: fix the inline suppression.** Change the bare `# nosemgrep` on line 152 of
`ci/scripts/check_doc_links.py` to include the rule ID:

```python
with urllib.request.urlopen(request, timeout=TIMEOUT) as response:  # nosemgrep: dynamic-urllib-use-detected
```

Then verify locally with `semgrep scan --config p/default` that the finding is suppressed.
This is a zero-collateral one-line change — no new files, no file-level exclusions.

**Fallback: edit `.semgrepignore`.** If the inline fix doesn't suppress the alert (e.g. due
to a Semgrep version quirk), add `ci/scripts/check_doc_links.py` to the existing
`.semgrepignore`. Note: this suppresses *all* rules on that file, not just this one — accept
that trade-off only if the inline approach fails.

Keep the existing runtime scheme guard (line 146) as defense-in-depth regardless.

### Step 3 — Verify locally

- `python3 -m py_compile ci/scripts/check_doc_links.py`
- Validate dependabot.yml:
  `python3 -c "import yaml; yaml.safe_load(open('.github/dependabot.yml'))"`
- `semgrep scan --config p/default` and confirm the `dynamic-urllib-use-detected` finding
  on `check_doc_links.py` is gone.

### Step 4 — Commit & confirm in GitHub

- Commit `.github/dependabot.yml` and (if needed) `ci/scripts/check_doc_links.py` or
  `.semgrepignore`.
- After the next CI run, the Security tab should show `#2`, `#3`, `#5` as resolved /
  dismissed with the documented reason.

## Files touched

- `.github/dependabot.yml` — edit (add `cooldown`).
- `ci/scripts/check_doc_links.py` — edit line 152 (add rule ID to `# nosemgrep`).
- `.semgrepignore` — edit only if inline suppression fails (fallback; file already exists).

## Caveats

- `#5` is treated as a justified false positive via an explicit, documented suppression
  rather than a library swap. If zero suppressions are desired, the only real alternative is
  refactoring the fetcher to `requests` (adds a dependency, no security gain) — rejected.
