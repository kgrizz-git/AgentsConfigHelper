# Safe Testing Strategies for AgentsConfigHelper

**Author:** Devin
**Date:** 2026-08-22
**Purpose:** Creative but practical approaches for safely testing the AgentsConfigHelper app without risking real configuration files.

## Codex assessment and recommended workflow

**Status update (macOS, 2026-08-22):** The app now has an in-progress,
test-only `--test-root` mode backed by descriptor-relative, no-follow native file
operations. It is tested against root, parent, and target symlink escapes and routes
config, backup, restore, and preference writes below a marked disposable root. Linux and
Windows intentionally reject the flag for now. The initial manual macOS smoke completed on
2026-08-22 with staged discovery, edits, backups, preferences, and external-project-root
rejection verified. Repeat the checklist below when changing test-root I/O or its launcher.
A `HOME` override alone remains exploratory, not a containment claim.

### Candidate manual macOS smoke

Run this only on a local macOS machine after building the app. The launcher copies only
repository-owned fixtures into a fresh private temporary directory, creates the required
marker, and never deletes the directory automatically.

```bash
flutter build macos --debug
scripts/run_macos_staging_smoke.sh
```

The app must display `TEST ROOT MODE` with the printed root. Confirm the user-scope entries
for Claude Code, Codex, Opencode, Kiro, and shared `AGENTS.md` appear. Add the printed
root's `workspace` directory as a project root, then confirm its Claude, Codex, and
`AGENTS.md` entries appear.

Perform one raw edit and one structured edit, inspect each diff, and confirm the backup,
restore, and preference files remain below the printed root. Exit the app before cleanup.
The cleanup script refuses symlinks, an unexpected marker, and paths outside its temporary
staging prefix:

```bash
scripts/cleanup_macos_staging_root.sh /path/printed/by/the/launcher
```

Record the outcome in the active testing plan. Do not substitute personal configuration files
for these fixtures.

The practical first step is a **synthetic staging home**, not a VM, Docker image, or
new application safety feature. The current home-directory resolver reads `HOME` (and
the Windows equivalents), so launching the already-built app with `HOME` set to a fresh
absolute staging directory exercises normal user-path discovery against disposable,
token-free fixture copies. Set `HOME` only for the app process; do not redirect Flutter
tooling itself to that directory. This is more complete than adding individual manual
paths because it tests the catalog's automatic user-path discovery as well as parsing
and editing.

Before treating this as a daily safe-write workflow, verify where `path_provider` and
preference storage place their data in a launched desktop app. The testing-foundation
plan requires every backup, restore, and preference write to remain within the staging
root (or introduces an explicit test-root override); a `HOME` override alone must not
be assumed to confine those platform services.

Treat the staging directory as disposable and seed it only with synthetic or carefully
redacted copies. The existing diff preview and automatic backups are useful defenses,
but neither prevents a write, so they are not a read-only or safe mode. Do not rely on
Git branches for private configs, and do not mount a real home directory read-write into
Docker. Docker is useful for Linux parser/build testing, while VMs or a separate OS user
are later validation layers for native desktop and permission behavior.

Recommended sequence:

1. Build a fixture matrix and automated parser/widget regression tests.
2. Finish the macOS fixture, root-creation, and manual-smoke gates for the tested
   `--test-root` boundary. Do not wait for Linux or Windows to begin this macOS work.
3. Add Linux/Windows test-root primitives before enabling the flag there; Docker remains
   optional Linux validation, not a substitute for native containment.
4. Use a dedicated user account or VM snapshots for platform-specific, real-world
   validation. Reserve Docker/VNC for Linux-specific or collaborative scenarios.

## Context

AgentsConfigHelper is a Flutter desktop app that reads and writes real configuration files for AI agents and IDEs (Claude Code, Codex, Opencode, Paseo, Cursor, Kiro, Devin, Antigravity, etc.). These files may contain API tokens, keys, and other sensitive credentials. The app currently operates unsandboxed on macOS to access real user configuration files, making safe testing critical.

---

## Testing Strategy Overview

| Strategy | Risk Level | Setup Complexity | Realism | Cost |
|----------|------------|------------------|---------|------|
| Virtual Machines | Low | Medium | High | Free (with VirtualBox/VMware) |
| Docker Containers | Very Low | Low | Medium | Free |
| Fake Sample Files | None | Low | Low | Free |
| Git Version Control | Low | Low | High | Free |
| Dedicated Test User | Low | Medium | High | Free |
| Snapshot/Cloning | Low | Medium | High | Free (Time Machine) |
| Read-Only Mode | None | Low | Medium | Free |

---

## Detailed Strategies

### 1. Virtual Machines (Recommended)

**Approach:** Create dedicated VMs for testing with isolated agent/IDE configurations.

**Pros:**

