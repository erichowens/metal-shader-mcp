import SwiftUI

/// Error severity levels for different banner styles
enum ErrorSeverity {
    case info
    case warning
    case error
    case success
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "exclamationmark.circle"
        case .success: return "checkmark.circle"
        }
    }
}

/// A reusable banner view for displaying errors, warnings, and status messages
struct ErrorBannerView: View {
    let message: String
    let severity: ErrorSeverity
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    init(message: String, severity: ErrorSeverity = .error, onDismiss: @escaping () -> Void) {
        self.message = message
        self.severity = severity
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: severity.icon)
                    .foregroundColor(severity.color)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(severity.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(severity.color.opacity(0.3), lineWidth: 1)
                    )
            )
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .onAppear {
                withAnimation {
                    isVisible = true
                }
            }
        }
    }
    
    private func dismiss() {
        withAnimation {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

/// A container view that manages multiple error banners with auto-dismiss
struct ErrorBannerContainer: View {
    @ObservedObject var errorManager: ErrorManager
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(errorManager.errors) { error in
                ErrorBannerView(
                    message: error.message,
                    severity: error.severity,
                    onDismiss: { errorManager.dismiss(error) }
                )
                .onAppear {
                    // Auto-dismiss after delay for non-error messages
                    if error.severity != .error {
                        DispatchQueue.main.asyncAfter(deadline: .now() + error.autoDismissDelay) {
                            errorManager.dismiss(error)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

/// Model for managing error messages
final class ErrorManager: ObservableObject {
    @Published var errors: [ErrorMessage] = []
    
    struct ErrorMessage: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let severity: ErrorSeverity
        let timestamp = Date()
        let autoDismissDelay: TimeInterval
        
        init(message: String, severity: ErrorSeverity = .error, autoDismissDelay: TimeInterval? = nil) {
            self.message = message
            self.severity = severity
            // Auto-dismiss delays based on severity
            self.autoDismissDelay = autoDismissDelay ?? {
                switch severity {
                case .success: return 3.0
                case .info: return 5.0
                case .warning: return 8.0
                case .error: return 0 // Don't auto-dismiss errors
                }
            }()
        }
        
        static func == (lhs: ErrorMessage, rhs: ErrorMessage) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    func show(_ message: String, severity: ErrorSeverity = .error) {
        // Remove any existing identical messages
        errors.removeAll { $0.message == message && $0.severity == severity }
        
        let errorMessage = ErrorMessage(message: message, severity: severity)
        errors.insert(errorMessage, at: 0) // Show newest errors at top
        
        // Limit to 3 visible errors at once
        if errors.count > 3 {
            errors.removeLast(errors.count - 3)
        }
    }
    
    func dismiss(_ error: ErrorMessage) {
        errors.removeAll { $0.id == error.id }
    }
    
    func dismissAll() {
        errors.removeAll()
    }
}

#Preview {
    VStack(spacing: 20) {
        ErrorBannerView(message: "Connection successful", severity: .success) {}
        ErrorBannerView(message: "Warning: Using fallback file bridge", severity: .warning) {}
        ErrorBannerView(message: "MCP server disconnected. Retrying...", severity: .info) {}
        ErrorBannerView(message: "Failed to compile shader: syntax error on line 45", severity: .error) {}
    }
    .padding()
}