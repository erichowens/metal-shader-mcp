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

## Recently completed
- [x] CI modernization (PR #30): cancel-in-progress, paths/label gating, AGENT_HANDOFF
- [x] Node/TS headless helpers & tests; YAML fix; simple-mcp.ts mkdir security tweak
- [x] Docs: file-bridge deprecation, visual-required label, single-flight policy