- Complete isolation from host system
- Can snapshot before risky operations
- Cross-platform testing (Windows, Linux, macOS VMs)
- Easy rollback if something breaks
- Can test with real config files safely
- Reproducible test environments

**Cons:**

- Requires disk space for VM images
- Setup time for each VM
- Performance overhead compared to native
- macOS VMs require Apple Silicon hardware
- Need to install Flutter toolchain in each VM

**Implementation:**

```bash
# Using VirtualBox (free)
# Create macOS, Windows, and Linux VMs
# Install Flutter SDK in each VM
# Seed the VM from token-free fixtures or carefully reviewed, sanitized reproductions
# Take snapshots before each test session

# Snapshot workflow
VBoxManage snapshot "Test-MacOS" take "before-test-session"
# Run tests
VBoxManage snapshot "Test-MacOS" restore "before-test-session"
```

**Best for:** Comprehensive testing across platforms, risky operations, development phases.

---

### 2. Docker Containers

**Approach:** Containerize the app or test environment with isolated config directories.

**Pros:**

- Lightweight compared to VMs
- Easy to create and destroy
- Can mount specific config directories
- Reproducible environments
- Quick spin-up time

**Cons:**

- Desktop GUI testing in Docker is complex
- Flutter desktop apps in containers require X11 forwarding
- Less isolated than VMs
- Limited support for macOS containers
- May not fully replicate desktop environment

**Implementation:**

```dockerfile
# Dockerfile for testing environment
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip libglu1-mesa
RUN git clone https://github.com/flutter/flutter.git -b stable
ENV PATH="$PATH:/flutter/bin"
WORKDIR /app
COPY . .
RUN flutter pub get
# Mount test config directory as volume
```

**Best for:** Linux testing, automated CI/CD, parser testing without GUI.

---

### 3. Fake Sample Files (Recommended for Initial Testing)

**Approach:** Create synthetic config files with dummy data for parser and UI testing.

**Pros:**

- Zero risk to real configurations
- Easy to create and maintain
- Fast iteration for development
- Can cover edge cases with contrived examples
- No setup complexity
- Perfect for unit and widget tests

**Cons:**

- Doesn't test real-world config complexity
- May miss format variations in actual files
- Limited testing of file discovery logic
- Doesn't validate permission handling
- Not suitable for integration testing

**Implementation:**

```yaml
# test/fixtures/sample-claude-config.json
{
  "maxTokens": 4096,
  "temperature": 0.7,
  "endpoint": "https://example.invalid/agent-service",
  "allowedTools": ["grep", "read", "write"],
  "rules": [
    "Always backup before editing",
    "Never modify system files"
  ]
}

# test/fixtures/sample-cursor-rules.md
# Cursor AI Rules for Testing
# This is a synthetic test file

## General Behavior
- Be helpful and concise
- Use fake API keys only
- Test mode enabled

## Testing Rules
- Validate all config changes
- Check backup creation
```

**Best for:** Early development, parser testing, unit tests, UI component testing.

#### Sanitized regression-fixture intake

Add a fixture only when it captures a specific parser, discovery, service, or widget
regression. Do not copy a personal configuration file into the repository. Before committing:

1. Record the confirmed source or the minimal reproducible shape in the test or its plan.
2. Remove user names, paths, tokens, keys, URLs, and copied explanatory comments.
3. Replace values with clearly synthetic equivalents such as `example.invalid` and generic
   relative paths; avoid token-shaped placeholder strings.
4. Keep only the smallest structure required to reproduce the behavior, and include a
   raw-editor fallback assertion when the shape is unsupported.
5. Have a reviewer confirm the fixture is synthetic, token-free, and covered by a focused
   regression test before merge.

---

### 4. Git Version Control with Branches

**Approach:** Use Git branches to review changes to synthetic fixtures and test code.
It is not a safety mechanism for personal configurations.

**Pros:**

- Built-in version control
- Easy diff and review
- Branch-per-test-strategy
- Can merge successful changes
- Free and already in use
- No additional tools needed

**Cons:**

- Does not prevent file modification
- Is useful only for repository-owned, token-free fixtures
- Personal config files and credentials must never be added to a repository
- Manual process (not automated)

**Implementation:**

```bash
# Create a branch for fixture/test changes.
git switch -c test-fixture-update

# Add or adjust only synthetic, token-free files under test/fixtures/.
# Review the diff before committing; do not copy personal config files into the repository.
git diff -- test/fixtures/
```

**Best for:** Tracking changes, experimental features, manual testing workflows.

---

### 5. Dedicated Test User Account

**Approach:** Create a separate user account on your system specifically for testing.

**Pros:**

- Complete user-level isolation
- Real system environment
- Can install test versions of agents/IDEs
- Real file permissions and paths
- Easy to delete and recreate
- No VM overhead

**Cons:**

