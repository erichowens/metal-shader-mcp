# UI/UX Design: Shader REPL App (macOS/iOS)

This document outlines the user stories, wireframes, view hierarchy, persistence model, and milestones for the local SwiftUI app that showcases MCP-driven shader development.

## 1) User Purpose & Stories

- As a shader artist, I want to write/iterate on a shader and immediately see the visual result so I can guide Claude toward the intended look.
- As a developer, I want a REPL loop with deterministic controls (time/seed/resolution) so I can reproduce and debug issues.
- As a learner, I want a rich shader library with educational annotations and presets so I can study, remix, and understand techniques.
- As a collaborator, I want to track generational improvements (snapshots/variants) across a project so I can show progress and avoid regressions.
- As a power user, I want to browse and trigger MCP tools, see their schemas, and run them with arguments from within the app.

## 2) Information Architecture / Screens

Primary Tabs (left sidebar or top tab bar):
- REPL
- Library
- Projects
- MCP Tools
- History

### REPL Screen (default)
Layout (3 columns):
- Left Pane: MCP Tool Explorer (collapsible)
  - Tools list (search/filter)
  - Tool detail: description + JSON schema + quick-run form
  - Recent tool calls & responses
- Center Pane: Canvas + Timeline
  - Render view (MTKView) with overlays (UV grid, centerlines, gamut warn, safe area)
  - Playback controls: Play/Pause, Speed, Time scrubber
  - Device/Resolution selector, Seed control
  - Performance HUD: fps, gpu_ms, cpu_ms
- Right Pane: Editor & Inspector
  - Code editor (Metal) with syntax highlighting & inline errors
  - Errors panel (list with line jump)
  - Uniforms panel (auto-generated controls: sliders/fields/vec pickers)
  - Export controls: Screenshot/Sequence

### Library Screen
- Grid of Educational Shaders (thumbnail + title + tags)
- Filters: category (generative, image fx, animation, 3D), difficulty, performance
- Detail Drawer:
  - Code, Description, Annotations (educational notes), References
  - Presets (thumbnails), “Open in REPL” button

### Projects Screen
- List of projects with progress metrics
- Project detail: Snapshots (timeline), Variants (branches), Notes
- “Compare” mode: select two snapshots/variants → diptych/triptych export

### MCP Tools Screen
- Full-screen tool browser
- Each tool shows: name, description, schema, examples, run form, result log

### History Screen
- Chronological log of edits: code changes, tool calls, screenshots
- Quick diff: before/after code, baseline/actual visuals

## 3) View Hierarchy (SwiftUI)
- App
  - NavigationSplitView (Sidebar: Tabs; Content: selected screen)
    - REPLView
      - HStack { ToolExplorerView | CanvasView | EditorInspectorView }
    - LibraryView (LazyVGrid of ShaderCardView)
    - ProjectsView → ProjectDetailView (SnapshotsView, VariantsView)
    - MCPToolsView (ToolList → ToolDetail)
    - HistoryView (Timeline + Detail)

## 4) Persistence Model (JSON)
Paths under Resources/:
- communication/  (MCP bridge files)
- screenshots/
- projects/<project-id>/project.json
- projects/<project-id>/snapshots/<snapshot-id>.json
- projects/<project-id>/variants/<variant-id>.json
- library/index.json, library/<slug>.metal, library/<slug>.json (metadata)
- presets/<shader-id>/*.json (named parameter sets)

Schemas (illustrative):
- project.json
  {
    "id": "proj_2025_09_07",
    "name": "Ocean_Study",
    "created_at": "2025-09-07T17:00:00Z",
    "snapshots": ["snap_001", "snap_002"],
    "variants": ["var_main", "var_bold"],
    "notes": "Goals and constraints"
  }
- snapshot.json
  {
    "id": "snap_001",
    "time": 1.25,
    "seed": 42,
    "resolution": {"w":1920, "h":1080},
    "uniforms": {"turbulence": 0.5},
    "code_path": "shader.metal",
    "image_path": "../../screenshots/2025-09-07_..._ocean_snap1.png",
    "message": "Improved highlight rolloff"
  }
- variant.json
  {
    "id": "var_bold",
    "base_snapshot": "snap_001",
    "branch_reason": "Increase contrast, more aggressive motion",
    "history": ["snap_001", "snap_003", "snap_005"]
  }
- library/<slug>.json
  {
    "name": "Plasma",
    "tags": ["generative", "animated"],
    "description": "Classic sine-sum plasma with radial modulation",
    "difficulty": "beginner",
    "notes": "Explain trigonometric layering, center shifting",
    "presets": [
      {"name":"Calm","uniforms":{"speed":0.3}},
      {"name":"Storm","uniforms":{"speed":1.2}}
    ]
  }

## 5) Educational Shader Library
Categories & Examples:
- Generative: plasma, gradient, noise, ripples, flow fields
- Image FX: blur, sharpen, color remap, edge detect
- Animation: waves, spiral morphs, particle sheets
- 3D/Raymarch: SDFs (sphere/torus), lighting demos
Each entry: code, annotated explanation, presets, references, performance notes.

## 6) Overlays & Debugging
- UV grid, centerlines, gamut warn, safe area
- Pixel sampler (shows RGBA, UV, depth if available)
- Buffer capture (final, depth, normal, uv, motion) when supported

## 7) Performance HUD
- FPS, gpu_ms (avg/p95), cpu_ms, draw calls
- Memory report: textures bytes, buffers bytes, peak transient bytes

## 8) Keyboard Shortcuts (examples)
- Cmd+Enter: Compile
- Space: Play/Pause
- Cmd+S: Save Snapshot
- Cmd+B: Set Baseline
- Cmd+D: Diff Against Baseline

## 9) Milestones / Build Order
M1 (REPL MVP): Compile, Canvas render, Time/Seed/Resolution controls, Uniform sliders, Screenshot
M2 (Debug): Error panel, Overlays, Pixel sampler, Baseline/Diff
M3 (Exploration): Sweep/Compare, Projects/Snapshots/Variants
M4 (Education): Library grid, details, presets, “Open in REPL”
M5 (Polish): MCP Explorer UI, History log, Accessibility, Device profiles

## 10) MCP Integration in UI
- Tool Explorer lists tools from MCP, shows input schema and examples
- One-click run with last args; response view (text/image)
- Log of recent tool invocations with parameters and outcomes

This design centers on making shader iteration observable, controllable, and educational—so Claude can truly learn by seeing. 
