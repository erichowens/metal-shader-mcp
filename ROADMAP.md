# Roadmap and Task List (Single Source of Truth)

This file enumerates the major epics and concrete tasks ahead. We operate with a single-flight PR policy for core work: only one active (non-draft) PR at a time; others remain draft and are rebased after merge.

Links
- Active PR: #29 (headless MCP helpers, fast Node CI, priorities review)
- Next PR (draft): #32 (strict MCP client groundwork)
- Branch protection update: issue #31
- PRIORITIES.md: required checks and process policy
- AGENT_HANDOFF.md: current state and continuity plan

## Epic 1 — Strict MCP Client (MCP-first, no bridge)
- [ ] Implement MCPLiveClient in Swift (stdio/websocket) behind `MCPBridge`
- [ ] Replace `FileBridgeMCP` usages in ContentView, HistoryTabView, AppShellView
- [ ] Remove polling loop (`checkForCommands`); use event/callbacks from MCP client
- [ ] Add robust error handling + retries; surface structured errors in UI
- [ ] Swift unit tests to assert UI actions call `MCPBridge` methods
- [ ] Deprecate/retire file-bridge paths and docs
- [ ] Update README/CONTRIBUTING with final deprecation details

## Epic 2 — Headless MCP server maturation
- [ ] Expand tools: `run_frame`, `export_sequence` (deterministic), parameter extraction, baseline/diff, snapshot/session ops
- [ ] Security hardening: remove any shell execs, sanitize inputs; no command injection vectors
- [ ] Replace busy-wait with fs.watch or event-based signaling where appropriate
- [ ] CLI ergonomics: subcommands and help output
- [ ] Tests for each tool (happy-path + failures)

## Epic 3 — Visual Regression & Evidence
- [ ] Baseline storage per shader + resolution; pixelmatch thresholds
- [ ] Multi-resolution coverage; configurable thresholds
- [ ] CI artifact retention tuning; index + summary pages
- [ ] Label/paths policy documented (visual-required)
- [ ] Nightly workflow to run full visual/evidence suite

## Epic 4 — Shader Library & Education UX
- [ ] Parse docstrings; index name/description/tags; search
- [ ] Parameter sliders from uniforms; ranges & presets; morphing between presets
- [ ] Glossary/tooltips; guided tutorials; beginner-friendly examples
- [ ] Library management: import/export/share entries

## Epic 5 — Archivist & Projects
- [ ] Sessions timeline: events, notes, tags
- [ ] Snapshot diff views (side-by-side, overlay, heatmap)
- [ ] Export/import session bundles
- [ ] Provenance metadata for study reproducibility

## Epic 6 — Performance & Profiling
- [ ] GPU/CPU timing overlay; average/min/max; FPS budget
- [ ] Memory/thermal hooks where available
- [ ] Benchmark harness + perf budgets per canonical shader set

