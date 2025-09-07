#!/usr/bin/env python3
"""
Find CGWindowID for MetalShaderStudio using PyObjC (built into macOS Python)
"""

import subprocess
import json
import sys
import os

def get_window_id_via_applescript():
    """Alternative method using AppleScript to get process info"""
    script = '''
    tell application "System Events"
        tell process "MetalShaderStudio"
            if exists window 1 then
                return {name of window 1, id of window 1}
            else
                return "no window"
            end if
        end tell
    end tell
    '''
    try:
        result = subprocess.run(['osascript', '-e', script], 
                              capture_output=True, text=True, timeout=10)
        return result.stdout.strip()
    except:
        return None

def get_window_id_via_swift():
    """Use Swift to get CGWindowID - most reliable method"""
    swift_code = '''
import Cocoa
import CoreGraphics

let windowList = CGWindowListCopyWindowInfo(.excludeDesktopElements, kCGNullWindowID) as! [[String: Any]]

// First pass: look for visible windows with names
for window in windowList {
    if let ownerName = window["kCGWindowOwnerName"] as? String,
       let windowID = window["kCGWindowNumber"] as? Int {
        
        if ownerName.contains("MetalShaderStudio") {
            let windowName = window["kCGWindowName"] as? String ?? ""
            let isOnScreen = window["kCGWindowIsOnscreen"] as? Bool ?? false
            
            // Prioritize visible windows with names
            if isOnScreen && !windowName.isEmpty {
                print("\\(windowID)")
                exit(0)
            }
        }
    }
}

// Second pass: any visible MetalShaderStudio window
for window in windowList {
    if let ownerName = window["kCGWindowOwnerName"] as? String,
       let windowID = window["kCGWindowNumber"] as? Int {
        
        if ownerName.contains("MetalShaderStudio") {
            let isOnScreen = window["kCGWindowIsOnscreen"] as? Bool ?? false
            
            if isOnScreen {
                print("\\(windowID)")
                exit(0)
            }
        }
    }
}

exit(1)
'''
    
    # Write Swift code to temp file
    swift_file = "/tmp/find_window.swift"
    with open(swift_file, 'w') as f:
        f.write(swift_code)
    
    try:
        # Compile and run Swift code
        result = subprocess.run(['swift', swift_file], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            window_id = result.stdout.strip()
            if window_id.isdigit():
                return int(window_id)
        return None
    except Exception as e:
        print(f"Swift method failed: {e}")
        return None
    finally:
        # Clean up
        if os.path.exists(swift_file):
            os.remove(swift_file)

def main():
    print("🔍 Searching for MetalShaderStudio window ID...")
    
    # Method 1: Try Swift approach (most reliable)
    window_id = get_window_id_via_swift()
    if window_id:
        print(f"✅ Found CGWindowID via Swift: {window_id}")
        return window_id
    
    print("⚠️ Swift method failed, trying alternative approaches...")
    
    # Method 2: Try AppleScript (less reliable but worth trying)
    result = get_window_id_via_applescript()
    if result and result != "no window":
        print(f"📋 AppleScript result: {result}")
    
    print("❌ Could not find reliable CGWindowID")
    return None

if __name__ == "__main__":
    window_id = main()
    if window_id:
        print(window_id)
        sys.exit(0)
    else:
        sys.exit(1)
