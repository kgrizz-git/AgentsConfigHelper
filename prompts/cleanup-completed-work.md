# Cleanup Completed Work

Run this when completing significant work or at session end to ensure proper logging and archival.

## Checklist

### TODO cleanup
- [ ] Remove completed items from `to_do.md`
- [ ] Move items to "Recently done" section (max 10) if useful for reference
- [ ] Verify no completed items remain in main TODO list

### Completion logging
- [ ] Log user-visible changes in `CHANGELOG.md`
- [ ] Log internal/harness changes in `CHANGELOG.dev.md`
- [ ] Log maintenance/security work in `MAINTENANCE.md` (create if needed)
- [ ] Reference the source (plan, issue, or commit) for each logged item

### Plan archival
- [ ] Move completed plans to `plans/archive/`
- [ ] Update plan status to `complete` or `abandoned`
- [ ] Update `orchestration-state.md` if present
- [ ] Verify no active plans remain in main `plans/` directory

### Scratch file cleanup
- [ ] Review `.context/` directory for old scratch files
- [ ] Delete scratch files older than 7 days (unless explicitly needed)
- [ ] Archive valuable research notes to appropriate docs location

### Source code cleanup
- [ ] Check for resolved TODOs/FIXMEs in source code
- [ ] Remove or update resolved markers
- [ ] Verify no orphaned TODO comments remain

### Verification
- [ ] Run `python hooks/scripts/check_todo_limits.py` to verify cleanup
- [ ] Run `python hooks/scripts/check_file_size.py` to check for bloat
- [ ] Verify git status shows only intended changes

## Logging decision tree

Use this tree to decide where to log completed work:

```
User-visible impact?
├─ Yes → CHANGELOG.md + VERSION bump if appropriate
└─ No → Internal-only?
    ├─ Yes → CHANGELOG.dev.md
    └─ No → Maintenance/security?
        ├─ Yes → MAINTENANCE.md
        └─ No → Document only → No changelog needed
```

### Examples

**User-visible feature:** "Added user authentication" → `CHANGELOG.md`
**Internal tooling:** "Updated pre-commit hooks" → `CHANGELOG.dev.md`
**Security fix:** "Rotated API keys" → `CHANGELOG.md` (if user-facing) or `MAINTENANCE.md` (if internal)
**Documentation:** "Updated API docs" → `CHANGELOG.dev.md`
**Bug fix:** "Fixed login redirect loop" → `CHANGELOG.md`

## Before declaring cleanup complete

- [ ] All completed work is properly logged
- [ ] No orphaned TODO items remain
- [ ] Plans are archived with correct status
- [ ] Scratch files are cleaned up
- [ ] Git status is clean (except for intended changes)
- [ ] Relevant policy checks pass

## Commit message guidance

When committing cleanup, use a descriptive message:

```
Cleanup: Log and archive completed work

- Logged [X] completions in CHANGELOG.md/dev.md
- Archived [Y] completed plans to plans/archive/
- Cleaned up .context/ scratch files
- Removed resolved TODOs from source
```

This creates a clear audit trail and prevents accumulation of completed work artifacts.
