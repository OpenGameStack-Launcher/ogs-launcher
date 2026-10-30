---
name: Bug report
about: Report a defect, incorrect launcher logic, resource leak, or UI glitch
title: ''
labels: 'bug'
assignees: ''
---

<!-- Include if blocked by prior work: **Depends on #<issue_number>** -->

### 1. Problem & Context
A concise explanation of the problem, reproduction steps, observed behavior, and expected behavior.

**Reproduction Steps:**
1. 
2. 
3. 

**Observed Behavior:**
<!-- What actually happened -->

**Expected Behavior:**
<!-- What should have happened per docs/Design_Doc.md or docs/The_Plan.md -->

### 2. Technical Scope & Affected Files
Direct references to files, scenes, or scripts that need modification or investigation:
- `scripts/<domain>/<script_name>.gd`
- `scenes/<scene_name>.tscn` or `main.tscn`
- `tests/<test_name>_tests.gd`
- `tests/test_runner.gd` (if registering a new class or test suite)

### 3. Acceptance Criteria

#### [Component / Fix Area]
- [ ] Describe the expected behavior or fix
- [ ] Ensure `OgsLogger` (`const OgsLogger = preload("res://scripts/logging/logger.gd")`) is used for operational events without logging sensitive paths

#### Automated Tests (`tests/`)
- [ ] Add or update unit or scene test cases in `tests/<test_name>_tests.gd` verifying the fix.
- [ ] Register any new test suite or `class_name` in `tests/test_runner.gd`.
- [ ] Ensure all existing automated test suites pass without regressions (`tests failed: 0`).

#### Documentation Coordination (Mandatory per docs/REVIEWING_AND_MERGING_PRS.md)
- [ ] Update `docs/The_Plan.md` or `docs/Design_Doc.md` if specifications were ambiguous or changed.
- [ ] Update `docs/TESTING.md` and/or `docs/MANUAL_TESTING.md` with regression test cases.
- [ ] Update `docs/MANIFEST_SCHEMA.md`, `docs/CONFIG_SCHEMA.md`, or `docs/MIRROR_SCHEMA.md` if any schema behavior changed.
- [ ] Update `README.md` if user-facing workflows or visuals were modified.