- Need to switch users for testing
- Must install Flutter toolchain for test user
- Still affects system (just different user)
- Setup time for each test session
- Platform-specific

**Implementation:**

```bash
# Create a standard, non-admin test account through macOS System Settings and set its
# password interactively. Do not put account credentials in shell history or documents.
# Sign in as that account, seed its home from token-free fixtures, then run the app.
```

**Best for:** Realistic testing without VM overhead, user-specific behavior testing.

---

### 6. System Snapshot/Cloning (Recommended for Safety)

**Approach:** Use system snapshot tools to capture state before testing and restore if needed.

**Pros:**

- Complete system state capture
- Fast restore process
- Can snapshot multiple test states
- No ongoing performance impact
- Works with real config files
- One-time setup cost

**Cons:**

- Requires disk space for snapshots
- Platform-specific (Time Machine for macOS)
- Restore may affect other work
- Snapshot management overhead
- Not instant (unlike VM snapshots)

**Implementation:**

```bash
# macOS Time Machine local snapshots
tmutil localsnapshot
# Run tests
# Restore through Time Machine's UI by selecting the snapshot and explicitly choosing
# both the source item and a destination. `tmutil restore` requires those paths, so do
# not use an unscoped command as a rollback procedure.
```

**Best for:** Safety net for risky operations, long-running test sessions.

---

### 7. Read-Only Mode with Diff Preview

**Approach:** Implement and use a read-only mode that shows changes without applying them.

**Pros:**

- Zero risk of data modification
- Can validate edit logic
- Good for UI testing
- No setup required
- Can test with real files safely
- Already part of app design (diff preview)

**Cons:**

- Doesn't test write functionality
- Limited test coverage
- Requires app implementation
- Can't test backup/restore
- Not end-to-end testing

**Implementation:**

```dart
// Add read-only mode to app
class ConfigEditor extends ConsumerWidget {
  final bool readOnlyMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConfigEditorUI(
      onSave: readOnlyMode ? null : _handleSave,
      onPreview: _showDiffPreview,
    );
  }
}
```

**Best for:** UI testing, parser validation, user experience testing.

---

## Combined Recommendations

### Phase 1: Development (Low Risk)

- **Primary:** Fake sample files in `test/fixtures/`
- **Secondary:** Read-only mode for UI testing
- **Safety:** Git branches for tracking changes

### Phase 2: Integration Testing (Medium Risk)

- **Primary:** Dedicated test user account
- **Secondary:** Local system snapshots
- **Safety:** Manual backup of config files before tests

### Phase 3: Cross-Platform Validation (High Risk)

- **Primary:** Virtual Machines for each target platform
- **Secondary:** Docker containers for Linux
- **Safety:** VM snapshots before each test session

### Phase 4: Production Validation (Highest Safety)

- **Primary:** VMs with full system snapshots
- **Secondary:** dedicated test user accounts for native-platform validation
- **Safety:** Complete isolation and rollback capability

---

## Quick-Start Setup

```bash
# 1. Create test fixtures directory
mkdir -p test/fixtures/configs

# 2. Add sample config files (see fake sample files section)
# 3. Update app to support --test-mode flag
# 4. Create dedicated test user (optional but recommended)
# 5. Set up VM for cross-platform testing (Phase 3+)
```

---

## Safety Checklist

Before any testing session with real config files:

- [ ] Create backup of all config files to be tested
- [ ] Document current config state (hashes, timestamps)
- [ ] Create system snapshot or VM snapshot
- [ ] Test in read-only mode first
- [ ] Start with least critical config files
- [ ] Have rollback procedure documented
- [ ] Never test with production API keys/tokens

---

## Fixture-intake checklist

Use this checklist when adding or updating any file under `test/fixtures/`. Its purpose is to keep committed fixtures synthetic, token-free, and safe to use in the `--test-root` smoke workflow and CI parser tests. A fixture that fails any item below is not ready to commit.

- [ ] **Source provenance recorded** — note the origin of the structure (vendor docs, schema reference, or hand-synthesized) in the pull request description. Do not copy a personal configuration, a vendor example containing credential-shaped values, or an unredacted third-party file into the tree.
- [ ] **Synthetic rewrite / redaction** — the content is a hand-written reproduction of the *shape* of a real config, not a verbatim copy. All string values are obviously fake (`"example.invalid"`, `"test-model"`, `"fixture-rule"`). User names, hostnames, paths, and identifiers are generic. Comments and rule text contain no private project names or internal URLs.
- [ ] **Secret scan clean** — the diff is free of API keys, tokens, connection strings, and credential-shaped values. `gitleaks` runs in pre-commit and CI; verify locally before opening the PR with `pre-commit run --files <fixture-path>`. A fixture that looks structurally real must still fail a secret scan if it contains a plausible-looking key.
- [ ] **Token-free and environment-independent** — the fixture contains no values that resolve differently per user or machine (no real home paths, no usernames, no hostnames, no absolute paths outside the fixture tree). It must parse identically on any machine running `flutter test` without network access.
- [ ] **Validation / parsing expectations documented** — the fixture's expected parse result is covered by a Dart test (e.g. `test/fixtures/staging_fixtures_test.dart` or `test/fixtures/claude_permissions_fixtures_test.dart`), or the PR adds one. A fixture that is not exercised by any test is dead weight and may silently rot.
- [ ] **Raw-editor fallback for unsupported structures** — if the fixture exercises a format the app does not yet parse as structured data (Markdown rules, Starlark, plain text, glob-matched instruction files), it is discovered and edited only through the raw-text editor. Do not claim a "verified example" or "structured-schema" status for such a fixture in `docs/supported-tools.md`; record it as `paths recorded; schema needs verification` or `primary docs only` until a parser exists.

