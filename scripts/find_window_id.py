#!/usr/bin/env python3
"""
Find CGWindowID for macOS applications with resilience and flexibility.

Supports:
- Retries with exponential backoff for app initialization
- Selection by bundle ID or window title
- Multiple selection strategies (frontmost, largest, first)
- JSON output format
- Proper exit codes and error handling

Exit codes:
  0: Success - window ID found
  2: No window found
  3: Multiple ambiguous windows found
  4: Dependency error (missing swift or other tools)
"""

import subprocess
import json
import sys
import os
import time
import argparse
from typing import Optional, Dict, Any

# Configuration from environment
DEFAULT_MAX_RETRIES = int(os.getenv('FIND_WINDOW_MAX_RETRIES', '10'))
DEFAULT_RETRY_DELAY = float(os.getenv('FIND_WINDOW_RETRY_DELAY', '0.5'))
DEFAULT_BACKOFF_MULTIPLIER = float(os.getenv('FIND_WINDOW_BACKOFF', '1.5'))


def log_stderr(msg: str, verbose: bool = True):
    """Log to stderr for structured output"""
    if verbose:
        print(msg, file=sys.stderr)


def check_dependencies() -> bool:
    """Check if required tools are available"""
    try:
        result = subprocess.run(['swift', '--version'], 
                              capture_output=True, timeout=5)
        return result.returncode == 0
    except (subprocess.SubprocessError, FileNotFoundError):
        return False


