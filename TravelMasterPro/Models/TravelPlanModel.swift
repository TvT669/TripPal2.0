//
//  TravelPlanModel.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/31.
//

import Foundation

// MARK: - 混合响应模型

/// 混合响应模型 - 同时包含自然语言与结构化数据
struct HybridResponse: Codable {
    /// 面向用户的自然语言回复（用于聊天气泡）
    let conversationalText: String
    
    /// 面向 UI 的结构化数据（用于卡片渲染，可选）
    let structuredPlan: TravelPlanModel?
    
    /// 内部思考链（调试用，前端不显示）
    let internalThoughts: String?
    
    enum CodingKeys: String, CodingKey {
        case conversationalText = "message"
        case structuredPlan = "plan_data"
        case internalThoughts = "thoughts"
    }
}

// MARK: - 旅行计划数据模型

/// 旅行计划数据模型（扩展版）
struct TravelPlanModel: Codable, Equatable {
    /// 预算状态
    let budgetStatus: BudgetStatus
    
    /// 每日行程
    let itinerary: [DailyItinerary]
    
    /// 风险提示
    let riskWarnings: [String]
    
    /// 精选推荐（可选）
    let highlights: [String]?
    
    /// 备选方案（可选）
    let alternatives: [Alternative]?
    
    enum CodingKeys: String, CodingKey {
        case budgetStatus = "budget_status"
        case itinerary
        case riskWarnings = "risk_warnings"
        case highlights
        case alternatives
    }
}

/// 预算状态
struct BudgetStatus: Codable, Equatable {
    let totalBudget: Double
    let estimatedCost: Double
    let isOverBudget: Bool
    let verdict: String
    let breakdown: [CostItem]? // 花费细目
    
    enum CodingKeys: String, CodingKey {
        case totalBudget = "total_budget"
        case estimatedCost = "estimated_cost"
        case isOverBudget = "is_over_budget"
        case verdict
        case breakdown
    }
}

/// 花费细目
struct CostItem: Codable, Equatable {
    let category: String // "交通" | "住宿" | "餐饮" | "门票"
    let amount: Double
}

/// 每日行程
struct DailyItinerary: Codable, Equatable, Identifiable {
    let day: Int
    let date: String? // "2025-01-15"
    let title: String
    let activities: [Activity]
    let costEstimate: Double
    
    // Identifiable 协议要求
    var id: Int { day }
    
    enum CodingKeys: String, CodingKey {
        case day
        case date
        case title
        case activities
        case costEstimate = "cost_estimate"
    }
}

/// 活动详情
struct Activity: Codable, Equatable, Identifiable {
    let id: String
    let time: String? // "09:00"
    let description: String
    let location: String?
    let cost: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case time
        case description
        case location
        case cost
    }
    
    init(id: String = UUID().uuidString, time: String? = nil, description: String, location: String? = nil, cost: Double? = nil) {
        self.id = id
        self.time = time
        self.description = description
        self.location = location
        self.cost = cost
    }
    
    // 自定义解码器（支持 id 默认值）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.time = try container.decodeIfPresent(String.self, forKey: .time)
        self.description = try container.decode(String.self, forKey: .description)
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.cost = try container.decodeIfPresent(Double.self, forKey: .cost)
    }
}

/// 备选方案
struct Alternative: Codable, Equatable, Identifiable {
    let id: String
    let type: String // "flight" | "hotel" | "route"
    let description: String
    let costDifference: Double // 与主方案的价格差
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case description
        case costDifference = "cost_difference"
    }
    
    init(id: String = UUID().uuidString, type: String, description: String, costDifference: Double) {
        self.id = id
        self.type = type
        self.description = description
        self.costDifference = costDifference
    }
}
