//
//  BudgetAnalyzerTool.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import Foundation

/// 预算分析工具 - 提供旅行预算计算、分析和优化建议
class BudgetAnalyzerTool: BaseTool {
    
    init() {
        super.init(
            name: "budget_analyzer",
            description: "分析旅行预算，计算各项费用，提供预算优化建议和消费提醒",
            parameters: [
                "destination": ParameterDefinition(
                    type: "string",
                    description: "目的地城市或国家",
                    enumValues: nil
                ),
                "duration": ParameterDefinition(
                    type: "number",
                    description: "旅行天数",
                    enumValues: nil
                ),
                "travelers": ParameterDefinition(
                    type: "number",
                    description: "旅行人数",
                    enumValues: nil
                ),
                "budget_constraint": ParameterDefinition(
                    type: "number",
                    description: "预算上限（人民币）",
                    enumValues: nil
                ),
                "accommodation_type": ParameterDefinition.string(
                    "住宿类型",
                    enumValues: ["budget", "mid_range", "luxury", "hostel", "apartment"]
                ),
                "transportation_mode": ParameterDefinition.string(
                    "主要交通方式",
                    enumValues: ["flight", "train", "bus", "car", "mixed"]
                ),
                "meal_preference": ParameterDefinition.string(
                    "用餐偏好",
                    enumValues: ["budget", "mid_range", "fine_dining", "mixed"]
                ),
                "activity_level": ParameterDefinition.string(
                    "活动强度",
                    enumValues: ["low", "medium", "high"]
                ),
                "travel_season": ParameterDefinition.string(
                    "旅行季节",
                    enumValues: ["spring", "summer", "autumn", "winter", "peak", "off_peak"]
                ),
                "currency": ParameterDefinition.string(
                    "目的地货币代码",
                    enumValues: ["CNY", "USD", "EUR", "JPY", "GBP", "AUD", "THB", "SGD"]
                ),
                "include_shopping": ParameterDefinition.string(
                    "是否包含购物预算",
                    enumValues: ["true", "false"]
                )
            ],
            requiredParameters: ["destination", "duration", "travelers"]
        )
    }
    
