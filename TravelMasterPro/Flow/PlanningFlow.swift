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
    
    // 状态管理
    @Published private(set) var status: FlowStatus = .idle
    private var currentTasks: [SimpleTask] = []
    private var sharedContext: [String: Any] = [:]
    
    init(primaryAgent: Agent, agents: [String: Agent]) {
        self.primaryAgent = primaryAgent
        self.agents = agents
    }
    
    // MARK: - Flow 协议实现
    
    func execute(request: String) async throws -> FlowResult {
        let startTime = Date()
        status = .planning
        
        do {
            // 1. 智能任务分解
            let tasks = try await decomposeTasks(request)
            currentTasks = tasks
            
            status = .executing
            
            // 2. 执行任务
            let results = try await executeTasks(tasks)
            
            // 3. 整合结果
            let finalOutput = synthesizeResults(results)
            
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
    private func decomposeTasks(_ request: String) async throws -> [SimpleTask] {
        let decompositionPrompt = """
        作为旅行规划专家，请将以下用户请求分解为具体的执行任务：
        
        用户请求：\(request)
        
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
                
                return SimpleTask(
                    id: "task_\(index + 1)",
                    type: TaskType(rawValue: agentType) ?? .general,
                    description: description,
                    assignedAgent: agentType,
                    status: .pending,
                    result: nil
                )
            }
            
            return nil
        }
    }
    
    /// 执行任务列表
    private func executeTasks(_ tasks: [SimpleTask]) async throws -> [String] {
        var results: [String] = []
        
        for var task in tasks {
            // 获取负责的智能体
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
            task.status = .running
            updateTaskInList(&task)
            
            do {
                let result = try await agent.run(request: task.description)
                
                task.status = .completed
                task.result = result
                updateTaskInList(&task)
                
                results.append(result)
                
                // 更新共享上下文
                mergeContext(from: agent.getSharedContext())
                sharedContext["task_\(task.id)_result"] = result
                
            } catch {
                task.status = .failed
                updateTaskInList(&task)
                throw FlowError.executionTimeout
            }
        }
        
        return results
    }
    
    /// 整合结果
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
    
    private func updateTaskInList(_ updatedTask: inout SimpleTask) {
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
