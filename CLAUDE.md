# Claude Shader REPL Guide

A pragmatic guide for building beautiful shaders with fast, visual iteration. This replaces the previous aspirational document and aligns with our WARP.md single-agent workflow.

## Why a REPL?
Claude can only learn to write good shaders if it can immediately see the results of each change. The REPL provides eyes (render), hands (uniforms/time), a notebook (snapshots/baselines), and a lab bench (sweep, profile, compare).

## Prioritized MCP Tooling (source of truth)
MVP (build in this order):
1) set_shader, compile_shader, get_compilation_errors
2) run_frame/screenshot, set_uniforms, set_time/play/pause/set_playback_speed
3) set_resolution/aspect/seed/mouse
4) profile_frame, set_baseline/diff_against_baseline
5) sweep_param/grid + compare_variants
6) sample_pixel/capture_histogram/toggle_overlays
7) library, assets, snapshots
8) explain_error/auto_tune (optional)

See DESIGN.md and WARP.md for details.

## REPL Workflows (recipes Claude should follow)

### 1. Basic Loop
- set_shader(code)
- compile_shader() → if errors: get_compilation_errors() and fix
- run_frame(time, uniforms, resolution, seed)
- screenshot("desc") and record observations

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
- Communication files under Resources/communication/*.json
- Screenshots: Resources/screenshots/YYYY-MM-DD_HH-MM-SS_<desc>.png
- Projects, snapshots, variants, presets: Resources/projects/<project-id>/*.json
- Educational shader library: Resources/library/*.metal + metadata.json

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
