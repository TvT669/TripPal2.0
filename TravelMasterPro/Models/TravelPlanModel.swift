//
//  TravelPlanModel.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/31.
//

import Foundation

// MARK: - 核心数据模型

/// 旅行计划数据模型 (对应 JSON 输出)
struct TravelPlanModel: Codable, Equatable {
    let summaryText: String
    let budgetStatus: BudgetStatus
    let itinerary: [DailyItinerary]
    let riskWarnings: [String]
    
    enum CodingKeys: String, CodingKey {
        case summaryText = "summary_text"
        case budgetStatus = "budget_status"
        case itinerary
        case riskWarnings = "risk_warnings"
    }
}

/// 预算状态
struct BudgetStatus: Codable, Equatable {
    let totalBudget: Double
    let estimatedCost: Double
    let isOverBudget: Bool
    let verdict: String
    
    enum CodingKeys: String, CodingKey {
        case totalBudget = "total_budget"
        case estimatedCost = "estimated_cost"
        case isOverBudget = "is_over_budget"
        case verdict
    }
}

/// 每日行程
struct DailyItinerary: Codable, Equatable, Identifiable {
    var id: Int { day }
    let day: Int
    let title: String
    let activities: [String]
    let costEstimate: Double
    
    enum CodingKeys: String, CodingKey {
        case day
        case title
        case activities
        case costEstimate = "cost_estimate"
    }
}