## Epic 7 — CI/CD Hardening
- [ ] Branch protection: set required checks per PRIORITIES.md (issue #31)
- [ ] Cache keys include Swift version; pin toolchains where possible
- [ ] Optional macOS matrix for visual (cost/benefit)
- [ ] Consider reusable workflow via `workflow_call` for shared steps

## Epic 8 — Security & Compliance
- [ ] Remove remaining exec usage; prefer fs APIs and safe wrappers
- [ ] Dependency hygiene; lockfiles; minimal privileges
- [ ] Secrets scanning & policy

## Epic 9 — Documentation
- [ ] MCP tool API docs + examples
- [ ] CONTRIBUTING: contributor flow, labels (visual-required), single-flight policy
- [ ] README: evolving architecture diagrams and quick-starts

## Epic 10 — Study: LLM + MCP artist productivity
- [ ] Define fair contest protocol; tasks; seed shaders; metrics
- [ ] Logging & anonymization; reproducible exports
- [ ] Report templates; figures; summary dashboards

## Epic 11 — (Future) VLM training “critical aesthete”
- [ ] Data pipeline; labeling strategy; ethics & safety review
- [ ] Training scripts; evaluation protocols
- [ ] Integration points back into MCP for critique/feedback loops

## Epic 12 — Release Packaging
- [ ] Swift Package / app bundle targets; GH Releases
- [ ] Homebrew tap or SwiftPM install story (where applicable)
- [ ] Crash reporting (opt-in) and diagnostics guides

## Epic 13 — Telemetry (optional, privacy-first)
- [ ] Opt-in local metrics; clear policy & toggles
- [ ] Use to guide education UX improvements

---

## Near-term checklist (next 1–2 PRs)
- [ ] Merge PR #29 (headless helpers + fast Node CI + priorities review)
- [ ] Implement MCPLiveClient and swap `FileBridgeMCP` (start with REPL + History)
- [ ] Add Swift tests for MCPBridge calls; basic error handling surfacing
- [ ] Remove polling where replaced; document final bridge removal

---

## Post‑checklist plan (what we do after that)
Phase 2 — MCP-first parity and stability
- Wire remaining UI (AppShellView, Library load/search, Projects) to MCPBridge
- Replace remaining bridge writes (status/meta/library index) with MCP tool calls
- Harden error surfacing (Swift) and tool error models (Node)
- Expand Node tests to cover all helper paths (success/failure/timeout)

Phase 3 — Visual regression and evidence
- Land baseline/diff pipeline for a small canonical shader set
- Add multi-resolution matrix + thresholds; nightly job
- Evidence dashboards in CI summaries (links to top artifacts)

Phase 4 — Education and library
- Docstring parsing pipeline, tagging, search
- Parameter sliders + ranges + presets; morph between presets
- Tutorials and “learn mode” in UI

Phase 5 — Archivist + study readiness
- Session timeline UX polish; quick compare, notes, tags
- Export/import session bundles; provenance metadata
- Study harness scripts for fair contests

Phase 6 — Packaging & polish
- Release targets, install story, README quick-starts, troubleshooting
- Optional telemetry (opt‑in), diagnostics, crash reporting

---

## Next 30 actionable items (prioritized)
[P0] Highest priority; [P1] High; [P2] Medium

1. [P0][Swift] Introduce MCPLiveClient (stdio) implementing MCPBridge
2. [P0][Swift] Replace FileBridgeMCP in REPL (ContentView) for set_shader/export_frame
3. [P0][Swift] Replace FileBridgeMCP in HistoryTabView open snapshot (+silent)
4. [P0][Swift] Remove checkForCommands polling from REPL once MCPLiveClient is active
5. [P0][Swift] Surface structured errors from MCP (compile errors, IO, timeouts) in UI banner
6. [P0][Swift Tests] Add tests that tapping Export Frame/History open calls MCPBridge with correct payloads
7. [P0][Node Tests] Add tests for exportFrame/setShader error/timeout branches
8. [P1][Node] Add run_frame deterministic tool (PNG bytes out, base64) with seed + resolution
9. [P1][Node] Add export_sequence with deterministic stepping and progress callbacks
10. [P1][Node] Implement fs.watch‑based signaling (optional env to fall back to polling for local-only)
11. [P1][CI] Nightly visual run on canonical shaders; upload baseline/diff artifacts
12. [P1][CI] Add Swift version to cache keys; pin toolchains where feasible
13. [P1][Docs] CONTRIBUTING: full “visual-required” and single-flight guidance with examples
14. [P1][Docs] README: updated architecture diagram (MCPBridge ⇄ Node MCP)
15. [P1][Swift] Library: parse docstrings, build searchable index via MCP tool
16. [P1][Swift] Parameter sliders from uniforms; default ranges; persist presets
17. [P1][Swift] Add quick-compare overlay (A/B) for two snapshots
18. [P1][Swift] Session bundle export/import; include code, image, meta, timeline
19. [P1][Security] Remove remaining execSync usage from Node code; prefer fs/child_process with strict args where needed
20. [P1][Security] Add lint/check to fail CI if execSync/spawn with shell:true is introduced
21. [P2][UX] Tutorials (“learn mode”) with step‑through examples; glossary tooltips
22. [P2][Perf] In‑app FPS/timing HUD; average/min/max; soft budget display
23. [P2][Perf] Benchmark harness across canonical shaders; store trends
24. [P2][CI] Reusable workflow via workflow_call for common setup (Node/Swift)
25. [P2][Node] CLI ergonomics: `mcp run-frame`, `mcp set-shader` quick commands
26. [P2][Docs] MCP tool API reference page with examples
27. [P2][Release] Swift Package/App bundle targets; initial GH Release
28. [P2][Telemetry] Opt‑in local metrics for education UX (clearly documented)
29. [P2][Study] Define fair contest protocol; seed tasks; metrics; anonymization plan
30. [P2][Governance] Add “good first issue” labels and contributor paths

Acceptance notes (for early P0/P1 items)
- MCPLiveClient: proves end‑to‑end set_shader + export_frame without file-bridge
- UI error surfacing: user-visible banner with title/body, retry, and basic diagnostics link
- Tests: at least one Swift test per MCPBridge entry point; Node tests for success and failure branches

## Recently completed
- [x] CI modernization (PR #30): cancel-in-progress, paths/label gating, AGENT_HANDOFF
- [x] Node/TS headless helpers & tests; YAML fix; simple-mcp.ts mkdir security tweak
- [x] Docs: file-bridge deprecation, visual-required label, single-flight policy