/**
 * Hot Reload Manager for Metal Shaders
 * Watches shader files and triggers recompilation on changes
 */

import { watch, FSWatcher } from 'chokidar';
import { EventEmitter } from 'events';
import * as path from 'path';
import * as fs from 'fs/promises';
import { compileShader, CompilationResult } from './compiler.js';

export interface WatchOptions {
  debounce?: number;
  autoCompile?: boolean;
  optimize?: boolean;
}

export interface FileChange {
  path: string;
  type: 'add' | 'change' | 'unlink';
  timestamp: Date;
}

export class HotReloadManager extends EventEmitter {
  private watchers: Map<string, FSWatcher> = new Map();
  private compilationCache: Map<string, CompilationResult> = new Map();
  private changeQueue: Map<string, NodeJS.Timeout> = new Map();
  
  /**
   * Watch a shader file or directory
   */
  async watch(
    filePath: string,
    onChange: (change: FileChange) => void,
    options: WatchOptions = {}
  ): Promise<void> {
    const { debounce = 300, autoCompile = true, optimize = false } = options;
    
    // Check if already watching
    if (this.watchers.has(filePath)) {
      console.warn(`Already watching ${filePath}`);
      return;
    }
    
    // Create watcher
    const watcher = watch(filePath, {
      persistent: true,
      ignored: /(^|[\/\\])\../, // ignore dotfiles
      ignoreInitial: true,
      awaitWriteFinish: {
        stabilityThreshold: 200,
        pollInterval: 100,
      },
    });
    
    // Handle file changes
    watcher.on('change', async (changedPath) => {
      this.handleChange(changedPath, 'change', debounce, async () => {
        const change: FileChange = {
          path: changedPath,
          type: 'change',
          timestamp: new Date(),
        };
        
        // Auto-compile if enabled
        if (autoCompile && changedPath.endsWith('.metal')) {
          try {
            const code = await fs.readFile(changedPath, 'utf-8');
            const result = await compileShader(code, {
              target: 'air',
              optimize,
            });
            
            this.compilationCache.set(changedPath, result);
            this.emit('compiled', { path: changedPath, result });
            
            // Notify about compilation result
            if (result.success) {
              this.emit('success', {
                path: changedPath,
                outputPath: result.outputPath,
                compileTime: result.compileTime,
              });
            } else {
              this.emit('error', {
                path: changedPath,
                errors: result.errors,
                warnings: result.warnings,
              });
            }
          } catch (error) {
            this.emit('error', {
              path: changedPath,
              error: error,
            });
          }
        }
        
        // Call user callback
        onChange(change);
      });
    });
    
    watcher.on('add', (addedPath) => {
      this.handleChange(addedPath, 'add', debounce, () => {
        onChange({
          path: addedPath,
          type: 'add',
          timestamp: new Date(),
        });
      });
    });
    
    watcher.on('unlink', (removedPath) => {
      this.handleChange(removedPath, 'unlink', debounce, () => {
        // Clear compilation cache
        this.compilationCache.delete(removedPath);
        
        onChange({
          path: removedPath,
          type: 'unlink',
          timestamp: new Date(),
        });
      });
    });
    
    watcher.on('error', (error) => {
      this.emit('error', { path: filePath, error });
    });
    
    // Store watcher
    this.watchers.set(filePath, watcher);
    
    this.emit('watching', { path: filePath });
  }
  
  /**
   * Stop watching a file or directory
   */
  async unwatch(filePath: string): Promise<void> {
    const watcher = this.watchers.get(filePath);
    if (watcher) {
      await watcher.close();
      this.watchers.delete(filePath);
      this.compilationCache.delete(filePath);
      this.emit('unwatched', { path: filePath });
    }
  }
  
  /**
   * Stop watching all files
   */
  async unwatchAll(): Promise<void> {
    const promises = Array.from(this.watchers.keys()).map(path => this.unwatch(path));
    await Promise.all(promises);
  }
  
  /**
   * Get compilation result from cache
   */
  getCompilationResult(filePath: string): CompilationResult | undefined {
    return this.compilationCache.get(filePath);
  }
  
