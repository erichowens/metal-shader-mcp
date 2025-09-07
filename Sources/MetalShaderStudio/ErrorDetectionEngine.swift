import Foundation
import Metal
import RegexBuilder

// MARK: - Error Detection Engine
class ErrorDetectionEngine: ObservableObject {
    @Published var syntaxErrors: [CompilationError] = []
    @Published var semanticErrors: [CompilationError] = []
    @Published var warnings: [CompilationError] = []
    @Published var suggestions: [CompilationError] = []
    
    private let metalKeywords = [
        "vertex", "fragment", "kernel", "constant", "device", "threadgroup", "thread",
        "float", "float2", "float3", "float4", "half", "half2", "half3", "half4",
        "int", "int2", "int3", "int4", "uint", "uint2", "uint3", "uint4",
        "bool", "bool2", "bool3", "bool4", "void", "struct", "enum", "union",
        "if", "else", "for", "while", "do", "switch", "case", "default",
        "return", "break", "continue", "discard", "true", "false",
        "buffer", "texture1d", "texture2d", "texture3d", "texturecube",
        "sampler", "stage_in", "vertex_id", "instance_id", "position",
        "color", "depth", "sample_id", "front_facing", "point_coord"
    ]
    
    private let metalBuiltinFunctions = [
        "sin", "cos", "tan", "asin", "acos", "atan", "atan2",
        "sinh", "cosh", "tanh", "asinh", "acosh", "atanh",
        "exp", "exp2", "log", "log2", "log10", "sqrt", "rsqrt",
        "pow", "powr", "pown", "rootn", "fabs", "abs", "sign",
        "floor", "ceil", "round", "trunc", "fract", "modf",
        "fmin", "fmax", "min", "max", "clamp", "mix", "step", "smoothstep",
        "length", "distance", "dot", "cross", "normalize", "reflect", "refract",
        "faceforward", "determinant", "transpose", "inverse",
        "degrees", "radians", "fmod", "remainder", "ldexp", "frexp",
        "isinf", "isnan", "isfinite", "isnormal", "signbit"
    ]
    
    func validateShaderSyntax(_ code: String) -> [CompilationError] {
        var errors: [CompilationError] = []
        let lines = code.components(separatedBy: .newlines)
        
        for (lineIndex, line) in lines.enumerated() {
            let lineNumber = lineIndex + 1
            
            // Check for common syntax errors
            errors += checkBraceBalance(line, lineNumber: lineNumber)
            errors += checkParenthesesBalance(line, lineNumber: lineNumber)
            errors += checkSemicolonUsage(line, lineNumber: lineNumber)
            errors += checkVariableDeclarations(line, lineNumber: lineNumber)
            errors += checkFunctionDeclarations(line, lineNumber: lineNumber)
            errors += checkAttributeUsage(line, lineNumber: lineNumber)
            errors += checkTypeUsage(line, lineNumber: lineNumber)
        }
        
        // Check overall structure
        errors += checkOverallStructure(code)
        
        return errors
    }
    
    func analyzeSemanticErrors(_ code: String, compilationResult: Result<Void, ShaderCompilationError>) -> [CompilationError] {
        var errors: [CompilationError] = []
        
        if case .failure(let compilationError) = compilationResult {
            // Parse Metal compiler errors and enhance them
            for error in compilationError.errors {
                let enhancedError = enhanceCompilerError(error, code: code)
                errors.append(enhancedError)
            }
        }
        
        // Add additional semantic analysis
        errors += analyzeUndeclaredVariables(code)
        errors += analyzeTypeCompatibility(code)
        errors += analyzeFunctionCalls(code)
        
        return errors
    }
    
    func generateWarningsAndSuggestions(_ code: String) -> [CompilationError] {
        var warnings: [CompilationError] = []
        let lines = code.components(separatedBy: .newlines)
        
        for (lineIndex, line) in lines.enumerated() {
            let lineNumber = lineIndex + 1
            
            // Performance warnings
            warnings += checkPerformanceIssues(line, lineNumber: lineNumber)
            
            // Style suggestions
            warnings += checkCodeStyle(line, lineNumber: lineNumber)
            
            // Best practices
            warnings += checkBestPractices(line, lineNumber: lineNumber)
        }
        
        return warnings
    }
    
    // MARK: - Syntax Validation Methods
    
