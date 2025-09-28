# One‑Pager PRD

- Problem
  - Shader authors and learners need a fast, deterministic, MCP‑first shader studio with immediate visual feedback, visual baselines, and production discipline (tests, CI, docs). Most tools either lack MCP hooks, visual regression, or the rigorous WARP after‑action loop.

- Audience
  - Shader artists, technical artists, shader‑curious developers, educators, and researchers working on macOS with Metal.

- Goals (Must‑haves)
  - MCP‑first control of the entire shader loop; app is a strict client.
  - Deterministic renders (time/seed/resolution/uniforms) and reproducible exports.
  - Visual baselines/diffs and screenshot capture on every visual change.
  - 60fps target; REPL round‑trip under 1 second typical.
  - Educational shader library with docstrings, presets, and search.

- Non‑Goals
  - No demo scaffolding; production by default. Web target is secondary via exports.
  - No default telemetry; any metrics are strictly opt‑in.

- Core Features (MCP + App)
  - set_shader, compile_shader, run_frame, screenshot, set_uniforms/time/seed/resolution.
  - set_baseline/diff_against_baseline, sweep_param, compare_variants.
  - Performance HUD: fps, gpu_ms/cpu_ms; soft budgets and warnings.
  - Library: named shaders, descriptions, tags, presets; “Open in REPL.”
  - Projects: snapshots, variants, compare modes; export/import bundles.

- KPIs / Budgets
  - REPL loop < 1s typical; 60fps on reference shaders.
  - Visual baseline coverage: 100% of canonical shaders; 80%+ of library.
  - CI required checks ≤ 8 min end‑to‑end.

- Milestones (aligned to ROADMAP)
  1) Strict MCP client (replace file‑bridge) + tests + error surfacing
  2) Headless MCP maturation (run_frame/export_sequence)
  3) Visual regression (baselines, multi‑res, nightly)
  4) Education/library (docstrings, search, presets)
  5) Archivist/projects (snapshots/variants/bundles)
  6) Performance/profiling (HUD, budgets, benchmarks)

- Risks & Mitigations
  - macOS‑only audience → export adapters (GLSL/WGSL) to share outputs
  - GPU determinism variance → define reference env, tolerances, baselines
  - CI flakiness on mac runners → keep heavy jobs nightly; PRs run smoke + fakes
  - Security (shell exec) → safe APIs, lint to block dangerous patterns

- Links
  - WARP.md, ROADMAP.md, PRIORITIES.md, VISUAL_TESTING.md, .github/workflows/epic-sync.yml

- Definition of Done
  - Full PRD and this one‑pager live at .taskmaster/docs/, align with WARP/ROADMAP/PRIORITIES, and pass docs checks.
