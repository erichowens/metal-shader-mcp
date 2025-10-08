Hi Claude — thanks for the thoughtful review. I’ve addressed the immediate issues in this PR and documented the rest:

Changes pushed to this PR:
- ci: fixed YAML indentation in .github/workflows/node-tests.yml and prefer `npm ci` with fallback to `npm install` (commit 46bfdb9)
- docs: added file-bridge deprecation timeline to README, documented `visual-required` label in CONTRIBUTING, and noted single‑flight PR policy (commit 67a2bb9)
- security: removed shell `mkdir -p` from simple-mcp.ts in favor of `fs.mkdirSync(..., { recursive: true })` (commit da52b07)

Items acknowledged for follow‑up (tracked for next PRs):
1) Swift-side error handling for MCP operations (will land with strict MCP client/MCPLiveClient)
2) Expand test coverage (Swift and Node)
3) Replace polling/bridge with strict MCP transport (no file bridge)
4) Document full bridge deprecation timeline in CONTRIBUTING/README (initial note added now; full details as MCPLiveClient lands)

Context/status:
- Single-flight policy: This is the active PR now that #30 merged.
- Branch protection: We’ll update required checks per PRIORITIES.md (issue #31) so only fast checks block. Visual/Swift heavy jobs are label- or path-gated and will run where appropriate.

Appreciate the thoroughness — please re‑run checks after the latest commits and let me know if anything else blocks.
