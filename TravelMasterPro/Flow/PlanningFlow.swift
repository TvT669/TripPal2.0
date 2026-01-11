//
//  PlanningFlow.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import Foundation

/// 旅行规划工作流 - 任务总指挥
/// 负责"做什么"和"怎么组织"
class PlanningFlow: Flow {
    let name: String = "TravelPlanningFlow"
    
    // 智能体团队
    private let primaryAgent: Agent  // 主要规划师
    private let agents: [String: Agent]  // 专业智能体团队
    private let synthesisAgent: SynthesisAgent // 综合智能体
    
    // 状态管理
    @Published private(set) var status: FlowStatus = .idle
    private var currentTasks: [SimpleTask] = []
    private var sharedContext: [String: Any] = [:]
    
    init(primaryAgent: Agent, agents: [String: Agent]) {
        self.primaryAgent = primaryAgent
        self.agents = agents
        // 假设 primaryAgent 的 LLM 服务可以复用，或者创建一个新的
        // 这里为了简单，我们假设可以从 primaryAgent 获取 LLMService，或者直接新建
        // 由于 Agent 协议没有暴露 LLMService，我们这里临时创建一个新的 LLMService 实例
        // 在实际项目中，应该通过依赖注入传递
        self.synthesisAgent = SynthesisAgent(llm: LLMService())
    }
    
    // MARK: - Flow 协议实现
    
    func execute(request: String) async throws -> FlowResult {
        return try await execute(request: request, history: [], onProgress: nil)
    }
    
    func execute(request: String, history: [Message], onProgress: ((String) -> Void)? = nil) async throws -> FlowResult {
        let startTime = Date()
        status = .planning
        
        do {
            // 1. 智能任务分解 (带历史上下文)
            onProgress?("正在拆解任务...")
            let tasks = try await decomposeTasks(request, history: history)
            currentTasks = tasks
            
            status = .executing
            
            // 2. 执行任务 (带反馈循环)
            let results = try await executeTasksWithFeedback(tasks, originalRequest: request, onProgress: onProgress)
            
            // 3. 整合结果 (使用 SynthesisAgent)
            onProgress?("正在整合规划结果...")
            let finalOutput = try await performSynthesis(request: request)
            
            status = .completed
            let executionTime = Date().timeIntervalSince(startTime)
            
            return FlowResult(
                success: true,
                output: finalOutput,
                executionTime: executionTime,
                tasksCompleted: tasks.count,
                metadata: ["context": sharedContext]
            )
            
        } catch {
            status = .failed(error.localizedDescription)
            throw error
        }
    }
    
    func cancel() async {
        status = .cancelled
        currentTasks.removeAll()
        sharedContext.removeAll()
    }
    
    func getProgress() -> FlowProgress {
        let total = currentTasks.count
        let completed = currentTasks.filter { $0.status == .completed }.count
        
        return FlowProgress(
            currentTask: currentTasks.first { $0.status == .running }?.description,
            percentage: total > 0 ? Double(completed) / Double(total) : 0.0,
            estimatedTimeRemaining: nil
        )
    }
    
    // MARK: - 私有实现方法
    
    /// 智能任务分解
    private func decomposeTasks(_ request: String, history: [Message] = []) async throws -> [SimpleTask] {
        
        var contextStr = ""
        if !history.isEmpty {
            // 提取最近的对话历史作为上下文
            contextStr = "\n历史对话上下文：\n" + history.suffix(5).map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")
        }
        
        let decompositionPrompt = """
        作为旅行规划专家，请将以下用户请求分解为具体的执行任务：
        
        用户请求：\(request)
        \(contextStr)
        
        可用的智能体类型：
        - flight: 航班搜索和预订
        - hotel: 酒店搜索和预订  
        - route: 路线规划和导航
        - budget: 预算分析和管理
        - general: 通用任务处理
        
        请按以下格式返回任务列表（每行一个任务）：
        1. [flight] 搜索北京到上海的航班
        2. [hotel] 查找上海市中心的酒店
        3. [budget] 计算总体旅行预算
        
        只返回任务列表，不要其他说明。
        """
        
        let response = try await primaryAgent.run(request: decompositionPrompt)
        return parseTasks(response)
    }
    
