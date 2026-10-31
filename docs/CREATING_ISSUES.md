# GitHub Issue Creation Standard & Guidelines

This document outlines the standard specifications, structure, and workflow for creating GitHub issues for the **Open Game Stack (OGS) Launcher** repository. Adhering to these standards ensures that any contributor, human developer or autonomous agent, can pick up an issue, understand the context and requirements without ambiguity, implement the change, and properly verify their work.

---

## 1. Principles & Quality Bar

Every issue created in this repository must meet the following criteria:
1. **Self-Contained & Actionable:** Provide all necessary context, architectural decisions, and acceptance criteria. A contributor should never have to guess design intent or search for unlinked resources.
2. **Clear Boundaries:** Group requirements logically by affected components (e.g., Projects UI, Tools Controller, Library & Mirror Hydration, Manifest/Config Schemas, Network/Offline Enforcement, Automated Tests, Documentation).
3. **Traceability:** Explicitly list any dependencies (`Depends on #<issue_number>`) and note which documentation files need to be synchronized as part of the implementation.
4. **No Duplicates:** Always search open and closed issues (`gh issue list --state all`) before submitting a new issue.

---

## 2. Standard Issue Structure

All issues filed in OGS Launcher must follow this standardized layout. When creating an issue on GitHub, use one of the predefined templates in `.github/ISSUE_TEMPLATE/`:
* **Bug Report (`.github/ISSUE_TEMPLATE/bug_report.md`):** For defects, unexpected behavior, logic bugs, resource leaks, or UI glitches. Pre-labeled with `bug`.
* **Feature Request (`.github/ISSUE_TEMPLATE/feature_request.md`):** For new launcher capabilities, UI enhancements, or architectural improvements. Pre-labeled with `enhancement`.

Both templates implement the following required markdown structure:

```markdown
**Depends on #<issue_number>** (Include only if this issue has blockers)

### 1. Problem & Context
A concise explanation of the problem, bug, or feature request.
- For bugs: Reproduction steps, observed behavior, and expected behavior.
- For features/enhancements: User story, design motivation, and how the change aligns with OGS sovereignty/air-gap principles.

### 2. Technical Scope & Affected Files
Direct references to the files, scenes, or scripts that need modification or inspection:
- `scripts/<domain>/<script_name>.gd`
- `scenes/<scene_name>.tscn` or `main.tscn`
- `tests/<test_name>_tests.gd`
- `tests/test_runner.gd` (if registering a new class or test suite)

### 3. Acceptance Criteria
Checklist grouped by component or responsibility:

#### [Component / Feature Area 1]
- [ ] Explicit requirement 1
- [ ] Explicit requirement 2

#### [Component / Feature Area 2]
- [ ] Explicit requirement 3

#### Automated Tests (`tests/`)
- [ ] Add or update unit or scene test cases in `tests/<test_name>_tests.gd` verifying the new behavior.
- [ ] If adding a new test file or `class_name`, register it in `tests/test_runner.gd`.
- [ ] Ensure all existing automated test suites pass without regressions (`tests failed: 0`).

#### Documentation Coordination (Mandatory per docs/REVIEWING_AND_MERGING_PRS.md)
- [ ] Update `docs/The_Plan.md` or `docs/Design_Doc.md` if architecture, roadmap tasks, or specifications changed.
- [ ] Update `docs/TESTING.md` and/or `docs/MANUAL_TESTING.md` with new test coverage or manual verification steps.
- [ ] Update `docs/MANIFEST_SCHEMA.md`, `docs/CONFIG_SCHEMA.md`, or `docs/MIRROR_SCHEMA.md` if any JSON schema changed.
- [ ] Update `README.md` if user-facing workflows or visuals are altered.
```

---

## 3. Title & Labeling Conventions

### Title Format
Titles must be concise and use standard prefixes to indicate the area of the codebase:
- `UI - <Action/Description>` (e.g., `UI - Add Filter Search Box to Tools Download Tab`)
- `Core - <Action/Description>` (e.g., `Core - Validate Tool SHA-256 Before Extraction`)
- `Library - <Action/Description>` (e.g., `Library - Handle Trailing Slashes in PathResolver`)
- `Mirror - <Action/Description>` (e.g., `Mirror - Cache Remote Repository Manifest Locally`)
- `Network - <Action/Description>` (e.g., `Network - Enforce Port Range Validation in SocketBlocker`)
- `Seal - <Action/Description>` (e.g., `Seal - Stream Large Archives in ProjectSealArchiver`)
- `Docs - <Action/Description>` (e.g., `Docs - Update Manual Testing Guide for Tool Removal`)

Audit findings may also use `[<ID>] <Description>` (e.g., `[H-10] Close file handle in project_seal_config_writer`), and conventional commit prefixes (`feat:`, `fix:`, `refactor:`, `docs:`) are also acceptable.

### Labels
Apply at least one standard GitHub label when creating the issue:
- **Primary Category:** `bug`, `enhancement`, `documentation`, `good first issue`, `help wanted`, `audit`
- **Severity (Optional / Audit):** `severity: critical`, `severity: high`, `severity: medium`, `severity: low`
- **Technical Type (Optional):** `type: security`, `type: performance`, `type: resource-leak`, `type: fragility`, `type: readability`, `type: godot-best-practice`, `type: architecture`, `type: error-handling`, `type: type-safety`

---

## 4. Pre-Creation Checklist (For Authors & Agents)

Before publishing an issue via GitHub:
1. [ ] **Search Existing Issues:** Run `gh issue list --state all --limit 100` to confirm the issue does not already exist or duplicate past work.
2. [ ] **Inspect Codebase:** Verify the exact file paths (`scripts/...`, `scenes/...`, `tests/...`), variable names, and current behavior in the code.
3. [ ] **Clarify Design Choices:** Resolve any open design questions (e.g., offline fallback behavior, error codes, UI states) before publishing so the issue body contains firm decisions rather than open questions.
4. [ ] **Air-Gap & Security Guardrails:** If the issue touches file paths, archive extraction, or network logic, include acceptance criteria requiring `OfflineEnforcer` / `SocketBlocker` compliance, path traversal (`../`) validation, and `OgsLogger` structured logging without leaking sensitive paths.
5. [ ] **Include Documentation Acceptance Criteria:** Ensure the mandatory documentation coordination checklist is included per `docs/REVIEWING_AND_MERGING_PRS.md`.

---

## 5. Creating Issues via GitHub CLI

Contributors and agents can create issues directly from the command line using the GitHub CLI (`gh`).

### Option A: Using Predefined Templates
You can invoke the repository issue templates directly with the `--template` flag:
```powershell
# Create a bug report using the bug_report.md template
gh issue create --template "bug_report.md"

# Create a feature request using the feature_request.md template
gh issue create --template "feature_request.md" --title "UI - Add Search Filter to Tools Page"
```

### Option B: Scripted / Headless Creation (Recommended for Agents)
When generating an issue programmatically, an `issue_creator` agent is spun up to create **exactly one** issue per run and is shut down immediately afterward (if multiple issues need to be logged, the orchestrator spawns a separate `issue_creator` agent sequentially for each individual issue). Write the formatted markdown body to a temporary file (`issue_body.md`), create the single issue with `--body-file`, and remove the temporary file right after:

```powershell
# After writing issue_body.md with native file tools:
gh issue create --title "<Prefix> - <Short Summary>" --body-file issue_body.md --label "<bug|enhancement>"
Remove-Item -Path issue_body.md -Force -ErrorAction SilentlyContinue
```