    private func checkBraceBalance(_ line: String, lineNumber: Int) -> [CompilationError] {
        var errors: [CompilationError] = []
        let openBraces = line.filter { $0 == "{" }.count
        let closeBraces = line.filter { $0 == "}" }.count
        
        // This is a simplified check - in practice, you'd track across multiple lines
        if openBraces != closeBraces && (openBraces > 0 || closeBraces > 0) {
            let column = line.firstIndex(of: openBraces > closeBraces ? "{" : "}").map { 
                line.distance(from: line.startIndex, to: $0) + 1 
            } ?? 1
            
            errors.append(CompilationError(
                line: lineNumber,
                column: column,
                message: "Unbalanced braces - ensure each '{' has a matching '}'",
                type: .syntaxError,
                severity: .error,
                suggestion: "Check that all code blocks are properly closed"
            ))
        }
        
        return errors
    }
    
    private func checkParenthesesBalance(_ line: String, lineNumber: Int) -> [CompilationError] {
        var errors: [CompilationError] = []
        var stack = 0
        var column = 1
        
        for char in line {
            if char == "(" {
                stack += 1
            } else if char == ")" {
                stack -= 1
                if stack < 0 {
                    errors.append(CompilationError(
                        line: lineNumber,
                        column: column,
                        message: "Unmatched closing parenthesis",
                        type: .syntaxError,
                        severity: .error,
                        suggestion: "Remove extra ')' or add matching '('"
                    ))
                    break
                }
            }
            column += 1
        }
        
        if stack > 0 {
            errors.append(CompilationError(
                line: lineNumber,
                column: line.count,
                message: "Missing closing parenthesis",
                type: .syntaxError,
                severity: .error,
                suggestion: "Add missing ')' to close function call or expression"
            ))
        }
        
        return errors
    }
    
    private func checkSemicolonUsage(_ line: String, lineNumber: Int) -> [CompilationError] {
        var errors: [CompilationError] = []
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Check if line needs semicolon
        let needsSemicolon = [
            "return", "break", "continue", "discard"
        ].contains { trimmed.hasPrefix($0) }
        
        if needsSemicolon && !trimmed.hasSuffix(";") && !trimmed.hasSuffix("{") {
            errors.append(CompilationError(
                line: lineNumber,
                column: line.count,
                message: "Missing semicolon at end of statement",
                type: .syntaxError,
                severity: .error,
                suggestion: "Add ';' at the end of the line"
            ))
        }
        
        return errors
    }
    
    private func checkVariableDeclarations(_ line: String, lineNumber: Int) -> [CompilationError] {
        var errors: [CompilationError] = []
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Check for variable declarations with Metal types
        let metalTypes = ["float", "float2", "float3", "float4", "int", "int2", "int3", "int4", "bool", "half"]
        
        for type in metalTypes {
            if trimmed.hasPrefix(type + " ") {
                // Check for proper variable naming
                let pattern = "\\b\(type)\\s+(\\w+)"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                   let varRange = Range(match.range(at: 1), in: trimmed) {
                    
                    let varName = String(trimmed[varRange])
                    
                    // Check variable naming conventions
                    if varName.first?.isUppercase == true {
                        let column = line.distance(from: line.startIndex, 
                                                 to: line.range(of: varName)?.lowerBound ?? line.startIndex) + 1
                        errors.append(CompilationError(
                            line: lineNumber,
                            column: column,
                            message: "Variable name should start with lowercase letter",
                            type: .warning,
                            severity: .warning,
                            suggestion: "Use camelCase naming: '\(varName.prefix(1).lowercased() + varName.dropFirst())'"
                        ))
                    }
                }
                break
            }
        }
        
        return errors
    }
    
    private func checkFunctionDeclarations(_ line: String, lineNumber: Int) -> [CompilationError] {
        var errors: [CompilationError] = []
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Check for fragment/vertex function declarations
        if trimmed.contains("fragment") || trimmed.contains("vertex") || trimmed.contains("kernel") {
            if !trimmed.contains("float4") && trimmed.contains("fragment") {
                errors.append(CompilationError(
                    line: lineNumber,
                    column: 1,
                    message: "Fragment shader should return float4",
                    type: .typeError,
                    severity: .error,
                    suggestion: "Change return type to 'float4' for fragment shaders"
                ))
            }
            
            if !trimmed.contains("[[stage_in]]") && trimmed.contains("fragment") {
                errors.append(CompilationError(
                    line: lineNumber,
                    column: 1,
                    message: "Fragment shader input should use [[stage_in]] attribute",
                    type: .warning,
                    severity: .warning,
                    suggestion: "Add '[[stage_in]]' attribute to the input parameter"
                ))
            }
        }
        
        return errors
    }
    
