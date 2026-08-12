# Maintenance Log

This file tracks maintenance activities, security updates, and operational tasks that don't belong in the public changelog.

## [YYYY-MM-DD] - Session Type

### Completed

- [task description] - [impact/context] (ref: [plan/commit/issue])
- [task description] - [impact/context] (ref: [plan/commit/issue])

### Deferred

- [task description] - [reason for deferral] (filed as [issue/TODO])
- [task description] - [reason for deferral] (filed as [issue/TODO])

### Issues Found

- [issue description] - [severity] - [planned action/timeline]
- [issue description] - [severity] - [planned action/timeline]

### Security Notes

- [security-related maintenance] - [context] (ref: [commit/issue])
- [security-related maintenance] - [context] (ref: [commit/issue])

### Infrastructure/Tools

- [infrastructure change] - [impact] (ref: [commit/issue])
- [tool update] - [version] - [reason]

### Next Scheduled

- [date] - [focus areas/planned work]
- [date] - [focus areas/planned work]

---

## Usage Guidelines

### When to use this log

- Security updates and patches that don't affect user-facing behavior
- Infrastructure changes, tool updates, and dependency maintenance
- Performance tuning and optimization work
- Backup/restore testing and verification
- Compliance and audit activities
- Internal process improvements

### When to use CHANGELOG.dev.md instead

- Changes to the agent harness, prompts, or skills
- Updates to CI/CD workflows and hooks
- Documentation-only changes
- Test coverage improvements
- Code refactoring with no user impact

### When to use CHANGELOG.md instead

- User-visible features and changes
- Bug fixes that affect users
- Breaking changes or migration requirements
- Performance improvements users notice

### Entry format

Keep entries concise and actionable. Include:

- What was done
- Why it matters
- Reference to related commits, issues, or plans
- Any follow-up needed

### Rotation

Archive old entries to `docs/maintenance-archive/` or similar when this file grows beyond 200 lines. Keep at least the last 6 months of activity readily accessible.
