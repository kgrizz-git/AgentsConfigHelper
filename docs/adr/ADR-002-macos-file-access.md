# ADR-002: macOS source-build file access

Last reviewed: 2026-08-21
Date: 2026-08-21
Status: accepted
Deciders: maintainers
Related plan: [`plans/active/macos-local-execution.md`](../../plans/active/macos-local-execution.md)

## Context

AgentsConfigHelper needs to discover, edit, and back up configuration files in
the user's real home directory, user-selected project roots, and manually-added
absolute paths. Flutter's macOS template enables App Sandbox, which changes
`HOME` to the application container. The existing environment-based resolver
then scans that empty container and presents an indistinguishable “No
configurations found” result.

The immediate need is for maintainers and contributors to run the app locally
from source. No Developer ID certificate is available and this project will not
publish a prebuilt macOS app in this cycle.

## Decision

For the current **source-build-only** workflow, remove App Sandbox from the
Debug/Profile and Release entitlement files.

This lets the existing normal `HOME` resolution address the real user home and
permits the app to perform its core local filesystem workflow. The source
builder chooses whether to trust and run the source; the app continues to show
a diff before writes and creates timestamped backups first.

This decision does **not** authorize distributing an unsigned or ad-hoc-signed
macOS binary. Do not publish a `.app`, `.dmg`, `.pkg`, or prebuilt release zip
until this ADR is revisited with a Developer ID signing and notarization plan.

## Consequences

### Positive

- Local `flutter run -d macos` can discover files in the real user home.
- Project roots and manual absolute paths work without an Open-panel grant UX.
- The implementation stays limited to the entitlement change and local
  validation; it avoids premature native FFI and bookmark infrastructure.

### Tradeoffs

- The local app has the user session's normal filesystem access. That breadth
  is necessary for automatic discovery and editing, but source builders must
  review and trust the code they run.
- Existing preferences and in-app backup history stored in the old sandbox
  container may not appear after the switch. Original configuration files are
  not moved or changed. The implementation records the recovery path instead
  of silently migrating or deleting data.
- A future binary-distribution or Mac App Store decision requires a new review
  of signing/notarization and, if sandboxing is required, user-granted
  bookmarks or a similarly explicit access model.

## Explicitly deferred

- Developer ID signing, Hardened Runtime, notarization, stapling, and release
  automation.
- Final non-template bundle identifier and sandbox-container data migration.
- Sandboxed temporary exceptions, security-scoped bookmarks, and dual variants.
- `getpwuid_r` FFI, container-path heuristics, and macOS-host FFI tests.
- Parser fuzzing and a separate confirmation model for writes outside the
  discovered set.

## Revisit triggers

- A plan to distribute any prebuilt macOS binary.
- A Mac App Store or enterprise sandbox requirement.
- A decision to persist or migrate pre-sandbox preferences/backups automatically.

## References

- [`plans/active/macos-local-execution.md`](../../plans/active/macos-local-execution.md)
- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Release.entitlements`
- `lib/services/home_directory_resolver.dart`