    /// 解析任务列表
    private func parseTasks(_ response: String) -> [SimpleTask] {
        let lines = response.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        return lines.enumerated().compactMap { index, line in
            // 解析格式: "1. [agent] description"
            let pattern = #"\d+\.\s*\[(\w+)\]\s*(.+)"#
            
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                
                let agentRange = Range(match.range(at: 1), in: line)!
                let descriptionRange = Range(match.range(at: 2), in: line)!
                
                let agentType = String(line[agentRange])
                let description = String(line[descriptionRange])
                
                // 确保使用有效的 Agent 类型（处理 LLM 可能的大小写不一致或幻觉）
                // 如果解析失败，回退到 general
                let safeType = TaskType(rawValue: agentType.lowercased()) ?? .general
                
                return SimpleTask(
                    id: "task_\(index + 1)",
                    type: safeType,
                    description: description,
                    assignedAgent: safeType.rawValue, // ✅ 强制使用有效的 Key，防止 AgentNotFound 错误
                    status: .pending,
                    result: nil
                )
            }
            
            return nil
        }
    }
    
    /// 执行任务列表 (带反馈循环) - 并行优化版
    private func executeTasksWithFeedback(_ tasks: [SimpleTask], originalRequest: String, onProgress: ((String) -> Void)? = nil) async throws -> [String] {
        var results: [String] = []
        
        // 分离依赖任务 (budget) 和独立任务 (flight, hotel, route, general)
        // 预算任务通常依赖其他任务的成本结果，所以放在最后执行
        let dependentTypes: [TaskType] = [.budget]
        
        let parallelPhaseTasks = tasks.filter { !dependentTypes.contains($0.type) }
        let sequentialPhaseTasks = tasks.filter { dependentTypes.contains($0.type) }
        
        // 更新当前任务列表顺序
        await MainActor.run {
            currentTasks = parallelPhaseTasks + sequentialPhaseTasks
        }
        
        // 1. 第一阶段：并行执行独立任务
        if !parallelPhaseTasks.isEmpty {
            onProgress?("多智能体团队并行工作中...")
            
            // 按 Agent 分组任务，确保同一 Agent 的任务串行执行 (避免非线程安全的 Agent 状态冲突)
            let tasksByAgent = Dictionary(grouping: parallelPhaseTasks, by: { $0.assignedAgent })
            
            let parallelResults = try await withThrowingTaskGroup(of: [(String, String, [String: Any])].self) { group in
                
                for (agentId, agentTasks) in tasksByAgent {
                    group.addTask {
                        // 获取负责的智能体
                        guard let agent = self.agents[agentId] else {
                            throw FlowError.agentNotFound(agentId)
                        }
                        
                        // 设置共享上下文 (使用当前快照)
                        agent.setSharedContext(self.sharedContext)
                        
                        var agentResults: [(String, String, [String: Any])] = []
                        
                        // 串行执行该 Agent 的所有任务
                        for var task in agentTasks {
                            // 更新状态: Running
                            await MainActor.run {
                                task.status = .running
                                self.updateTaskInList(task)
                                // 通知进度，例如 "正在搜索北京到上海的航班..."
                                onProgress?("[\(agent.name)] 正在\(self.simplifyTaskDesc(task.description))...")
                            }
                            
                            // 执行任务
                            let result = try await agent.run(request: task.description)
                            
                            // 更新状态: Completed
                            await MainActor.run {
                                var completedTask = task
                                completedTask.status = .completed
                                completedTask.result = result
                                self.updateTaskInList(completedTask)
                            }
                            
                            agentResults.append((task.id, result, agent.getSharedContext()))
                        }
                        
                        return agentResults
                    }
                }
                
                var collectedResults: [String] = []
                for try await agentTaskResults in group {
                    for (taskId, result, agentContext) in agentTaskResults {
                        collectedResults.append(result)
                        
                        // 合并上下文 (Consumer 线程串行执行，安全)
                        self.mergeContext(from: agentContext)
                        
                        if let task = parallelPhaseTasks.first(where: { $0.id == taskId }) {
                            self.updateContextWithTaskResult(taskType: task.type, result: result, taskId: taskId)
                        }
                    }
                }
                return collectedResults
            }
            results.append(contentsOf: parallelResults)
        }
        
        // 2. 第二阶段：串行执行依赖任务
        for var task in sequentialPhaseTasks {
            guard let agent = agents[task.assignedAgent] else {
                throw FlowError.agentNotFound(task.assignedAgent)
            }
            
            // 检查智能体能力
            let requiredCapability = mapTaskTypeToCapability(task.type)
            if let capability = requiredCapability, !agent.isCapableOf(capability) {
                throw FlowError.invalidConfiguration
            }
            
            // 设置共享上下文
            agent.setSharedContext(sharedContext)
            
            // 执行任务
            await MainActor.run {
                task.status = .running
                self.updateTaskInList(task)
                onProgress?("[\(agent.name)] 正在\(self.simplifyTaskDesc(task.description))...")
            }
            
            do {
                // 动态构建请求：如果是预算任务，注入已知的成本信息
                var taskRequest = task.description
                if task.type == .budget {
                    taskRequest = enrichBudgetRequest(taskRequest, context: sharedContext)
                }
                
                let result = try await agent.run(request: taskRequest)
                
                await MainActor.run {
                    var completedTask = task
                    completedTask.status = .completed
                    completedTask.result = result
                    self.updateTaskInList(completedTask)
                }
                
                results.append(result)
                
                // 更新共享上下文
                mergeContext(from: agent.getSharedContext())
                
                // 关键步骤：提取结构化数据并更新上下文
                updateContextWithTaskResult(taskType: task.type, result: result, taskId: task.id)
                
            } catch {
                await MainActor.run {
                    var failedTask = task
                    failedTask.status = .failed
                    self.updateTaskInList(failedTask)
                }
                throw FlowError.executionTimeout
            }
        }
        
        return results
    }
    
    // 简化任务描述，避免过长
    private func simplifyTaskDesc(_ desc: String) -> String {
        let prefix = desc.replacingOccurrences(of: "\\[.*?\\]", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        return prefix.count > 15 ? String(prefix.prefix(15)) + "..." : prefix
    }
    
    /// 丰富预算请求，注入已知成本
    private func enrichBudgetRequest(_ originalRequest: String, context: [String: Any]) -> String {
        var enrichment = "\n\n【已知成本信息】\n"
        var hasCostInfo = false
        
        if let flightCost = context["extracted_flight_cost"] as? Double {
            enrichment += "- 航班预估费用：¥\(flightCost)\n"
            hasCostInfo = true
        }
        
        if let hotelCost = context["extracted_hotel_cost"] as? Double {
            enrichment += "- 酒店预估费用：¥\(hotelCost)\n"
            hasCostInfo = true
        }
        
        if hasCostInfo {
            return originalRequest + enrichment + "\n请基于以上实际搜索到的费用，重新评估总预算的可行性。"
        }
        
        return originalRequest
    }
    
    /// 从任务结果中提取数据并更新上下文
    private func updateContextWithTaskResult(taskType: TaskType, result: String, taskId: String) {
        // 保存原始结果
        sharedContext["task_\(taskType.rawValue)_result"] = result
        sharedContext["task_\(taskId)_result"] = result
        
        // 尝试提取价格信息 (简单的正则提取，实际可优化为更复杂的解析)
        if taskType == .flight || taskType == .hotel {
            if let price = extractPrice(from: result) {
                sharedContext["extracted_\(taskType.rawValue)_cost"] = price
                print("💰 从 \(taskType.rawValue) 任务中提取到价格: ¥\(price)")
            }
        }
    }
    
    /// 简单的价格提取逻辑
    private func extractPrice(from text: String) -> Double? {
        // 匹配 "¥1234" 或 "1234元" 或 "价格：1234"
        let patterns = [
            "¥\\s*(\\d+(?:\\.\\d{1,2})?)",
            "(\\d+(?:\\.\\d{1,2})?)\\s*元",
            "价格[：:]\\s*(\\d+(?:\\.\\d{1,2})?)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text),
               let price = Double(text[range]) {
                return price
            }
        }
        return nil
    }
    
    /// 使用 SynthesisAgent 进行结果整合
    private func performSynthesis(request: String) async throws -> String {
        synthesisAgent.setSharedContext(sharedContext)
        return try await synthesisAgent.run(request: request)
    }
    
    /// 整合结果 (旧方法，保留兼容性但不再主要使用)
    private func synthesizeResults(_ results: [String]) -> String {
        if results.isEmpty {
            return "没有完成任何任务"
        }
        
        if results.count == 1 {
            return results.first!
        }
        
        return """
        ## 旅行规划结果
        
        \(results.enumerated().map { index, result in
            "### 步骤 \(index + 1)\n\(result)"
        }.joined(separator: "\n\n"))
        
        ## 总结
        已成功完成 \(results.count) 个任务的旅行规划。
        """
    }
    
    // MARK: - 辅助方法
    
    private func mapTaskTypeToCapability(_ taskType: TaskType) -> AgentCapability? {
        switch taskType {
        case .flight:
            return .flightSearch
        case .hotel:
            return .hotelBooking
        case .route:
            return .routePlanning
        case .budget:
            return .budgetPlanning
        case .general:
            return .textGeneration
        }
    }
    
    private func updateTaskInList(_ updatedTask: SimpleTask) {
        if let index = currentTasks.firstIndex(where: { $0.id == updatedTask.id }) {
            currentTasks[index] = updatedTask
        }
    }
    
    private func mergeContext(from agentContext: [String: Any]) {
        for (key, value) in agentContext {
            if !key.hasPrefix("last_") { // 只合并非临时数据
                sharedContext[key] = value
            }
        }
    }
}
