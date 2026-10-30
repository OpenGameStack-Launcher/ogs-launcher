---
name: Issue Resolution Workflow
description: The standard workflow for triaging, implementing, testing, and opening Pull Requests for GitHub issues in OGS Launcher.
trigger: always_on
---

# Issue Resolution Workflow

When tasked with resolving GitHub issues, follow the canonical specifications in [docs/RESOLVING_ISSUES.md](../../docs/RESOLVING_ISSUES.md). When asked to orchestrate multi-issue creation, resolution, and PR review using subagents, activate the `issue-orchestration` skill (`.agents/skills/issue-orchestration/SKILL.md`).

## 1. Triage & Select an Issue
- Fetch open issues using:
  ```powershell
  gh issue list --state open --limit 50 --json number,title,labels,body
  ```
- **CRITICAL:** Never run a bare `gh issue view <id>` command without `--json` (it can fail with `read:project` token scope errors). Always use:
  ```powershell
  gh issue view <number> --json number,title,body,state,labels,assignees
  ```
- Check for `Depends on #<number>` in the issue body. Only select an issue whose dependencies are `CLOSED` and merged into `main`.
- Work on issues **one at a time**, prioritizing critical/high severity and foundational modules (`scripts/config`, `scripts/manifest`, `scripts/library`, `scripts/network`) before localized UI changes, starting with the lowest issue number in the top priority tier unless specified otherwise.

## 2. Create an Isolated Worktree Branch
- Follow `git_workflow.md`: always work inside `.worktrees/`, never directly on `main`:
  ```powershell
  git fetch origin
  git worktree add .worktrees/issue-<number> -b fix/issue-<number>-<short-description> origin/main
  ```
  *(Use `feature/issue-<number>-<short-description>` for enhancements).*

## 3. Implement the Fix
- Write clean, statically typed Godot 4.7.2 GDScript meeting every item in the issue's Acceptance Criteria.
- Preserve OGS architectural rules: air-gap first (`OfflineEnforcer`, `SocketBlocker`), portable paths (`PathResolver`), and path traversal protection.
- Add `##` docstrings to new functions and log operational events using `const OgsLogger = preload("res://scripts/logging/logger.gd")` (never alias as `Logger` and never log sensitive user paths).

## 4. Automated Testing
- Add or update unit or scene tests in `tests/*_tests.gd` (`extends RefCounted`, `class_name`, `func run() -> Dictionary`). Ensure scene tests `.free()` all created UI nodes.
- **CRITICAL:** Register any new `class_name` script and any new `tests/*_tests.gd` suite inside `tests/test_runner.gd`.
- Run the headless import pass and test suite inside the worktree:
  ```powershell
  godot --headless --editor --quit
  godot --headless -s res://tests/test_runner.gd
  ```
- All tests **MUST** pass (`tests failed: 0`, exit code `0`) before proceeding.

## 5. Commit & Open Pull Request
- Run `git status` inside the worktree and ensure all modified files and generated `.uid` files are staged and committed.
- Push the branch to origin (`git push -u origin HEAD`).
- Write the PR description to `pr_body.md` using `write_file` (following `.github/pull_request_template.md`, including `Resolves #<number>` and the **Handoff for PR Reviewer & Documentation Agent** section), create the PR, and remove `pr_body.md`:
  ```powershell
  gh pr create --title "<type>: <short description> (Resolves #<number>)" --body-file pr_body.md --base main
  Remove-Item -Path pr_body.md -Force -ErrorAction SilentlyContinue
  ```

## 6. Handoff Boundaries
- **Do not update project documentation** (`docs/The_Plan.md`, `docs/TESTING.md`, `docs/MANUAL_TESTING.md`, `README.md`) during the resolver step unless the issue itself is a documentation issue; provide handoff notes in the PR body for the PR Reviewer & Documentation Steward.
- **Do not merge the PR** from the resolver role. Either hand off to the `pr_reviewer` subagent (when running the authorized `issue-orchestration` pipeline) or report the PR URL to the user.
