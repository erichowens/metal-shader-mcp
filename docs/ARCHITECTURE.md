# Metal Shader MCP — Architecture Overview

This document explains the current and target architecture of Metal Shader MCP, why we are migrating away from the file-bridge to a strict MCP client, the error and testing model, and how this all supports the WARP workflow.

## Executive summary

- Replace file-polling with a strict MCP client to improve correctness, latency, security, and testability.
- Keep a safe fallback (legacy file-bridge) to avoid breaking workflows during the migration.
- Elevate evidence and reliability with structured errors and visual regression.

## Components (target)

```text
+-------------------------+      +------------------+      +---------------------------+
|  SwiftUI App (macOS)    |      | MCPBridge (DI)   |      |   MCP Live Client (STDIO) |
|  - ContentView (REPL)   | ---> | - protocol       | ---> | - Spawn server process    |
|  - HistoryTabView       |      | - BridgeContainer|      | - JSON-RPC over pipes     |
|  - LibraryView          |      | - FileBridgeMCP  |      | - Timeouts, retries       |
+-------------------------+      +------------------+      +-------------+-------------+
          ^                                |                              |
          |                                +------------------------------+
          |                                         (fallback)
          |
          | if MCP_SERVER_CMD unset or USE_FILE_BRIDGE=true
          |
          v
+----------------------+              +--------------------------------------+
|  File Bridge (today) |              |   Node/TS MCP Server (headless)      |
|  - commands.json     | <----------> | - Tools: set_shader, export_frame,   |
|  - status.json       |              |   export_sequence, extractDocstring  |
+----------------------+              | - Deterministic rendering hooks      |
                                      | - Structured errors + diagnostics    |
                                      +--------------------------------------+
```

## Data flows

### Transitional (file bridge)

```text
SwiftUI UI
  |
  | write commands.json (through FileBridgeMCP)
  v
Resources/communication/commands.json   (input queue)
  ^
  |  ContentView polling loop (checkForCommands)
  |
status.json, current_shader_meta.json, compilation_errors.json (UI/renderer write status/diagnostics)
```

Limitations: polling latency, implicit file contracts, race conditions, silent failures.

### Target (live MCP)

```text
SwiftUI UI
  |
  | MCPBridge (selected by BridgeFactory)
  v
MCPLiveClient (JSON-RPC over stdio)
  |
  v
Node MCP Server -> compile / render / post-process -> structured JSON result
```

Benefits: request/response semantics, timeouts/retries, structured error propagation, optional streaming/progress.

## Key sequences

### set_shader (target)

```text
User action -> ContentView.setShader()
   -> MCPBridge.setShader(code, desc, noSnapshot)
     -> MCPLiveClient: { "method":"set_shader", "params":{...} }
       -> Node compiles, parses docstrings, returns meta/errors
     -> Swift UI updates preview + metadata or shows error banner
```

### export_frame (deterministic)

```text
User clicks Export -> MCPBridge.exportFrame(desc, time?)
  -> MCPLiveClient: { "method":"export_frame", "params":{...} }
  -> Node renders with fixed seed/time -> { pngBase64, diagnostics }
  -> Swift saves PNG to Resources/screenshots/ and records to timeline
```

## Error surfacing (planned)

Node-side error example:

```json
{
  "error": {
    "code": "METAL_COMPILE_ERROR",
    "message": "undeclared identifier 'foo' at line 23",
    "data": { "line": 23, "suggestion": "Check function/variable names" }
  }
}
```

Swift shows ErrorBannerView:
- Title: "Compilation failed"
- Body: `undeclared identifier 'foo' at line 23`
- Actions: [Copy diagnostics], [Open logs]

## Configuration toggles

- `MCP_SERVER_CMD`: when set, the app prefers `MCPLiveClient` (live stdio JSON-RPC).
- `USE_FILE_BRIDGE=true`: force legacy file-bridge implementation.
- `Resources/communication/coreml_config.json`: optional Core ML post-processing; missing model is benign.

## Test strategy

- Swift unit tests at the UI boundary: inject a MockBridge to assert payloads, and verify error banner behavior.
- Node tests for MCP tools: success/failure/timeout cases; deterministic seeds.
- Visual regression: canonical shaders with multi-resolution baselines and pixel diff thresholds.

## Security rationale

- Avoid generic file inboxes; narrow to a structured API with typed requests/responses.
- Deterministic rendering improves reproducibility and reduces attack surface from arbitrary IO.
- CI advisors/rules can gate against insecure exec usage.

## WARP integration & evidence

- Visual changes must produce screenshots in `Resources/screenshots/`.
- CI jobs attach artifacts and summarize evidence.
- CHANGELOG.md records actions and screenshot paths; BUGS.md tracks issues.

## Glossary

- MCP: Model Context Protocol — here, a local tool bridge that the app (and AI assistants) can call.
- Bridge: The Swift interface (`MCPBridge`) that decouples UI from transport.
- File-bridge: Transitional mechanism using JSON files as a queue.
- Live client: Process boundary with stdio-based JSON-RPC protocol.

## References

- ROADMAP.md (phases and the next 30 actionable items)
- WARP.md (workflow protocol and evidence requirements)
- README.md (current state, quick start)
- CHANGELOG.md (history)