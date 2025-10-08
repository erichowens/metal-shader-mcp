import Foundation
import Combine

/// Mock implementation of MCPBridge for testing
class MockMCPBridge: MCPBridge {
    // MARK: - Call Recording
    struct CallRecord {
        let method: String
        let parameters: [String: Any]
        let timestamp: Date = Date()
    }
    
    private(set) var callHistory: [CallRecord] = []
    
    // MARK: - Health & Connection State (Epic 2)
    let connectionState = CurrentValueSubject<ConnectionState, Never>(.connected)
    var mockIsHealthy: Bool = true
    
    // MARK: - Response Configuration
    var shouldThrowError: Bool = false
    var errorToThrow: Error?
    var responseDelay: TimeInterval = 0
    
    // MARK: - State Tracking
    private(set) var lastShaderCode: String?
    private(set) var lastDescription: String?
    private(set) var lastNoSnapshot: Bool = false
    private(set) var lastTab: String?
    private(set) var lastExportDescription: String?
    private(set) var lastExportTime: Float?
    
    // MARK: - MCPBridge Implementation
    func setShader(code: String, description: String?, noSnapshot: Bool) throws {
        recordCall(method: "setShader", parameters: [
            "code": code,
            "description": description as Any,
            "noSnapshot": noSnapshot
        ])
        
        lastShaderCode = code
        lastDescription = description
        lastNoSnapshot = noSnapshot
        
        if shouldThrowError {
            throw errorToThrow ?? MockError.simulatedFailure
        }
        
        simulateDelay()
    }
    
    func setShaderWithMeta(name: String?, description: String?, path: String?, code: String?, save: Bool, noSnapshot: Bool) throws {
        recordCall(method: "setShaderWithMeta", parameters: [
            "name": name as Any,
            "description": description as Any,
            "path": path as Any,
            "code": code as Any,
            "save": save,
            "noSnapshot": noSnapshot
        ])
        
        if let code = code {
            lastShaderCode = code
        }
        lastDescription = description
        lastNoSnapshot = noSnapshot
        
        if shouldThrowError {
            throw errorToThrow ?? MockError.simulatedFailure
        }
        
        simulateDelay()
    }
    
    func exportFrame(description: String, time: Float?) throws {
        recordCall(method: "exportFrame", parameters: [
            "description": description,
            "time": time as Any
        ])
        
        lastExportDescription = description
        lastExportTime = time
        
        if shouldThrowError {
            throw errorToThrow ?? MockError.simulatedFailure
        }
        
        simulateDelay()
    }
    
    func setTab(_ tab: String) throws {
        recordCall(method: "setTab", parameters: [
            "tab": tab
        ])
        
        lastTab = tab
        
        if shouldThrowError {
            throw errorToThrow ?? MockError.simulatedFailure
        }
        
        simulateDelay()
    }
    
    // MARK: - Health Check (Epic 2)
    func isHealthy() async -> Bool {
        return mockIsHealthy
    }
    
    // MARK: - Test Utilities
    func reset() {
        callHistory.removeAll()
        lastShaderCode = nil
        lastDescription = nil
        lastNoSnapshot = false
        lastTab = nil
        lastExportDescription = nil
        lastExportTime = nil
        shouldThrowError = false
        errorToThrow = nil
        responseDelay = 0
    }
    
    func getCallCount(for method: String) -> Int {
        return callHistory.filter { $0.method == method }.count
    }
    
    func getLastCall(for method: String) -> CallRecord? {
        return callHistory.last { $0.method == method }
    }
    
    func getAllCalls(for method: String) -> [CallRecord] {
        return callHistory.filter { $0.method == method }
    }
    
    // MARK: - Private Methods
    private func recordCall(method: String, parameters: [String: Any]) {
        let record = CallRecord(method: method, parameters: parameters)
        callHistory.append(record)
    }
    
    private func simulateDelay() {
        if responseDelay > 0 {
            Thread.sleep(forTimeInterval: responseDelay)
        }
    }
    
    // MARK: - Error Types
    enum MockError: Error, LocalizedError {
        case simulatedFailure
        case networkTimeout
        case serverUnavailable
        case invalidRequest
        
        var errorDescription: String? {
            switch self {
            case .simulatedFailure:
                return "Simulated test failure"
            case .networkTimeout:
                return "Network timeout"
            case .serverUnavailable:
                return "Server unavailable"
            case .invalidRequest:
                return "Invalid request"
            }
        }
    }
}

/// Factory for creating mock bridges with predefined behaviors
enum MockBridgeFactory {
    static func successful() -> MockMCPBridge {
        let mock = MockMCPBridge()
        mock.shouldThrowError = false
        return mock
    }
    
    static func failing(with error: Error = MockMCPBridge.MockError.simulatedFailure) -> MockMCPBridge {
        let mock = MockMCPBridge()
        mock.shouldThrowError = true
        mock.errorToThrow = error
        return mock
    }
    
    static func slow(delay: TimeInterval = 1.0) -> MockMCPBridge {
        let mock = MockMCPBridge()
        mock.responseDelay = delay
        return mock
    }
    
    static func intermittent(failureRate: Double = 0.3) -> MockMCPBridge {
        let mock = IntermisentMockBridge()
        mock.failureRate = failureRate
        return mock
    }
}

/// Mock bridge that fails intermittently for reliability testing
private final class IntermisentMockBridge: MockMCPBridge {
    var failureRate: Double = 0.3
    
    override func setShader(code: String, description: String?, noSnapshot: Bool) throws {
        if Double.random(in: 0...1) < failureRate {
            shouldThrowError = true
            errorToThrow = MockError.networkTimeout
        } else {
            shouldThrowError = false
        }
        try super.setShader(code: code, description: description, noSnapshot: noSnapshot)
    }
    
    override func setShaderWithMeta(name: String?, description: String?, path: String?, code: String?, save: Bool, noSnapshot: Bool) throws {
        if Double.random(in: 0...1) < failureRate {
            shouldThrowError = true
            errorToThrow = MockError.serverUnavailable
        } else {
            shouldThrowError = false
        }
        try super.setShaderWithMeta(name: name, description: description, path: path, code: code, save: save, noSnapshot: noSnapshot)
    }
    
    override func exportFrame(description: String, time: Float?) throws {
        if Double.random(in: 0...1) < failureRate {
            shouldThrowError = true
            errorToThrow = MockError.invalidRequest
        } else {
            shouldThrowError = false
        }
        try super.exportFrame(description: description, time: time)
    }
    
    override func setTab(_ tab: String) throws {
        if Double.random(in: 0...1) < failureRate {
            shouldThrowError = true
            errorToThrow = MockError.networkTimeout
        } else {
            shouldThrowError = false
        }
        try super.setTab(tab)
    }
}