    override func executeImpl(arguments: [String: Any]) async throws -> ToolResult {
        // 获取参数
        let destination = try getRequiredString("destination", from: arguments)
        let duration = Int(try getRequiredNumber("duration", from: arguments))
        let travelers = Int(try getRequiredNumber("travelers", from: arguments))
        let accommodationType = getString("accommodation_type", from: arguments) ?? "mid_range"
        let mealPreference = getString("meal_preference", from: arguments) ?? "mid_range"
        let activityLevel = getString("activity_level", from: arguments) ?? "medium"
        let transportationMode = getString("transportation_mode", from: arguments) ?? "mixed"
        let budgetConstraint = getNumber("budget_constraint", from: arguments)
        let currency = getString("currency", from: arguments) ?? "CNY"
        let includeShopping = getBoolean("include_shopping", from: arguments) ?? false
        let travelSeason = getString("travel_season", from: arguments) ?? "off_peak"
        
        do {
            // 创建预算分析器
            let analyzer = BudgetCalculator()
            
            // 计算各项预算
            let budgetBreakdown = try await analyzer.calculateBudget(
                destination: destination,
                duration: duration,
                travelers: travelers,
                accommodationType: accommodationType,
                mealPreference: mealPreference,
                activityLevel: activityLevel,
                transportationMode: transportationMode,
                currency: currency,
                includeShopping: includeShopping,
                travelSeason: travelSeason
            )
            
            // 分析预算合理性
            let analysis = analyzer.analyzeBudget(
                breakdown: budgetBreakdown,
                constraint: budgetConstraint
            )
            
            // 生成优化建议
            let recommendations = analyzer.generateRecommendations(
                breakdown: budgetBreakdown,
                constraint: budgetConstraint,
                destination: destination
            )
            
            // 格式化结果
            let formattedResult = formatBudgetAnalysis(
                breakdown: budgetBreakdown,
                analysis: analysis,
                recommendations: recommendations,
                destination: destination,
                duration: duration,
                travelers: travelers
            )
            
            return successResult(formattedResult, metadata: [
                "total_budget": budgetBreakdown.total,
                "budget_per_person": budgetBreakdown.total / Double(travelers),
                "budget_per_day": budgetBreakdown.total / Double(duration),
                "currency": currency,
                "within_constraint": budgetConstraint == nil || budgetBreakdown.total <= budgetConstraint!
            ])
            
        } catch {
            return errorResult("预算分析失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 辅助方法
    
    private func getRequiredNumber(_ key: String, from arguments: [String: Any]) throws -> Double {
        guard let value = getNumber(key, from: arguments) else {
            throw ToolError.missingRequiredParameter(key)
        }
        return value
    }
    
    private func formatBudgetAnalysis(
        breakdown: BudgetBreakdown,
        analysis: BudgetAnalysis,
        recommendations: [BudgetRecommendation],
        destination: String,
        duration: Int,
        travelers: Int
    ) -> String {
        var result = """
        💰 【\(destination) \(duration)天\(travelers)人旅行预算分析】
        
        📊 预算明细：
        ✈️ 交通费用：¥\(Int(breakdown.transportation))
        🏨 住宿费用：¥\(Int(breakdown.accommodation))
        🍽️ 餐饮费用：¥\(Int(breakdown.meals))
        🎯 活动娱乐：¥\(Int(breakdown.activities))
        💳 购物费用：¥\(Int(breakdown.shopping))
        🚨 应急费用：¥\(Int(breakdown.emergency))
        ─────────────────────
        💸 总计费用：¥\(Int(breakdown.total))
        
        👥 人均费用：¥\(Int(breakdown.total / Double(travelers)))
        📅 日均费用：¥\(Int(breakdown.total / Double(duration)))
        
        """
        
        // 添加预算分析
        result += """
        📈 预算分析：
        💡 预算等级：\(analysis.budgetLevel)
        ⚖️ 合理性评分：\(analysis.reasonabilityScore)/10分
        📋 \(analysis.summary)
        
        """
        
        // 添加建议
        if !recommendations.isEmpty {
            result += "💡 优化建议：\n"
            for (index, recommendation) in recommendations.enumerated() {
                result += "\(index + 1). \(recommendation.category): \(recommendation.suggestion)\n"
                if let savings = recommendation.potentialSavings {
                    result += "   💰 可节省：¥\(Int(savings))\n"
                }
            }
        }
        
        return result
    }
}

// MARK: - 预算计算器

class BudgetCalculator {
    
    func calculateBudget(
        destination: String,
        duration: Int,
        travelers: Int,
        accommodationType: String,
        mealPreference: String,
        activityLevel: String,
        transportationMode: String,
        currency: String,
        includeShopping: Bool,
        travelSeason: String
    ) async throws -> BudgetBreakdown {
        
        // 获取目的地成本系数
        let costMultiplier = getCostMultiplier(for: destination)
        let seasonMultiplier = getSeasonMultiplier(for: travelSeason)
        
        // 计算各项费用
        let transportation = calculateTransportation(
            destination: destination,
            travelers: travelers,
            mode: transportationMode,
            costMultiplier: costMultiplier
        )
        
        let accommodation = calculateAccommodation(
            type: accommodationType,
            duration: duration,
            travelers: travelers,
            costMultiplier: costMultiplier,
            seasonMultiplier: seasonMultiplier
        )
        
        let meals = calculateMeals(
            preference: mealPreference,
            duration: duration,
            travelers: travelers,
            costMultiplier: costMultiplier
        )
        
        let activities = calculateActivities(
            level: activityLevel,
            duration: duration,
            travelers: travelers,
            costMultiplier: costMultiplier
        )
        
        let shopping = includeShopping ? calculateShopping(
            duration: duration,
            travelers: travelers,
            costMultiplier: costMultiplier
        ) : 0
        
        let total = transportation + accommodation + meals + activities + shopping
        let emergency = total * 0.1 // 10% 应急费用
        
        return BudgetBreakdown(
            transportation: transportation,
            accommodation: accommodation,
            meals: meals,
            activities: activities,
            shopping: shopping,
            emergency: emergency,
            total: total + emergency
        )
    }
    
    func analyzeBudget(breakdown: BudgetBreakdown, constraint: Double?) -> BudgetAnalysis {
        let budgetLevel: String
        let reasonabilityScore: Int
        let summary: String
        
        // 判断预算等级
        let dailyBudget = breakdown.total / 7.0 // 假设7天行程
        
        switch dailyBudget {
        case 0..<300:
            budgetLevel = "经济型"
            reasonabilityScore = 7
        case 300..<600:
            budgetLevel = "舒适型"
            reasonabilityScore = 8
        case 600..<1200:
            budgetLevel = "豪华型"
            reasonabilityScore = 9
        default:
            budgetLevel = "奢华型"
            reasonabilityScore = 8
        }
        
        // 生成分析总结
        if let constraint = constraint {
            if breakdown.total <= constraint {
                summary = "预算在合理范围内，符合您的预算约束。"
            } else {
                let excess = breakdown.total - constraint
                summary = "预算超出约束¥\(Int(excess))，建议优化部分支出项目。"
            }
        } else {
            summary = "预算结构合理，各项支出比例适中。"
        }
        
        return BudgetAnalysis(
            budgetLevel: budgetLevel,
            reasonabilityScore: reasonabilityScore,
            summary: summary
        )
    }
    
    func generateRecommendations(
        breakdown: BudgetBreakdown,
        constraint: Double?,
        destination: String
    ) -> [BudgetRecommendation] {
        var recommendations: [BudgetRecommendation] = []
        
        // 住宿优化建议
        if breakdown.accommodation > breakdown.total * 0.4 {
            recommendations.append(BudgetRecommendation(
                category: "住宿",
                suggestion: "住宿费用占比较高，建议考虑民宿或青旅，可节省30-50%费用",
                potentialSavings: breakdown.accommodation * 0.3
            ))
        }
        
        // 餐饮优化建议
        if breakdown.meals > breakdown.total * 0.3 {
            recommendations.append(BudgetRecommendation(
                category: "餐饮",
                suggestion: "餐饮预算较高，建议尝试当地小吃和自助餐厅",
                potentialSavings: breakdown.meals * 0.2
            ))
        }
        
        // 购物建议
        if breakdown.shopping > breakdown.total * 0.2 {
            recommendations.append(BudgetRecommendation(
                category: "购物",
                suggestion: "购物预算充足，建议关注当地特色产品和免税商品",
                potentialSavings: nil
            ))
        }
        
        // 预算紧张时的建议
        if let constraint = constraint, breakdown.total > constraint {
            recommendations.append(BudgetRecommendation(
                category: "整体优化",
                suggestion: "预算超支，建议选择淡季出行，预订早鸟优惠",
                potentialSavings: breakdown.total * 0.15
            ))
        }
        
        return recommendations
    }
    
    // MARK: - 私有计算方法
    
    private func getCostMultiplier(for destination: String) -> Double {
        let destination = destination.lowercased()
        
        switch true {
        case destination.contains("日本") || destination.contains("japan"):
            return 1.3
        case destination.contains("韩国") || destination.contains("korea"):
            return 0.9
        case destination.contains("泰国") || destination.contains("thailand"):
            return 0.6
        case destination.contains("新加坡") || destination.contains("singapore"):
            return 1.2
        case destination.contains("美国") || destination.contains("usa"):
            return 1.4
        case destination.contains("欧洲") || destination.contains("europe"):
            return 1.3
        default:
            return 1.0
        }
    }
    
    private func getSeasonMultiplier(for season: String) -> Double {
        switch season {
        case "peak":
            return 1.5
        case "off_peak":
            return 0.8
        default:
            return 1.0
        }
    }
    
    private func calculateTransportation(destination: String, travelers: Int, mode: String, costMultiplier: Double) -> Double {
        let baseCost: Double
        
        switch mode {
        case "flight":
            baseCost = 2000
        case "train":
            baseCost = 800
        case "bus":
            baseCost = 400
        case "car":
            baseCost = 600
        default:
            baseCost = 1500
        }
        
        return baseCost * Double(travelers) * costMultiplier
    }
    
    private func calculateAccommodation(type: String, duration: Int, travelers: Int, costMultiplier: Double, seasonMultiplier: Double) -> Double {
        let baseNightlyRate: Double
        
        switch type {
        case "budget", "hostel":
            baseNightlyRate = 150
        case "mid_range":
            baseNightlyRate = 400
        case "luxury":
            baseNightlyRate = 800
        case "apartment":
            baseNightlyRate = 300
        default:
            baseNightlyRate = 400
        }
        
        let roomsNeeded = ceil(Double(travelers) / 2.0) // 假设每间房住2人
        return baseNightlyRate * Double(duration) * roomsNeeded * costMultiplier * seasonMultiplier
    }
    
    private func calculateMeals(preference: String, duration: Int, travelers: Int, costMultiplier: Double) -> Double {
        let dailyMealCost: Double
        
        switch preference {
        case "budget":
            dailyMealCost = 80
        case "mid_range":
            dailyMealCost = 150
        case "fine_dining":
            dailyMealCost = 300
        case "mixed":
            dailyMealCost = 200
        default:
            dailyMealCost = 150
        }
        
        return dailyMealCost * Double(duration) * Double(travelers) * costMultiplier
    }
    
    private func calculateActivities(level: String, duration: Int, travelers: Int, costMultiplier: Double) -> Double {
        let dailyActivityCost: Double
        
        switch level {
        case "low":
            dailyActivityCost = 100
        case "medium":
            dailyActivityCost = 200
        case "high":
            dailyActivityCost = 400
        default:
            dailyActivityCost = 200
        }
        
        return dailyActivityCost * Double(duration) * Double(travelers) * costMultiplier
    }
    
    private func calculateShopping(duration: Int, travelers: Int, costMultiplier: Double) -> Double {
        let baseShoppingBudget = 500.0 // 人均购物预算
        return baseShoppingBudget * Double(travelers) * costMultiplier
    }
}

// MARK: - 数据模型

/// 预算明细
struct BudgetBreakdown {
    let transportation: Double
    let accommodation: Double
    let meals: Double
    let activities: Double
    let shopping: Double
    let emergency: Double
    let total: Double
}

/// 预算分析结果
struct BudgetAnalysis {
    let budgetLevel: String
    let reasonabilityScore: Int
    let summary: String
}

/// 预算建议
struct BudgetRecommendation {
    let category: String
    let suggestion: String
    let potentialSavings: Double?
}
