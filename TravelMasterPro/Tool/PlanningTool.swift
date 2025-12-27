//
//  PlanningTool.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import Foundation

class PlanningTool: BaseTool {
    // 计划存储
    private var plans: [String: [String: Any]] = [:]
    
    init() {
        super.init(
            name: "planning",
            description: "用于创建和管理任务执行计划",
            parameters: [
                "command": ParameterDefinition.string(
                    "要执行的命令",
                    enumValues: ["create", "update", "list", "get", "mark_step", "delete"]
                ),
                "plan_id": ParameterDefinition(
                    type: "string",
                    description: "计划ID",
                    enumValues: nil
                ),
                "title": ParameterDefinition(
                    type: "string",
                    description: "计划标题",
                    enumValues: nil
                ),
                "steps": ParameterDefinition(
                    type: "array",
                    description: "计划步骤列表",
                    enumValues: nil
                ),
                "step_index": ParameterDefinition(
                    type: "integer",
                    description: "步骤索引",
                    enumValues: nil
                ),
                "step_status": ParameterDefinition.string(
                    "步骤状态",
                    enumValues: ["not_started", "in_progress", "completed", "blocked"]
                )
            ],
            requiredParameters: ["command"]
        )
    }
    
    // ✅ 使用 executeImpl 而不是重写 execute
    override func executeImpl(arguments: [String: Any]) async throws -> ToolResult {
        guard let command = getString("command", from: arguments) else {
            return errorResult("缺少command参数")
        }
        
        switch command {
        case "create":
            return try createPlan(arguments)
        case "get":
            return getPlan(arguments)
        case "mark_step":
            return markStep(arguments)
        case "list":
            return listPlans()
        case "update":
            return try updatePlan(arguments)
        case "delete":
            return deletePlan(arguments)
        default:
            return errorResult("未知命令: \(command)")
        }
    }
    
    private func createPlan(_ args: [String: Any]) throws -> ToolResult {
        guard let planId = getString("plan_id", from: args),
              let title = getString("title", from: args),
              let stepsArray = getArray("steps", from: args),
              let steps = stepsArray as? [String] else {
            return errorResult("缺少必要参数: plan_id, title, steps")
        }
        
        // 检查计划是否已存在
        if plans[planId] != nil {
            return errorResult("计划ID已存在: \(planId)")
        }
        
        // 创建计划
        let plan: [String: Any] = [
            "id": planId,
            "title": title,
            "steps": steps,
            "step_statuses": Array(repeating: "not_started", count: steps.count),
            "step_notes": Array(repeating: "", count: steps.count),
            "created_at": Date(),
            "updated_at": Date()
        ]
        
        // 保存计划
        plans[planId] = plan
        
        return successResult("✅ 计划创建成功: \(title)\n包含 \(steps.count) 个步骤")
    }
    
    private func getPlan(_ args: [String: Any]) -> ToolResult {
        guard let planId = getString("plan_id", from: args) else {
            return errorResult("缺少计划ID")
        }
        
        guard let plan = plans[planId] else {
            return errorResult("计划不存在: \(planId)")
        }
        
        // 格式化计划详情
        let title = plan["title"] as? String ?? "无标题"
        let steps = plan["steps"] as? [String] ?? []
        let statuses = plan["step_statuses"] as? [String] ?? []
        let notes = plan["step_notes"] as? [String] ?? []
        
        var result = "📋 计划: \(title) (ID: \(planId))\n"
        result += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        
        for (i, step) in steps.enumerated() {
            let status = i < statuses.count ? statuses[i] : "not_started"
            let note = i < notes.count ? notes[i] : ""
            let statusSymbol = getStatusSymbol(status)
            
            result += "\(i+1). \(statusSymbol) \(step)"
            if !note.isEmpty {
                result += " 📝 \(note)"
            }
            result += "\n"
        }
        
        // 添加进度统计
        let completed = statuses.filter { $0 == "completed" }.count
        let total = steps.count
        let progress = total > 0 ? Int(Double(completed) / Double(total) * 100) : 0
        result += "\n📊 进度: \(completed)/\(total) (\(progress)%)"
        
        return successResult(result)
    }
    
