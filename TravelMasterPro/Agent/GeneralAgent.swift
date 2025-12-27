//
//  GeneralAgent.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import Foundation

/// 通用智能体 - 旅行大管家，整合所有专业能力
/// 作为用户的主要入口，智能分析需求并调度专业智能体
class GeneralAgent: ToolCallAgent {
    private let toolCollection: ToolCollection
    private let toolAnalyzer: ToolAnalyzer
    
    static func create(llm: LLMService) -> GeneralAgent {
        let systemPrompt = Prompts.generalAgentSystem + """
        
        ## 可用工具能力：
        \(ToolCollection.createTravelSuite().generateToolGuide())
        
        请根据用户需求智能选择和组合使用工具。
        """
        
        let toolCollection = ToolCollection.createTravelSuite()
        let capabilities = AgentCapability.allCases
        
        return GeneralAgent(
            name: "TravelMasterAgent",
            systemPrompt: systemPrompt,
            capabilities: capabilities,
            toolCollection: toolCollection,
            llm: llm
        )
    }
    
    init(name: String, systemPrompt: String, capabilities: [AgentCapability], 
         toolCollection: ToolCollection, llm: LLMService) {
        self.toolCollection = toolCollection
        self.toolAnalyzer = ToolAnalyzer()
        super.init(name: name, systemPrompt: systemPrompt, 
                   capabilities: capabilities, tools: toolCollection.getAllTools(), llm: llm)
    }
    
    // 重写工具执行以加入统计
    func executeTool(name: String, arguments: [String: Any]) async throws -> ToolResult {
        let startTime = Date()
        let result = try await toolCollection.execute(name: name, arguments: arguments)
        let duration = Date().timeIntervalSince(startTime)
        
        // 记录使用统计
        toolAnalyzer.recordUsage(
            toolName: name, 
            success: result.error == nil, 
            duration: duration
        )
        
        return result
    }
    
    /// 获取工具使用报告
    func getToolUsageReport() -> String {
        return toolAnalyzer.generateReport()
    }
    
    // MARK: - 高级整合方法
    
    /// 一站式旅行规划 - 最核心的功能
    func planCompleteTrip(
        destination: String,
        startDate: String,
        endDate: String,
        travelers: Int = 1,
        budget: Double? = nil,
        preferences: [String] = []
    ) async throws -> CompleteTravelPlan {
        
        let planningPrompt = """
        请为用户制定完整的旅行计划：
        
        🎯 基本信息：
        - 目的地：\(destination)
        - 出发日期：\(startDate)
        - 返回日期：\(endDate)  
        - 旅行人数：\(travelers)人
        - 预算：\(budget.map { "¥\($0)" } ?? "待定")
        - 偏好：\(preferences.isEmpty ? "无特殊要求" : preferences.joined(separator: "、"))
        
        请按以下步骤制定完整计划：
        
        1. 🎫 **航班规划**：使用 flight_search 搜索最优航班
        2. 🏨 **住宿安排**：使用 hotel_search 推荐合适酒店
        3. 🗺️ **路线设计**：使用 route_planner 规划游览路线
        4. 💰 **预算分析**：使用 budget_analyzer 分析费用结构
        5. 📋 **整合方案**：使用 travel_planner 生成完整计划
        
        请确保各部分协调一致，提供完整可行的旅行方案。
        """
        
        let result = try await run(request: planningPrompt)
        return try parseCompletePlan(result)
    }
    
    /// 智能需求分析 - 理解复杂需求
    func analyzeComplexRequest(_ userRequest: String) async throws -> TravelRequestAnalysis {
        let analysisPrompt = """
        请深度分析用户的旅行需求：
        
        用户原始需求：
        \(userRequest)
        
        请分析：
        1. 🎯 核心需求识别（必须满足的要求）
        2. 🔄 隐含需求挖掘（用户可能需要但未明确的）
        3. ⚖️ 优先级排序（时间、预算、体验等的重要性）
        4. 🚨 风险点识别（可能的问题和挑战）
        5. 🛠️ 工具选择策略（需要用到哪些专业工具）
        
        以JSON格式返回分析结果。
        """
        
        let result = try await run(request: analysisPrompt)
        return try parseTravelAnalysis(result)
    }
    
    /// 多方案对比 - 提供选择
    func compareMultipleOptions(
        baseRequest: String,
        variations: [String]
    ) async throws -> String {
        
        let comparisonPrompt = """
        请对比不同的旅行方案：
        
        基础需求：\(baseRequest)
        
        对比方案：
        \(variations.enumerated().map { "方案\($0.offset + 1)：\($0.element)" }.joined(separator: "\n"))
        
        请为每个方案：
        1. 使用相应工具获取详细信息
        2. 分析优缺点和适用场景
        3. 计算性价比评分
        4. 提供选择建议
        
        最后给出综合推荐和决策建议。
        """
        
        return try await run(request: comparisonPrompt)
    }
    
