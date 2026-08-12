# New Agent Session: Orient and Start

Run this at the beginning of any work session that is **not** an initial bootstrap.
It gives you the project context you need in under two minutes without loading everything.

---

## Step 1: Read the project profile

Read `.context/project-profile.md`.

If the file does not exist:

1. Tell the user it's missing.
2. Run `prompts/project-init-profile.md` to create it.
3. Return here once written.

From the profile, report to the user in a single short paragraph:

- Project name, purpose, and primary type
- Stack (language + framework)
- Orchestration tier and any active subagents/skills
- Any open questions listed at the bottom of the profile

If the profile says `regulated` data or mentions PII, PHI, medical, FHIR/HL7, or DICOM, read
[`prompts/strict-phi-agent-guidance.md`](strict-phi-agent-guidance.md) before inspecting or
editing data-bearing files. Verify the strict sensitive-data hook/CI setup before making a
relevant commit; do not modify its human approval inventory.

---

## Step 1.5: Check for an unfinished bootstrap or a pending handoff

Read these if they exist — both are cheap and both prevent redoing finished work:

- **`.context/handoff.md`** — a packet from the previous agent/IDE/session. Read its **Next
  action** first, and note what it lists as verified vs assumed. Delete it once the work lands.
- **`.context/bootstrap-state.md`** — an unfinished bootstrap. If any phase is `pending` or
  `in-progress`, tell the user which, and offer to resume from
  [`bootstrap-checklist.md`](bootstrap-checklist.md) at that phase ID rather than starting new work.

To check claims against reality rather than against the state file:

```bash
bash scripts/check-bootstrap.sh
```

---

## Step 2: Check for active work

Check for a plans folder. If `plans/orchestration-state.md` exists, read it.

Report: is there an active plan, open task, or in-flight branch?

- If yes: summarize the next action and ask if the user wants to continue it.
- If no: proceed to step 3.

Also run:

```bash
git log --oneline -5
git status --short
```

Surface any uncommitted work or recent commits relevant to the current task.

**Open PRs (advisory, ~once a day):** if `gh` is available and this is a GitHub
remote:

1. **Check the stamp first** (cheaper than launching the script): look at
   `.context/open-prs-check.stamp`. If it exists and was modified within the last
   24 hours, **skip** — do not run the script.
2. Otherwise run:

   ```bash
   python3 ci/scripts/check_open_prs.py --once-per-day
   ```

   (`--once-per-day` is a safety net if the stamp check was skipped.)

Report any open PRs that overlap the current branch or task. Prefer updating an
existing PR over opening a duplicate. This must never block the session. See
[`policies/commits-and-branches.md`](../policies/commits-and-branches.md).

---

## Step 2.5: Check for cleanup needed

Before starting new work, check for cleanup from previous sessions:

- **Completed items in `to_do.md`**: Are there items marked complete that should be removed or logged?
- **Completed plans not archived**: Are there plans in `plans/` with status `complete` or `abandoned`?
- **Cluttered `.context/`**: Are there scratch files older than 7 days that should be cleaned up?
- **Unlogged completions**: Check recent commits vs changelogs for missing completion entries.

If cleanup is needed, ask the user: "Found [X] completed items needing cleanup. Run cleanup before starting new work?"

If yes, run [`prompts/cleanup-completed-work.md`](cleanup-completed-work.md) before proceeding.

---

## Step 3: Load only the relevant inventory

Read the inventory files listed in the profile's **Relevant inventory** section.
Do **not** load all 18 inventory files — load only what this project uses.

If the project profile lists no inventory files yet, default to:

- `inventory/README.md` (scan the table, choose what applies)
- `inventory/security-quality.md` (always relevant)

---

## Step 4: Quick doc freshness check

```bash
python hooks/scripts/check_doc_freshness.py
```

If the script is not installed yet, manually check: do the key docs in `policies/`,
`templates/`, and `inventory/` have `Last reviewed:` markers within the last 180 days?

Report anything stale so the user can decide whether to update now or defer.

---

## Step 5: Take the task

Ask the user what they want to accomplish this session, or read the issue, PR, or task
they have pointed you to.

Before writing code or making broad changes:

1. Confirm your understanding of the goal in one sentence.
2. If the task is non-trivial, propose a brief plan and wait for approval.
3. If the task is a quick fix, state what you will change and do it.

Check the profile's orchestration tier:

- `none` or `hub-and-spoke` — proceed as a single agent.
- `hub-and-spoke` — check if the orchestrator subagent should be invoked
  (see `inventory/catalog-skills-agents.md` → orchestrator agent).
- `langgraph` or `symphony` — verify the workflow server is running before proceeding.
