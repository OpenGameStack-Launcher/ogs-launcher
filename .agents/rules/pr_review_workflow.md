# Pull Request Review and Merge Workflow

When the user asks you to review and merge Pull Requests, you MUST adhere to the following workflow to ensure quality, stability, and total isolation from the user's main workspace.

## 1. Discovery and Assessment
- Fetch the list of open PRs using `gh pr list`.
- Read the PR details and diff using `gh pr view <ID>` and `gh pr diff <ID>`.
- Perform an initial assessment. Changes must include:
  - **Proper Logging**: Modifications and new code should use the `OgsLogger` system where appropriate.
  - **Proper Comments/Documentation**: Code should be well-commented and explain *why* it does what it does.
  - **Automated Tests**: There must be adequate automated test coverage for the changes.

## 2. Safe Isolation (Worktrees)
To avoid interfering with the main repository or other agents, you MUST perform all deep inspections and changes in an isolated Git worktree (as specified in `git_workflow.md`).

1. Fetch the PR into a local branch:
   ```powershell
   git fetch origin pull/<PR_ID>/head:pr-<PR_ID>
   ```
2. Create the worktree:
   ```powershell
   git worktree add .worktrees/pr-<PR_ID> pr-<PR_ID>
   ```
3. Change into the worktree directory:
   ```powershell
   cd .worktrees/pr-<PR_ID>
   ```

## 3. Deep Inspection & Testing
- Inside the worktree, review the files directly if needed.
- Run the automated tests to verify the PR does not break the build:
  ```powershell
  & "C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe" --headless -s res://tests/test_runner.gd
  ```

## 4. Modification (If Needed)
If the PR lacks proper logging, comments, tests, or fails the test suite:
- Make the necessary code modifications **within the worktree**.
- Run the tests again to ensure your fixes work.
- Commit the changes (ensure a clean working tree per `git_workflow.md`).
- Push the changes back to the remote PR branch:
  ```powershell
  # Check which remote branch the PR is tracking, or use gh CLI to push
  # If pushing to a fork might be restricted, fallback to commenting via gh pr review
  git push origin HEAD:<remote-branch-name> 
  ```

## 5. Merge and Cleanup
If everything passes inspection (or after you have fixed it):
1. Navigate back to the main repository root.
2. Merge the PR using the GitHub CLI:
   ```powershell
   gh pr merge <PR_ID> --squash --delete-branch
   ```
3. Remove the temporary worktree to keep the workspace clean:
   ```powershell
   git worktree remove .worktrees/pr-<PR_ID> --force
   ```
4. Delete the local PR tracking branch:
   ```powershell
   git branch -D pr-<PR_ID>
   ```

## 6. Reporting
- Always provide a clear summary in the chat detailing what PRs you reviewed, any changes you had to make to them (e.g., adding tests, fixing Godot syntax), and confirm they were successfully merged and the worktrees cleaned up.
