//
//  TravelMasterProApp.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import SwiftUI
import SwiftData

@main
struct TravelMasterProApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var tripStore = TripStore()
       
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .environmentObject(tripStore)
        }
    }
}

// MARK: - 应用状态管理

/// 应用全局状态管理器
/// 负责协调智能体、工作流和UI状态
class AppState: ObservableObject {
    // MARK: - UI 状态
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var response = "" // ✅ ContentView 需要的响应属性
    @Published var errorMessage: String? = nil
    @Published var statusMessage: String = "AI思考中..." // ✅ 实时状态消息
    
    // MARK: - 服务层
    private let llmService: LLMService
    private let memoryService: MemoryService
    private let toolCollection: ToolCollection
    // MARK: - 智能体
    private let generalAgent: GeneralAgent
    private let flightAgent: FlightAgent
    private let hotelAgent: HotelAgent
    private let routeAgent: RouteAgent // ✅ 修正名称
    private let budgetAgent: BudgetAgent
    
    // MARK: - 工作流
    private var planningFlow: PlanningFlow?
    private var intentRouter: IntentRouter? // ✅ 新增意图路由器
    
    // MARK: - 初始化
    
    init() {
        // 从安全存储加载API密钥
        let apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        
        // 初始化服务
        self.llmService = LLMService()
        self.memoryService = MemoryService()
        self.toolCollection = ToolCollection.createTravelSuite()
        
        // 初始化智能体
        self.generalAgent = GeneralAgent.create(llm: llmService)
        self.flightAgent = FlightAgent.create(llm: llmService)
        self.hotelAgent = HotelAgent.create(llm: llmService)
        self.routeAgent = RouteAgent.create(llm: llmService)
        self.budgetAgent = BudgetAgent.create(llm: llmService)
        
        // 创建工作流
        self.planningFlow = PlanningFlow(
            primaryAgent: generalAgent,
            agents: [
                "general": generalAgent,
                "flight": flightAgent,
                "hotel": hotelAgent,
                "route": routeAgent,
                "budget": budgetAgent
            ]
        )
        
        // ✅ 初始化意图路由器
        self.intentRouter = IntentRouter(llm: llmService)
        
        // ✅ 直接在这里配置记忆服务，而不是调用方法
        // 配置记忆服务参数
        // memoryService.configure(maxMessages: 100)
        // memoryService.enableContextTracking(true)
    }
    
    // MARK: - 公共方法
    
