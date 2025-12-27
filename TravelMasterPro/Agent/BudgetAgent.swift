//
//  BudgetAgent.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/31.
//

import Foundation

/// 预算智能体 - 专业的旅行预算规划和管理专家
/// 继承 ToolCallAgent 的动力系统，集成预算分析专业工具和能力
class BudgetAgent: ToolCallAgent {
    
    /// 创建预算智能体实例
    static func create(llm: LLMService) -> BudgetAgent {
        let systemPrompt = """
        你是专业的旅行预算规划和管理专家，致力于帮助用户制定合理、可行的旅行预算方案。
        
        ## 你的核心职责：
        1. **预算规划**：根据用户需求和目的地特点，制定详细的预算计划
        2. **成本分析**：分析各项支出的合理性，提供优化建议
        3. **风险控制**：预留应急费用，避免预算超支
        4. **省钱攻略**：提供实用的节省技巧和优惠信息
        5. **消费跟踪**：帮助用户监控实际支出，及时调整预算
        
        ## 专业特长：
        - 🌍 熟悉各国消费水平和汇率变化
        - 💰 精通预算分配和成本控制策略
        - 📊 擅长数据分析和财务规划
        - 🎯 提供个性化的省钱方案
        - ⚠️ 风险评估和应急预算规划
        
        ## 工作原则：
        - 以用户的实际经济能力为基础
        - 平衡预算约束与旅行体验质量
        - 提供透明、详细的费用明细
        - 考虑季节性价格波动和汇率影响
        - 预留合理的应急费用和弹性空间
        
        ## 可用工具：
        - budget_analyzer: 分析旅行预算，计算各项费用，提供优化建议
        
        当用户咨询预算相关问题时，请使用 budget_analyzer 工具进行详细分析，并根据结果提供专业建议。
        """
        
        let tools: [Tool] = [
            BudgetAnalyzerTool()
        ]
        
        let capabilities: [AgentCapability] = [
            .budgetPlanning,
            .dataAnalysis,
            .textGeneration
        ]
        
        return BudgetAgent(
            name: "BudgetAgent",
            systemPrompt: systemPrompt,
            capabilities: capabilities,
            tools: tools,
            llm: llm
        )
    }
    
    // MARK: - 专业方法
    
    /// 制定完整预算计划
    func createBudgetPlan(
        destination: String,
        duration: Int,
        travelers: Int,
        budgetLimit: Double? = nil,
        travelStyle: String = "mid_range"
    ) async throws -> String {
        
        let planningPrompt = """
        请为用户制定完整的旅行预算计划：
        
        📍 目的地：\(destination)
        📅 旅行天数：\(duration)天
        👥 旅行人数：\(travelers)人
        💰 预算限制：\(budgetLimit.map { "¥\($0)" } ?? "无限制")
        🎯 旅行风格：\(travelStyle)
        
        请使用 budget_analyzer 工具进行详细分析，并提供：
        1. 详细的预算分配方案
        2. 各项费用的合理性评估
        3. 针对性的省钱建议
        4. 应急预算规划
        5. 不同消费等级的对比选择
        """
        
        return try await run(request: planningPrompt)
    }
    
    /// 预算优化建议
    func optimizeBudget(
        currentBudget: [String: Double],
        targetReduction: Double,
        destination: String
    ) async throws -> String {
        
        let currentTotal = currentBudget.values.reduce(0, +)
        let optimizationPrompt = """
        用户当前预算需要优化，请提供专业建议：
        
        📊 当前预算明细：
        \(currentBudget.map { "- \($0.key): ¥\($0.value)" }.joined(separator: "\n"))
        
        💸 当前总预算：¥\(currentTotal)
        🎯 目标节省：¥\(targetReduction)
        📍 目的地：\(destination)
        
        请分析如何在保证旅行质量的前提下，达成预算优化目标。
        重点关注性价比最高的优化方案。
        """
        
        return try await run(request: optimizationPrompt)
    }
    
