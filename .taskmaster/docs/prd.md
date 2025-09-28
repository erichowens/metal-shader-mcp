# Product Requirements Document (PRD)

## 1. Overview
- Working title: Metal Shader MCP — Claude’s Shader Development Playground
- Owner / stakeholders: Solo maintainer (Erich), primary agent (WARP single‑agent), assistants (Claude/others via MCP)
- Status: Draft for review (will be promoted to Approved when ROADMAP deltas are resolved)
- Last updated: 2025‑09‑14
- Links: README.md, WARP.md, ROADMAP.md, PRIORITIES.md, VISUAL_TESTING.md, .github/workflows/epic-sync.yml, docs/EPICS.json
- Vision: A production‑grade, MCP‑first, artist‑friendly shader REPL where AI can see what it builds, iterate rapidly, and preserve visual intent with tests, baselines, and reproducible study artifacts.

## 2. Problem Statement
Shader artists, technical artists, and shader‑curious developers need a fast, reliable way to iterate on Metal shaders with immediate visual feedback, deterministic controls (time/seed/resolution), and educational scaffolding. Current tools are either code‑only, lack visual baselines, are not MCP‑driven, or don’t integrate a rigorous “visual evidence + CI” workflow. We need a tool‑assisted studio where AI and humans co‑create, with guardrails that preserve artistic intent.

## 3. Goals and Non‑Goals
### Goals
- MCP‑first: All shader lifecycle operations are invokable via tools; the app is a strict client.
- Determinism: Given time, seed, resolution, and uniforms, renders are reproducible.
- Visual Evidence: Every visual change is captured and testable (baselines/diffs/screenshots).
- Education: Library with named shaders, docstrings, presets, and explanations.
- Performance: 60fps target on reference hardware; REPL round‑trip under 1s for typical edits.
- CI Discipline: Fast, reliable checks; single‑flight PRs; WARP after‑action compliance.

### Non‑Goals
- Not a demo. Avoid “fake it” stubs. Production by default.
- Not web‑only. Primary target is macOS app with Metal; web exports are secondary.
- No telemetry by default. Any metrics are opt‑in and privacy‑first.

## 4. Users and Use Cases
- Shader Artist: Sketch looks quickly; tune parameters live; export frames/sequences.
- Technical Artist: Build reusable blocks; profile performance; enforce budgets; regressions guarded by baselines.
- Developer/Learner: Study annotated shaders; tweak parameters; watch errors; learn by comparison.
- Educator: Prepare lessons with presets and snapshots; show before/after; export galleries.
- Researcher: Run deterministic parameter sweeps; compare variants; archive provenance.

User stories (selected)
- As an artist, I want to adjust uniforms in real‑time and screenshot in one keystroke so I can capture iterations.
- As a TA, I want a performance HUD showing fps, gpu_ms, cpu_ms and a baseline diff to catch regressions.
- As a learner, I want each shader to have a name, description, tags, and presets so I can understand and remix.
- As a researcher, I want deterministic exports (seed/time/resolution) so comparisons are fair.

## 5. Requirements
### 5.1 Functional Requirements (App + MCP)
Core REPL
- set_shader(code), compile_shader(): compile, surface errors with line/col/snippet.
- run_frame(time, uniforms, resolution, seed): render offscreen; return image bytes.
- screenshot(description): save to Resources/screenshots with WARP naming.
- set_uniforms(map), set_time(t), set_seed(n), set_resolution(preset or WxH).

Visual Validation
- set_baseline(name), diff_against_baseline(name, threshold): generate pass/fail + diff image.
- sweep_param(name, from, to, steps) → contact sheet; compare_variants([...]).

Education & Library
- Library index with name, description, tags, difficulty; search and “Open in REPL”.
- Presets per shader; docstrings embedded next to code and persisted.

Archivist & Projects
- save_snapshot(): code path, image path, params, time/seed/resolution, message.
- Variants and timeline; export/import project bundles with provenance.

Performance & Profiling
- HUD: fps, gpu_ms p50/p95, cpu_ms, draw calls.
- Profile passes; soft budgets; warnings when exceeded.

Export
- Export still PNG; image sequence; future: MP4/GIF via AVFoundation.
- Cross‑format shader export (stretch goal): GLSL/HLSL/WGSL; Shadertoy/Unity/Unreal adapters.

MCP Strictness
- Swift app uses MCPBridge → MCPLiveClient; no file‑bridge for new work.
- Node headless tools provide run_frame/export_sequence; tests cover success/failure.

### 5.2 Non‑Functional Requirements
- Performance: 60fps target on reference device; compile < 500ms typical.
- REPL latency: round‑trip (compile+render small frame) under 1s typical.
- Reliability: graceful error surfacing; recovery paths; no app crashes from tool errors.
- Accessibility: keyboard‑first flows, contrast mindful UI, tooltip help.
- Privacy/Security: no secrets in repo; opt‑in telemetry only; sanitize inputs; avoid shell exec where possible.
- Portability: macOS initially; exports enable sharing to broader ecosystems.