    /// 应急方案生成 - 风险控制
    func generateBackupPlans(
        originalPlan: String,
        riskScenarios: [String]
    ) async throws -> String {
        
        let backupPrompt = """
        请为原始旅行计划制定应急备选方案：
        
        原始计划：\(originalPlan)
        
        风险场景：
        \(riskScenarios.enumerated().map { "风险\($0.offset + 1)：\($0.element)" }.joined(separator: "\n"))
        
        为每种风险场景制定：
        1. 🚨 快速应对策略
        2. 🔄 替代方案选项
        3. 💰 额外成本评估
        4. ⏰ 调整时间要求
        5. 📞 应急联系信息
        
        确保备选方案实用可行。
        """
        
        return try await run(request: backupPrompt)
    }
    
    /// 个性化推荐 - 基于用户画像
    func generatePersonalizedRecommendations(
        userProfile: UserProfile,
        destination: String
    ) async throws -> String {
        
        let personalizedPrompt = """
        基于用户画像提供个性化旅行推荐：
        
        👤 用户画像：
        - 年龄群体：\(userProfile.ageGroup)
        - 旅行风格：\(userProfile.travelStyle)
        - 预算范围：\(userProfile.budgetRange)
        - 兴趣爱好：\(userProfile.interests.joined(separator: "、"))
        - 旅行经验：\(userProfile.experienceLevel)
        
        🎯 目的地：\(destination)
        
        请结合用户特点，使用相关工具提供：
        1. 🎯 量身定制的景点推荐
        2. 🏨 符合偏好的住宿选择
        3. 🍽️ 个性化餐饮建议
        4. 🎪 匹配兴趣的活动安排
        5. 📱 实用的旅行贴士
        """
        
        return try await run(request: personalizedPrompt)
    }
    
    /// 预算优化顾问 - 省钱专家
    func optimizeOverallBudget(
        totalBudget: Double,
        mustHaveItems: [String],
        flexibleItems: [String]
    ) async throws -> String {
        
        let budgetOptimizationPrompt = """
        请帮助用户优化整体旅行预算：
        
        💰 总预算：¥\(totalBudget)
        ✅ 必须项目：\(mustHaveItems.joined(separator: "、"))
        🔄 可调整项目：\(flexibleItems.joined(separator: "、"))
        
        请通过以下方式优化：
        1. 使用 budget_analyzer 分析预算结构
        2. 使用各专业工具搜索最优价格
        3. 提供替代方案和节省策略
        4. 计算不同方案的性价比
        5. 给出最终优化建议
        
        目标：在预算内最大化旅行价值。
        """
        
        return try await run(request: budgetOptimizationPrompt)
    }
    
    // MARK: - 私有辅助方法
    
    private func parseCompletePlan(_ response: String) throws -> CompleteTravelPlan {
        // 解析完整旅行计划的逻辑
        // 这里简化处理，实际应该有更复杂的解析逻辑
        return CompleteTravelPlan(
            flights: extractFlightInfo(response),
            hotels: extractHotelInfo(response),
            routes: extractRouteInfo(response),
            budget: extractBudgetInfo(response),
            summary: response
        )
    }
    
    private func parseTravelAnalysis(_ response: String) throws -> TravelRequestAnalysis {
        // 解析旅行需求分析的逻辑
        return TravelRequestAnalysis(
            coreRequirements: [],
            implicitNeeds: [],
            priorities: [:],
            riskFactors: [],
            recommendedTools: []
        )
    }
    
    private func extractFlightInfo(_ response: String) -> FlightPlanInfo? {
        // 从响应中提取航班信息
        return nil
    }
    
    private func extractHotelInfo(_ response: String) -> HotelPlanInfo? {
        // 从响应中提取酒店信息
        return nil
    }
    
    private func extractRouteInfo(_ response: String) -> RoutePlanInfo? {
        // 从响应中提取路线信息
        return nil
    }
    
    private func extractBudgetInfo(_ response: String) -> BudgetPlanInfo? {
        // 从响应中提取预算信息
        return nil
    }
    
    
    // MARK: - 新增工具
    
    /// 综合旅行计划工具
    class TravelPlannerTool: BaseTool {
        init() {
            super.init(
                name: "travel_planner",
                description: "综合制定完整旅行计划，整合航班、酒店、路线、预算等信息",
                parameters: [
                    "destination": .string("目的地"),
                    "start_date": .string("开始日期"),
                    "end_date": .string("结束日期"),
                    "travelers": .number("旅行人数"),
                    "budget": .number("总预算"),
                    "preferences": .string("旅行偏好，逗号分隔"),
                    "flight_info": .string("航班信息（JSON格式）"),
                    "hotel_info": .string("酒店信息（JSON格式）"),
                    "route_info": .string("路线信息（JSON格式）"),
                    "include_activities": .string("是否包含活动安排", enumValues: ["true", "false"])
                ],
                requiredParameters: ["destination", "start_date", "end_date"]
            )
        }
        
