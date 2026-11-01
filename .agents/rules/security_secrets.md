---
name: Security, Secrets, and Air-Gap Enforcement
description: Critical security directives for secrets management, air-gap isolation, and untrusted input validation in OGS Launcher.
trigger: always_on
---

# Security, Secrets & Air-Gap Enforcement

**CRITICAL DIRECTIVES FOR ALL AGENTS:**

1. **NEVER COMMIT SECRETS OR LOCAL SIGNING PATHS**:
   - You are strictly forbidden from committing or pushing private keys, certificates, `.keystore`/`.jks`/`.pfx` files, API tokens, or credentials to the repository.
   - When modifying `export_presets.cfg`, never commit machine-specific signing identities, passwords, or personal filesystem paths.

2. **STRICT AIR-GAP & OFFLINE ENFORCEMENT**:
   - OGS Launcher is an air-gap-first application. Never add telemetry, analytics, or silent outbound HTTP/socket calls.
   - All network activity must go through the explicit download/mirror flows (`scripts/network/` and `scripts/mirror/`) and must honor `OfflineEnforcer` and `SocketBlocker`.

3. **UNTRUSTED INPUT & PATH TRAVERSAL PROTECTION**:
   - Treat `ogs_stack.json`, `ogs_config.json`, `repository.json`, and ZIP archives as untrusted input.
   - Normalize and validate all resolved paths to prevent directory traversal (`../`) and zip-slip attacks during archive extraction or tool launching.
   - Enforce SHA-256 hash verification on tool archives before extraction.

4. **PRIVACY-SAFE LOGGING (`OgsLogger`)**:
   - Never log raw user-identifying filesystem paths, tokens, or secrets. Use `OgsLogger` (`scripts/logging/logger.gd`), which automatically redacts `system_path`, `absolute_path`, and `local_path` context keys.