def get_windows_via_swift(bundle_id: Optional[str] = None, 
                         window_title: Optional[str] = None,
                         app_name: Optional[str] = None,
                         verbose: bool = True) -> list:
    """
    Get all matching windows using Swift/CoreGraphics.
    Returns list of dicts with windowID, ownerName, windowName, bounds, layer.
    """
    swift_code = f'''
import Cocoa
import CoreGraphics
import Foundation

let windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements, .optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]

var matches: [[String: Any]] = []

for window in windowList {{
    guard let ownerName = window[kCGWindowOwnerName as String] as? String,
          let windowID = window[kCGWindowNumber as String] as? Int,
          let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
          let layer = window[kCGWindowLayer as String] as? Int else {{
        continue
    }}
    
    let windowName = window[kCGWindowName as String] as? String ?? ""
    let isOnScreen = window[kCGWindowIsOnscreen as String] as? Bool ?? false
    
    var matches_criteria = false
    
    // Match by bundle ID (if provided)
    {"if let bundleId = \"" + (bundle_id or "") + "\".isEmpty ? nil : \"" + (bundle_id or "") + "\" {{" if bundle_id else "// No bundle ID filter"}
    {"    if let ownerPID = window[kCGWindowOwnerPID as String] as? Int {{" if bundle_id else ""}
    {"        let task = Process()" if bundle_id else ""}
    {"        task.launchPath = \"/bin/ps\"" if bundle_id else ""}
    {"        task.arguments = [\"-p\", \"\\(ownerPID)\", \"-o\", \"comm=\"]" if bundle_id else ""}
    {"        let pipe = Pipe()" if bundle_id else ""}
    {"        task.standardOutput = pipe" if bundle_id else ""}
    {"        try? task.run()" if bundle_id else ""}
    {"        task.waitUntilExit()" if bundle_id else ""}
    {"        let data = pipe.fileHandleForReading.readDataToEndOfFile()" if bundle_id else ""}
    {"        if let comm = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {{" if bundle_id else ""}
    {"            if comm.contains(bundleId) {{ matches_criteria = true }}" if bundle_id else ""}
    {"        }}" if bundle_id else ""}
    {"    }}" if bundle_id else ""}
    {"}}" if bundle_id else ""}
    
    // Match by window title (if provided)
    {"if let title = \"" + (window_title or "") + "\".isEmpty ? nil : \"" + (window_title or "") + "\" {{" if window_title else "// No window title filter"}
    {"    if windowName.contains(title) {{ matches_criteria = true }}" if window_title else ""}
    {"}}" if window_title else ""}
    
    // Match by app name (if provided)
    {"if let name = \"" + (app_name or "") + "\".isEmpty ? nil : \"" + (app_name or "") + "\" {{" if app_name else "// No app name filter"}
    {"    if ownerName.contains(name) {{ matches_criteria = true }}" if app_name else ""}
    {"}}" if app_name else ""}
    
    // Default: look for common app names if no filters
    {"if !matches_criteria {{" if not (bundle_id or window_title or app_name) else "// Filters provided"}
    {"    if ownerName.contains(\"ShaderPlayground\") || ownerName.contains(\"MetalShaderStudio\") {{" if not (bundle_id or window_title or app_name) else ""}
    {"        matches_criteria = true" if not (bundle_id or window_title or app_name) else ""}
    {"    }}" if not (bundle_id or window_title or app_name) else ""}
    {"}}" if not (bundle_id or window_title or app_name) else ""}
    
    if matches_criteria && isOnScreen {{
        let width = bounds["Width"] ?? 0
        let height = bounds["Height"] ?? 0
        let x = bounds["X"] ?? 0
        let y = bounds["Y"] ?? 0
        
        let match: [String: Any] = [
            "windowID": windowID,
            "ownerName": ownerName,
            "windowName": windowName,
            "width": width,
            "height": height,
            "x": x,
            "y": y,
            "layer": layer
        ]
        matches.append(match)
    }}
}}

// Output as JSON
if let jsonData = try? JSONSerialization.data(withJSONObject: matches, options: .prettyPrinted),
   let jsonString = String(data: jsonData, encoding: .utf8) {{
    print(jsonString)
}}
'''
    
    swift_file = "/tmp/find_window.swift"
    try:
        with open(swift_file, 'w') as f:
            f.write(swift_code)
        
        result = subprocess.run(['swift', swift_file], 
                              capture_output=True, text=True, timeout=15)
        
        if result.returncode == 0 and result.stdout.strip():
            try:
                windows = json.loads(result.stdout)
                return windows
            except json.JSONDecodeError as e:
                log_stderr(f"Failed to parse Swift output: {e}", verbose)
                return []
        else:
            log_stderr(f"Swift command failed: {result.stderr}", verbose)
            return []
            
    except Exception as e:
        log_stderr(f"Swift method error: {e}", verbose)
        return []
    finally:
        if os.path.exists(swift_file):
            try:
                os.remove(swift_file)
            except:
                pass


def select_best_window(windows: list, strategy: str = 'frontmost') -> Optional[Dict[str, Any]]:
    """
    Select the best window from candidates based on strategy.
    
    Strategies:
    - 'frontmost': Lowest layer number (closest to user)
    - 'largest': Largest window by area
    - 'first': First match found
    """
    if not windows:
        return None
    
    if strategy == 'first':
        return windows[0]
    
    if strategy == 'frontmost':
        return min(windows, key=lambda w: w.get('layer', 999999))
    
    if strategy == 'largest':
        return max(windows, key=lambda w: w.get('width', 0) * w.get('height', 0))
    
    # Default to frontmost
    return min(windows, key=lambda w: w.get('layer', 999999))


