# Metal Shader MCP Setup Guide

## For Claude Code (Recommended)

Claude Code has built-in MCP support. To set up:

1. **Build the MCP server:**
   ```bash
   cd ~/coding/metal-shader-mcp
   npm install
   npm run build
   ```

2. **In Claude Code Settings:**
   - Open Settings (Cmd+,)
   - Navigate to: Extensions → MCP Servers
   - Click "Add Server"
   - Configure:
     - **Name:** `metal-shader-studio`
     - **Command:** `npm`
     - **Arguments:** `start`
     - **Working Directory:** `/Users/[your-username]/coding/metal-shader-mcp`

3. **Restart Claude Code** to activate the MCP server

## For Claude Desktop

1. **Edit Claude Desktop config:**
   ```bash
   open ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

2. **Add the MCP server configuration:**
   ```json
   {
     "mcpServers": {
       "metal-shader-studio": {
         "command": "node",
         "args": ["dist/index.js"],
         "cwd": "/Users/[your-username]/coding/metal-shader-mcp"
       }
     }
   }
   ```

3. **Restart Claude Desktop**

## For Other LLMs (OpenAI, Anthropic API, etc.)

The MCP server exposes a stdio interface that can be integrated with any LLM that supports tool calling:

### Using with LangChain:
```python
from langchain.tools import Tool
import subprocess

def call_metal_shader_mcp(tool_name, args):
    process = subprocess.Popen(
        ["node", "dist/index.js"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        cwd="/path/to/metal-shader-mcp"
    )
    # Send MCP protocol messages
    request = {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": tool_name,
            "arguments": args
        }
    }
    # ... handle stdio communication
```

### Using with AutoGPT/AgentGPT:
Add to your agent configuration:
```yaml
tools:
  - name: metal_shader_compiler
    type: mcp
    command: node dist/index.js
    working_dir: /path/to/metal-shader-mcp
    protocol: stdio
```

## Available MCP Tools

Once connected, your LLM will have access to these tools:

1. **compile_shader** - Compile Metal shader code
   ```
   Arguments: {
     "code": "shader source code",
     "target": "air|metallib|spirv",
     "optimize": true/false
   }
   ```

2. **preview_shader** - Generate preview images
   ```
   Arguments: {
     "shaderPath": "path/to/compiled.shader",
     "width": 512,
     "height": 512,
     "time": 0.5,
     "touchPoint": {"x": 0.5, "y": 0.5}
   }
   ```

3. **update_uniforms** - Update shader parameters
   ```
   Arguments: {
     "uniforms": {
       "time": 1.0,
       "resolution": [1920, 1080],
       "mouse": [0.5, 0.5]
     }
   }
   ```

4. **profile_performance** - Measure FPS and GPU usage
   ```
   Arguments: {
     "shaderPath": "path/to/shader",
     "iterations": 100
   }
   ```

5. **hot_reload** - Watch files for changes
   ```
   Arguments: {
     "filePath": "shaders/my_shader.metal",
     "enable": true
   }
   ```

6. **validate_shader** - Check syntax without compiling
   ```
   Arguments: {
     "code": "shader source code"
   }
   ```

## Testing the Connection

Ask your LLM to:
1. "Compile a simple gradient shader"
2. "Show me the available shader functions"
3. "Create a kaleidoscope effect with 6 segments"

## Troubleshooting

### MCP Server won't start:
- Check Node.js is installed: `node --version`
- Ensure you've run `npm install` and `npm run build`
- Check the logs in the Metal Studio app's MCP panel

### Claude Code doesn't see the tools:
- Restart Claude Code after adding the MCP server
- Check the MCP Servers panel in settings shows "Connected"
- Try running `npm start` manually to check for errors

### Shaders won't compile:
- Ensure Xcode Command Line Tools are installed: `xcode-select --install`
- Check that Metal is supported: `xcrun metal --version`