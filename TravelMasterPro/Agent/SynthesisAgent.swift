//
//  SynthesisAgent.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/30.
//

import Foundation

/// 综合智能体 - 负责信息整合与方案生成
/// 解决 "Missing Synthesis Layer" 问题
/// 将各专业智能体的原始数据转化为用户友好的自然语言方案
class SynthesisAgent: Agent {
    let name: String = "SynthesisAgent"
    let systemPrompt: String
    let capabilities: [AgentCapability] = [.textGeneration, .dataAnalysis]
    
    private let llm: LLMService
    private var sharedContext: [String: Any] = [:]
    
    init(llm: LLMService) {
        self.llm = llm
        self.systemPrompt = """
        你是 TravelMasterPro 的首席旅行方案整合专家。
        你的职责是将来自不同专业智能体（航班、酒店、预算等）的原始数据和片段信息，
        整合成一份结构化的 JSON 数据，供前端应用渲染。
        
        ## 工作原则：
        1. **数据驱动**：不要输出 Markdown 文本，必须输出符合 Schema 的 JSON。
        2. **逻辑自洽**：检查航班时间、酒店入住时间与行程安排是否冲突。
        3. **预算闭环**：明确指出实际搜索到的价格对总预算的影响（是超支还是结余）。
        4. **用户视角**：重点突出对用户决策有帮助的关键信息。
        
        ## 输出格式 (Strict JSON Mode)：
        你必须且只能输出一个有效的 JSON 对象，不要包含任何 Markdown 标记（如 ```json）。
        JSON 结构如下：
        {
          "summary_text": "一段简短、温暖的对话式总结（最多2句话），直接告诉用户方案的核心亮点或问题。",
          "budget_status": {
            "total_budget": 3000, // 用户设定的总预算
            "estimated_cost": 3675, // 实际预估总花费
            "is_over_budget": true, // 是否超支
            "verdict": "预算紧张" // 简短评价，如"预算充足"、"严重超支"、"勉强够用"
          },
          "itinerary": [
            {
              "day": 1,
              "title": "抵达与安顿", // 当天的主题
              "activities": ["入住前门酒店", "步行至天安门广场", "前门大街晚餐"], // 活动列表
              "cost_estimate": 200 // 当天预估花费
            }
          ],
          "risk_warnings": ["往返火车票需提前15天抢票", "环球影城门票价格波动大"] // 风险提示列表
        }
        """
    }
    
    func run(request: String) async throws -> String {
        // 构建包含上下文的完整请求
        let contextSummary = buildContextSummary()
        
        let fullPrompt = """
        \(systemPrompt)
        
        ## 当前任务上下文：
        \(contextSummary)
        
        ## 用户原始请求：
        \(request)
        
        请根据以上信息，生成最终的旅行方案 JSON 数据。
        """
        
        let response = try await llm.chat(messages: [Message.userMessage(fullPrompt)])
        return response
    }
    
    func setSharedContext(_ context: [String: Any]) {
        self.sharedContext = context
    }
    
    func getSharedContext() -> [String: Any] {
        return sharedContext
    }
    
    private func buildContextSummary() -> String {
        var summary = ""
        
        if let flightResult = sharedContext["task_flight_result"] as? String {
            summary += "\n### ✈️ 航班搜索结果：\n\(flightResult)\n"
        }
        
        if let hotelResult = sharedContext["task_hotel_result"] as? String {
            summary += "\n### 🏨 酒店搜索结果：\n\(hotelResult)\n"
        }
        
        if let budgetResult = sharedContext["task_budget_result"] as? String {
            summary += "\n### 💰 预算分析结果：\n\(budgetResult)\n"
        }
        
        if let routeResult = sharedContext["task_route_result"] as? String {
            summary += "\n### 🗺️ 路线规划结果：\n\(routeResult)\n"
        }
        
        // 添加提取出的结构化数据（如果有）
        if let totalCost = sharedContext["extracted_total_cost"] as? Double {
            summary += "\n### 📊 预估总花费：¥\(totalCost)\n"
        }
        
        return summary
    }
}
