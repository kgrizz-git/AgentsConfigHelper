# Maintenance Loop

Run this prompt periodically — weekly for active projects, monthly for stable ones —
to keep the repo healthy, docs current, and agent guidance accurate.

This is a **checklist prompt**: work through each section, fix what you can immediately,
file issues or TODOs for the rest, and report a summary at the end.

---

## 1. Doc freshness

```bash
python hooks/scripts/check_doc_freshness.py
```

For any file flagged as stale (>180 days: warn, >365 days: error):

- If the content is still accurate: update only the `Last reviewed:` date.
- If the content needs revision: update the content, then update the date.
- If the file is obsolete: propose removing it.

Key docs to check manually if the script misses them:

- `AGENTS.md`, `README.md`
- All files in `policies/`, `templates/`, `inventory/`

---

## 2. Garbage collection

### Dead code and unused imports (Python)

```bash
vulture . --min-confidence 80          # dead code
ruff check --select F401 .             # unused imports
autoflake --check -r .                 # unused imports (alternative)
```

### Unused dependencies

```bash
deptry .                               # Python: unused/missing/transitive deps
```

For JavaScript/TypeScript:

```bash
npx depcheck                           # unused deps
npx knip                               # unused exports and files
```

### Stale branches

```bash
git fetch --prune
git branch --merged main | grep -v '^* main$' | grep -v '^\s*main$'
```

Delete merged branches that are no longer needed.

### Orphaned TODOs and FIXMEs

```bash
grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.py" --include="*.ts" --include="*.md" .
```

Review each one: resolve it, file a proper issue, or delete if obsolete.

### Cleanup audit

Check for incomplete cleanup from previous work:

```bash
# Check for completed items still in to_do.md
grep -n "^\- \[x\]" to_do.md TODO.md 2>/dev/null || echo "No completed items found"

# Check for completed plans not archived
find plans/ -name "*.md" -type f ! -path "plans/archive/*" -exec grep -l "Status: complete\|Status: abandoned" {} \;

# Check for old context files
find .context/ -type f -mtime +7 -ls 2>/dev/null || echo "No old context files"
```

For each issue found:

- Completed items in `to_do.md` → Run [`prompts/cleanup-completed-work.md`](cleanup-completed-work.md)
- Completed plans not archived → Move to `plans/archive/` and log completion
- Old `.context/` files → Delete or archive valuable content
- Unlogged completions → Check git log vs changelogs, add missing entries

---

## 3. Security and dependency audit

```bash
gitleaks detect --source . --no-git    # secrets in working tree
pip-audit                              # known CVEs in Python deps
```

For JavaScript:

```bash
npm audit --audit-level=high
```

Check Dependabot or Renovate alerts on GitHub if enabled.
Review any Semgrep SARIF results from the last CI security run.

### Full-history PII/PHI audit (Sensitive and Regulated tiers)

Per-commit hooks only see the diff. On a schedule (monthly, or after any large data-bearing
import), run a **repo-wide, full-history** PII/PHI audit against a local checkout—the working
tree and past commits, not just recent changes. This complements, and does not replace, the
strict local gate and human approval. Keep it local-first; do not route a regulated repo's
contents through a SaaS scanner without the data-residency/BAA review in
[`policies/github-repository-hygiene.md`](../policies/github-repository-hygiene.md).

```bash
# OCR + NLP + regex over images/PDFs/docs in the working tree (pin a reviewed commit).
# Run locally on an approved runner and redact matches from logs.
python octopii.py <local-checkout-path>

# Sweep past commits for anything a current-tree scan would miss.
git log --all --oneline | wc -l   # scope check; then scan blobs from history as justified
```

Record only sanitized finding categories, paths, and remediation—never detected values—and
keep scan reports out of Git. Treat hits as triage for human review, not proof of absence.

---

## 4. Policy checks

```bash
python hooks/scripts/check_file_size.py $(git ls-files)
python hooks/scripts/check_doc_freshness.py
```

Review any soft-gate warnings (files approaching line caps, complexity warnings).
File follow-up tasks for anything that needs refactoring but is not urgent.

