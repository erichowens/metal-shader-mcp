import SwiftUI

/// Connection status for MCP bridge
enum MCPConnectionStatus: Equatable {
    case connected
    case disconnected
    case connecting
    case error(String)
    
    var color: Color {
        switch self {
        case .connected: return .green
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .error: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .connected: return "wifi"
        case .disconnected: return "wifi.slash"
        case .connecting: return "wifi.exclamationmark"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    var displayText: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .error(let message): return "Error: \(message)"
        }
    }
}

/// Type of MCP bridge being used
enum MCPBridgeType: Equatable {
    case fileBridge
    case liveClient(serverCommand: String)
    
    var displayName: String {
        switch self {
        case .fileBridge: return "File Bridge"
        case .liveClient: return "Live Client"
        }
    }
    
    var icon: String {
        switch self {
        case .fileBridge: return "doc.text"
        case .liveClient: return "network"
        }
    }
    
    var description: String {
        switch self {
        case .fileBridge: 
            return "Using file-based communication via Resources/communication/*.json"
        case .liveClient(let cmd):
            return "Connected to live MCP server: \(cmd.components(separatedBy: " ").first ?? cmd)"
        }
    }
}

/// Observable model for tracking MCP connection status
final class MCPStatusManager: ObservableObject {
    @Published var status: MCPConnectionStatus = .disconnected
    @Published var bridgeType: MCPBridgeType = .fileBridge
    @Published var lastActivity: Date?
    @Published var requestCount: Int = 0
    @Published var errorCount: Int = 0
    
    func updateStatus(_ newStatus: MCPConnectionStatus) {
        DispatchQueue.main.async {
            self.status = newStatus
            self.lastActivity = Date()
        }
    }
    
    func updateBridgeType(_ type: MCPBridgeType) {
        DispatchQueue.main.async {
            self.bridgeType = type
        }
    }
    
    func recordRequest() {
        DispatchQueue.main.async {
            self.requestCount += 1
            self.lastActivity = Date()
        }
    }
    
    func recordError() {
        DispatchQueue.main.async {
            self.errorCount += 1
            self.lastActivity = Date()
        }
    }
    
    func reset() {
        DispatchQueue.main.async {
            self.requestCount = 0
            self.errorCount = 0
            self.lastActivity = nil
        }
    }
}

/// Compact status indicator for showing in toolbars
struct MCPStatusIndicator: View {
    @ObservedObject var statusManager: MCPStatusManager
    @State private var showDetails = false
    
    var body: some View {
        Button(action: { showDetails = true }) {
            HStack(spacing: 4) {
                Image(systemName: statusManager.status.icon)
                    .foregroundColor(statusManager.status.color)
                    .font(.system(size: 12, weight: .semibold))
                
                Image(systemName: statusManager.bridgeType.icon)
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))
                
                if statusManager.status == .connecting {
                    ProgressView()
                        .scaleEffect(0.6)
                        .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                }
            }
        }
        .buttonStyle(.plain)
        .help(statusTooltip)
        .popover(isPresented: $showDetails) {
            MCPStatusDetailView(statusManager: statusManager)
                .frame(width: 320, height: 240)
        }
    }
    
    private var statusTooltip: String {
        let typeInfo = statusManager.bridgeType.displayName
        let statusInfo = statusManager.status.displayText
        return "\(typeInfo): \(statusInfo)"
    }
}

/// Detailed status view shown in popover
struct MCPStatusDetailView: View {
    @ObservedObject var statusManager: MCPStatusManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("MCP Connection Status")
                    .font(.headline)
                Spacer()
                Button("Reset Stats") {
                    statusManager.reset()
                }
                .font(.caption)
            }
            
            Divider()
            
            // Connection Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Type:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: statusManager.bridgeType.icon)
                            .font(.caption)
                        Text(statusManager.bridgeType.displayName)
                            .font(.caption)
                    }
                }
                
                HStack {
                    Text("Status:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: statusManager.status.icon)
                            .foregroundColor(statusManager.status.color)
                            .font(.caption)
                        Text(statusManager.status.displayText)
                            .font(.caption)
                            .foregroundColor(statusManager.status.color)
                    }
                }
                
                Text(statusManager.bridgeType.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            // Statistics
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Requests")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(statusManager.requestCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Errors")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(statusManager.errorCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(statusManager.errorCount > 0 ? .red : .primary)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Activity")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(lastActivityText)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var lastActivityText: String {
        guard let lastActivity = statusManager.lastActivity else {
            return "None"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: lastActivity, relativeTo: Date())
    }
}

/// Full-width status bar for showing at the top of views
struct MCPStatusBar: View {
    @ObservedObject var statusManager: MCPStatusManager
    @ObservedObject var errorManager: ErrorManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Error banners at the top
            if !errorManager.errors.isEmpty {
                ErrorBannerContainer(errorManager: errorManager)
                    .padding(.bottom, 8)
            }
            
            // Status bar
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: statusManager.status.icon)
                        .foregroundColor(statusManager.status.color)
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text(statusManager.bridgeType.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(statusManager.status.displayText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if statusManager.requestCount > 0 || statusManager.errorCount > 0 {
                    HStack(spacing: 8) {
                        if statusManager.requestCount > 0 {
                            Text("\(statusManager.requestCount) req")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        if statusManager.errorCount > 0 {
                            Text("\(statusManager.errorCount) err")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                }
                
                MCPStatusIndicator(statusManager: statusManager)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        let statusManager = MCPStatusManager()
        
        MCPStatusIndicator(statusManager: statusManager)
        
        MCPStatusBar(
            statusManager: statusManager,
            errorManager: ErrorManager()
        )
        
        MCPStatusDetailView(statusManager: statusManager)
            .frame(width: 320, height: 240)
            .border(Color.gray.opacity(0.3))
    }
    .padding()
    .onAppear {
        let statusManager = MCPStatusManager()
        statusManager.status = .connected
        statusManager.bridgeType = .liveClient(serverCommand: "node mcp-server.js")
        statusManager.requestCount = 42
        statusManager.errorCount = 3
        statusManager.lastActivity = Date().addingTimeInterval(-120)
    }
}