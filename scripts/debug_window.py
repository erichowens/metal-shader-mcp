#!/usr/bin/env python3
"""
Debug window properties for MetalShaderStudio
"""

import subprocess
import sys
import os

def debug_window_via_swift():
    """Get detailed window info using Swift"""
    swift_code = '''
import Cocoa
import CoreGraphics

let windowList = CGWindowListCopyWindowInfo(.excludeDesktopElements, kCGNullWindowID) as! [[String: Any]]

print("=== All MetalShaderStudio Windows ===")
var foundCount = 0

for window in windowList {
    if let ownerName = window["kCGWindowOwnerName"] as? String,
       let windowID = window["kCGWindowNumber"] as? Int {
        
        if ownerName.contains("MetalShaderStudio") {
            foundCount += 1
            let windowName = window["kCGWindowName"] as? String ?? "No Name"
            let bounds = window["kCGWindowBounds"] as? [String: Any] ?? [:]
            let layer = window["kCGWindowLayer"] as? Int ?? 0
            let alpha = window["kCGWindowAlpha"] as? Double ?? 1.0
            let isOnScreen = window["kCGWindowIsOnscreen"] as? Bool ?? false
            let ownerPID = window["kCGWindowOwnerPID"] as? Int ?? 0
            
            print("Window #\\(foundCount):")
            print("  ID: \\(windowID)")
            print("  Name: '\\(windowName)'")
            print("  Owner: \\(ownerName)")
            print("  PID: \\(ownerPID)")
            print("  Layer: \\(layer)")
            print("  Alpha: \\(alpha)")
            print("  OnScreen: \\(isOnScreen)")
            print("  Bounds: \\(bounds)")
            print("  ---")
        }
    }
}

if foundCount == 0 {
    print("No MetalShaderStudio windows found!")
} else {
    print("Found \\(foundCount) MetalShaderStudio windows")
}
'''
    
    # Write Swift code to temp file
    swift_file = "/tmp/debug_window.swift"
    with open(swift_file, 'w') as f:
        f.write(swift_code)
    
    try:
        # Compile and run Swift code
        result = subprocess.run(['swift', swift_file], 
                              capture_output=True, text=True, timeout=10)
        return result.stdout, result.stderr
    except Exception as e:
        return None, f"Swift method failed: {e}"
    finally:
        # Clean up
        if os.path.exists(swift_file):
            os.remove(swift_file)

def main():
    print("🔍 Debugging MetalShaderStudio windows...")
    
    stdout, stderr = debug_window_via_swift()
    if stdout:
        print(stdout)
    if stderr:
        print("Errors:", stderr)

if __name__ == "__main__":
    main()
