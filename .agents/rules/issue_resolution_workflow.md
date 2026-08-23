---
name: Risk Assessment Process
description: The standard workflow for addressing issues tracked in risk_assessment.csv.
trigger: always_on
---

# Issue Resolution Workflow (risk_assessment.csv)

When tasked with tackling an issue from the `risk_assessment.csv` file, the agent **MUST** follow this exact process to ensure consistency and quality:

1. **Create a Branch**: 
   - Check out a new local branch named after the issue number (e.g., `fix-issue-15`).
2. **Implement the Fix**:
   - Write or update the necessary code.
   - Ensure the code follows Godot 4.7.2 syntax and best practices.
   - Add appropriate inline documentation and comments.
   - Include any necessary logging using the `OgsLogger` system.
3. **Automated Testing**:
   - Add or update automated tests that specifically cover the code you changed or added.
   - Run the tests locally to ensure they pass. Note: Use `& "C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe" --headless -s res://tests/test_runner.gd` to run tests locally via the console executable.
4. **Pull Request**:
   - Commit the changes with a clear message referencing the issue (e.g., `Fix #15: ...`).
   - Push the branch to origin.
   - Open a pull request using the GitHub CLI (`gh pr create`). The title and body should describe the fix and mention the issue it resolves.
5. **Review**:
   - Wait for user feedback/approval on the PR before merging.
