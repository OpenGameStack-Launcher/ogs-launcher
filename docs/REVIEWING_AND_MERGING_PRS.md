# Pull Request Review, Documentation & Merge Standards

This document establishes the official standards and workflow for reviewing, documenting, and merging Pull Requests in the **Open Game Stack (OGS) Launcher** repository, whether handled by a human developer or an autonomous agent.

---

## 1. Role Overview & Responsibilities

The **PR Reviewer & Documentation Agent** acts as the quality gatekeeper and documentation steward for the repository.

### Primary Responsibilities
1. **Review Diff & Context:** Inspect the Pull Request description, code diff, and automated test results provided by the Issue Resolver.
2. **Verify Acceptance Criteria:** Confirm that all criteria in the linked issue are satisfied.
3. **Verify Architecture, Security & Code Standards:** Audit the diff against Godot 4.7.2 syntax, static typing, `OgsLogger` usage, air-gap/offline safety, and path traversal protections (see `.agents/skills/code-review/SKILL.md`).
4. **Independent Test Execution:** Run the headless test suite inside the worktree and confirm zero failures (`tests failed: 0`).
5. **Synchronize Documentation:** Update `docs/TESTING.md`, `docs/MANUAL_TESTING.md`, `docs/The_Plan.md`, `docs/*_SCHEMA.md`, and `README.md` as appropriate on the feature branch prior to merge.
6. **Merge to Main & Clean Up:** Perform a standard Git merge commit (`--merge --delete-branch`), release Windows file locks, remove all local worktrees for the issue/PR, prune worktrees, and synchronize local `main`.

---

## 2. Review Checklist

Before approving or merging any Pull Request, verify the following:

### 1. Pre-Review & Dependency Check
* [ ] **Dependencies Resolved:** If the linked issue or PR mentions `Depends on #<number>`, confirm that all dependency issues are `CLOSED` and their PRs are already merged into `main`.
* [ ] **Reviewer Handoff Notes:** Check the PR description's **"Handoff for PR Reviewer & Documentation Agent"** section for specific documentation and testing notes provided by the resolver.

