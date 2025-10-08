# Epic 1 — Strict MCP Client (Live stdio JSON-RPC)

This plan describes the goals, scope, deliverables, acceptance criteria, and rollout for replacing the file-bridge with a strict MCP live client.

## Goals
- Replace polling and file-queue with request/response over stdio JSON-RPC.
- Surface structured, actionable errors to the UI.
- Improve testability and reliability while keeping a safe fallback.

## Non-goals
- Rewriting the entire Node toolset.
- Removing the file-bridge on day one (it remains as a feature-flag fallback).

## Scope (initial)
- `MCPLiveClient` process lifecycle + JSON-RPC framing over stdin/stdout.
- Methods required by current UI flows:
  - `set_shader(code, description?, noSnapshot)`
  - `set_shader_with_meta(name?, description?, path?, code?, save, noSnapshot)`
  - `export_frame(description, time?)`
  - `set_tab(name)` (temporary until UI-only state is fully decoupled)
- Structured error mapping into Swift error banners.
- Removal of `checkForCommands` polling when live client is active.

## Deliverables
1) Live client (Swift)
- Spawn server using `MCP_SERVER_CMD`.
- JSON-RPC framing, request IDs, timeouts, and retry policy.
- Typed error mapping (code/message/data) -> UI banner with actions.

2) Node server (existing tools)
- Ensure tool endpoints return structured results and errors deterministically.
- Add explicit timeout paths and diagnostics.

3) Tests
- Swift: `MCPBridge` tests covering success, error, timeout.
- Node: tool tests for success/failure/timeout.

4) Docs
- Update README (transport overview) and MIGRATION (file-bridge -> live client).
- This EPIC plan + ARCHITECTURE diagrams (added).

## Acceptance criteria
- UI calls always go through `MCPBridge`.
- With `MCP_SERVER_CMD` set, live client is used and file polling is disabled.
- File-bridge remains available behind `USE_FILE_BRIDGE=true`.
- Each MCPBridge entry point has at least one Swift unit test.
- Node tool tests cover success/failure/timeout paths.
- Error Banner appears on structured failures, with copy/open-log affordances.
- Visual evidence captured for representative flows (REPL set_shader, History open, export_frame).
- CHANGELOG updated with screenshots and summary.

## JSON-RPC sketch

Request example:
```json
{ "jsonrpc": "2.0", "id": 1, "method": "set_shader", "params": { "code": "...", "description": "...", "noSnapshot": false } }
```

Success response:
```json
{ "jsonrpc": "2.0", "id": 1, "result": { "ok": true, "meta": { "name": "...", "description": "..." } } }
```

Error response:
```json
{ "jsonrpc": "2.0", "id": 1, "error": { "code": "METAL_COMPILE_ERROR", "message": "...", "data": { "line": 23 } } }
```

## Risks & mitigations
- Process stability: add timeouts, retries, and a circuit-breaker banner.
- Visual flakiness: deterministic seeds and fixed window sizes for tests.
- Drift between docs and reality: CI doc checks and EPIC progress sync.

## Ops & toggles
- `MCP_SERVER_CMD` enables live client.
- `USE_FILE_BRIDGE=true` forces legacy file-bridge.
- CoreML config: `Resources/communication/coreml_config.json` (optional).

## Rollout plan
1) Land live transport behind feature flag; keep file-bridge default unless `MCP_SERVER_CMD` provided.
2) Remove polling when live is active.
3) Add tests and visual evidence.
4) Flip default in docs when stable.

## Definition of Done
- All acceptance criteria satisfied.
- CHANGELOG entry with links to screenshots; BUGS.md updated as needed.
- PR merged; roadmap items ticked.

## Related
- ROADMAP.md (Epic 1 and Next 30 items)
- ARCHITECTURE.md (this repo)
- WARP.md (after-action requirements)