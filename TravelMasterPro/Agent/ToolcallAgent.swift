//
//  ToolcallAgent.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/31.
//

import Foundation

/// 工具调用智能体 - 动力系统
/// 实现了"如何驱动"的具体机制：think-act 循环
/// 负责"怎么做"和"做得好"
class ToolCallAgent: Agent {
    let name: String
    let systemPrompt: String
    let capabilities: [AgentCapability]
    
    // 核心动力组件
    private let llm: LLMService
    private let memory: MemoryService
    private let toolCollection: ToolCollection
    
    // 状态管理
    @Published private(set) var status: AgentStatus = .idle
    private var sharedContext: [String: Any] = [:]
    
    init(name: String,
         systemPrompt: String,
         capabilities: [AgentCapability],
         tools: [Tool],
         llm: LLMService) {
        self.name = name
        self.systemPrompt = systemPrompt
        self.capabilities = capabilities
        self.llm = llm
        self.memory = MemoryService()
        self.toolCollection = ToolCollection(tools: tools)
        
        // 初始化系统提示
        memory.addMessage(Message.systemMessage(systemPrompt))
    }
    
    // MARK: - Agent 协议实现
    
    func run(request: String) async throws -> String {
        guard status == .idle else {
            throw AgentError.concurrentExecution
        }
        
        status = .working
        defer { status = .idle }
        
        do {
            return try await executeThinkActCycle(request)
        } catch {
            status = .failed(error.localizedDescription)
            throw error
        }
    }
    
    func isCapableOf(_ capability: AgentCapability) -> Bool {
        return capabilities.contains(capability)
    }
    
    func setSharedContext(_ context: [String: Any]) {
        self.sharedContext = context
    }
    
    func getSharedContext() -> [String: Any] {
        return sharedContext
    }
    
    // MARK: - 核心动力系统：Think-Act 循环
    
    private func executeThinkActCycle(_ request: String) async throws -> String {
        // 添加用户请求到记忆
        memory.addMessage(Message.userMessage(request))
        addContextToMemory()
        
        var steps = 0
        let maxSteps = 10
        var lastResponse = ""
        
        while steps < maxSteps {
            steps += 1
            
            // 🧠 思考阶段：决定使用哪些工具
            let toolCalls = try await think()
            
            // 如果没有工具调用，说明思考完成
            if toolCalls.isEmpty {
                lastResponse = getLastAssistantMessage()
                break
            }
            
            // ⚡ 行动阶段：执行工具调用
            let actionResult = try await act(toolCalls: toolCalls)
            lastResponse = actionResult
            
            // 检查是否应该终止
            if shouldTerminate(toolCalls) {
                break
            }
        }
        
        if steps >= maxSteps {
            throw AgentError.maxStepsExceeded
        }
        
        return lastResponse.isEmpty ? "任务完成" : lastResponse
    }
    
    private func think() async throws -> [ToolCall] {
        do {
            let result = try await llm.askTool(
                messages: memory.messages,
                tools: toolCollection.toParameters(),
                toolChoice: .auto
            )
            
            // 记录思考结果
            // ✅ 修复：即使 content 为空，如果有 toolCalls，也必须记录 assistant 消息
            // 否则会导致 "Messages with role 'tool' must be a response to a preceding message with 'tool_calls'" 错误
            let content = result.content ?? ""
            let toolCalls = result.toolCalls ?? []
            
            if !content.isEmpty || !toolCalls.isEmpty {
                var message = Message.assistantMessage(content)
                if !toolCalls.isEmpty {
                    var metadata = MessageMetadata()
                    metadata.toolCalls = toolCalls
                    message.metadata = metadata
                }
                memory.addMessage(message)
            }
            
            return toolCalls
            
        } catch {
            throw AgentError.executionFailed("思考阶段失败: \(error.localizedDescription)")
        }
    }
    
    private func act(toolCalls: [ToolCall]) async throws -> String {
        var results: [String] = []
        
        for call in toolCalls {
            do {
                let result = try await toolCollection.execute(
                    name: call.function.name,
                    arguments: call.function.arguments
                )
                
                let resultContent = result.output ?? "执行完成"
                results.append(resultContent)
                
                // 记录到记忆
                memory.addMessage(Message.toolMessage(
                    content: resultContent,
                    toolCallId: call.id,
                    toolName: call.function.name
                ))
                
                // 更新共享上下文
                sharedContext["last_\(call.function.name)_result"] = resultContent
                
            } catch {
                let errorMsg = "工具 \(call.function.name) 执行失败: \(error.localizedDescription)"
                results.append(errorMsg)
                memory.addMessage(Message.toolMessage(
                    content: errorMsg,
                    toolCallId: call.id,
                    toolName: call.function.name
                ))
            }
        }
        
        return results.joined(separator: "\n\n")
    }
    
    // MARK: - 辅助方法
    
    private func addContextToMemory() {
        if !sharedContext.isEmpty {
            let contextInfo = sharedContext.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            memory.addMessage(Message.systemMessage("当前上下文:\n\(contextInfo)"))
        }
    }
    
    private func getLastAssistantMessage() -> String {
        return memory.messages.last { $0.role == .assistant }?.content ?? "任务完成"
    }
    
    private func shouldTerminate(_ toolCalls: [ToolCall]) -> Bool {
        return toolCalls.contains { $0.function.name == "terminate" }
    }
}
