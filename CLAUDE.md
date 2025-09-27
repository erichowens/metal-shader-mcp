# CLAUDE.md — Creative Direction and Assistant Guidance

This project follows an MCP‑first, evidence‑driven workflow. For upcoming work and priorities, consult the living roadmap.

- Roadmap (single source of truth): ROADMAP.md
- Priorities/process policy: PRIORITIES.md (required checks, single‑flight PRs)
- Handoff/state: AGENT_HANDOFF.md

Guidance for Claude and other assistants
- Always check ROADMAP.md first to understand what’s next.
- If you discover future work, write it down in ROADMAP.md under the appropriate epic and open an issue/PR as needed.
- Keep the roadmap living: re‑consider scope weekly; prune, promote, or defer.
- Follow the single‑flight PR policy to reduce cognitive load.

Notes
- File‑bridge is being deprecated in favor of a strict MCP client. See README for the deprecation timeline.
- Visual tests on PR require the label `visual-required`; they always run on main.

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

### Shader metadata conventions (required)
Every shader must include a docstring at the top that encodes name and description. This is parsed by `ShaderMetadata.from(code:path:)` and later powers Library indexing/search.

Example:
```
/**
 * Wavy Plasma
 * A smooth oscillating color field demonstrating uniforms.
 */
#include <metal_stdlib>
using namespace metal;
fragment float4 fragmentShader() { return float4(0,0,0,1); }
```

- First non-empty line becomes the shader name.
- Subsequent non-empty lines until the first blank line become the description.
- The absolute path (when known) is stored in `path` for provenance.

### Visual regression harness (now live)
- Tests render canonical shaders and compare against bundled goldens (processed resources under `Tests/MetalShaderTests/Fixtures`).
- On failure, tests write artifacts to `Resources/screenshots/tests/`:
  - `actual_*.png` (current actual)
  - `diff_*.png` (highlighting mismatches)
  - `*_summary.json` (quick diagnostics)
- Approve changes by refreshing goldens: `make regen-goldens`.

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
