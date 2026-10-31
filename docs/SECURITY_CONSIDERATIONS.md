# Security Considerations

This document lists recurring security pitfalls and checks for contributors. Use it as a checklist when changing launcher behavior, manifest handling, or any network-related features.

## Trust Boundaries

- Treat `stack.json` and `ogs_config.json` as untrusted input.
- Do not execute binaries from untrusted or unexpected locations.
- Avoid writing project paths or sensitive data to shared user storage without explicit need.

## Manifest and Tool Execution

- Enforce project-relative tool paths by default.
- Normalize resolved paths and verify they remain under the project root.
- Require SHA-256 verification when checksums are present.
- Reject unknown tools unless explicitly approved by the user.

## Network Access

- All launcher network access must go through SocketBlocker.
- Default to offline-safe behavior; require explicit enablement for network access.
- Use allowlists for hostnames and ports; log outbound attempts for auditability.

## Offline Enforcement Scope

- Offline enforcement targets launcher/editor tooling only.
- Do not modify project runtime networking; exported applications may require internal network access.

## Tool Config Injection

- Keep overrides tool-scoped and reversible.
- Avoid modifying project assets or runtime configuration.
- Prefer best-effort overrides and document any limitations.

## Data Handling

- Minimize storage of local paths in shared locations; prefer hashed project identifiers.
- Avoid storing credentials; never write secrets to disk.

## Remote Git Cloning and CLI Hardening

- Air-Gap Enforcement: Verify `OfflineEnforcer.is_offline()` before initiating any Git network invocation; block operations immediately when offline.
- Git Argument Injection Defenses: Never pass unsanitized user-supplied URLs directly to Git CLI commands without leading dash/hyphen validation (`begins_with("-")`) and delimiter protection (`--` argument separator before repo URL and target directory).
- Git Protocol Restrictions: Explicitly pass security configuration flags on every Git execution:
  - `-c protocol.ext.allow=never`: Disables custom protocol helpers that can execute arbitrary commands (`ext::`).
  - `-c protocol.file.allow=never`: Prevents cloning local filesystem paths via Git protocol smuggling.
- Symlink and Hook Hardening: Enforce `-c core.symlinks=false` and `-c core.fsmonitor=false` to mitigate repository checkout vulnerabilities such as symlink path traversal and malicious hook execution (CVE-2024-32002).
- Two-Phase Pre-Checkout Manifest Verification: For remote repositories containing heavy binary assets, perform a blobless, no-checkout clone (`--filter=blob:none --no-checkout`) followed by `git show HEAD:stack.json` inspection. Validate `stack.json` using `StackManifest` before hydrating working tree files, aborting and purging if the manifest is invalid or missing.
- Defensive Directory Deletion Bounds: Guard all folder purges (on cancellation or failure) with `PathUtils.is_path_under_root(target_dir, dest_root)` to prevent accidental directory traversal or unintended deletions outside the configured projects directory.
- Credential and Path Redaction: Never log user passwords, Personal Access Tokens, or raw filesystem home directories. Route all operational logging through `OgsLogger` which automatically redacts sensitive paths.

## Testing Expectations

- Add unit tests for validation, path handling, and offline guards.
- Add scene tests for UI gating of network features.