    private func markStep(_ args: [String: Any]) -> ToolResult {
        guard let planId = getString("plan_id", from: args),
              let stepIndex = args["step_index"] as? Int,
              let stepStatus = getString("step_status", from: args) else {
            return errorResult("缺少必要参数: plan_id, step_index, step_status")
        }
        
        guard var plan = plans[planId] else {
            return errorResult("计划不存在: \(planId)")
        }
        
        guard var statuses = plan["step_statuses"] as? [String],
              stepIndex >= 0 && stepIndex < statuses.count else {
            return errorResult("步骤索引无效: \(stepIndex)")
        }
        
        let oldStatus = statuses[stepIndex]
        statuses[stepIndex] = stepStatus
        plan["step_statuses"] = statuses
        plan["updated_at"] = Date()
        plans[planId] = plan
        
        let stepTitle = (plan["steps"] as? [String])?[stepIndex] ?? "步骤\(stepIndex + 1)"
        let statusSymbol = getStatusSymbol(stepStatus)
        
        return successResult("✅ 步骤更新成功\n\(stepIndex + 1). \(statusSymbol) \(stepTitle)\n状态: \(oldStatus) → \(stepStatus)")
    }
    
    private func listPlans() -> ToolResult {
        if plans.isEmpty {
            return successResult("📋 暂无计划")
        }
        
        var result = "📋 所有计划列表\n"
        result += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        
        for (planId, plan) in plans {
            let title = plan["title"] as? String ?? "无标题"
            let steps = plan["steps"] as? [String] ?? []
            let statuses = plan["step_statuses"] as? [String] ?? []
            
            let completed = statuses.filter { $0 == "completed" }.count
            let total = steps.count
            let progress = total > 0 ? Int(Double(completed) / Double(total) * 100) : 0
            
            result += "• \(title) (ID: \(planId))\n"
            result += "  📊 进度: \(completed)/\(total) (\(progress)%)\n\n"
        }
        
        return successResult(result)
    }
    
    private func updatePlan(_ args: [String: Any]) throws -> ToolResult {
        guard let planId = getString("plan_id", from: args) else {
            return errorResult("缺少计划ID")
        }
        
        guard var plan = plans[planId] else {
            return errorResult("计划不存在: \(planId)")
        }
        
        // 更新标题
        if let newTitle = getString("title", from: args) {
            plan["title"] = newTitle
        }
        
        // 更新步骤
        if let stepsArray = getArray("steps", from: args),
           let newSteps = stepsArray as? [String] {
            plan["steps"] = newSteps
            // 重置状态数组以匹配新步骤数量
            plan["step_statuses"] = Array(repeating: "not_started", count: newSteps.count)
            plan["step_notes"] = Array(repeating: "", count: newSteps.count)
        }
        
        plan["updated_at"] = Date()
        plans[planId] = plan
        
        return successResult("✅ 计划更新成功: \(plan["title"] ?? planId)")
    }
    
    private func deletePlan(_ args: [String: Any]) -> ToolResult {
        guard let planId = getString("plan_id", from: args) else {
            return errorResult("缺少计划ID")
        }
        
        guard let plan = plans.removeValue(forKey: planId) else {
            return errorResult("计划不存在: \(planId)")
        }
        
        let title = plan["title"] as? String ?? planId
        return successResult("🗑️ 计划删除成功: \(title)")
    }
    
    // 辅助方法: 获取状态符号
    private func getStatusSymbol(_ status: String) -> String {
        switch status {
        case "not_started":
            return "⚪"
        case "in_progress":
            return "🔄"
        case "completed":
            return "✅"
        case "blocked":
            return "⚠️"
        default:
            return "❓"
        }
    }
}
