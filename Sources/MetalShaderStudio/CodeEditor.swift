import SwiftUI
import AppKit
import Combine

// MARK: - Enhanced Code Editor with Error Highlighting
struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var errors: [CompilationError]
    @Binding var cursorPosition: (line: Int, column: Int)
    
    let font: NSFont
    let theme: CodeEditorTheme
    let showLineNumbers: Bool
    let errorDetectionEngine: ErrorDetectionEngine
    
    init(text: Binding<String>, 
         errors: Binding<[CompilationError]>,
         cursorPosition: Binding<(line: Int, column: Int)>,
         font: NSFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
         theme: CodeEditorTheme = .dark,
         showLineNumbers: Bool = true,
         errorDetectionEngine: ErrorDetectionEngine) {
        self._text = text
        self._errors = errors
        self._cursorPosition = cursorPosition
        self.font = font
        self.theme = theme
        self.showLineNumbers = showLineNumbers
        self.errorDetectionEngine = errorDetectionEngine
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = EnhancedTextView(
            errorDetectionEngine: errorDetectionEngine,
            theme: theme
        )
        
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = font
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        
        // Configure text view appearance
        textView.backgroundColor = theme.backgroundColor
        textView.textColor = theme.textColor
        textView.insertionPointColor = theme.cursorColor
        textView.selectedTextAttributes = [
            .backgroundColor: theme.selectionColor,
            .foregroundColor: theme.textColor
        ]
        
        // Setup line numbers if requested
        if showLineNumbers {
            let lineNumberView = LineNumberView(textView: textView, theme: theme)
            scrollView.verticalRulerView = lineNumberView
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
        }
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? EnhancedTextView {
            if textView.string != text {
                textView.string = text
            }
            
            // Update error highlighting
            textView.updateErrorHighlighting(errors)
            
            // Update syntax highlighting
            textView.applySyntaxHighlighting(theme: theme)
            
            // Update line numbers
            if let lineNumberView = nsView.verticalRulerView as? LineNumberView {
                lineNumberView.needsDisplay = true
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: CodeEditor
        private var debounceTimer: Timer?
        
        init(_ parent: CodeEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                DispatchQueue.main.async {
                    self.parent.text = textView.string
                    
                    // Update cursor position
                    let selectedRange = textView.selectedRange()
                    let (line, column) = self.lineColumnFromRange(textView.string, range: selectedRange)
                    self.parent.cursorPosition = (line: line, column: column)
                    
                    // Debounced real-time error detection
                    self.debounceTimer?.invalidate()
                    self.debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                        self.performRealTimeValidation(textView.string)
                    }
                }
            }
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                DispatchQueue.main.async {
                    let selectedRange = textView.selectedRange()
                    let (line, column) = self.lineColumnFromRange(textView.string, range: selectedRange)
                    self.parent.cursorPosition = (line: line, column: column)
                }
            }
        }
        
        private func performRealTimeValidation(_ code: String) {
            let syntaxErrors = parent.errorDetectionEngine.validateShaderSyntax(code)
            let warnings = parent.errorDetectionEngine.generateWarningsAndSuggestions(code)
            
            DispatchQueue.main.async {
                self.parent.errors = syntaxErrors + warnings
            }
        }
        
        private func lineColumnFromRange(_ string: String, range: NSRange) -> (Int, Int) {
            let lines = string.components(separatedBy: .newlines)
            var currentPosition = 0
            
            for (lineIndex, line) in lines.enumerated() {
                let lineLength = line.count + 1 // +1 for newline
                if currentPosition + lineLength > range.location {
                    let column = range.location - currentPosition + 1
                    return (lineIndex + 1, column)
                }
                currentPosition += lineLength
            }
            
            return (lines.count, 1)
        }
    }
}

// MARK: - Enhanced Text View with Error Highlighting
class EnhancedTextView: NSTextView {
    private let errorDetectionEngine: ErrorDetectionEngine
    private let theme: CodeEditorTheme
    private var errorHighlights: [NSRange: CompilationError] = [:]
    private var errorTooltip: NSView?
    