See also: [macOS test-root mode](macos-test-root.md) (disposable-staging workflow), [Supported Tools](supported-tools.md) (catalog evidence contract and schema-evidence states).

---

## Conclusion

**Recommended Approach:** Start with fake sample files for development, progress to dedicated test user accounts for integration testing, and use virtual machines for cross-platform validation. Always maintain the ability to rollback quickly through snapshots or backups.

The key is layering multiple safety approaches rather than relying on a single method. Even with fake files, maintain good practices like version control and backup habits for when you eventually test with real configurations.

**Priority order:** Fake files → Read-only mode → Test user → System snapshots → VMs → Sandbox profiles

---

## Gemini's Testing Strategy Recommendations

**Author:** Gemini
**Date:** 2026-08-22
**Purpose:** Additional creative and practical testing strategies, supplementing the ones above with Flutter-specific abstractions, environment manipulation, and cloud environments.

### 8. Environment Variable `$HOME` Override (Fake Home Directory)

**Approach:** Launch the app from the terminal with a spoofed `$HOME` environment
variable, redirecting the Dart home-directory resolver to a temporary folder containing
dummy configs. This is an exploratory discovery test until the testing-foundation
plan's Phase 0 proves that configuration, backup, restore, and preference writes are
also confined to the disposable root.

**Pros:**

- Zero setup cost; no VMs or Docker needed.
- Very fast iteration cycle.
- Tests the app exactly as it runs natively, including real file I/O operations.

**Cons:**

- Relies on the app strictly using environment variables (like `Platform.environment['HOME']` in Dart) instead of native platform APIs that might bypass the spoof.
- Doesn't protect against absolute path hardcoding in the app.
- Does not yet establish a safe-write boundary for application-support or preference
  storage; do not edit, restore, or treat it as an isolated daily workflow before the
  Phase 0 containment gate passes.

**Implementation:**

```bash
# Create a fake home directory structure
mkdir -p /tmp/fake_home/.config/claude
cp test/fixtures/sample-claude-config.json /tmp/fake_home/.config/claude/config.json

# Run an already-built app with the spoofed HOME (do not redirect Flutter itself)
HOME=/tmp/fake_home build/macos/Build/Products/Debug/agents_config_helper.app/Contents/MacOS/agents_config_helper
```

**Best for:** Exploratory discovery testing with token-free fixtures. It becomes suitable
for routine manual write testing only after the containment gate passes.

---

### 9. In-Memory File System (Dependency Injection)

**Approach:** Architect the app to use the `file` package (`package:file`) instead of `dart:io` directly. Use `LocalFileSystem` in production and `MemoryFileSystem` during testing.

**Pros:**

- Blazing fast unit and widget tests.
- 100% safe; no actual disk I/O occurs during tests.
- Easy to simulate edge cases (e.g., disk full, permission denied, missing files) by manipulating the memory filesystem.

**Cons:**

- Requires refactoring existing code if `dart:io` `File` and `Directory` classes are already hardcoded.
- Doesn't test actual OS-level file locking or exact platform permission quirks.

**Implementation:**

```dart
// Using Riverpod for Dependency Injection
final fileSystemProvider = Provider<FileSystem>((ref) => const LocalFileSystem());

// In tests:
testWidgets('Editor saves config', (tester) async {
  final memoryFs = MemoryFileSystem();
  memoryFs.file('/mock/config.json').writeAsStringSync('{"key":"value"}');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fileSystemProvider.overrideWithValue(memoryFs),
      ],
      child: MyApp(),
    )
  );
  // Interact and verify memoryFs state
});
```

**Best for:** Automated unit and widget tests, achieving high test coverage safely.

---

### 10. Test-Root Write Redirection (macOS implementation in progress)

**Approach:** macOS now has a test-only `--test-root` flag that redirects config saves,
backups, restores, and preferences into one marker-validated disposable root. It uses native
no-follow operations rather than a Dart path-prefix check. The fixture launcher and manual
smoke checklist above are the only supported starting point; never write a `.shadow` file next
to a real configuration file.

