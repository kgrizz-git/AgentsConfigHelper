# Policy: Documentation Freshness

Last reviewed: 2026-08-11
Enforced by: [`hooks/scripts/check_doc_freshness.py`](../hooks/scripts/check_doc_freshness.py),
[`ci/scripts/check_doc_links.py`](../ci/scripts/check_doc_links.py) (tool catalogs)

## Why

Stale docs are worse than missing docs: they mislead humans and agents alike. A visible
review marker plus a staleness window keeps durable docs trustworthy.

## Rules & defaults

| Rule | Default | Tier |
| --- | --- | --- |
| Durable docs carry a freshness marker | `Last reviewed: YYYY-MM-DD` near the top | soft gate |
| Staleness window before review is due | 180 days | advisory (warn), CI soft gate |
| Hard-stale threshold | 365 days | hard gate in CI |
| Marker required in these paths | `policies/`, `templates/`, `inventory/`, root `*.md` | soft gate |
| Exempt paths | `.context/`, `CHANGELOG.md`, auto-generated indexes | n/a |

### Marker format

Put one of these within the first ~10 lines of the doc:

```
Last reviewed: 2026-06-26
```

The checker parses the date, compares to today, and reports docs past the window.

## Reviewing a doc (what "reviewed" means)

1. Re-read it against the current code/behavior.
2. Fix anything inaccurate; verify commands, paths, links.
3. Update the date only after the content is confirmed current.

> Bumping the date without re-reading defeats the policy. The date asserts "a human/agent
> confirmed this is accurate as of this date."

## Tool catalogs: a second, tighter marker

Prose accuracy and menu accuracy rot at different rates. An inventory entry can read perfectly
while the project behind it has been archived, renamed, or superseded — `Last reviewed` will not
catch that, because nothing in the text became wrong.

Files that catalog external tools may carry a second marker:

```
Catalog reviewed through: 2026-08-11
```

| Marker | Asserts | Window | Checked by |
| --- | --- | --- | --- |
| `Last reviewed` | the text is accurate | 180 warn / 365 hard | `hooks/scripts/check_doc_freshness.py` |
| `Catalog reviewed through` | this is still the right menu | 120 days | `ci/scripts/check_doc_links.py` |

Refresh the catalog date when a new tool in that space is **evaluated** — whether or not it was
adopted. Recording "considered X, rejected as redundant with Y" is the point; it stops the next
agent re-litigating the same comparison.

The link checker also reports 404s and GitHub redirects (a rename or transfer). Both are prompts
to re-evaluate an entry, **not** grounds to auto-delete it: a quiet project is not the same as a
dead one, and that judgement is deliberately left to a human. The marker is opt-in — only files
that carry it are checked.

## Generated indexes

Auto-generated lists (e.g. directory indexes) should be regenerated, not hand-dated. Track
their generator and last-run instead of a manual marker.
