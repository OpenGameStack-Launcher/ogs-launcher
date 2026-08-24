# Copilot MCP Setup for Context-Aware Code Reviews

This repository already contains review-focused Copilot skills and instructions.
Use this guide to configure MCP servers in GitHub repository settings so Copilot code reviews can use richer context.

## Why this matters

Copilot code review can use MCP tools to inspect pull requests, linked issues, workflow runs, and security metadata.
That makes review comments more tailored to this repository's standards and active changes.

## 1. Configure MCP servers in repository settings

In GitHub for this repository:

1. Open Settings.
2. Go to Copilot -> MCP servers.
3. Paste a JSON configuration into MCP configuration.
4. Save.

Use this baseline configuration:

```json
{
  "mcpServers": {
    "github-mcp-server": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/readonly",
      "tools": [
        "get_pull_request",
        "get_pull_request_files",
        "get_pull_request_reviews",
        "get_issue",
        "list_issue_comments",
        "list_workflow_runs",
        "list_workflow_jobs",
        "list_code_scanning_alerts"
      ],
      "headers": {
        "X-MCP-Toolsets": "pull_requests,issues,actions,code_security,secret_protection"
      }
    }
  }
}
```

Notes:
- The GitHub MCP server is enabled by default, but this explicit config allowlists review-relevant tools.
- Keep the server read-only for review workflows.

## 2. Keep MCP enabled for code review

In Settings -> Copilot -> Code review, confirm:

- Allow Copilot to use MCP tools when reviewing pull requests is enabled.

## 3. Validate the setup

1. Open or update a pull request.
2. Request a Copilot review.
3. In the PR timeline, open View session.
4. In logs, confirm MCP server startup and tool calls.
5. In review comments, check attribution for MCP server and skills usage.

## 4. Optional: use wider GitHub scope

If reviews must reference data outside this repository, configure a personal access token as an Agents secret:

- COPILOT_MCP_GITHUB_PERSONAL_ACCESS_TOKEN

Then customize the GitHub MCP server configuration per GitHub docs.

## 5. Repository context already in place

This repository already includes:

- .github/skills/code-review/SKILL.md
- .github/instructions/godot-code-review.instructions.md
- .github/copilot-instructions.md

These files bias Copilot toward Godot 4.7.2 and OGS-specific review criteria.