    init(errorDetectionEngine: ErrorDetectionEngine, theme: CodeEditorTheme) {
        self.errorDetectionEngine = errorDetectionEngine
        self.theme = theme
        super.init(frame: .zero, textContainer: nil)
        
        setupErrorTracking()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupErrorTracking() {
        // Setup mouse tracking for error tooltips
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInActiveApp, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    func updateErrorHighlighting(_ errors: [CompilationError]) {
        // Clear previous error highlights
        errorHighlights.removeAll()
        
        guard let textStorage = textStorage else { return }
        
        // Remove previous error attributes
        textStorage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: textStorage.length))
        textStorage.removeAttribute(.underlineStyle, range: NSRange(location: 0, length: textStorage.length))
        textStorage.removeAttribute(.underlineColor, range: NSRange(location: 0, length: textStorage.length))
        
        // Apply new error highlights
        let lines = string.components(separatedBy: .newlines)
        
        for error in errors {
            guard error.line <= lines.count else { continue }
            
            let lineRange = rangeForLine(error.line - 1, in: lines)
            let errorRange = NSRange(
                location: lineRange.location + max(0, error.column - 1),
                length: min(10, lineRange.length - max(0, error.column - 1))
            )
            
            // Store error for tooltip
            errorHighlights[errorRange] = error
            
            // Apply visual highlighting based on error severity
            let attributes = errorHighlightAttributes(for: error.severity)
            textStorage.addAttributes(attributes, range: errorRange)
        }
    }
    
    func applySyntaxHighlighting(theme: CodeEditorTheme) {
        guard let textStorage = textStorage else { return }
        
        // Apply base text color
        textStorage.addAttribute(.foregroundColor, 
                                value: theme.textColor, 
                                range: NSRange(location: 0, length: textStorage.length))
        
        let code = string
        
        // Highlight Metal keywords
        highlightKeywords(in: textStorage, code: code, theme: theme)
        
        // Highlight comments
        highlightComments(in: textStorage, code: code, theme: theme)
        
        // Highlight strings
        highlightStrings(in: textStorage, code: code, theme: theme)
        
        // Highlight numbers
        highlightNumbers(in: textStorage, code: code, theme: theme)
        
        // Highlight Metal attributes
        highlightAttributes(in: textStorage, code: code, theme: theme)
        
        // Highlight function calls
        highlightFunctionCalls(in: textStorage, code: code, theme: theme)
    }
    
    private func errorHighlightAttributes(for severity: CompilationError.ErrorSeverity) -> [NSAttributedString.Key: Any] {
        switch severity {
        case .error:
            return [
                .underlineStyle: NSUnderlineStyle.single.rawValue | NSUnderlineStyle.thick.rawValue,
                .underlineColor: NSColor.systemRed,
                .backgroundColor: NSColor.systemRed.withAlphaComponent(0.1)
            ]
        case .warning:
            return [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: NSColor.systemOrange,
                .backgroundColor: NSColor.systemOrange.withAlphaComponent(0.1)
            ]
        case .info:
            return [
                .underlineStyle: NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue,
                .underlineColor: NSColor.systemBlue,
                .backgroundColor: NSColor.systemBlue.withAlphaComponent(0.05)
            ]
        }
    }
    
    private func rangeForLine(_ lineIndex: Int, in lines: [String]) -> NSRange {
        var location = 0
        
        for i in 0..<lineIndex {
            location += lines[i].count + 1 // +1 for newline
        }
        
        let length = lineIndex < lines.count ? lines[lineIndex].count : 0
        return NSRange(location: location, length: length)
    }
    
    // MARK: - Syntax Highlighting Methods
    
    private func highlightKeywords(in textStorage: NSTextStorage, code: String, theme: CodeEditorTheme) {
        let keywords = [
            "vertex", "fragment", "kernel", "constant", "device", "threadgroup",
            "float", "float2", "float3", "float4", "half", "int", "bool",
            "if", "else", "for", "while", "return", "break", "continue",
            "struct", "enum", "true", "false"
        ]
        
        for keyword in keywords {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
            highlightPattern(pattern, in: textStorage, color: theme.keywordColor)
        }
    }
    
    private func highlightComments(in textStorage: NSTextStorage, code: String, theme: CodeEditorTheme) {
        // Single line comments
        highlightPattern("//.*$", in: textStorage, color: theme.commentColor, options: [.anchorsMatchLines])
        
        // Multi-line comments
        highlightPattern("/\\*[\\s\\S]*?\\*/", in: textStorage, color: theme.commentColor)
    }
    