    private func checkAttributeUsage(_ line: String, lineNumber: Int) -> [CompilationError] {
        var errors: [CompilationError] = []
        
        // Check for proper Metal attribute usage
        let attributes = ["[[buffer(", "[[stage_in]]", "[[vertex_id]]", "[[position]]", "[[color("]
        
        for attribute in attributes {
            if line.contains(attribute) {
                // Validate attribute syntax
                if attribute.contains("buffer(") && !line.contains("]]") {
                    if let range = line.range(of: attribute) {
                        let column = line.distance(from: line.startIndex, to: range.lowerBound) + 1
                        errors.append(CompilationError(
                            line: lineNumber,
                            column: column,
                            message: "Incomplete attribute declaration",
                            type: .syntaxError,
                            severity: .error,
                            suggestion: "Complete the attribute with proper closing brackets"
                        ))
                    }
                }
            }
        }
        
        return errors
    }
    
    private func checkTypeUsage(_ line: String, lineNumber: Int) -> [CompilationError] {
        var errors: [CompilationError] = []
        
        // Check for common type mismatches
        if line.contains("=") {
            // Simple type checking for assignments
            if line.contains("float3") && line.contains("float4(") {
                errors.append(CompilationError(
                    line: lineNumber,
                    column: 1,
                    message: "Potential type mismatch: assigning float4 to float3",
                    type: .typeError,
                    severity: .warning,
                    suggestion: "Use .xyz to extract float3 from float4, or change variable type"
                ))
            }
        }
        
        return errors
    }
    
    private func checkOverallStructure(_ code: String) -> [CompilationError] {
        var errors: [CompilationError] = []
        
        // Check for required includes
        if !code.contains("#include <metal_stdlib>") {
            errors.append(CompilationError(
                line: 1,
                column: 1,
                message: "Missing Metal standard library include",
                type: .warning,
                severity: .warning,
                suggestion: "Add '#include <metal_stdlib>' at the top of your shader"
            ))
        }
        
        if !code.contains("using namespace metal;") {
            errors.append(CompilationError(
                line: 1,
                column: 1,
                message: "Missing Metal namespace declaration",
                type: .warning,
                severity: .warning,
                suggestion: "Add 'using namespace metal;' after the include statement"
            ))
        }
        
        return errors
    }
    
    // MARK: - Semantic Analysis Methods
    
    private func enhanceCompilerError(_ error: CompilationError, code: String) -> CompilationError {
        let lines = code.components(separatedBy: .newlines)
        guard error.line <= lines.count else { return error }
        
        let errorLine = lines[error.line - 1]
        
        // Analyze the error and provide enhanced information
        var suggestion = error.suggestion
        var errorType = error.type
        
        if error.message.contains("undeclared identifier") {
            errorType = .undeclaredVariable
            suggestion = generateUndeclaredVariableSuggestion(error.message, errorLine: errorLine)
        } else if error.message.contains("no matching function") {
            errorType = .invalidFunction
            suggestion = generateFunctionSuggestion(error.message, errorLine: errorLine)
        } else if error.message.contains("expected") {
            errorType = .syntaxError
            suggestion = generateSyntaxSuggestion(error.message, errorLine: errorLine)
        }
        
        return CompilationError(
            line: error.line,
            column: error.column,
            message: error.message,
            type: errorType,
            severity: error.severity,
            code: String(errorLine.dropFirst(max(0, error.column - 10)).prefix(20)),
            suggestion: suggestion,
            context: CompilationError.ErrorContext(
                startLine: error.line,
                endLine: error.line,
                startColumn: max(1, error.column - 5),
                endColumn: min(errorLine.count, error.column + 5),
                affectedText: String(errorLine.dropFirst(max(0, error.column - 1)).prefix(10))
            )
        )
    }
    
    private func generateUndeclaredVariableSuggestion(_ message: String, errorLine: String) -> String {
        // Extract the undeclared identifier from the error message
        let pattern = "'([^']+)'"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
           let range = Range(match.range(at: 1), in: message) {
            
            let identifier = String(message[range])
            
            // Check for common typos in Metal identifiers
            let suggestions = findSimilarIdentifiers(identifier, in: metalKeywords + metalBuiltinFunctions)
            
            if !suggestions.isEmpty {
                return "Did you mean: \(suggestions.joined(separator: ", "))?"
            } else {
                return "Make sure '\(identifier)' is declared before use, or check for typos"
            }
        }
        
        return "Check variable declaration and spelling"
    }
    