## 6. UX / UI
- REPL layout: Tool Explorer (schemas, quick run) | Canvas (MTKView + overlays) | Editor/Inspector (code, errors, uniforms, export).
- Library: grid with thumbnails, tags, difficulty; detail with code, notes, presets.
- Projects: snapshots timeline, variants branches, notes, compare modes (split/overlay/heatmap).
- MCP Tools: searchable list, schema display, run forms; recent call log.
- History: chronological events with links to screenshots and snapshots.
- Overlays: grid, centerlines, gamut warn, safe area; pixel sampler.
- Shortcuts: Cmd+Enter compile; Space play/pause; Cmd+S snapshot; Cmd+B set baseline; Cmd+D diff.

Visual evidence expectations
- All visual changes must produce screenshots saved to Resources/screenshots/ with timestamps and descriptions.

## 7. Data Model
Paths under Resources/
- communication/ (transitional; to be removed after strict MCP)
- screenshots/ (baselines/, current/, diffs/, archive/)
- projects/<id>/project.json, snapshots/<id>.json, variants/<id>.json
- library/index.json, library/<slug>.metal, library/<slug>.json (metadata)
- presets/<shader-id>/*.json

Snapshot JSON (illustrative)
- id, time, seed, resolution, uniforms, code_path, image_path, message.

Shader metadata
- name, description, tags, difficulty, presets; stored alongside code; docstrings preferred.

## 8. APIs / Integrations
Swift side
- Protocol MCPBridge with methods: setShader(code), compile(), runFrame(args), screenshot(desc), setUniforms(map), setTime, setSeed, setResolution, setBaseline, diffAgainstBaseline.
- MCPLiveClient: stdio/websocket client; maps to Node MCP tools.

Node side
- Tools: set_shader, compile_shader, run_frame, export_sequence, extract_docstring, set_uniforms, set_time, set_seed, set_resolution, set_baseline, diff_against_baseline, sweep_param, compare_variants.

CI
- EPIC Progress Sync (.github/workflows/epic-sync.yml) posts progress to mapped EPICs.
- Required checks per PRIORITIES.md; WARP compliance; docs checks.

Exports
- PNG/image sequence now; stretch: MP4/GIF; shader code adapters (GLSL/HLSL/WGSL) later.

## 9. Success Metrics & KPIs
- REPL round‑trip < 1s typical; 60fps on reference shaders.
- Visual baseline coverage: 100% for canonical set; 80%+ across library initially.
- CI total time ≤ 8 minutes for required checks.
- Docs freshness SLO: key docs updated in same PR as changes (WARP enforced).

## 10. Rollout Plan (aligned with ROADMAP.md)
- Epic 1: Strict MCP Client (replace file‑bridge) with tests and error surfacing.
- Epic 2: Headless MCP maturation (run_frame, export_sequence, watch).
- Epic 3: Visual regression (baselines, multi‑res thresholds, nightly runs).
- Epic 4: Education & Library (docstrings, search, presets, “Open in REPL”).
- Epic 5: Archivist & Projects (snapshots/variants, compare, bundles).
- Epic 6: Performance & Profiling (HUD, budgets, benchmark harness).
- Epics 7–13: CI/CD hardening, Security, Docs, Study, Packaging, Telemetry (opt‑in).

## 11. Risks & Mitigations
- macOS‑only limits audience → provide export adapters (GLSL/WGSL) to share outputs.
- CI macOS runner variability → minimize heavy tests on PR; nightly full suite.
- Shader determinism may vary across GPUs → define reference env and acceptable tolerances.
- Scope creep → single‑flight PR policy; ROADMAP governance; PRD as guardrail.
- Security (exec usage) → replace with safe APIs; lint to block shell:true; sanitize inputs.

## 12. Dependencies
- Swift/SwiftUI/Metal toolchains; macOS runner; Node for MCP tools; GitHub Actions; local GPU.

## 13. Testing Strategy
- Swift: unit tests for MCPBridge interactions; UI smoke; later visual regression.
- Node: tool unit/integration tests; deterministic fake render in CI.
- Visual: baselines/diff for canonical shaders; cross‑resolution matrix; accept thresholds.
- Acceptance checklist per feature; WARP after‑action steps enforced.

## 14. Monitoring & Alerting
- CI dashboards; artifact links; EPIC sync comments as progress trail.
- Optional local telemetry (opt‑in); later crash reporting (opt‑in).

## 15. Documentation Plan
- Keep README, WARP, PRIORITIES, ROADMAP current; add MCP tool API docs.
- Update diagrams as architecture evolves.
- Website landing page and gallery (static site) sourced from screenshots and library metadata.

## 16. Security & Secrets
- Retrieval: per‑service portals (e.g., GitHub, Vercel/Netlify for website, Sentry if adopted).
- Storage:
  - Local dev: .env.local (gitignored), export via shell; never commit secrets.
  - CI: GitHub Actions Secrets; use built‑in GITHUB_TOKEN where possible; EPIC_SYNC_TOKEN only if cross‑repo posting is needed.
- Rotation: least privilege; rotate on suspicion; scrub from history if leaked.

## 17. Acceptance Criteria
- This PRD and the one‑pager exist under .taskmaster/docs/ and pass docs checks.
- Content aligns with WARP.md, ROADMAP.md, PRIORITIES.md; no contradictions.
- Concrete, testable statements for core loops and metrics.

## Appendix: Glossary
- Baseline: Reference image to compare against.
- Diff: Visual comparison result with highlighted changes.
- Uniforms: Runtime parameters provided to shaders.
- Seed/Time/Resolution: Determinism controls for reproducible renders.
- WGSL/GLSL/HLSL: Shader languages for web/OpenGL/DirectX ecosystems.