**Pros:**

- Allows safe end-to-end testing of representative fixture configurations.
- Developers can verify exact output without writing beside an original file.
- The UI can display a banner indicating Safe Mode is active.

**Cons:**

- Requires application-level logic changes.
- Requires a complete, tested containment boundary; a partial redirect could still write
  outside the disposable root.

**Best for:** The test-only fallback identified by the safe-testing plan, not a shortcut
for testing personal data.

---

### 11. Disposable Cloud Desktops (e.g., GitHub Codespaces)

**Approach:** Since the app targets Linux desktop as well, run it in a disposable cloud workspace (like GitHub Codespaces or Gitpod) that supports VNC or web-based desktop rendering.

**Pros:**

- Complete physical isolation from the developer's local machine.
- Ephemeral environment; destroys itself after the session.
- Great for sharing a reproducible testing environment with other contributors.

**Cons:**

- Web-based VNC can be laggy.
- Only tests the Linux build, not macOS or Windows specific behaviors.

**Best for:** Collaborative debugging, CI/CD visual testing, onboarding new contributors safely.

---

### Overall Recommendations (Gemini's Take)

While Devin's suggestions of VMs and Fake Sample Files are excellent baselines, I recommend a tiered approach leveraging Flutter's strengths:

1. **For Automated Testing:** Implement the **In-Memory File System (Strategy 10)**. It's an industry-standard practice for Dart/Flutter apps that manipulate files, ensuring tests run in milliseconds safely.
2. **For Local Manual Testing:** Use the **`$HOME` Override (Strategy 8)** only for
   exploratory, fixture-based discovery until Phase 0 proves containment.
3. **For Edge Cases:** Add a sanitized fixture that preserves the reported structure,
   then extend the fixture matrix and regression tests. Do not test against real files.

---

### Config Structures and Tool Identification

When manually testing the app to edit various configs, settings, permissions, and rules across tools like Opencode, Kiro, Cline, Antigravity (Agy), and Devin CLI, you'll encounter a mix of shared formats and highly specific schemas.

**Are the structures general enough to be modified in similar ways?**

- **Format Level (Yes):** Most tools rely on standard file formats. JSON/JSONC (Claude, Cursor, Devin, Antigravity, Opencode, Kilo, Cline), YAML (Kiro, LM Studio), TOML (Codex), and Markdown (rules/instructions across all tools). From a raw text editing perspective, the app modifies them in identical ways, ensuring formatting and comments (where possible) are preserved.
- **Schema Level (No):** Even within the same format and conceptual area (e.g., permissions), the actual data schemas vary wildly.
  - **Antigravity (Agy) & Claude:** Use `allow`, `ask`, and `deny` arrays containing glob strings (e.g., `"allow": ["command(git)"]`).
  - **Opencode:** Uses a nested object mapping tool names to actions (e.g., `"bash": { "git *": "allow" }`).
  - **Kiro:** Uses capability-based YAML arrays (e.g., `capability: shell, effect: allow, match: [...]`).
  - **Devin:** Uses scope-based `Read()`, `Write()`, `Exec()` functions inside JSON arrays.

**Which ones require indication of the tool and field type?**

- **Structured Settings & Permissions (Tool Indication Required):** Any JSON/YAML/TOML file where the app presents a *structured UI* (like checkboxes, dropdowns, or specific permission cards instead of a raw text editor) requires strict tool identification. Because an Opencode permission looks entirely different from a Kiro permission, the app must parse the file using a tool-specific parser to render the correct UI. If the app cannot identify the tool or schema, it must fall back to a generic JSON/text editor.
- **Rules and Instructions (Generic):** Markdown files like `AGENTS.md`, `.cursorrules`, or `CLAUDE.md` do not require strict structural parsing. They are generic text instructions. The app only needs to know the tool to locate the file (e.g., knowing to look for `.clinerules` vs `.cursorrules`), but the editing experience itself is a universal Markdown text editor.

---

## Inkling's Additional Testing Strategies

**Author:** Inkling (Thinking Machines Lab)
**Date:** 2026-08-22
**Purpose:** Supplementary practical and creative approaches for safely testing AgentsConfigHelper — focusing on hands-on manual safety, Flutter-specific automation, and layered defense.

---

### 12. Manual Backup-First Protocol with Timestamped Backups and Diff Verification

