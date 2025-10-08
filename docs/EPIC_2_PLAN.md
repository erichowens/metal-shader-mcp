# Epic 2: MCP Server Maturation & Reliability

**Status**: 🎯 **Ready to Start** (Epic 1 completed)  
**Owner**: TBD  
**Target**: Production-ready MCP server with comprehensive testing

---

## 🎯 Goals

Build upon Epic 1's foundation to create a production-grade MCP server with:
1. **Reliability**: Health checks, auto-recovery, connection monitoring
2. **Testing**: Integration tests, stress tests, benchmarks
3. **Security**: Hardened command parsing, input validation
4. **Performance**: Optimized timeouts, resource management
5. **Observability**: Structured logging, telemetry, metrics

---

## 📋 Tasks

### 1. Health Checks & Connection Recovery (HIGH PRIORITY)

**From Claude Code Review**: Implement health checks and auto-restart on process death

**Tasks**:
- [ ] Add `MCPBridge.isHealthy() async -> Bool` protocol method
- [ ] Implement periodic health check timer in MCPLiveClient (every 30s)
- [ ] Add ping/pong JSON-RPC method for lightweight health checks
- [ ] Track consecutive health check failures
- [ ] Implement auto-restart logic after 3 consecutive failures
- [ ] Add observable connection state (`connecting`, `connected`, `disconnected`, `unhealthy`)
- [ ] Wire connection state to UI (MCPStatusView enhancement)
- [ ] Add telemetry for connection state transitions

**Acceptance Criteria**:
```swift
// Protocol enhancement
protocol MCPBridge {
    func isHealthy() async -> Bool
    var connectionState: Observable<ConnectionState> { get }
    // ... existing methods
}

// MCPLiveClient implementation
class MCPLiveClient: MCPBridge {
    private var healthCheckTimer: Timer?
    private var consecutiveFailures: Int = 0
    private let maxFailures = 3
    
    func startHealthCheck() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                if !(await self?.isHealthy() ?? false) {
                    self?.handleUnhealthyState()
                }
            }
        }
    }
    
    func isHealthy() async -> Bool {
        do {
            _ = try sendRequest(method: "ping", params: nil, timeout: 2.0)
            consecutiveFailures = 0
            return true
        } catch {
            consecutiveFailures += 1
            return false
        }
    }
    
    private func handleUnhealthyState() {
        if consecutiveFailures >= maxFailures {
            logger.warning("MCP client unhealthy, attempting restart...")
            terminateChild()
            try? ensureLaunched()
        }
    }
}
```

---

### 2. Integration Tests (HIGH PRIORITY)

**From Claude Code Review**: Add integration tests with mock MCP server, missing edge case coverage

**Tasks**:
- [ ] Create mock MCP server (Node.js script) for integration tests
- [ ] Add integration test target to Package.swift
- [ ] Test scenarios:
  - [ ] Full request/response cycle
  - [ ] Multiple concurrent requests
  - [ ] Process crash mid-request
  - [ ] Timeout scenarios
  - [ ] Malformed JSON responses
  - [ ] Large payloads (>5MB)
  - [ ] Rapid request sequences
  - [ ] Connection recovery after failure
- [ ] Add integration test CI job (runs on every PR)

**Mock Server Example**:
```javascript
// Tests/Integration/mock-mcp-server.js
const readline = require('readline');
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

const scenarios = {
  timeout: () => {
    // Never respond to simulate timeout
  },
  malformed: () => {
    console.log('this is not json\n');
  },
  success: (id, method) => {
    console.log(JSON.stringify({
      jsonrpc: '2.0',
      id,
      result: { success: true, method }
    }) + '\n');
  }
};

rl.on('line', (line) => {
  try {
    const req = JSON.parse(line);
    const scenario = process.env.TEST_SCENARIO || 'success';
    // Access request metadata
    scenarios[scenario](req.id, req.method);
  } catch (e) {
    // Malformed input
  }
});
```

---

### 3. Stress Tests & Benchmarks (MEDIUM PRIORITY)

**From Claude Code Review**: Add stress tests for concurrent requests and benchmarks

**Tasks**:
- [ ] Create stress test suite
- [ ] Test concurrent request handling (10, 50, 100 concurrent requests)
- [ ] Measure request latency (p50, p95, p99)
- [ ] Test sustained load (100 requests/sec for 60s)
- [ ] Memory leak detection under load
- [ ] CPU usage profiling
- [ ] Compare live client vs file bridge performance
- [ ] Create benchmark baselines and regression detection