    /// 实时预算监控
    func trackBudgetProgress(
        plannedBudget: [String: Double],
        actualSpent: [String: Double],
        remainingDays: Int
    ) async throws -> String {
        
        let monitoringPrompt = """
        请分析用户的预算执行情况并提供调整建议：
        
        📋 计划预算：
        \(plannedBudget.map { "- \($0.key): ¥\($0.value)" }.joined(separator: "\n"))
        
        💳 实际支出：
        \(actualSpent.map { "- \($0.key): ¥\($0.value)" }.joined(separator: "\n"))
        
        📅 剩余天数：\(remainingDays)天
        
        请评估：
        1. 当前预算执行情况
        2. 超支风险评估
        3. 剩余天数的支出建议
        4. 必要的预算调整方案
        """
        
        return try await run(request: monitoringPrompt)
    }
    
    /// 应急预算方案
    func createEmergencyBudget(
        mainBudget: Double,
        riskLevel: String = "medium"
    ) async throws -> String {
        
        let emergencyPrompt = """
        请制定应急预算方案：
        
        💰 主要预算：¥\(mainBudget)
        ⚠️ 风险等级：\(riskLevel)
        
        请提供：
        1. 应急费用的合理比例
        2. 各类突发情况的预算预留
        3. 应急费用的使用优先级
        4. 风险控制策略
        """
        
        return try await run(request: emergencyPrompt)
    }
    
    /// 多方案预算对比
    func compareBudgetOptions(
        destination: String,
        duration: Int,
        travelers: Int,
        options: [String] = ["budget", "mid_range", "luxury"]
    ) async throws -> String {
        
        let comparisonPrompt = """
        请对比不同消费等级的预算方案：
        
        📍 目的地：\(destination)
        📅 天数：\(duration)天
        👥 人数：\(travelers)人
        
        请分析以下消费等级的预算方案：
        \(options.joined(separator: "、"))
        
        对每个等级提供：
        1. 详细预算明细
        2. 体验质量说明
        3. 适合人群分析
        4. 性价比评价
        """
        
        return try await run(request: comparisonPrompt)
    }
    
    /// 汇率影响分析
    func analyzeExchangeRateImpact(
        destination: String,
        budgetCNY: Double,
        targetCurrency: String
    ) async throws -> String {
        
        let rateAnalysisPrompt = """
        请分析汇率对旅行预算的影响：
        
        📍 目的地：\(destination)
        💰 人民币预算：¥\(budgetCNY)
        💱 目标货币：\(targetCurrency)
        
        请提供：
        1. 当前汇率情况分析
        2. 汇率波动风险评估
        3. 最佳兑换时机建议
        4. 外汇风险控制策略
        5. 多币种支付方案
        """
        
        return try await run(request: rateAnalysisPrompt)
    }
}

// MARK: - 扩展方法

extension BudgetAgent {
    /// 快速预算估算
    func quickEstimate(destination: String, days: Int, people: Int) async throws -> String {
        return try await createBudgetPlan(
            destination: destination,
            duration: days,
            travelers: people
        )
    }
    
    /// 学生预算方案
    func studentBudgetPlan(destination: String, days: Int, maxBudget: Double) async throws -> String {
        return try await createBudgetPlan(
            destination: destination,
            duration: days,
            travelers: 1,
            budgetLimit: maxBudget,
            travelStyle: "budget"
        )
    }
    
    /// 家庭旅行预算
    func familyBudgetPlan(destination: String, days: Int, adults: Int, children: Int = 0) async throws -> String {
        let totalPeople = adults + children
        return try await createBudgetPlan(
            destination: destination,
            duration: days,
            travelers: totalPeople,
            travelStyle: "mid_range"
        )
    }
    
    /// 蜜月旅行预算
    func honeymoonBudgetPlan(destination: String, days: Int, budget: Double) async throws -> String {
        return try await createBudgetPlan(
            destination: destination,
            duration: days,
            travelers: 2,
            budgetLimit: budget,
            travelStyle: "luxury"
        )
    }
    
    /// 预算救急方案
    func budgetEmergencyPlan(overspent: Double, remainingDays: Int) async throws -> String {
        let emergencyPrompt = """
        用户预算超支，需要紧急调整方案：
        
        💸 超支金额：¥\(overspent)
        📅 剩余天数：\(remainingDays)天
        
        请提供紧急预算控制方案：
        1. 立即削减的支出项目
        2. 剩余天数的节省策略
        3. 必要支出的优先级排序
        4. 避免进一步超支的措施
        """
        
        return try await run(request: emergencyPrompt)
    }
}
