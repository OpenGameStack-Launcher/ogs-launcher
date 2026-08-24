---
name: Issue Resolution Workflow
description: The standard workflow for picking up and resolving GitHub issues.
trigger: always_on
---

# Issue Resolution Workflow

When tasked with fixing issues, the agent **MUST** follow this process to ensure consistency and quality.

## 1. Select an Issue

- Use `gh issue list --state open --limit 1 --json number,title,body --jq "sort_by(.number)"` to fetch open issues from the GitHub repository.
- Work on issues **one at a time**, starting with the **oldest** (lowest number) unless the user specifies otherwise.
- Read the full issue body to understand the problem before writing any code.

## 2. Create a Worktree Branch

- Follow the rules in `git_workflow.md` — always work in a worktree, never directly on `main`.
- Branch naming convention: `fix-issue-<number>` (e.g., `fix-issue-42`).

## 3. Implement the Fix

- Write or update the necessary code.
- Ensure the code follows Godot 4.7.2 syntax and best practices.
- Add appropriate inline documentation and comments.
- Include any necessary logging using the `OgsLogger` system.

## 4. Automated Testing

- Add or update automated tests that specifically cover the code you changed or added.
- Run the tests locally to ensure they pass:
  ```
  & "C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe" --headless -s res://tests/test_runner.gd
  ```
- All tests **MUST** pass before proceeding.

## 5. Commit & Pull Request

- Run `git status` and ensure the working tree is clean (no uncommitted or untracked files).
- Commit with a clear message referencing the issue (e.g., `Fix #42: Refactor setup() to use UIDeps`).
- Push the branch to origin.
- Open a pull request using the GitHub CLI:
  ```
  gh pr create --title "Fix #42: <short description>" --body "Resolves #42. <explanation of the change>"
  ```

## 6. Review

- Wait for user feedback/approval on the PR before merging.
- Do **not** move on to the next issue until the user confirms it is time.

## 7. Cleanup

- Once the PR is merged or the user says to move on, clean up the worktree per `git_workflow.md`.
