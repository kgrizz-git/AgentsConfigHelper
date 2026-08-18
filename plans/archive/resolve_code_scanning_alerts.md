# Plan: Resolve open GitHub code-scanning alerts

**Repo:** `kgrizz-git/AgentsConfigHelper`
**Status:** changes shipped in PR #8 (commit `53c6d46`); closure of alerts #2, #3, #5 pending CI and Security-tab confirmation.
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

### Step 1 — Fix Dependabot cooldown (alerts `#2`, `#3`) ✓

Edit `.github/dependabot.yml` to add a `cooldown` block to each `updates` entry.
The `cooldown` key uses flat hyphenated keys (`default-days`, `semver-major-days`, etc.).

```yaml
version: 2
updates:
  - package-ecosystem: "pub"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    cooldown:
      default-days: 7

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    cooldown:
      default-days: 7
```

### Step 2 — Resolve the urllib alert (`#5`) ✓

Shipped: inline suppression with rule ID. `.semgrepignore` fallback not needed.

### Step 3 — Verify locally ✓

Verified: `py_compile` passes, `dependabot.yml` is valid YAML.

### Step 4 — Commit & confirm in GitHub ✓

Shipped in PR #8. Pending: post-merge Security-tab confirmation that alerts #2, #3, #5
auto-close after the next CI run.

## Files touched

- `.github/dependabot.yml` — edited (added `cooldown` with `default-days: 7`).
- `ci/scripts/check_doc_links.py` — edited line 152 (added rule ID to `# nosemgrep`).
- `.semgrepignore` — not changed (inline suppression worked).

## Caveats

- `#5` is treated as a justified false positive via an explicit, documented suppression
  rather than a library swap. If zero suppressions are desired, the only real alternative is
  refactoring the fetcher to `requests` (adds a dependency, no security gain) — rejected.
