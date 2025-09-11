# Claude Shader REPL Guide

A pragmatic guide for building beautiful shaders with fast, visual iteration. This replaces the previous aspirational document and aligns with our WARP.md single-agent workflow.

## Why a REPL?
Claude can only learn to write good shaders if it can immediately see the results of each change. The REPL provides eyes (render), hands (uniforms/time), a notebook (snapshots/baselines), and a lab bench (sweep, profile, compare).

## Prioritized MCP Tooling (source of truth)
MVP (build in this order):
1) set_shader, compile_shader, validate_shader, get_compilation_errors
2) run_frame, start_preview_stream, update_uniforms
3) set_resolution/aspect/seed/mouse/time/play/pause/set_playback_speed
4) profile_performance, baseline.set, baseline.diff
5) sweep/grid + compare_variants
6) sample_pixel/capture_histogram/toggle_overlays
7) library.search/get/inject/list_categories, sessions.save_snapshot/list/get, examples.get
8) explain_compilation_error, explain_shader (optional)

See DESIGN.md and WARP.md for details.

## MCP-First Rules
- The UI and any agents MUST only act through MCP tools. No file-bridge, AppleScript, or private side-channels.
- All image artifacts are saved to `Resources/screenshots/` via MCP tools. No `Resources/exports/`.
- Every shader must carry a docstring name/description; MCP returns and persists this metadata.

## REPL Workflows (recipes Claude should follow)

### 1. Basic Loop
- set_shader(code)
- compile_shader() → if errors: get_compilation_errors() and fix
- run_frame(time, uniforms, resolution, seed) → returns image and writes to Resources/screenshots/
- sessions.save_snapshot({label, uniforms}) to persist code+image+meta

### 2. Debugging Compilation Errors
- get_compilation_errors() → use line/col/snippet to patch code
- recompile quickly (keep changes minimal)

### 3. Explore Parameters
- set_uniforms({ name: value }) and rerender
- sweep_param(name, from, to, steps) → produce contact sheet
- compare_variants([...]) for A/B

### 4. Guard Against Regressions
- set_baseline("name") → later diff_against_baseline("name", threshold)

### 5. Make it Reproducible
- set_seed(42), set_time(1.25), set_resolution("1080p")
- save_snapshot() prior to risky edits; branch_snapshot() for explorations

### 6. Education & Inspiration
- get_example_shader(type) → study → modify → document

## Conventions and Storage
- All interactions occur via MCP tools (stdio). No `Resources/communication/*.json` control plane.
- Screenshots: `Resources/screenshots/YYYY-MM-DD_HH-MM-SS_<desc>.png`
- Sessions and variants: `Resources/sessions/<session-id>/*`
- Educational shader library: `Resources/library/*.metal` + metadata.json

## WARP Alignment (must-do after each significant change)
1. Update BUGS.md if issues discovered
2. Update CHANGELOG.md with what changed
3. Capture visual evidence (screenshots)
4. Commit to git with descriptive message
5. Run tests or add new ones for new functionality

## Success Metrics
- REPL round‑trip under 1s for typical edits
- Deterministic renders given (time, seed, resolution)
- Visual regressions caught by baseline/diff
- Library examples compile and render on first try
- Claude can iteratively improve a shader across snapshots

---

This document is deliberately practical. Build the REPL, use it constantly, and document the journey with visuals and tests.