    private func generateFunctionSuggestion(_ message: String, errorLine: String) -> String {
        // Extract function name and suggest alternatives
        return "Check function name spelling and parameter types. Ensure all required parameters are provided."
    }
    
    private func generateSyntaxSuggestion(_ message: String, errorLine: String) -> String {
        if message.contains("expected ';'") {
            return "Add semicolon at the end of the statement"
        } else if message.contains("expected '{'") {
            return "Add opening brace to start code block"
        } else if message.contains("expected '}'") {
            return "Add closing brace to end code block"
        }
        
        return "Check syntax according to Metal shading language rules"
    }
    
    private func findSimilarIdentifiers(_ target: String, in candidates: [String]) -> [String] {
        return candidates.filter { candidate in
            let distance = levenshteinDistance(target, candidate)
            return distance <= 2 && distance > 0
        }.prefix(3).map { $0 }
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        
        var dist = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        
        for i in 0...a.count {
            dist[i][0] = i
        }
        
        for j in 0...b.count {
            dist[0][j] = j
        }
        
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    dist[i][j] = dist[i-1][j-1]
                } else {
                    dist[i][j] = Swift.min(
                        dist[i-1][j] + 1,    // deletion
                        dist[i][j-1] + 1,    // insertion
                        dist[i-1][j-1] + 1   // substitution
                    )
                }
            }
        }
        
        return dist[a.count][b.count]
    }
    
    private func analyzeUndeclaredVariables(_ code: String) -> [CompilationError] {
        // Implementation for undeclared variable analysis
        // This would involve parsing the code and tracking variable scopes
        return []
    }
    
    private func analyzeTypeCompatibility(_ code: String) -> [CompilationError] {
        // Implementation for type compatibility analysis
        return []
    }
    
    private func analyzeFunctionCalls(_ code: String) -> [CompilationError] {
        // Implementation for function call analysis
        return []
    }
    
    // MARK: - Performance and Style Checking
    
    private func checkPerformanceIssues(_ line: String, lineNumber: Int) -> [CompilationError] {
        var warnings: [CompilationError] = []
        
        // Check for expensive operations
        if line.contains("pow(") && (line.contains(", 2.0") || line.contains(", 2)")) {
            warnings.append(CompilationError(
                line: lineNumber,
                column: 1,
                message: "Consider using x*x instead of pow(x, 2) for better performance",
                type: .info,
                severity: .info,
                suggestion: "Replace pow(x, 2.0) with x*x"
            ))
        }
        
        // Check for division by constants that could be multiplication
        if line.contains("/ 2.0") {
            warnings.append(CompilationError(
                line: lineNumber,
                column: 1,
                message: "Consider using multiplication by 0.5 instead of division by 2.0",
                type: .info,
                severity: .info,
                suggestion: "Replace '/ 2.0' with '* 0.5'"
            ))
        }
        
        return warnings
    }
    
    private func checkCodeStyle(_ line: String, lineNumber: Int) -> [CompilationError] {
        var warnings: [CompilationError] = []
        
        // Check for consistent spacing
        if line.contains("if(") || line.contains("for(") || line.contains("while(") {
            warnings.append(CompilationError(
                line: lineNumber,
                column: 1,
                message: "Add space before parentheses in control statements",
                type: .info,
                severity: .info,
                suggestion: "Use 'if (' instead of 'if('"
            ))
        }
        
        return warnings
    }
    
    private func checkBestPractices(_ line: String, lineNumber: Int) -> [CompilationError] {
        var warnings: [CompilationError] = []
        
        // Check for magic numbers
        let magicNumberPattern = "\\b(?!0\\.0|1\\.0|0|1)\\d+\\.\\d+\\b"
        if let regex = try? NSRegularExpression(pattern: magicNumberPattern),
           regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
            warnings.append(CompilationError(
                line: lineNumber,
                column: 1,
                message: "Consider using named constants instead of magic numbers",
                type: .info,
                severity: .info,
                suggestion: "Define constants for better code readability"
            ))
        }
        
        return warnings
    }
}
