---
name: Pull Request Review and Merge Workflow
description: The standard workflow for reviewing Pull Requests, synchronizing documentation, running headless tests, merging, and cleaning up worktrees.
trigger: always_on
---

# Pull Request Review and Merge Workflow

When reviewing and merging Pull Requests, adhere to the canonical standards in [docs/REVIEWING_AND_MERGING_PRS.md](../../docs/REVIEWING_AND_MERGING_PRS.md) and `.agents/skills/code-review/SKILL.md`.

## 1. Discovery and Inspection
- Fetch open PRs using `gh pr list --state open`.
- **CRITICAL:** Never run a bare `gh pr view <ID>` command without `--json` (to avoid `read:project` token scope errors). Always inspect PR metadata and diffs using:
  ```powershell
  gh pr view <PR_ID> --json number,title,body,state,baseRefName,headRefName,commits,files
  gh pr diff <PR_ID>
  ```
- Audit the changes against:
  - **Acceptance Criteria & Dependencies:** All issue checklist items met; any `Depends on #X` issues closed and merged.
  - **Godot 4.7.2 & OGS Standards:** Static typing across `scripts/` and `tests/`, `##` docstrings, `const OgsLogger = preload("res://scripts/logging/logger.gd")` usage, air-gap safety (`OfflineEnforcer`, `SocketBlocker`), and path traversal protection.
  - **Test Coverage & Registration:** Adequate tests in `tests/*_tests.gd`, `.free()` called on UI nodes in scene tests, threads joined on exit, and any new test suites or `class_name` scripts registered in `tests/test_runner.gd`.

## 2. Worktree Reuse or Creation
- First check if the resolver's worktree already exists locally (e.g., `.worktrees/issue-<issue_number>` or `.worktrees/<headRefName>`).
  - **If it exists locally:** Perform your review, test execution, and documentation commits directly inside that existing worktree so you do not orphan it.
  - **If it does not exist locally:** Fetch the branch and create `.worktrees/review-pr-<PR_ID>`:
    ```powershell
    git fetch origin
    git worktree add .worktrees/review-pr-<PR_ID> <headRefName>
    ```

## 3. Independent Test Execution
- Inside the worktree, run the headless import pass and test suite:
  ```powershell
  godot --headless --editor --quit
  godot --headless -s res://tests/test_runner.gd
  ```
- Confirm 0 failures (`tests failed: 0`, exit code `0`).

## 4. Documentation Coordination & Fixes (Prior to Merge)
- As the **Documentation Steward**, review the PR's "Handoff for PR Reviewer & Documentation Agent" section and synchronize `docs/TESTING.md`, `docs/MANUAL_TESTING.md`, `docs/The_Plan.md`, `docs/*_SCHEMA.md`, and `README.md` as needed.
- If the PR needs documentation updates or minor review fixes (missing docstrings, comments, or logging), apply them inside the worktree, re-run tests, verify `git status` is clean, commit, and push to the PR branch:
  ```powershell
  git add -A
  git commit -m "docs: synchronize documentation and review updates for PR #<PR_ID>"
  git push origin HEAD:<headRefName>
  ```

## 5. Safe Merge and Complete Cleanup
Once tests pass and documentation is pushed:
1. Release any Windows file locks held by Godot processes and return to the repository root:
   ```powershell
   Stop-Process -Name "Godot*" -Force -ErrorAction SilentlyContinue
   Set-Location "c:\Projects\ogs-launcher"
   ```
2. Remove any local worktrees for this issue/PR and prune worktree metadata:
   ```powershell
   git worktree remove .worktrees/issue-<issue_number> --force -ErrorAction SilentlyContinue
   git worktree remove .worktrees/review-pr-<PR_ID> --force -ErrorAction SilentlyContinue
   if (Test-Path ".worktrees/issue-<issue_number>") { Remove-Item -Path ".worktrees/issue-<issue_number>" -Recurse -Force -ErrorAction SilentlyContinue }
   if (Test-Path ".worktrees/review-pr-<PR_ID>") { Remove-Item -Path ".worktrees/review-pr-<PR_ID>" -Recurse -Force -ErrorAction SilentlyContinue }
   git worktree prune
   ```
3. Merge the PR using a standard merge commit (never squash or rebase):
   ```powershell
   gh pr merge <PR_ID> --merge --delete-branch
   ```
4. Synchronize `main`, delete the local feature branch, register merged classes, and confirm the issue is closed:
   ```powershell
   git checkout main
   git pull origin main
   git branch -D <headRefName> -ErrorAction SilentlyContinue
   godot --headless --editor --quit
   ```
