import SwiftUI
import AppKit

// MARK: - Error Panel View
struct ErrorPanel: View {
    @Binding var errors: [CompilationError]
    @Binding var cursorPosition: (line: Int, column: Int)
    @State private var selectedError: CompilationError?
    @State private var filterSeverity: CompilationError.ErrorSeverity?
    @State private var showOnlyCurrentLine = false
    @State private var searchText = ""
    
    let onErrorSelected: (CompilationError) -> Void
    let onApplyFix: (CompilationError) -> Void
    
    var filteredErrors: [CompilationError] {
        var filtered = errors
        
        // Filter by severity
        if let severity = filterSeverity {
            filtered = filtered.filter { $0.severity == severity }
        }
        
        // Filter by current line
        if showOnlyCurrentLine {
            filtered = filtered.filter { $0.line == cursorPosition.line }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.suggestion?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return filtered.sorted { 
            if $0.severity.rawValue != $1.severity.rawValue {
                return $0.severity.rawValue > $1.severity.rawValue
            }
            if $0.line != $1.line {
                return $0.line < $1.line
            }
            return $0.column < $1.column
        }
    }
    
    var errorSummary: (errors: Int, warnings: Int, info: Int) {
        let errorCount = errors.filter { $0.severity == .error }.count
        let warningCount = errors.filter { $0.severity == .warning }.count
        let infoCount = errors.filter { $0.severity == .info }.count
        return (errorCount, warningCount, infoCount)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with summary and filters
            errorPanelHeader
            
            Divider()
            
            // Search and filter controls
            searchAndFilterControls
            
            Divider()
            
            // Error list
            if filteredErrors.isEmpty {
                emptyStateView
            } else {
                errorListView
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Header
    private var errorPanelHeader: some View {
        HStack {
            Label("Problems", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Error summary badges
            HStack(spacing: 8) {
                if errorSummary.errors > 0 {
                    ErrorBadge(count: errorSummary.errors, severity: .error)
                }
                if errorSummary.warnings > 0 {
                    ErrorBadge(count: errorSummary.warnings, severity: .warning)
                }
                if errorSummary.info > 0 {
                    ErrorBadge(count: errorSummary.info, severity: .info)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Search and Filter Controls
    private var searchAndFilterControls: some View {
        HStack {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search problems...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            
            // Severity filter
            Menu {
                Button("All") { filterSeverity = nil }
                Divider()
                Button("Errors Only") { filterSeverity = .error }
                Button("Warnings Only") { filterSeverity = .warning }
                Button("Info Only") { filterSeverity = .info }
            } label: {
                HStack {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                    Text(filterSeverity?.description ?? "All")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlColor))
                .cornerRadius(4)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            
            // Current line filter toggle
            Toggle("Current Line", isOn: $showOnlyCurrentLine)
                .toggleStyle(CheckboxToggleStyle())
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("No Problems Found")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(filteredErrors.isEmpty && !errors.isEmpty ? 
                 "All problems are filtered out" : 
                 "Your shader code looks good!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor).opacity(0.3))
    }
    
    // MARK: - Error List
    private var errorListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredErrors) { error in
                    ErrorRow(
                        error: error,
                        isSelected: selectedError?.id == error.id,
                        onSelect: {
                            selectedError = error
                            onErrorSelected(error)
                        },
                        onApplyFix: {
                            onApplyFix(error)
                        }
                    )
                    .background(
                        Rectangle()
                            .fill(selectedError?.id == error.id ? 
                                  Color.accentColor.opacity(0.1) : 
                                  Color.clear)
                    )
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Error Badge
struct ErrorBadge: View {
    let count: Int
    let severity: CompilationError.ErrorSeverity
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: severity.icon)
                .font(.caption2)
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(severity.color).opacity(0.2))
        .foregroundColor(Color(severity.color))
        .cornerRadius(10)
    }
}

// MARK: - Error Row
struct ErrorRow: View {
    let error: CompilationError
    let isSelected: Bool
    let onSelect: () -> Void
    let onApplyFix: () -> Void
    
    @State private var isHovered = false
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main error information
            HStack(alignment: .top, spacing: 12) {
                // Severity icon
                Image(systemName: error.severity.icon)
                    .foregroundColor(Color(error.severity.color))
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Error message
                    Text(error.message)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Location and type info
                    HStack {
                        // File location
                        Text("Line \(error.line), Column \(error.column)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Error type
                        Text(error.type.description)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(NSColor.separatorColor))
                            .cornerRadius(4)
                            .foregroundColor(.secondary)
                    }
                    
                    // Code context if available
                    if let code = error.code, !code.isEmpty {
                        HStack {
                            Rectangle()
                                .fill(Color(error.severity.color))
                                .frame(width: 3)
                            
                            Text(code)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                        }
                        .background(Color(NSColor.separatorColor).opacity(0.3))
                        .cornerRadius(4)
                    }
                    
                    // Suggestion if available
                    if let suggestion = error.suggestion, !suggestion.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Suggestion:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Text(suggestion)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                            
                            if isHovered {
                                Button("Apply Fix") {
                                    onApplyFix()
                                }
                                .buttonStyle(PlainButtonStyle())
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                // Action buttons
                if isHovered {
                    VStack(spacing: 4) {
                        Button(action: onSelect) {
                            Image(systemName: "arrow.right.circle")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Jump to error location")
                        
                        Button(action: { showingDetails.toggle() }) {
                            Image(systemName: showingDetails ? "info.circle.fill" : "info.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Show details")
                    }
                }
            }
            
            // Detailed information (expandable)
            if showingDetails {
                ErrorDetailsView(error: error)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button("Jump to Line") { onSelect() }
            if error.suggestion != nil {
                Button("Apply Fix") { onApplyFix() }
            }
            Divider()
            Button("Copy Error Message") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(error.message, forType: .string)
            }
        }
    }
}

// MARK: - Error Details View
struct ErrorDetailsView: View {
    let error: CompilationError
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            HStack {
                Text("Error Details")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                DetailRow(label: "Type", value: error.type.description)
                DetailRow(label: "Severity", value: error.severity.description)
                DetailRow(label: "Line", value: "\(error.line)")
                DetailRow(label: "Column", value: "\(error.column)")
                
                if let context = error.context {
                    DetailRow(label: "Affected Text", value: "'\(context.affectedText)'")
                    DetailRow(label: "Range", value: "Line \(context.startLine)-\(context.endLine), Col \(context.startColumn)-\(context.endColumn)")
                }
                
                if let code = error.code, !code.isEmpty {
                    DetailRow(label: "Code Context", value: code, isCode: true)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.separatorColor).opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let label: String
    let value: String
    let isCode: Bool
    
    init(label: String, value: String, isCode: Bool = false) {
        self.label = label
        self.value = value
        self.isCode = isCode
    }
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(isCode ? .system(.caption, design: .monospaced) : .caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// MARK: - Extensions
extension CompilationError.ErrorSeverity {
    var description: String {
        switch self {
        case .error: return "Error"
        case .warning: return "Warning"
        case .info: return "Info"
        }
    }
}

extension CompilationError.ErrorType {
    var description: String {
        switch self {
        case .syntaxError: return "Syntax Error"
        case .typeError: return "Type Error"
        case .undeclaredVariable: return "Undeclared Variable"
        case .invalidFunction: return "Invalid Function"
        case .missingReturn: return "Missing Return"
        case .compilationError: return "Compilation Error"
        case .warning: return "Warning"
        case .info: return "Info"
        }
    }
}

// MARK: - Checkbox Toggle Style
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkbox" : "square")
                .foregroundColor(configuration.isOn ? .accentColor : .secondary)
                .onTapGesture { configuration.isOn.toggle() }
            
            configuration.label
                .onTapGesture { configuration.isOn.toggle() }
        }
    }
}