**Benchmark Framework**:
```swift
// Tests/Benchmarks/MCPBenchmarks.swift
import XCTest

class MCPBenchmarks: XCTestCase {
    func testConcurrentRequests() async throws {
        let client = MCPLiveClient(serverCommand: "node dist/simple-mcp.js")
        let requestCount = 100
        let start = Date()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<requestCount {
                group.addTask {
                    try await client.setTab("tab_\(i)")
                }
            }
            try await group.waitForAll()
        }
        
        let duration = Date().timeIntervalSince(start)
        let rps = Double(requestCount) / duration
        
        print("📊 Concurrent requests: \(requestCount) in \(duration)s (\(rps) req/s)")
        XCTAssertLessThan(duration, 10.0, "Should complete 100 concurrent requests in <10s")
    }
    
    func testRequestLatency() async throws {
        let client = MCPLiveClient(serverCommand: "node dist/simple-mcp.js")
        var latencies: [TimeInterval] = []
        
        for _ in 0..<100 {
            let start = Date()
            try await client.setTab("library")
            latencies.append(Date().timeIntervalSince(start))
        }
        
        latencies.sort()
        let p50 = latencies[latencies.count / 2]
        let p95 = latencies[Int(Double(latencies.count) * 0.95)]
        let p99 = latencies[Int(Double(latencies.count) * 0.99)]
        
        print("📊 Latency: p50=\(p50*1000)ms p95=\(p95*1000)ms p99=\(p99*1000)ms")
        
        // Performance budgets
        XCTAssertLessThan(p50, 0.050, "p50 latency should be <50ms")
        XCTAssertLessThan(p95, 0.200, "p95 latency should be <200ms")
    }
}
```

---

### 4. Structured Logging (MEDIUM PRIORITY)

**From Claude Code Review**: Replace print statements with proper logging framework

**Tasks**:
- [ ] Add `os.log` or unified logging framework
- [ ] Define log levels (debug, info, warning, error, critical)
- [ ] Add structured metadata (request ID, method, duration)
- [ ] Configure log persistence options
- [ ] Add log viewer in UI (debug panel)
- [ ] Document logging best practices

**Implementation**:
```swift
import os.log

private let logger = Logger(subsystem: "com.metalshader.mcp", category: "live-client")

// Usage examples:
logger.debug("Launching MCP server: \(serverCommand)")
logger.info("MCP request completed in \(duration)ms")
logger.warning("MCP health check failed (attempt \(consecutiveFailures)/\(maxFailures))")
logger.error("MCP request failed: \(error.localizedDescription)")
logger.critical("MCP process terminated unexpectedly")
```

---

### 5. Per-Method Timeouts (LOW PRIORITY)

**From Claude Code Review**: Consider per-method timeout configuration

**Tasks**:
- [ ] Define timeout enum for different method types
- [ ] Update sendRequest to use method-specific timeouts
- [ ] Document timeout values and rationale
- [ ] Add timeout configuration via environment variables

**Implementation**:
```swift
private enum MethodTimeout {
    static let setShader: TimeInterval = 5.0       // Fast operation
    static let exportFrame: TimeInterval = 15.0    // Rendering takes time
    static let exportSequence: TimeInterval = 60.0 // Multiple frames
    static let setTab: TimeInterval = 2.0          // UI operation
    static let ping: TimeInterval = 1.0            // Health check
    static let `default`: TimeInterval = 8.0       // Fallback
}

func setShader(...) throws {
    _ = try sendRequest(method: "set_shader", params: params, 
                       timeout: MethodTimeout.setShader)
}
```

---

### 6. Telemetry & Metrics (LOW PRIORITY)

**From Claude Code Review**: Add telemetry for RPC latency, success rates

**Tasks**:
- [ ] Track request/response times
- [ ] Track success/failure rates by method
- [ ] Track fallback to file-bridge frequency
- [ ] Track connection state transitions
- [ ] Add metrics dashboard in debug panel
- [ ] Export metrics to file for analysis
- [ ] Add performance regression detection in CI

