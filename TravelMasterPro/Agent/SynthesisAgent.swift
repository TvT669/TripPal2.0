//
//  SynthesisAgent.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/30.
//

import Foundation

/// 综合智能体 - 双模输出架构
/// 同时生成"聊天式回复"与"结构化数据"
/// 解决用户体验问题：既要自然语言对话，又要结构化卡片渲染
class SynthesisAgent: Agent {
    let name: String = "SynthesisAgent"
    let systemPrompt: String
    let capabilities: [AgentCapability] = [.textGeneration, .dataAnalysis]
    
    private let llm: LLMService
    private var sharedContext: [String: Any] = [:]
    
    init(llm: LLMService) {
        self.llm = llm
        self.systemPrompt = """
        你是 TravelMasterPro 的首席旅行顾问。你需要扮演两个角色：
        
        ## 角色 1：热情的旅行助手（Conversational Mode）
        - 用自然、温暖的语气与用户对话
        - 用 2-3 句话总结方案的核心亮点或关键问题
        - 可以使用简单的 emoji 增强表达（如 ✈️🏨💰）
        - 避免枯燥的流水账，重点突出"决策建议"
        
        ## 角色 2：精确的数据工程师（Structured Mode）
        - 提取所有必要的数字、日期、地点，转化为标准 JSON
        - 确保数据完整性：预算、行程、风险提示一个都不能少
        - 如果某些数据缺失（如没找到酒店），在 JSON 中标注为 null
        
        ## 输出格式要求
        你必须输出一个严格的 JSON 对象，包含以下字段：
        
        {
          "message": "嘿！我帮你看了一下，这趟长沙之旅预算有点紧张哦 💰 建议考虑提前抢火车票，可以省不少钱！",
          
          "plan_data": {
            "budget_status": {
              "total_budget": 3000,
              "estimated_cost": 3675,
              "is_over_budget": true,
              "verdict": "略有超支",
              "breakdown": [
                {"category": "交通", "amount": 800},
                {"category": "住宿", "amount": 1200},
                {"category": "餐饮", "amount": 900},
                {"category": "门票", "amount": 775}
              ]
            },
            "itinerary": [
              {
                "day": 1,
                "date": "2025-01-15",
                "title": "初探长沙",
                "activities": [
                  {
                    "id": "act-001",
                    "time": "14:00",
                    "description": "入住五一广场附近酒店",
                    "location": "长沙市芙蓉区",
                    "cost": 400
                  },
                  {
                    "id": "act-002",
                    "time": "18:00",
                    "description": "太平街品尝臭豆腐",
                    "location": "太平街",
                    "cost": 50
                  }
                ],
                "cost_estimate": 450
              }
            ],
            "risk_warnings": [
              "长沙火车票需提前15天抢购",
              "岳麓山周末人流量大，建议早上8点前到达"
            ],
            "highlights": [
              "茶颜悦色总店打卡",
              "橘子洲头看烟花（周六晚上20:30）"
            ],
            "alternatives": [
              {
                "id": "alt-001",
                "type": "hotel",
                "description": "如果预算允许，推荐升级到IFS国金中心附近的四星酒店",
                "cost_difference": 300
              }
            ]
          },
          
          "thoughts": "用户预算3000元，但根据FlightAgent和HotelAgent的搜索结果，最低成本约3675元。主要超支项是住宿（五一广场附近酒店均价400/晚）。建议1: 改住青年旅舍可节省600元；建议2: 提前2个月订票可节省约200元..."
        }
        
        ## 关键规则
        1. "message" 字段：必须是完整的自然语言句子，不要出现 JSON 片段
        2. "plan_data" 字段：如果任何子任务失败（如没找到酒店），将对应字段设为 null，但在 "message" 中向用户说明
        3. "thoughts" 字段：仅供开发者调试，前端不展示
        4. 整个输出必须是合法的 JSON，不要有 ```json 标记
        5. activities 数组中的每个活动必须有唯一的 id
        6. alternatives 数组中的每个备选方案必须有唯一的 id
        """
    }
    
    // MARK: - 核心方法
    
    func run(request: String) async throws -> String {
        let contextSummary = buildContextSummary()
        
        let fullPrompt = """
        \(systemPrompt)
        
        ## 上下文数据
        \(contextSummary)
        
        ## 用户需求
        \(request)
        
        现在请生成混合响应（必须是合法的 JSON 对象）。
        """
        
        let rawResponse = try await llm.chat(messages: [Message.userMessage(fullPrompt)])
        
        // ✅ 清理可能的 Markdown 包裹
        let cleanedJSON = cleanMarkdownWrapper(rawResponse)
        
        // ✅ 验证是否为合法 JSON（如果验证失败，启用降级处理）
        if let data = cleanedJSON.data(using: .utf8),
           let _ = try? JSONDecoder().decode(HybridResponse.self, from: data) {
            return cleanedJSON
        } else {
            // 降级处理：如果 LLM 返回的不是标准 JSON，包装成兜底格式
            print("⚠️ SynthesisAgent 返回了非标准 JSON，启用降级模式")
            let fallbackResponse = HybridResponse(
                conversationalText: rawResponse,
                structuredPlan: nil,
                internalThoughts: "LLM未按要求返回JSON"
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            return String(data: try encoder.encode(fallbackResponse), encoding: .utf8) ?? "{}"
        }
    }
    
    // MARK: - Agent 协议实现
    
    func setSharedContext(_ context: [String: Any]) {
        self.sharedContext = context
    }
    
    func getSharedContext() -> [String: Any] {
        return sharedContext
    }
    
    func isCapableOf(_ capability: AgentCapability) -> Bool {
        return capabilities.contains(capability)
    }
    
    // MARK: - 辅助方法
    
    private func buildContextSummary() -> String {
        var summary = "### 📋 各智能体执行结果汇总\n\n"
        
        // 航班数据
        if let flightResult = sharedContext["task_flight_result"] as? String {
            summary += "**✈️ 航班搜索 (FlightAgent)**\n\(flightResult)\n\n"
        } else {
            summary += "**✈️ 航班搜索**\n未找到航班数据\n\n"
        }
        
        // 酒店数据
        if let hotelResult = sharedContext["task_hotel_result"] as? String {
            summary += "**🏨 酒店搜索 (HotelAgent)**\n\(hotelResult)\n\n"
        } else {
            summary += "**🏨 酒店搜索**\n未找到酒店数据\n\n"
        }
        
        // 预算分析
        if let budgetResult = sharedContext["task_budget_result"] as? String {
            summary += "**💰 预算分析 (BudgetAgent)**\n\(budgetResult)\n\n"
        }
        
        // 路线规划
        if let routeResult = sharedContext["task_route_result"] as? String {
            summary += "**🗺️ 路线规划 (RouteAgent)**\n\(routeResult)\n\n"
        }
        
        // 提取的关键数字
        if let totalCost = sharedContext["extracted_total_cost"] as? Double {
            summary += "**� 预估总花费**: ¥\(totalCost)\n"
        }
        
        if let userBudget = sharedContext["user_budget"] as? Double {
            summary += "**💵 用户预算**: ¥\(userBudget)\n"
        }
        
        return summary
    }
    
    /// 清理 LLM 可能返回的 Markdown 代码块包裹
    private func cleanMarkdownWrapper(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除 ```json ... ``` 包裹
        if cleaned.hasPrefix("```json") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
        }
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
