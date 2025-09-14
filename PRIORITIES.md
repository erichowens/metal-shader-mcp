# Project Priorities (Single Source of Truth)

This file captures our intent, rationale, and enforcement posture. Revisit weekly.

## Must Do
- MCP-first architecture. All shader lifecycle ops are driven via MCP tools. UI is a strict client (no hidden side-channels).
- Deterministic, visual evidence for visual changes. Store under `Resources/screenshots/`.
- Fast PR loop: required checks complete in ≤ 8 minutes.
- Education-first: library with named shaders, descriptions, and approachable UI.

## Should Do
- Headless rendering/export APIs for batch runs and studies.
- Parameter extraction and presets; librarian tooling with docstring metadata.
- Baselines + visual diffing for key shaders.

## Shouldn’t Do
- UI-only features that can’t be triggered via MCP.
- File-bridge hacks in new code (only tolerated in transitional glue).

## Can’t Do
- Secrets in repo or logs. Never leak keys.
- Block merges without actionable feedback.

## Won’t Do (for now)
- Expensive, always-on heavy pipelines on every PR. Run on-demand/nightly.

## Required checks (branch protection target)
- MCP Node/TypeScript Tests
- Swift/Metal Build and Validation (smoke)
- UI Smoke (tab + status)

## Rationale snapshot (Q3 2025)
- Node/TypeScript tests: keep headless MCP tools deterministic and fast; validate parsing, IO, sequencing without macOS runner.
- Swift/Metal smoke: ensure the app compiles and minimal render path works.
- UI smoke: ensure shell tabs and status wiring remain healthy.

## Review cadence
- Weekly, via the scheduled workflow that checks branch protection vs this list and opens/updates an issue when they drift.

## Process policy
- Local-first testing: You MUST run local tests before pushing (Node: MCP_FAKE_RENDER=1 npm test; Swift: swift build/test).
- Single-flight PRs: only one active (non-draft) PR in flight for core work. Others remain draft and rebased after merge.
- Weekly, via the scheduled workflow that checks branch protection vs this list and opens/updates an issue when they drift.