    private func highlightStrings(in textStorage: NSTextStorage, code: String, theme: CodeEditorTheme) {
        highlightPattern("\"[^\"]*\"", in: textStorage, color: theme.stringColor)
    }
    
    private func highlightNumbers(in textStorage: NSTextStorage, code: String, theme: CodeEditorTheme) {
        highlightPattern("\\b\\d+\\.\\d+f?\\b|\\b\\d+f?\\b", in: textStorage, color: theme.numberColor)
    }
    
    private func highlightAttributes(in textStorage: NSTextStorage, code: String, theme: CodeEditorTheme) {
        highlightPattern("\\[\\[[^\\]]*\\]\\]", in: textStorage, color: theme.attributeColor)
    }
    
    private func highlightFunctionCalls(in textStorage: NSTextStorage, code: String, theme: CodeEditorTheme) {
        highlightPattern("\\b\\w+(?=\\s*\\()", in: textStorage, color: theme.functionColor)
    }
    
    private func highlightPattern(_ pattern: String, 
                                 in textStorage: NSTextStorage, 
                                 color: NSColor, 
                                 options: NSRegularExpression.Options = []) {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let range = NSRange(location: 0, length: textStorage.length)
            
            regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
                guard let matchRange = match?.range else { return }
                textStorage.addAttribute(.foregroundColor, value: color, range: matchRange)
            }
        } catch {
            print("Regex error: \(error)")
        }
    }
    
    // MARK: - Mouse Tracking for Error Tooltips
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        
        let point = convert(event.locationInWindow, from: nil)
        let characterIndex = characterIndexForInsertion(at: point)
        
        // Check if mouse is over an error
        for (range, error) in errorHighlights {
            if NSLocationInRange(characterIndex, range) {
                showErrorTooltip(for: error, at: point)
                return
            }
        }
        
        // Hide tooltip if not over an error
        hideErrorTooltip()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hideErrorTooltip()
    }
    
    private func showErrorTooltip(for error: CompilationError, at point: NSPoint) {
        hideErrorTooltip()
        
        let tooltip = ErrorTooltipView(error: error, theme: theme)
        tooltip.frame = NSRect(x: point.x + 10, y: point.y - 30, width: 300, height: 80)
        
        addSubview(tooltip)
        errorTooltip = tooltip
    }
    
    private func hideErrorTooltip() {
        errorTooltip?.removeFromSuperview()
        errorTooltip = nil
    }
}

// MARK: - Code Editor Theme
struct CodeEditorTheme {
    let backgroundColor: NSColor
    let textColor: NSColor
    let keywordColor: NSColor
    let commentColor: NSColor
    let stringColor: NSColor
    let numberColor: NSColor
    let attributeColor: NSColor
    let functionColor: NSColor
    let cursorColor: NSColor
    let selectionColor: NSColor
    let lineNumberColor: NSColor
    let lineNumberBackgroundColor: NSColor
    
    static let dark = CodeEditorTheme(
        backgroundColor: NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0),
        textColor: NSColor(red: 0.83, green: 0.83, blue: 0.83, alpha: 1.0),
        keywordColor: NSColor(red: 0.8, green: 0.47, blue: 0.86, alpha: 1.0),
        commentColor: NSColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0),
        stringColor: NSColor(red: 0.96, green: 0.55, blue: 0.24, alpha: 1.0),
        numberColor: NSColor(red: 0.28, green: 0.84, blue: 0.6, alpha: 1.0),
        attributeColor: NSColor(red: 0.26, green: 0.63, blue: 0.95, alpha: 1.0),
        functionColor: NSColor(red: 0.35, green: 0.72, blue: 0.96, alpha: 1.0),
        cursorColor: NSColor.white,
        selectionColor: NSColor(red: 0.26, green: 0.35, blue: 0.51, alpha: 1.0),
        lineNumberColor: NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0),
        lineNumberBackgroundColor: NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
    )
    
    static let light = CodeEditorTheme(
        backgroundColor: NSColor.white,
        textColor: NSColor.black,
        keywordColor: NSColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0),
        commentColor: NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0),
        stringColor: NSColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 1.0),
        numberColor: NSColor(red: 0.1, green: 0.6, blue: 0.4, alpha: 1.0),
        attributeColor: NSColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 1.0),
        functionColor: NSColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0),
        cursorColor: NSColor.black,
        selectionColor: NSColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 1.0),
        lineNumberColor: NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0),
        lineNumberBackgroundColor: NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
    )
}