def find_window_with_retry(bundle_id: Optional[str] = None,
                          window_title: Optional[str] = None,
                          app_name: Optional[str] = None,
                          max_retries: int = DEFAULT_MAX_RETRIES,
                          retry_delay: float = DEFAULT_RETRY_DELAY,
                          backoff_multiplier: float = DEFAULT_BACKOFF_MULTIPLIER,
                          strategy: str = 'frontmost',
                          verbose: bool = True) -> Optional[Dict[str, Any]]:
    """
    Find window with exponential backoff retry logic.
    """
    delay = retry_delay
    
    for attempt in range(max_retries):
        windows = get_windows_via_swift(bundle_id, window_title, app_name, verbose)
        
        if windows:
            if len(windows) == 1:
                log_stderr(f"✅ Found 1 matching window on attempt {attempt + 1}", verbose)
                return windows[0]
            else:
                log_stderr(f"Found {len(windows)} matching windows on attempt {attempt + 1}, applying '{strategy}' strategy", verbose)
                return select_best_window(windows, strategy)
        
        if attempt < max_retries - 1:
            log_stderr(f"⏳ Attempt {attempt + 1}/{max_retries}: No window found, retrying in {delay:.2f}s...", verbose)
            time.sleep(delay)
            delay *= backoff_multiplier
    
    return None


def main():
    parser = argparse.ArgumentParser(
        description='Find CGWindowID for macOS applications',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Find by app name
  %(prog)s --app-name MetalShaderStudio
  
  # Find by bundle ID
  %(prog)s --bundle-id com.example.MyApp
  
  # Find by window title
  %(prog)s --window-title "My Window"
  
  # JSON output
  %(prog)s --app-name MyApp --json
  
  # Custom retry settings
  %(prog)s --app-name MyApp --max-retries 20 --retry-delay 1.0

Environment Variables:
  FIND_WINDOW_MAX_RETRIES    Max retry attempts (default: 10)
  FIND_WINDOW_RETRY_DELAY    Initial delay between retries (default: 0.5)
  FIND_WINDOW_BACKOFF        Backoff multiplier (default: 1.5)
        """)
    
    parser.add_argument('--bundle-id', help='Bundle identifier to search for')
    parser.add_argument('--window-title', help='Window title to search for')
    parser.add_argument('--app-name', help='Application name to search for')
    parser.add_argument('--strategy', choices=['frontmost', 'largest', 'first'],
                       default='frontmost', help='Window selection strategy when multiple matches')
    parser.add_argument('--max-retries', type=int, default=DEFAULT_MAX_RETRIES,
                       help=f'Maximum retry attempts (default: {DEFAULT_MAX_RETRIES})')
    parser.add_argument('--retry-delay', type=float, default=DEFAULT_RETRY_DELAY,
                       help=f'Initial retry delay in seconds (default: {DEFAULT_RETRY_DELAY})')
    parser.add_argument('--backoff', type=float, default=DEFAULT_BACKOFF_MULTIPLIER,
                       help=f'Backoff multiplier (default: {DEFAULT_BACKOFF_MULTIPLIER})')
    parser.add_argument('--json', action='store_true',
                       help='Output result as JSON')
    parser.add_argument('--quiet', action='store_true',
                       help='Suppress stderr logging')
    
    args = parser.parse_args()
    verbose = not args.quiet
    
    # Check dependencies
    if not check_dependencies():
        log_stderr("❌ ERROR: swift command not found. Please install Xcode Command Line Tools:", verbose)
        log_stderr("  xcode-select --install", verbose)
        sys.exit(4)
    
    # Require at least one search criterion
    if not (args.bundle_id or args.window_title or args.app_name):
        log_stderr("⚠️  No search criteria provided, using default app names (ShaderPlayground, MetalShaderStudio)", verbose)
    
    # Find window
    window = find_window_with_retry(
        bundle_id=args.bundle_id,
        window_title=args.window_title,
        app_name=args.app_name,
        max_retries=args.max_retries,
        retry_delay=args.retry_delay,
        backoff_multiplier=args.backoff,
        strategy=args.strategy,
        verbose=verbose
    )
    
    if window:
        if args.json:
            print(json.dumps(window, indent=2))
        else:
            print(window['windowID'])
        sys.exit(0)
    else:
        if args.json:
            print(json.dumps({"error": "No window found", "exit_code": 2}, indent=2))
        else:
            log_stderr("❌ No window found after all retries", verbose)
        sys.exit(2)


if __name__ == "__main__":
    main()