---

## 5. Open ADRs and plans

Check `templates/adr.md` usage: are there any ADRs in draft or "proposed" state?
Review open plans in `plans/` (if the folder exists): are any stale or completed?
Update plan checkboxes to reflect current state.

### Cleanup status check

Verify that the cleanup audit from section 2.5 was completed:

- Are completed items properly logged in changelogs?
- Are completed plans archived to `plans/archive/`?
- Is `.context/` clean of old scratch files?
- Are there any completion logging gaps that need remediation?

If cleanup was deferred earlier, run it now or file as a follow-up task.

---

## 6. Inventory review

Tool facts rot faster than prose. Start with evidence rather than by re-reading:

```bash
# dead links, GitHub renames/transfers, and stale catalog-review dates
python3 ci/scripts/check_doc_links.py

# no network available:
python3 ci/scripts/check_doc_links.py --offline
```

Then, for the topic files relevant to this project:

- Did the checker flag a 404 or a redirect? A rename or archive is a prompt to **re-evaluate**
  the entry — not to delete it. A quiet project is not a dead one.
- Have any tools been deprecated or superseded?
- Are there new tools worth adding (check release notes, changelog)?
- Is the project profile's "Relevant inventory" list still accurate?

Update `Last reviewed:` on files you verified are accurate. Update
`Catalog reviewed through:` on catalog files only when you actually re-asked *"is this still the
right menu?"* — including recording tools you considered and rejected as redundant, with the
reason. See [`policies/doc-freshness.md`](../policies/doc-freshness.md).

### Quarterly catalog-freshness advisory

A scheduled GitHub Actions workflow (`.github/workflows/catalog-advisory.yml`) runs the
checker's offline advisory check quarterly and on manual `workflow_dispatch`:

```bash
# local equivalent of what the scheduled workflow runs
python3 ci/scripts/check_doc_links.py --offline
```

It is **advisory and no-write**: it runs with `permissions: contents: read`, probes no
external links, and never opens or updates issues. When the `Catalog reviewed through:` date
is stale (120-day window) it writes an actionable reminder to the run summary and emits a
`::warning` annotation on `docs/supported-tools.md`, visible in the Actions tab. It never
blocks PRs or releases. To act on it, follow the "What to do" steps in the run summary, then
refresh the `Catalog reviewed through:` marker.

### Agent tooling re-evaluation

Re-run the agent-tooling card ([`bootstrap/card-agent-tooling.md`](bootstrap/card-agent-tooling.md))
when the repo has grown past ~50 source files, or when sessions repeatedly waste context on the
same lookups. The reverse also applies: **an installed tool nobody has used since the last loop
should be removed.** Update the profile's Agent tooling section either way, including the
"Last evaluated" date.

---

## 7. Knowledge index (if applicable)

If the project uses a code map (aider repomap, sift-kg, tree-sitter index):

- Re-index if >20% of source files have changed since last index.
- Update the `Last indexed:` field in `.context/project-profile.md`.

```bash
# aider repomap (example)
aider --map-tokens 2048 --no-git --show-repo-map > .context/repomap.txt

# sift-kg (example — see inventory/knowledge-graph-code-mapping.md for setup)
sift-kg index .
```

---

## 8. CI and GitHub health

- Are all workflow files pinned to specific action versions (not `@latest`)?
- Are there failed or skipped checks that need investigation?
- Is Dependabot / Renovate configured and processing updates?
- Are any GitHub apps (CodeRabbit, DeepSource, Codecov) showing unresolved issues?

### Open pull requests (advisory)

```bash
python3 ci/scripts/check_open_prs.py --force
```

List stale or duplicate open PRs. Prefer closing/superseding duplicates and
updating the surviving PR. Do not treat a missing PR as a failure — this check
is informational only (see [`policies/commits-and-branches.md`](../policies/commits-and-branches.md)).

---

## 9. Report

Summarize the session to the user:

```
## Maintenance loop report — YYYY-MM-DD

### Fixed now
-

### Deferred (filed as TODO / issue)
-

### No action needed
-

### Next run recommended
- (date or trigger)
```
