# Agent Handoff: CI Modernization and MCP-First UI

Owner: Automated Agent (this file is maintained so any agent can resume work)

## Completed in PRs
- feature/headless-mcp (PR #29)
  - Headless Node/TS MCP helpers (set_shader, export_frame, extractDocstring)
  - MCP Node/TypeScript Tests workflow
  - PRIORITIES.md and weekly priorities-review workflow
  - Swift fix: write current_shader_meta.json instead of library_index.json

## In Progress (this branch: ci/modernization)
- Add concurrency cancel-in-progress, path filters, and label-gating:
  - swift-build.yml: added concurrency + paths-filter + PR short-circuit
  - test.yml: added concurrency + paths-filter + PR short-circuit
  - visual-tests.yml: added concurrency + label-gating (visual-required)
  - ui-smoke.yml: added concurrency block

## Next Steps
1) Update branch protection on main to require (see PRIORITIES.md):
   - MCP Node/TypeScript Tests
   - Swift/Metal Build and Validation (smoke)
   - UI Smoke (tab + status)
2) Move heavy visual tests to non-blocking (only on label or main).
3) Build strict MCP client in Swift (replace file-bridge). Plan:
   - Create Sources/MetalShaderCore/MCPBridge.swift (protocol) and MCPLiveClient.swift (impl)
   - Create tool schemas and map to UI actions; route all writes via MCP
   - Remove file-bridge calls from ContentView/AppShellView
4) Enhance UI for Artists & Learners:
   - Library (searchable, annotated docstrings, examples)
   - REPL (param sliders, FPS, compile errors)
   - Archivist (snapshot compare, notes)
   - Educator (guided tours, glossary)
5) Visual baselines + pixel diff for select shaders.

## Fallbacks
- If macOS runners are slow, keep Node/TypeScript tests as the only required check until smoke jobs are stabilized.

## Contacts / Links
- Draft PR (headless MCP): https://github.com/erichowens/metal-shader-mcp/pull/29
- PRIORITIES.md is the source of truth for required checks and rationale.