        override func executeImpl(arguments: [String: Any]) async throws -> ToolResult {
            let destination = try getRequiredString("destination", from: arguments)
            let startDate = try getRequiredString("start_date", from: arguments)
            let endDate = try getRequiredString("end_date", from: arguments)
            let travelers = Int(getNumber("travelers", from: arguments) ?? 1)
            let budget = getNumber("budget", from: arguments)
            let preferences = getString("preferences", from: arguments)?.components(separatedBy: ",") ?? []
            
            // 生成完整的旅行计划
            let plan = generateCompletePlan(
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                travelers: travelers,
                budget: budget,
                preferences: preferences
            )
            
            return successResult(plan)
        }
        
        private func generateCompletePlan(
            destination: String,
            startDate: String,
            endDate: String,
            travelers: Int,
            budget: Double?,
            preferences: [String]
        ) -> String {
            
            return """
        📋 【\(destination) 完整旅行计划】
        
        📅 行程时间：\(startDate) → \(endDate)
        👥 旅行人数：\(travelers)人
        💰 预算范围：\(budget.map { "¥\($0)" } ?? "待定")
        🎯 旅行偏好：\(preferences.joined(separator: "、"))
        
        🎫 交通安排：
        • 航班信息将通过航班搜索工具获取
        • 当地交通建议将通过路线规划工具提供
        
        🏨 住宿安排：
        • 酒店推荐将通过酒店搜索工具获取
        • 位置选择基于行程安排优化
        
        🗺️ 行程规划：
        • 详细路线将通过路线规划工具设计
        • 景点安排考虑时间和兴趣匹配
        
        💰 预算分析：
        • 费用明细将通过预算分析工具计算
        • 包含优化建议和节省策略
        
        📝 特别提醒：
        • 建议购买旅行保险
        • 关注目的地天气和政策变化
        • 预留应急联系方式
        """
        }
    }
    
    // MARK: - 数据模型
    
    /// 完整旅行计划
    struct CompleteTravelPlan {
        let flights: FlightPlanInfo?
        let hotels: HotelPlanInfo?
        let routes: RoutePlanInfo?
        let budget: BudgetPlanInfo?
        let summary: String
    }
    
    /// 旅行需求分析
    struct TravelRequestAnalysis {
        let coreRequirements: [String]
        let implicitNeeds: [String]
        let priorities: [String: Int]
        let riskFactors: [String]
        let recommendedTools: [String]
    }
    
    /// 用户画像
    struct UserProfile {
        let ageGroup: String
        let travelStyle: String
        let budgetRange: String
        let interests: [String]
        let experienceLevel: String
    }
    
    /// 各种计划信息
    struct FlightPlanInfo {
        let outbound: String
        let inbound: String?
        let totalCost: Double
    }
    
    struct HotelPlanInfo {
        let name: String
        let address: String
        let totalCost: Double
        let nights: Int
    }
    
    struct RoutePlanInfo {
        let dailyRoutes: [String]
        let totalDuration: Int
        let highlights: [String]
    }
    
    struct BudgetPlanInfo {
        let breakdown: [String: Double]
        let total: Double
        let optimizationTips: [String]
    }
    
}

// MARK: - 扩展方法

extension GeneralAgent {
    /// 快速旅行规划
    func quickPlan(to destination: String, from startDate: String, to endDate: String) async throws -> String {
        return try await planCompleteTrip(
            destination: destination,
            startDate: startDate,
            endDate: endDate
        ).summary
    }
    
    /// 紧急旅行安排
    func emergencyTravel(
        destination: String,
        departureDate: String,
        maxBudget: Double
    ) async throws -> String {
        let urgentPrompt = """
        用户需要紧急旅行安排：
        
        🚨 紧急情况：
        - 目的地：\(destination)
        - 出发日期：\(departureDate)
        - 最高预算：¥\(maxBudget)
        
        请提供：
        1. 最快可行的航班选择
        2. 就近可预订的住宿
        3. 简化的行程安排
        4. 应急联系信息
        5. 重要注意事项
        
        优先考虑可行性和时效性。
        """
        
        return try await run(request: urgentPrompt)
    }
    
    /// 长期旅行规划
    func longTermTravelPlanning(
        destinations: [String],
        timeframe: String,
        totalBudget: Double
    ) async throws -> String {
        let longTermPrompt = """
        制定长期旅行规划：
        
        🗺️ 目的地列表：\(destinations.joined(separator: "、"))
        📅 时间框架：\(timeframe)
        💰 总预算：¥\(totalBudget)
        
        请提供：
        1. 最优的旅行顺序和时间分配
        2. 各阶段的预算分配建议
        3. 签证和准备工作时间表
        4. 季节性考虑和最佳时机
        5. 风险评估和备选方案
        """
        
        return try await run(request: longTermPrompt)
    }
}