  /**
   * Get all watched paths
   */
  getWatchedPaths(): string[] {
    return Array.from(this.watchers.keys());
  }
  
  /**
   * Handle file changes with debouncing
   */
  private handleChange(
    filePath: string,
    type: string,
    debounce: number,
    callback: () => void
  ): void {
    // Clear existing timeout
    const existingTimeout = this.changeQueue.get(filePath);
    if (existingTimeout) {
      clearTimeout(existingTimeout);
    }
    
    // Set new timeout
    const timeout = setTimeout(() => {
      this.changeQueue.delete(filePath);
      callback();
    }, debounce);
    
    this.changeQueue.set(filePath, timeout);
  }
  
  /**
   * Create a development server with hot reload
   */
  async createDevServer(port: number = 3000): Promise<void> {
    const express = await import('express');
    const { WebSocketServer } = await import('ws');
    
    const app = express.default();
    const server = app.listen(port);
    const wss = new WebSocketServer({ server });
    
    // Track connected clients
    const clients = new Set<any>();
    
    // Serve static files
    app.use(express.static(process.cwd()));
    
    // WebSocket connections
    wss.on('connection', (ws) => {
      clients.add(ws);
      
      ws.on('close', () => {
        clients.delete(ws);
      });
      
      // Send initial state
      ws.send(JSON.stringify({
        type: 'connected',
        watched: this.getWatchedPaths(),
      }));
    });
    
    // Listen for compilation events
    this.on('compiled', ({ path, result }) => {
      const message = JSON.stringify({
        type: 'compiled',
        path,
        success: result.success,
        errors: result.errors,
        warnings: result.warnings,
      });
      
      clients.forEach(client => {
        if (client.readyState === 1) { // WebSocket.OPEN
          client.send(message);
        }
      });
    });
    
    // Serve development dashboard
    app.get('/dashboard', (req, res) => {
      res.send(this.getDashboardHTML(port));
    });
    
    console.log(`Hot reload server running at http://localhost:${port}/dashboard`);
  }
  