**Approach:** After the Phase 0 containment gate passes, back up staged fixture paths
before a manual write test. After editing, use `diff` (or the app's own diff preview) to
verify exactly what changed before accepting the edit.

**Pros:**

- Zero dependency on external infrastructure (VMs, Docker, cloud).
- Creates an auditable paper trail (`settings.json.bak.20260822-143012`) of every edit attempt.
- Applies to disposable staging copies, so the procedure never handles personal tokens.
- Diff verification teaches the user exactly how the parser transforms JSON/JSONC/YAML/TOML — useful for debugging parser bugs.
- Can be scripted in a single bash/python one-liner.

**Cons:**

- Manual discipline is required; forgetting to run the script risks unbacked edits.
- Does not prevent an accidental write — it only makes recovery faster.
- Backups accumulate on disk and need periodic cleanup.
- Not automated for CI; purely a human test-safety habit.

**Implementation:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Run only inside the proven disposable test root.
BACKUP_DIR="${TEST_ROOT:?set TEST_ROOT to the disposable root}/manual-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
failed=0
backed_up=0
for path in "$HOME/.claude" "$HOME/.codex" "$HOME/.config/opencode" "$HOME/.cursor" \
            "$HOME/.kiro" "$HOME/.config/devin" "$HOME/.gemini" \
            "$HOME/.config/kilo" "$HOME/.cline" "$HOME/.lmstudio" \
            "$HOME/.paseo" "$HOME/.openab/agy-acp"; do
  if [ -d "$path" ]; then
    if cp -R "$path" "$BACKUP_DIR/"; then
      backed_up=$((backed_up + 1))
    else
      printf 'Backup failed: %s\n' "$path" >&2
      failed=1
    fi
  fi
done
if [ "$failed" -ne 0 ] || [ "$backed_up" -eq 0 ]; then
  printf 'Required backups did not complete; do not edit. Backup root: %s\n' "$BACKUP_DIR" >&2
  exit 1
fi
printf 'Backups saved to %s\n' "$BACKUP_DIR"
```

After editing:

```bash
# In a later shell, set BACKUP_DIR to the path printed by backup-first.sh.
BACKUP_DIR='/absolute/path/printed/by/backup-first.sh'
diff -u "$BACKUP_DIR/.claude/settings.json" "$HOME/.claude/settings.json"
```

**Best for:** Everyday manual testing by developers and users who want a simple, repeatable safety net without spinning up VMs.

---

### 13. Staging Config / Copy-to-Temp Strategy

**Approach:** Create a temporary staging home that mirrors the relevant directory
structure (`~/.claude/`, `~/.codex/`, `.cursor/`, etc.) from repository-owned,
token-free fixtures. Launch the app with the explicit test-root configuration described
in the plan. Test edits only against the copies; use an intentional, separately reviewed
change to update a real configuration later.

**Pros:**

- Tests representative complexity (nested permissions, comments in JSONC, TOML sections)
  without handling originals.
- The app's parser and UI are exercised exactly as they would be in production because the file formats are authentic.
- Works well with the app's "user-managed paths" feature (described in `AGENTS.md`).

**Cons:**

- Requires an extra manual migration step after testing; if the user forgets, good edits stay in `/tmp/`.
- Does not test file discovery logic that depends on the exact real home directory (e.g., OS-specific paths for Cursor IDE settings).
- If the app uses native platform APIs that bypass environment variables for path resolution, the staging directory may not be fully respected.

**Implementation:**

```bash
TEST_ROOT="$(mktemp -d)"
cp -R test/fixtures/staging_home/. "$TEST_ROOT/"
# Launch only after Phase 0 has established the supported test-root command.
# Do not copy a personal configuration file into this directory.
```

**Best for:** Integration testing of representative supported paths and formats.

---

### 14. Canary Config Strategy

**Approach:** Designate one token-free fixture in the disposable test root as a "canary."
Always test new edits, parser changes, or UI workflows against that fixture before adding
broader fixture coverage.

**Pros:**

- Exercises the same catalog path and file behavior as the staged fixture workflow.
- Creates a psychological and procedural buffer: if the canary edit corrupts something, the damage is contained to a disposable file.
- Minimal setup cost — create an obvious synthetic config in the fixture tree.
- Complements the backup-first protocol perfectly.

**Cons:**

- Does not fully eliminate risk; a severe parser bug could corrupt the canary and any other file edited in the same session.
- Requires discipline to create the canary and resist skipping straight to the critical file.
- Not suitable for high-risk cross-tool bulk operations unless a canary exists for each tool format.

**Implementation:**

```bash
mkdir -p ~/test-projects/canary-project/.claude
cat > ~/test-projects/canary-project/.claude/settings.json << 'EOF'
{"permissions":{"defaultMode":"default","allow":[],"ask":[],"deny":[]},"model":"claude-sonnet-4-20250514"}
EOF
# Point AgentsConfigHelper at ~/test-projects/canary-project/.claude/settings.json
```

**Best for:** Daily development cycles where developers need quick, realistic feedback without full isolation overhead.

---

### 15. Synthetic Fixture Matrix for Edge Cases

**Approach:** Systematically generate a matrix of synthetic config files that cover tricky edge cases for every supported tool format (JSON/JSONC, YAML, TOML, Markdown). For example: JSON with trailing commas and comments (`json_ast` preservation tests), YAML with multi-line strings and anchors, TOML with nested tables, and Markdown rules with YAML frontmatter. Store these in `test/fixtures/edge-cases/` and run automated parser and widget tests against them.

**Pros:**

- Reveals parser bugs that only occur with unusual real-world syntax (e.g., `//` comments inside JSONC, `"` escaping in TOML strings).
- Creates reproducible regression tests: once a parser bug is fixed, the edge-case file remains in the fixture matrix to prevent regression.
- Fully automated — runs in CI with `flutter test`.
- Zero risk because fixtures never touch real user directories.

**Cons:**

- Does not test file-system-level behaviors (permission errors, missing directories, OS-specific path resolution).
- Requires initial effort to construct representative edge cases for all 10+ supported tools.
- Synthetic fixtures may miss domain-specific patterns that only appear in actual user files.

**Implementation:**

```text
test/fixtures/edge-cases/
  claude/
    settings_with_trailing_commas.jsonc
    settings_with_comments.json
  codex/
    config_with_nested_sandbox.toml
  opencode/
    opencode_with_glob_permissions.json
  paseo/
    paseo_config_with_mcp.json
```

**Best for:** Automated parser regression testing and ensuring the structured editor handles non-standard but valid syntax correctly.

---

### 16. Parser Snapshot Testing (Dart)

**Approach:** Serialize each parser result into a deterministic, normalized text form
(for example, sorted JSON containing only stable fields) and compare it with a checked-in
text fixture. Any change creates a normal text diff that must be intentionally reviewed.

**Pros:**

- Extremely fast feedback: parser tests run in milliseconds.
- Captures the full structured representation, not just string equality, making it easy to spot unintended structural changes.
- Works seamlessly with the app's pure-function parser architecture (`lib/` parsers are pure functions — easy to test, per `AGENTS.md`).
- Text-fixture diffs can be reviewed in pull requests, providing a clear audit trail.

**Cons:**

- Does not test file I/O or UI behavior — it is strictly parser-level.
- Golden files must be maintained; renaming fields or restructuring output requires updating all snapshots.
- Only covers formats with structured parsers (JSON/JSONC, YAML, TOML); Markdown rules require separate text-level verification.

**Implementation:**

```dart
import 'package:flutter_test/flutter_test.dart';

group('Claude settings parser', () {
  test('preserves comments and trailing commas', () {
    final result = parseClaudeSettings(
      fixtureFile('claude/settings_with_trailing_commas.jsonc'),
    );
    final actual = normalizeParserResult(result);
    final expected = File(
      fixtureFile('snapshots/claude/settings_with_trailing_commas.json'),
    ).readAsStringSync();
    expect(actual, expected);
  });
});
```

**Best for:** Continuous integration pipelines that must catch parser regressions before they reach users.

`matchesGoldenFile` and `--update-goldens` are for Flutter image goldens; they are not
the mechanism for these text snapshots. Update the expected text deliberately in review.

---

### 17. App-Integrated `--dry-run` / `--safe-mode` CLI Flag

**Approach:** Extend the Flutter desktop build to accept a `--dry-run` (or `--preview-only`) command-line argument. When enabled:

- The app reads token-free fixtures using the test-root discovery configuration.
- All write operations (save, restore, edit apply) are redirected to an in-memory buffer
  or a path below the disposable test root.
- The UI displays a persistent banner indicating "SAFE MODE: Changes will not be saved."
- On exit, the temporary files are discarded unless the user explicitly exports them.

**Pros:**

- Allows users to explore the full app experience — including real file discovery, structured editing, and diff previews — with zero risk of persistent modification.
- Can serve as a onboarding/tutorial mode for new users who are afraid of editing real agent configs.
- Minimal architectural change: the app's `ConfigEditorService` only needs a conditional branch before invoking `File.writeAsString`.

**Cons:**

- Requires code changes to the app itself (new CLI argument parsing, conditional save logic).
- Does not fully test the actual write/restore pipeline unless safe-mode writes are also tested.
- Users may forget safe mode is active and assume their edits were saved.

**Implementation:**

```dart
// lib/services/config_service.dart (suggested modification)
Future<void> saveConfig(String path, String content, {bool dryRun = false}) async {
  if (dryRun) {
    previewStore.record(path, content); // In-memory only.
    return;
  }
  await File(path).writeAsString(content);
}
```

Launch:

```bash
flutter run -d macos -- --dry-run
```

**Best for:** User-facing safety feature and testing workflows that require full realism without persistence risk.

---

### 18. Docker with VNC for Flutter Desktop Testing

**Approach:** Improve the basic Docker container approach by using a Linux container (`ubuntu:22.04`) with a desktop environment (`xfce4` or `lxde`), a VNC server (`tigervnc`), and a web-based VNC client (`noVNC`). Build the Flutter Linux desktop binary inside the container, mount a test config directory as a volume, and connect via browser to interact with the GUI.

**Pros:**

- Provides actual GUI interaction (clicking, typing, navigating the structured editor) rather than only headless parser tests.
- Fully isolated from the developer's host OS and user home.
- Can be scripted for automated visual regression testing (compare screenshots before/after edits).
- Easier to share reproducible test environments with collaborators (just share the `docker-compose.yml` and fixture volume).

**Cons:**

- Heavy resource usage compared to headless tests; VNC adds latency.
- Only validates the Linux desktop build, not macOS or Windows-specific behaviors.
- Initial setup of X11, VNC, Flutter SDK, and desktop dependencies inside Docker is time-consuming.
- Rendering differences between containerized X11 and native macOS/Windows may cause false positives in visual tests.

**Implementation:**

```yaml
# docker-compose.yml (suggested; fixture input remains read-only)
services:
  flutter-test:
    image: flutter-linux-test
    build: .
    ports:
      - "6080:6080"  # noVNC
    volumes:
      - ./test/fixtures/staging_home:/fixtures:ro
    environment:
      - DISPLAY=:1
    command: >
      /bin/sh -c 'cp -a /fixtures/. /staging-home/ &&
      HOME=/staging-home ./scripts/run_container_smoke.sh'
```

Access at `http://localhost:6080` to interact with the running app.

**Best for:** Cross-platform CI validation and collaborative debugging where a visual GUI is required but isolation is critical.

---

### 19. CI Fixture Pipeline (GitHub Actions)

**Approach:** Add fixture parser, discovery, service, and widget tests to the existing
`flutter test` command in `.github/workflows/ci.yml`. The Dart tests own fixture syntax
and catalog assertions, avoiding separate validators until they provide coverage the
tests cannot.

**Pros:**

- Prevents broken fixtures or invalid syntax from creeping into the test suite.
- Runs automatically on every pull request — no manual intervention.
- Combines well with text snapshot testing (Strategy 17) for full regression coverage.
- Provides confidence that future parser changes don't break existing fixtures.

**Cons:**

- Only tests fixtures, not real user files; cannot catch environment-specific discovery bugs.
- Adds CI time; expected text-fixture updates require manual review.
- Fixture maintenance is an ongoing cost as new supported tools are added.

**Implementation:**

```yaml
# Existing .github/workflows/ci.yml test job, after fixture tests are added
- name: Test
  run: flutter test --coverage
```

**Best for:** Long-term maintenance of test quality and preventing parser regressions in a multi-tool project.

---

## Inkling's Overall Recommendations

### Written by Inkling — 2026-08-22

Based on the app's architecture (Flutter desktop, pure-function parsers, unsandboxed macOS access, real config file editing with timestamped backups), I recommend a **layered defense** that scales with risk:

| Phase | Primary Strategy | Secondary Strategy | Safety Net |
|---|---|---|---|
| Daily development / quick iteration | **Canary Config (14)** + **Staging Config (13)** | Read-only preview (`--dry-run` concept) | Manual timestamped backups (12) |
| Automated regression / parser quality | **Parser Snapshot Testing (16)** + **Synthetic Fixture Matrix (15)** | **CI Fixture Pipeline (19)** | Text-fixture reviews in PR |
| Integration / staged-fixture validation | **Staging Config (13)** | **Canary Config (14)** | Backup-first script (12) |
| Full isolation / high-stakes testing | **Virtual Machines** (existing) or **Docker with VNC (18)** | Dedicate a test user account (existing) | System snapshots (existing) |
| User-facing safety feature | **App-Integrated `--dry-run` (17)** | Proposed read-only UI mode | Backup restore (existing) |

**Top Priority Actions:**

1. **Complete the containment gate before using manual write tests.** Fixture work is
   safer and more valuable until that evidence exists.
2. **Add Synthetic Fixture Matrix (15)** for supported tool formats, focusing on JSONC
   comments, TOML nested tables, YAML multi-line strings, and Markdown YAML frontmatter.
3. **Introduce Parser Snapshot Testing (16)** for structured formats (`JSON`, `YAML`,
   `TOML`) using normalized text fixtures.
4. **Use the implemented macOS test-only `--test-root` boundary (10)** for disposable,
   token-free staging smoke tests. Linux and Windows must continue rejecting the flag until
   they have equivalent platform-native containment; a user-facing dry-run is separate
   product work.
5. **Layer VM or Docker isolation (18)** only for final cross-platform release
   validation, not for daily development.

**Key Principle:** Never rely on a single method. A synthetic fixture catches parser bugs; a canary config catches discovery bugs; a timestamped backup catches everything else. Combined, they provide practical, creative, and safe coverage for a desktop app that writes to real user files.

---

*End of Inkling's contributions to `docs/testing-strategies.md`*
