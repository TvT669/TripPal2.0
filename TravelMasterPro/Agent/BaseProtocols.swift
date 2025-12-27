//
//  BaseProtocols.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/22.
//

import Foundation

// MARK: - Agent Protocols

enum AgentStatus: Equatable {
    case idle
    case working
    case thinking
    case failed(String)
}

enum AgentCapability: String, CaseIterable {
    case general
    case flightSearch
    case hotelSearch
    case routePlanning
    case budgetAnalysis
    case textGeneration
    case hotelBooking
    case budgetPlanning
    case dataAnalysis
    case webSearch
    case travelPlanning
}

enum AgentError: Error {
    case concurrentExecution
    case executionFailed(String)
    case maxStepsExceeded
    case invalidRequest(String)
}

protocol Agent: AnyObject {
    var name: String { get }
    var systemPrompt: String { get }
    var capabilities: [AgentCapability] { get }
    
    func run(request: String) async throws -> String
    
    // Context & Capability methods
    func isCapableOf(_ capability: AgentCapability) -> Bool
    func setSharedContext(_ context: [String: Any])
    func getSharedContext() -> [String: Any]
}

extension Agent {
    func isCapableOf(_ capability: AgentCapability) -> Bool {
        return capabilities.contains(capability)
    }
    
    func setSharedContext(_ context: [String: Any]) {
        // Default implementation does nothing if agent doesn't support context
    }
    
    func getSharedContext() -> [String: Any] {
        return [:]
    }
}

// MARK: - Flow Protocols

enum FlowStatus {
    case idle
    case planning
    case executing
    case completed
    case failed(String)
    case cancelled
}

struct FlowResult {
    let success: Bool
    let output: String
    let executionTime: TimeInterval
    let tasksCompleted: Int
    let metadata: [String: Any]
}

struct FlowProgress {
    let currentTask: String?
    let percentage: Double
    let estimatedTimeRemaining: TimeInterval?
}

enum SimpleTaskStatus {
    case pending
    case running
    case completed
    case failed
}

enum TaskType: String {
    case flight
    case hotel
    case route
    case budget
    case general
}

struct SimpleTask: Identifiable {
    let id: String
    let type: TaskType
    let description: String
    let assignedAgent: String
    var status: SimpleTaskStatus
    var result: String?
    
    init(id: String = UUID().uuidString, type: TaskType, description: String, assignedAgent: String, status: SimpleTaskStatus = .pending, result: String? = nil) {
        self.id = id
        self.type = type
        self.description = description
        self.assignedAgent = assignedAgent
        self.status = status
        self.result = result
    }
}

enum FlowError: Error {
    case agentNotFound(String)
    case taskExecutionFailed(String)
    case invalidConfiguration
    case executionTimeout
}

protocol Flow: AnyObject {
    var name: String { get }
    var status: FlowStatus { get }
    
    func execute(request: String) async throws -> FlowResult
    func cancel() async
    func getProgress() -> FlowProgress
}

// MARK: - Memory Protocols

protocol Memory {
    var messages: [Message] { get }
    func addMessage(_ message: Message)
    func getContext() -> String
    func clear()
}

// MARK: - TripPal Compatibility

/// 智能体协议 (TripPal)
protocol TPAgentProtocol: AnyObject {
    /// 智能体名称
    func agentName() -> String
    
    /// 接收消息（可选）
    func receiveMessage(_ messageName: String, payload: [AnyHashable: Any]?)
}

extension TPAgentProtocol {
    func receiveMessage(_ messageName: String, payload: [AnyHashable: Any]?) {
        // 默认实现为空
    }
}
