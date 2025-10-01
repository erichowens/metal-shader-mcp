# Metal Shader MCP — Architecture Overview

This document explains the current and target architecture of Metal Shader MCP, why we are migrating away from the file-bridge to a strict MCP client, the error and testing model, and how this all supports the WARP workflow.

## Executive summary

- Replace file-polling with a strict MCP client to improve correctness, latency, security, and testability.
- Keep a safe fallback (legacy file-bridge) to avoid breaking workflows during the migration.
- Elevate evidence and reliability with structured errors and visual regression.

## Components (current)

```text
+-------------------------+      +--------------------+      +---------------------------+
|  SwiftUI App (macOS)    |      | MCPBridge (DI)     |      | MCPClient (high-level)    |
|  - ContentView (REPL)   | ---> | - protocol         | ---> | - Lazy initialization     |
|  - HistoryTabView       |      | - BridgeContainer  |      | - Health monitoring       |
|  - LibraryView          |      | - BridgeFactory    |      | - Error handling          |
+-------------------------+      +--------------------+      +-------------+-------------+
          ^                                |                              |
          |                                |                              v
          |                                |               +---------------------------+
          |                                |               | MCPTransport (protocol)   |
          |                                |               +-------------+-------------+
          |                                |                             |
          | if MCP_SERVER_CMD unset        |                             |
          | or USE_FILE_BRIDGE=true        +-----------------------------+
          |                                         (fallback)           |
          v                                                              v
+----------------------+              +------------------+   +------------------------+
|  FileBridgeMCP       |              | MCPStdioTransport|   | MockMCPTransport       |
|  - commands.json     | <--------->  | - stdio pipes    |   | - testing only         |
|  - status.json       |              | - JSON-RPC       |   | - no subprocess        |
+----------------------+              +------------------+   +------------------------+
          |                                     |                       |
          v                                     v                       v
+--------------------------------------+                     +-----------------------+
|   Node/TS MCP Server (headless)      |                     | Unit/Integration Tests|
| - Tools: set_shader, export_frame,   |                     | - Fast, reliable      |
|   export_sequence, extractDocstring  |                     | - No side effects     |
| - Deterministic rendering hooks      |                     +-----------------------+
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

### Current (live MCP with lazy initialization)

```text
SwiftUI UI
  |
  | MCPBridge (selected by BridgeFactory)
  v
MCPClient (automatic lazy initialization on first request)
  |
  | MCPTransport protocol
  v
MCPStdioTransport (JSON-RPC over stdio)
  |
  v
Node MCP Server -> compile / render / post-process -> structured JSON result
```

Benefits: 
- Request/response semantics with timeouts/retries
- Structured error propagation
- Lazy initialization (no explicit async init required)
- Testable via dependency injection (MockMCPTransport)
- Clean separation: high-level client logic vs. low-level transport

## Key sequences

### set_shader (current implementation)

```text
User action -> ContentView.setShader()
   -> MCPBridge.setShader(code, desc, noSnapshot)
     -> MCPClient.setShader() [auto-initializes if needed]
       -> MCPStdioTransport.sendRequest(method: "set_shader", params: {...})
         -> Node compiles, parses docstrings, returns meta/errors
       -> MCPClient returns success/error
     -> Swift UI updates preview + metadata or shows error banner
```

### export_frame (deterministic)

```text
User clicks Export -> MCPBridge.exportFrame(desc, time?)
  -> MCPClient.exportFrame() [auto-initializes if needed]
    -> MCPStdioTransport.sendRequest(method: "export_frame", params: {...})
      -> Node renders with fixed seed/time -> { pngBase64, diagnostics }
    -> MCPClient returns success/error
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

- `MCP_SERVER_CMD`: when set, the app uses `MCPClient` with `MCPStdioTransport` (live stdio JSON-RPC).
- `USE_FILE_BRIDGE=true`: force legacy file-bridge implementation.
- `DISABLE_FILE_POLLING=true`: disable file polling when using live MCP client.
- `Resources/communication/coreml_config.json`: optional Core ML post-processing; missing model is benign.

## Lazy Initialization

The `MCPClient` implements **lazy initialization** to simplify app startup:

- No explicit async initialization is required at app launch
- First call to any bridge method automatically initializes the transport
- Subsequent calls use the already-initialized connection
- Thread-safe: multiple concurrent first calls are handled correctly
- Idempotent: calling `initialize()` explicitly is safe but optional

This design eliminates the need for complex async app startup logic while maintaining correctness.

## Test strategy

### Integration tests (Swift)
- `MCPClientIntegrationTests`: Tests `MCPClient` with `MockMCPTransport`
  - No subprocess overhead (fast, reliable)
  - Tests lazy initialization, health checks, error handling, timeouts
  - Tests all MCPBridge protocol methods
  - Validates connection state transitions
  - 19 comprehensive test cases

### Unit tests (future)
- UI boundary tests: inject a MockBridge to assert payloads and verify error banner behavior
- Transport tests: verify stdio protocol implementation

### Node/server tests
- MCP tools: success/failure/timeout cases; deterministic seeds
- Visual regression: canonical shaders with multi-resolution baselines and pixel diff thresholds

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