### 2. Code Quality, Architecture & Security
* [ ] **Godot 4.7.2 Syntax & Static Typing:** No Godot 3.x syntax (`instance()`, `yield()`, old `connect()`). Variables, parameters, and return types use static typing across both `scripts/` and `tests/`.
* [ ] **Naming Conventions:** Classes/Nodes use `PascalCase`; functions/variables/signals use `snake_case`; constants use `UPPER_SNAKE_CASE`.
* [ ] **Structured Logging (`OgsLogger`):** Operational events use `OgsLogger` (`const OgsLogger = preload("res://scripts/logging/logger.gd")`), not raw `print()` and not aliased as `Logger` (which collides with Godot 4's built-in `Logger` class). No sensitive user paths or secrets logged.
* [ ] **Air-Gap & Security Compliance:** No unauthorized network calls outside `scripts/network/` and `scripts/mirror/`. All network operations respect `OfflineEnforcer` and `SocketBlocker`. File and archive operations guard against path traversal (`../`) and zip-slip.
* [ ] **Resource & Thread Safety:** Threads are properly joined (`wait_to_finish()`) on exit, `FileAccess` handles are closed, and `.uid` files for any new/moved scripts are committed.

### 3. Testing Verification
* [ ] **Automated Test Report:** PR body includes evidence that all automated tests pass (`tests passed: X`, `tests failed: 0`).
* [ ] **Test Runner Registration:** Any new test suite in `tests/*_tests.gd` is added to `test_files` in `tests/test_runner.gd`, and any new `class_name` script is preloaded in `tests/test_runner.gd`.
* [ ] **Node Cleanup:** Scene tests call `.free()` on all instantiated UI nodes.
* [ ] **Independent Test Execution:** Reviewer independently runs `godot --headless -s res://tests/test_runner.gd` on the branch and confirms 0 failures.

---

## 3. PR Inspection & Local Testing Protocol

All review operations, including inspecting code, running automated tests, and committing documentation updates, must take place within an isolated Git worktree under `.worktrees/`.

### 1. View PR Overview & Diff
Inspect the PR description and diff via the GitHub CLI:

> [!WARNING]
> **NEVER run a bare `gh pr view <pr_number>` command.** Repository token configurations can trigger a `read:project` scope error for the bare command. You must ALWAYS use the `--json` flag:

```powershell
gh pr view <pr_number> --json number,title,body,state,baseRefName,headRefName,commits,files
gh pr diff <pr_number>
```

### 2. Access or Create the Review Worktree
Determine whether a local worktree for this feature branch already exists (created by the Issue Resolver):
* **If the resolver's worktree already exists locally** (e.g., at `.worktrees/issue-<issue_number>` or `.worktrees/<headRefName>`):
  Perform your review, testing, and documentation commits directly inside that existing worktree directory so you do not create duplicate worktrees or orphan the resolver's worktree!
* **If no worktree exists locally for the branch**:
  Fetch the branch and create a dedicated review worktree:
  ```powershell
  git fetch origin
  git worktree add .worktrees/review-pr-<pr_number> <headRefName>
  ```

### 3. Run Automated Tests Locally
Inside the worktree, run a headless import pass followed by the test suite:
```powershell
godot --headless --editor --quit
godot --headless -s res://tests/test_runner.gd
```

---

## 4. Documentation Coordination (Mandatory Prior to Merge)

The reviewing agent is the documentation steward and is responsible for synchronizing project documentation with code changes before merging.

### 1. Check Documentation Targets
* **`docs/TESTING.md`:** Update test suite descriptions or counts when new test suites or test categories are added.
* **`docs/MANUAL_TESTING.md`:** Add or update manual verification steps when user-facing UI workflows change.
* **`docs/The_Plan.md` / `docs/Design_Doc.md`:** Update if roadmap items, architectural components, or tool catalog specifications changed.
* **Schema Docs (`docs/MANIFEST_SCHEMA.md`, `docs/CONFIG_SCHEMA.md`, `docs/MIRROR_SCHEMA.md`):** Update if any JSON schema fields or validation error codes changed.
* **`README.md`:** Update if user-facing quick-start instructions, features, or release links changed.

### 2. Commit Documentation Updates (If Needed)
If documentation updates or minor review fixes (missing docstrings, logging, or comments) are needed, commit them directly to the feature branch **prior to merging**:
```powershell
git add -A
git commit -m "docs: synchronize documentation for PR #<pr_number>"
git push origin HEAD:<headRefName>
```
Always run `git status` to verify the worktree is completely clean before proceeding to merge.

---

## 5. Review Decisions & Safe Merge Protocol

### Scenario A: Blocking Changes Required
If the PR fails the test suite, violates air-gap/security rules, or misses core acceptance criteria that require substantial rework by the resolver, **do not merge**. Submit a review requesting changes:
```powershell
gh pr review <pr_number> --request-changes --body "<Detailed description of what needs to be fixed>"
```

### Scenario B: Approved & Ready to Merge
Once all acceptance criteria are met, automated tests pass with 0 failures, and documentation is synchronized on the feature branch, proceed to merge.

#### 1. Release Windows Locks & Remove Worktrees Before Merging
Before merging, terminate any lingering background Godot processes so Windows file locks are released, return to the repository root (`c:\Projects\ogs-launcher`), and remove any worktrees associated with the issue or PR:

```powershell
# Kill any lingering Godot console/editor processes to release Windows file locks
Stop-Process -Name "Godot*" -Force -ErrorAction SilentlyContinue

# Return to the main repository root
Set-Location "c:\Projects\ogs-launcher"

# Remove the worktree(s) used by the resolver and/or reviewer
git worktree remove .worktrees/issue-<issue_number> --force -ErrorAction SilentlyContinue
git worktree remove .worktrees/review-pr-<pr_number> --force -ErrorAction SilentlyContinue

# If Windows left an empty or untracked folder in .worktrees/, remove it cleanly
if (Test-Path ".worktrees/issue-<issue_number>") {
    Remove-Item -Path ".worktrees/issue-<issue_number>" -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path ".worktrees/review-pr-<pr_number>") {
    Remove-Item -Path ".worktrees/review-pr-<pr_number>" -Recurse -Force -ErrorAction SilentlyContinue
}

git worktree prune
```

#### 2. Merge the Pull Request
Merge using the GitHub CLI with a **standard merge commit** (preserving complete Git history) and delete the remote branch:
```powershell
gh pr merge <pr_number> --merge --delete-branch
```
> [!IMPORTANT]
> **DO NOT squash** (`--squash`) or rebase (`--rebase`). Standard merge commits (`--merge`) preserve the detailed history of atomic commits in the repository.

#### 3. Verify Issue Closure
Confirm that the linked issue (`Resolves #<issue_number>`) has transitioned to `CLOSED`:
```powershell
gh issue view <issue_number> --json state
```
If GitHub did not automatically close the issue (for example, if the PR body omitted the `Resolves #<issue_number>` keyword), close it explicitly:
```powershell
gh issue close <issue_number> --comment "Resolved and merged via PR #<pr_number>."
```

#### 4. Local Repository Synchronization & Branch Cleanup
From the main project directory (`c:\Projects\ogs-launcher`):
```powershell
# Ensure main is checked out and synchronized with origin/main
git checkout main
git pull origin main

# Delete local feature branch if still lingering
git branch -D <headRefName>

# Force a headless editor import pass to register newly merged classes and assets on main
godot --headless --editor --quit
```
