#!/usr/bin/env swift

import Metal
import Cocoa

// Test if Metal is available
if let device = MTLCreateSystemDefaultDevice() {
    print("✅ Metal is available!")
    print("Device: \(device.name)")
    print("GPU Family: Apple\(device.supportsFamily(.apple1) ? " Silicon" : "")")
    print("Max threads per group: \(device.maxThreadsPerThreadgroup)")
    
    // Try to compile a simple shader
    let shaderCode = """
    #include <metal_stdlib>
    using namespace metal;
    
    kernel void testKernel() {
        return;
    }
    """
    
    do {
        let library = try device.makeLibrary(source: shaderCode, options: nil)
        print("✅ Shader compilation successful!")
        
        // Now launch a simple window
        print("\nLaunching simple Metal window...")
        
        NSApplication.shared.setActivationPolicy(.regular)
        
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Metal Test"
        window.backgroundColor = .black
        
        let label = NSTextField(labelWithString: "Metal is working! Close window to exit.")
        label.frame = NSRect(x: 50, y: 150, width: 300, height: 30)
        label.textColor = .green
        label.font = .systemFont(ofSize: 16)
        label.alignment = .center
        
        window.contentView?.addSubview(label)
        window.makeKeyAndOrderFront(nil)
        
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.run()
        
    } catch {
        print("❌ Shader compilation failed: \(error)")
    }
} else {
    print("❌ Metal is not available on this system")
}