// MARK: - Line Number View
class LineNumberView: NSRulerView {
    let textView: NSTextView
    let theme: CodeEditorTheme
    
    init(textView: NSTextView, theme: CodeEditorTheme) {
        self.textView = textView
        self.theme = theme
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        
        self.clientView = textView
        self.ruleThickness = 50
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Fill background
        context.setFillColor(theme.lineNumberBackgroundColor.cgColor)
        context.fill(rect)
        
        // Draw line numbers
        let content = textView.string
        let lines = content.components(separatedBy: .newlines)
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: theme.lineNumberColor
        ]
        
        let visibleRange = textView.visibleRect
        let textContainer = textView.textContainer!
        let layoutManager = textView.layoutManager!
        let startPoint = visibleRange.origin
        let endPoint = NSPoint(x: visibleRange.maxX, y: visibleRange.maxY)
        let startIndex = layoutManager.characterIndex(for: startPoint, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        let endIndex = layoutManager.characterIndex(for: endPoint, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        let visibleTextRange = NSRange(location: startIndex, length: endIndex - startIndex)
        let (startLine, _) = lineColumnFromRange(content, range: NSRange(location: visibleTextRange.location, length: 0))
        let (endLine, _) = lineColumnFromRange(content, range: NSRange(location: visibleTextRange.location + visibleTextRange.length, length: 0))
        
        for lineNumber in startLine...min(endLine + 1, lines.count) {
            let lineString = NSAttributedString(string: "\(lineNumber)", attributes: textAttributes)
            let lineRect = rectForLine(lineNumber, in: content)
            
            let drawRect = NSRect(
                x: ruleThickness - 40,
                y: lineRect.origin.y,
                width: 35,
                height: lineRect.height
            )
            
            lineString.draw(in: drawRect)
        }
    }
    
    private func lineColumnFromRange(_ string: String, range: NSRange) -> (Int, Int) {
        let lines = string.components(separatedBy: .newlines)
        var currentPosition = 0
        
        for (lineIndex, line) in lines.enumerated() {
            let lineLength = line.count + 1
            if currentPosition + lineLength > range.location {
                let column = range.location - currentPosition + 1
                return (lineIndex + 1, column)
            }
            currentPosition += lineLength
        }
        
        return (lines.count, 1)
    }
    
    private func rectForLine(_ lineNumber: Int, in content: String) -> NSRect {
        let lines = content.components(separatedBy: .newlines)
        guard lineNumber > 0 && lineNumber <= lines.count else { return .zero }
        
        let lineHeight = textView.font?.capHeight ?? 16
        let yOffset = CGFloat(lineNumber - 1) * lineHeight
        
        return NSRect(x: 0, y: yOffset, width: ruleThickness, height: lineHeight)
    }
}

// MARK: - Error Tooltip View
class ErrorTooltipView: NSView {
    let error: CompilationError
    let theme: CodeEditorTheme
    
    init(error: CompilationError, theme: CodeEditorTheme) {
        self.error = error
        self.theme = theme
        super.init(frame: .zero)
        
        setupTooltipAppearance()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTooltipAppearance() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = error.severity.color.cgColor
        
        // Add shadow
        let shadowObj = NSShadow()
        shadowObj.shadowOffset = NSSize(width: 0, height: -2)
        shadowObj.shadowBlurRadius = 4
        shadowObj.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow = shadowObj
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let smallFont = NSFont.systemFont(ofSize: 10, weight: .regular)
        
        // Draw error icon
        let iconRect = NSRect(x: 8, y: bounds.height - 24, width: 16, height: 16)
        let icon = NSImage(systemSymbolName: error.severity.icon, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        icon?.draw(in: iconRect)
        
        // Draw error message
        let messageRect = NSRect(x: 30, y: bounds.height - 24, width: bounds.width - 40, height: 16)
        let messageAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        error.message.draw(in: messageRect, withAttributes: messageAttributes)
        
        // Draw suggestion if available
        if let suggestion = error.suggestion {
            let suggestionRect = NSRect(x: 8, y: 8, width: bounds.width - 16, height: bounds.height - 32)
            let suggestionAttributes: [NSAttributedString.Key: Any] = [
                .font: smallFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            suggestion.draw(in: suggestionRect, withAttributes: suggestionAttributes)
        }
    }
}