  /**
   * Get HTML for development dashboard
   */
  private getDashboardHTML(port: number): string {
    return `
<!DOCTYPE html>
<html>
<head>
    <title>Metal Shader Hot Reload</title>
    <style>
        body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: #1a1a2e;
            color: #eee;
            padding: 20px;
        }
        
        .header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 30px;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border-radius: 12px;
        }
        
        h1 {
            margin: 0;
            font-size: 24px;
        }
        
        .status {
            padding: 8px 16px;
            background: rgba(255, 255, 255, 0.2);
            border-radius: 20px;
            font-size: 14px;
            font-weight: 600;
        }
        
        .files {
            display: grid;
            gap: 15px;
        }
        
        .file {
            background: #0f0f23;
            border-radius: 8px;
            padding: 15px;
            border-left: 4px solid #667eea;
            transition: all 0.3s ease;
        }
        
        .file.success {
            border-left-color: #4CAF50;
        }
        
        .file.error {
            border-left-color: #f44336;
        }
        
        .file.compiling {
            animation: pulse 1s infinite;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.7; }
        }
        
        .file-path {
            font-family: 'Courier New', monospace;
            font-size: 14px;
            margin-bottom: 10px;
            color: #64B5F6;
        }
        
        .file-status {
            display: flex;
            align-items: center;
            gap: 10px;
            font-size: 12px;
        }
        
        .errors {
            margin-top: 10px;
            padding: 10px;
            background: rgba(244, 67, 54, 0.1);
            border-radius: 4px;
            font-family: 'Courier New', monospace;
            font-size: 12px;
        }
        
        .error-line {
            margin: 5px 0;
            color: #ff5252;
        }
        
        .warnings {
            margin-top: 10px;
            padding: 10px;
            background: rgba(255, 193, 7, 0.1);
            border-radius: 4px;
            font-family: 'Courier New', monospace;
            font-size: 12px;
        }
        
        .warning-line {
            margin: 5px 0;
            color: #FFC107;
        }
        
        .compile-time {
            color: #4CAF50;
            font-weight: 600;
        }
        
        .log {
            position: fixed;
            bottom: 20px;
            right: 20px;
            width: 400px;
            max-height: 300px;
            background: #0f0f23;
            border-radius: 8px;
            padding: 15px;
            overflow-y: auto;
            border: 1px solid #333;
        }
        
        .log-entry {
            margin: 5px 0;
            font-family: 'Courier New', monospace;
            font-size: 11px;
            color: #888;
        }
        
        .log-entry.info { color: #64B5F6; }
        .log-entry.success { color: #4CAF50; }
        .log-entry.error { color: #f44336; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔥 Metal Shader Hot Reload</h1>
        <div class="status" id="status">Connecting...</div>
    </div>
    
    <div class="files" id="files"></div>
    
    <div class="log" id="log"></div>
    
    <script>
        const ws = new WebSocket('ws://localhost:${port}');
        const status = document.getElementById('status');
        const filesContainer = document.getElementById('files');
        const log = document.getElementById('log');
        
        const files = new Map();
        
        ws.onopen = () => {
            status.textContent = '🟢 Connected';
            addLog('Connected to hot reload server', 'success');
        };
        
        ws.onclose = () => {
            status.textContent = '🔴 Disconnected';
            addLog('Disconnected from server', 'error');
        };
        
        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            
            switch(data.type) {
                case 'connected':
                    data.watched.forEach(path => {
                        addFile(path);
                    });
                    break;
                    
                case 'compiled':
                    updateFile(data.path, data);
                    break;
            }
        };
        
        function addFile(path) {
            if (!files.has(path)) {
                const fileDiv = document.createElement('div');
                fileDiv.className = 'file';
                fileDiv.innerHTML = \`
                    <div class="file-path">\${path}</div>
                    <div class="file-status">
                        <span>Watching...</span>
                    </div>
                \`;
                filesContainer.appendChild(fileDiv);
                files.set(path, fileDiv);
                addLog(\`Watching \${path}\`, 'info');
            }
        }
        
        function updateFile(path, data) {
            const fileDiv = files.get(path);
            if (!fileDiv) {
                addFile(path);
                return;
            }
            
            fileDiv.className = 'file ' + (data.success ? 'success' : 'error');
            
            let statusHTML = \`<div class="file-status">\`;
            
            if (data.success) {
                statusHTML += \`<span>✅ Compiled successfully</span>\`;
                addLog(\`✅ \${path} compiled successfully\`, 'success');
            } else {
                statusHTML += \`<span>❌ Compilation failed</span>\`;
                addLog(\`❌ \${path} compilation failed\`, 'error');
            }
            
            statusHTML += \`</div>\`;
            
            if (data.errors && data.errors.length > 0) {
                statusHTML += \`<div class="errors">\`;
                data.errors.forEach(err => {
                    statusHTML += \`<div class="error-line">Line \${err.line}:\${err.column} - \${err.message}</div>\`;
                });
                statusHTML += \`</div>\`;
            }
            
            if (data.warnings && data.warnings.length > 0) {
                statusHTML += \`<div class="warnings">\`;
                data.warnings.forEach(warn => {
                    statusHTML += \`<div class="warning-line">Line \${warn.line}:\${warn.column} - \${warn.message}</div>\`;
                });
                statusHTML += \`</div>\`;
            }
            
            fileDiv.innerHTML = \`
                <div class="file-path">\${path}</div>
                \${statusHTML}
            \`;
        }
        
        function addLog(message, type = 'info') {
            const entry = document.createElement('div');
            entry.className = 'log-entry ' + type;
            entry.textContent = new Date().toLocaleTimeString() + ' - ' + message;
            log.appendChild(entry);
            log.scrollTop = log.scrollHeight;
            
            // Keep only last 50 entries
            while (log.children.length > 50) {
                log.removeChild(log.firstChild);
            }
        }
    </script>
</body>
</html>
`;
  }
}