    /// 执行用户请求（智能路由版）
    /// - Parameter request: 用户输入的请求文本
    @MainActor
    func executeRequest(_ request: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. 构建并保存用户消息
            let userMessage = Message.userMessage(request)
            memoryService.addMessage(userMessage)
            
            // 2. 获取历史消息上下文
            var contextMessages = memoryService.messages
            
            // 注入系统提示词
            if !contextMessages.contains(where: { $0.role == .system }) {
                let systemMessage = Message.systemMessage(Prompts.generalAgentSystem)
                contextMessages.insert(systemMessage, at: 0)
            }
            
            // ✅ 3. 意图识别（核心改进）
            guard let router = intentRouter else {
                // 降级：如果路由器未初始化，默认走多智能体流程
                try await executeComplexPlanning(request: request, history: contextMessages)
                return
            }
            
            statusMessage = "正在理解您的需求..."
            let intent = await router.classifyIntent(request)
            print("🎯 意图识别结果: \(intent.description)")
            
            // ✅ 4. 根据意图路由到不同的执行路径
            switch intent {
            case .complexPlanning:
                // 路径A: 复杂规划 -> 多智能体协作 -> HybridResponse
                try await executeComplexPlanning(request: request, history: contextMessages)
                
            case .singleQuery:
                // 路径B: 单一查询 -> 单智能体工具调用 -> 纯文本
                try await executeSingleQuery(request: request, history: contextMessages)
                
            case .casualChat:
                // 路径C: 闲聊 -> 直接 LLM 回复 -> 纯文本
                try await executeCasualChat(request: request, history: contextMessages)
            }
            
            isLoading = false
            
        } catch is CancellationError {
            isLoading = false
            print("⚠️ 请求已取消")
        } catch {
            isLoading = false
            errorMessage = "执行请求失败: \(error.localizedDescription)"
            print("🔍 详细错误: \(error)")
        }
    }
    
    // MARK: - 执行路径实现
    
    /// 路径A: 复杂旅行规划（多智能体协作）
    private func executeComplexPlanning(request: String, history: [Message]) async throws {
        guard let flow = planningFlow else {
            throw NSError(domain: "AppState", code: -1, userInfo: [NSLocalizedDescriptionKey: "PlanningFlow 未初始化"])
        }
        
        print("🚀 路径A: 启动多智能体规划流程")
        statusMessage = "正在召集智能体团队..."
        
        let result = try await flow.execute(request: request, history: history) { progressMsg in
            Task { @MainActor in
                self.statusMessage = progressMsg
            }
        }
        
        let assistantMessage = Message(role: .assistant, content: result.output)
        memoryService.addMessage(assistantMessage)
        response = result.output
    }
    
    /// 路径B: 单一查询（单智能体 + 工具）
    private func executeSingleQuery(request: String, history: [Message]) async throws {
        print("🔍 路径B: 单一查询模式")
        statusMessage = "正在查询..."
        
        // 根据关键词选择合适的智能体
        let selectedAgent: Agent
        
        if request.lowercased().contains("机票") || request.lowercased().contains("航班") {
            selectedAgent = flightAgent
        } else if request.lowercased().contains("酒店") || request.lowercased().contains("住宿") {
            selectedAgent = hotelAgent
        } else if request.lowercased().contains("路线") || request.lowercased().contains("怎么走") {
            selectedAgent = routeAgent
        } else if request.lowercased().contains("预算") || request.lowercased().contains("多少钱") {
            selectedAgent = budgetAgent
        } else {
            selectedAgent = generalAgent
        }
        
        // ✅ 修复：为 Agent 提供历史上下文
        // 注意：当前 Agent.run() 接口只接受 String，需要扩展或通过 SharedContext 传递
        // 临时方案：将最近的对话历史摘要附加到请求中
        var enrichedRequest = request
        if history.count > 2 {
            let recentHistory = history.suffix(4).map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")
            enrichedRequest = """
            [历史上下文]
            \(recentHistory)
            
            [当前请求]
            \(request)
            """
        }
        
        let result = try await selectedAgent.run(request: enrichedRequest)
        
        let assistantMessage = Message(role: .assistant, content: result)
        memoryService.addMessage(assistantMessage)
        response = result
    }
    
    /// 路径C: 闲聊（直接 LLM）
    private func executeCasualChat(request: String, history: [Message]) async throws {
        print("💬 路径C: 闲聊模式")
        statusMessage = "AI思考中..."
        
        let result = try await llmService.chat(messages: history + [Message.userMessage(request)])
        
        let assistantMessage = Message(role: .assistant, content: result)
        memoryService.addMessage(assistantMessage)
        response = result
    }
    
    /// 取消当前请求
    @MainActor
    func cancelRequest() {
        isLoading = false
    }
    
    /// 清空对话历史
    func clearConversation() {
        response = ""
        memoryService.clear()
        errorMessage = nil
    }
    
    /// 获取对话上下文
    func getConversationContext() -> String {
        return memoryService.getContext()
    }
    
    /// ✅ 修复 4: 重新连接服务 - 简化实现
    func reconnectServices() async {
        isLoading = true
        
        do {
            // 测试连接 - 使用现有的 completion 方法
            let testMessage = Message(role: .user, content: "测试连接")
            _ = try await llmService.completion(messages: [testMessage])
            
            isLoading = false
            errorMessage = nil
            
        } catch {
            isLoading = false
            errorMessage = "重新连接失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 配置方法
    
    /// 更新API密钥
    func updateApiKey(_ newApiKey: String) {
        UserDefaults.standard.set(newApiKey, forKey: "openai_api_key")
        
        // ✅ 修复 5: 直接更新API密钥
        llmService.updateApiKey(newApiKey)
        
        // 重新连接服务
        Task {
            await reconnectServices()
        }
    }
    
    /// 获取系统状态摘要
    func getSystemStatus() -> SystemStatus {
        return SystemStatus(
            isConnected: !isLoading && errorMessage == nil,
            memoryUsage: memoryService.getEnhancedMessages().count,
            lastError: errorMessage,
            agentCount: 5 // 当前智能体数量
        )
    }
    
    // MARK: - 私有方法
    
    private func setupMemoryService() {
        // 配置记忆服务参数
        // 这里可以根据需要调整记忆配置
    }
}

// MARK: - 辅助数据结构

/// 系统状态信息
struct SystemStatus {
    let isConnected: Bool
    let memoryUsage: Int
    let lastError: String?
    let agentCount: Int
    
    var statusDescription: String {
        if isConnected {
            return "🟢 系统正常运行"
        } else if let error = lastError {
            return "🔴 系统异常: \(error)"
        } else {
            return "🟡 系统连接中..."
        }
    }
}
