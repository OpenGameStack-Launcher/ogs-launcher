---
name: Feature request
about: Propose a new OGS Launcher capability, UI enhancement, or architectural improvement
title: ''
labels: 'enhancement'
assignees: ''
---

<!-- Include if blocked by prior work: **Depends on #<issue_number>** -->

### 1. Problem & Context
A concise explanation of the user story, design motivation, and how this enhancement improves OGS Launcher while preserving offline/air-gap sovereignty.

### 2. Technical Scope & Affected Files
Direct references to files, scenes, or scripts that need modification or creation:
- `scripts/<domain>/<script_name>.gd`
- `scenes/<scene_name>.tscn` or `main.tscn`
- `tests/<test_name>_tests.gd`
- `tests/test_runner.gd` (if registering a new class or test suite)

### 3. Acceptance Criteria

#### [Feature Area 1]
- [ ] Explicit requirement 1
- [ ] Explicit requirement 2
- [ ] Preserve air-gap safety (`OfflineEnforcer` / `SocketBlocker`) and portable path resolution (`PathResolver`)

#### Automated Tests (`tests/`)
- [ ] Add unit or scene test cases in `tests/<test_name>_tests.gd` verifying the new functionality.
- [ ] Register any new test suite or `class_name` in `tests/test_runner.gd`.
- [ ] Ensure all existing automated test suites pass without regressions (`tests failed: 0`).

#### Documentation Coordination (Mandatory per docs/REVIEWING_AND_MERGING_PRS.md)
- [ ] Update `docs/The_Plan.md` and/or `docs/Design_Doc.md` to reflect new or modified specifications.
- [ ] Update `docs/TESTING.md` and `docs/MANUAL_TESTING.md` with new automated and manual test verification steps.
- [ ] Update `docs/MANIFEST_SCHEMA.md`, `docs/CONFIG_SCHEMA.md`, or `docs/MIRROR_SCHEMA.md` if any JSON schema changed.
- [ ] Update `README.md` if user-facing behavior, controls, or visuals are altered.