**Metrics Structure**:
```swift
struct MCPMetrics {
    var requestCount: Int = 0
    var failureCount: Int = 0
    var totalLatency: TimeInterval = 0
    var methodStats: [String: MethodStats] = [:]
    var connectionTransitions: [(from: ConnectionState, to: ConnectionState, timestamp: Date)] = []
    
    var averageLatency: TimeInterval {
        requestCount > 0 ? totalLatency / Double(requestCount) : 0
    }
    
    var successRate: Double {
        requestCount > 0 ? Double(requestCount - failureCount) / Double(requestCount) : 0
    }
}

struct MethodStats {
    var count: Int = 0
    var failures: Int = 0
    var totalLatency: TimeInterval = 0
}
```

---

### 7. Enhanced Error Recovery (MEDIUM PRIORITY)

**From Claude Code Review**: Implement exponential backoff for transient failures

**Tasks**:
- [ ] Add retry logic with exponential backoff
- [ ] Distinguish transient vs permanent errors
- [ ] Add circuit breaker pattern for repeated failures
- [ ] Track retry metrics
- [ ] Document retry behavior for users

**Implementation**:
```swift
func sendRequestWithRetry(method: String, params: [String: Any]?, 
                         timeout: TimeInterval, maxRetries: Int = 2) throws -> Any? {
    var lastError: Error?
    var delay: TimeInterval = 0.1 // Start with 100ms
    
    for attempt in 0...maxRetries {
        do {
            return try sendRequest(method: method, params: params, timeout: timeout)
        } catch let error as NSError {
            lastError = error
            
            // Check if error is retryable
            if !isTransientError(error) {
                throw error // Permanent error, don't retry
            }
            
            if attempt < maxRetries {
                Thread.sleep(forTimeInterval: delay)
                delay *= 2 // Exponential backoff
                logger.warning("Retrying \(method) after \(delay)s (attempt \(attempt + 1)/\(maxRetries))")
            }
        }
    }
    
    throw lastError ?? makeError(code: 99, "Max retries exceeded")
}

private func isTransientError(_ error: NSError) -> Bool {
    // Timeout, connection, temporary failures
    return error.code == 4 || error.code == 3
}
```

---

## 📊 Success Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Health Check Coverage | 100% uptime detection | Monitor logs for missed failures |
| Integration Test Coverage | >80% code paths | Code coverage report |
| p95 Request Latency | <200ms | Benchmark suite |
| Concurrent Request Capacity | >100 req/s | Stress tests |
| Connection Recovery Time | <5s | Integration tests |
| Memory Leak Detection | 0 leaks | Instruments profiling |
| Test Execution Time | <30s total | CI metrics |

---

## 🔗 Dependencies

- **Epic 1** (COMPLETED): MCPLiveClient foundation
- **Node MCP Server**: Ping/pong method support
- **CI Infrastructure**: Integration test job

---

## 📝 Notes

### From Epic 1 Code Review:
1. ✅ Command parsing improved (handles quoted arguments)
2. ✅ stderr logging added for security errors
3. ✅ Resource cleanup enhanced (explicit file handle closing)
4. ✅ Buffer size limits added (10MB buffer, 5MB messages)
5. ✅ Basic edge case tests added (timeout, malformed JSON, process crash)
6. 🔄 **TODO**: Integration tests with real MCP server
7. 🔄 **TODO**: Stress tests for concurrency
8. 🔄 **TODO**: Health checks and auto-recovery
9. 🔄 **TODO**: Structured logging framework
10. 🔄 **TODO**: Performance benchmarks and regression detection

---

## 📅 Timeline

**Phase 1** (Week 1-2): Health checks, connection recovery, basic integration tests  
**Phase 2** (Week 3-4): Stress tests, benchmarks, structured logging  
**Phase 3** (Week 5-6): Telemetry, enhanced error recovery, performance optimization

**Total Estimated Duration**: 6 weeks

---

## ✅ Definition of Done

- [ ] All health check functionality implemented and tested
- [ ] Integration test suite with >10 scenarios passing
- [ ] Stress tests passing with defined performance budgets
- [ ] Benchmark baselines established with regression detection
- [ ] Structured logging in place throughout codebase
- [ ] Per-method timeouts configured and documented
- [ ] Telemetry dashboard functional
- [ ] All tests passing in CI
- [ ] Documentation updated (WARP.md, README.md, CONTRIBUTING.md)
- [ ] Code reviewed and approved
- [ ] Epic 2 merged to main

---

**References**:
- Epic 1 Code Review: PR #49 comments
- ROADMAP.md: Epic 2 section
- Claude's suggestions: Security, performance, testing gaps