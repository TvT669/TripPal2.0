//
//  ToolCollection.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import Foundation

/// 工具集合管理器 - 智能体的工具箱
/// 提供工具的统一管理、发现、执行和组合功能
class ToolCollection {
    private var tools: [Tool] = []
    private var toolMap: [String: Tool] = [:]
    private var capabilityMap: [AgentCapability: [Tool]] = [:]
    
    init(tools: [Tool] = []) {
        for tool in tools {
            addTool(tool)
        }
    }
    
    // MARK: - 工具管理
    
    func addTool(_ tool: Tool) {
        if toolMap[tool.name] == nil {
            tools.append(tool)
            toolMap[tool.name] = tool
            
            // 建立能力映射
            updateCapabilityMapping(for: tool)
        }
    }
    
    func removeTool(_ name: String) {
        guard let tool = toolMap[name] else { return }
        
        tools.removeAll { $0.name == name }
        toolMap.removeValue(forKey: name)
        
        // 更新能力映射
        rebuildCapabilityMapping()
    }
    
    func getTool(name: String) -> Tool? {
        return toolMap[name]
    }
    
    func getAllTools() -> [Tool] {
        return tools
    }
    
    // MARK: - 智能发现和查询
    
    /// 根据能力查找工具
    func getToolsByCapability(_ capability: AgentCapability) -> [Tool] {
        return capabilityMap[capability] ?? []
    }
    
    /// 根据关键词查找工具
    func searchTools(keywords: [String]) -> [Tool] {
        return tools.filter { tool in
            keywords.allSatisfy { keyword in
                tool.name.lowercased().contains(keyword.lowercased()) ||
                tool.description.lowercased().contains(keyword.lowercased())
            }
        }
    }
    
    /// 检查工具是否存在
    func hasToolForCapability(_ capability: AgentCapability) -> Bool {
        return !getToolsByCapability(capability).isEmpty
    }
    
    // MARK: - 工具执行
    
    func execute(name: String, arguments: [String: Any]) async throws -> ToolResult {
        guard let tool = toolMap[name] else {
            return ToolResult(
                output: nil,
                error: "工具 '\(name)' 不存在。可用工具：\(tools.map(\.name).joined(separator: ", "))",
                base64Image: nil,
                metadata: ["available_tools": tools.map(\.name)]
            )
        }
        
        do {
            return try await tool.execute(arguments: arguments)
        } catch {
            return ToolResult(
                output: nil,
                error: "工具 '\(name)' 执行失败: \(error.localizedDescription)",
                base64Image: nil,
                metadata: ["tool_name": name, "error_type": String(describing: type(of: error))]
            )
        }
    }
    
    /// 批量执行工具
    func executeBatch(_ requests: [(tool: String, arguments: [String: Any])]) async -> [ToolResult] {
        await withTaskGroup(of: (Int, ToolResult).self) { group in
            for (index, request) in requests.enumerated() {
                group.addTask {
                    do {
                        let result = try await self.execute(name: request.tool, arguments: request.arguments)
                        return (index, result)
                    } catch {
                        return (index, ToolResult(error: error.localizedDescription))
                    }
                }
            }
            
            var results: [(Int, ToolResult)] = []
            for await result in group {
                results.append(result)
            }
            
            // 按原始顺序排序
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
    
    // MARK: - LLM 集成
    
    /// 生成给 LLM 的工具定义
    func toParameters() -> [[String: Any]] {
        return tools.map { $0.toParameters() }
    }
    
    /// 生成工具使用说明
    func generateToolGuide() -> String {
        var guide = "📚 可用工具指南：\n\n"
        
        for capability in AgentCapability.allCases {
            let toolsForCapability = getToolsByCapability(capability)
            if !toolsForCapability.isEmpty {
                guide += "🔧 \(capability.displayName)：\n"
                for tool in toolsForCapability {
                    guide += "  • \(tool.name): \(tool.description)\n"
                }
                guide += "\n"
            }
        }
        
        return guide
    }
    
    // MARK: - 预设工具集合
    
    /// 创建完整的旅行工具套件
    static func createTravelSuite() -> ToolCollection {
        let tools: [Tool] = [
            FlightSearchTool(),
            HotelSearchTool(),
            RoutePlannerTool(),
            BudgetAnalyzerTool(),
            PlanningTool()
        ]
        return ToolCollection(tools: tools)
    }
    
    /// 创建基础工具集合
    static func createBasicSuite() -> ToolCollection {
        let tools: [Tool] = [
            FlightSearchTool(),
            HotelSearchTool(),
            BudgetAnalyzerTool()
        ]
        return ToolCollection(tools: tools)
    }
    
    /// 创建高级工具集合
    static func createAdvancedSuite() -> ToolCollection {
        let tools: [Tool] = [
            FlightSearchTool(),
            HotelSearchTool(),
            RoutePlannerTool(),
            BudgetAnalyzerTool(),
            PlanningTool(),
            // 未来可添加更多高级工具
            // WeatherTool(),
            // CurrencyTool(),
            // VisaTool()
        ]
        return ToolCollection(tools: tools)
    }
    
    // MARK: - 私有方法
    
    private func updateCapabilityMapping(for tool: Tool) {
        let capabilities = inferCapabilities(from: tool)
        for capability in capabilities {
            if capabilityMap[capability] == nil {
                capabilityMap[capability] = []
            }
            capabilityMap[capability]?.append(tool)
        }
    }
    
    private func rebuildCapabilityMapping() {
        capabilityMap.removeAll()
        for tool in tools {
            updateCapabilityMapping(for: tool)
        }
    }
    
    private func inferCapabilities(from tool: Tool) -> [AgentCapability] {
        var capabilities: [AgentCapability] = []
        
        let name = tool.name.lowercased()
        let description = tool.description.lowercased()
        
        if name.contains("flight") || description.contains("航班") {
            capabilities.append(.flightSearch)
        }
        if name.contains("hotel") || description.contains("酒店") {
            capabilities.append(.hotelBooking)
        }
        if name.contains("route") || description.contains("路线") {
            capabilities.append(.routePlanning)
        }
        if name.contains("budget") || description.contains("预算") {
            capabilities.append(.budgetPlanning)
        }
        if name.contains("travel") || description.contains("旅行") {
            capabilities.append(.travelPlanning)
        }
        
        return capabilities
    }
}

// MARK: - 工具分析器

/// 工具分析器 - 分析工具使用情况和性能
class ToolAnalyzer {
    private var usageStats: [String: ToolUsageStats] = [:]
    
    func recordUsage(toolName: String, success: Bool, duration: TimeInterval) {
        if usageStats[toolName] == nil {
            usageStats[toolName] = ToolUsageStats(toolName: toolName)
        }
        usageStats[toolName]?.recordUsage(success: success, duration: duration)
    }
    
    func getStats(for toolName: String) -> ToolUsageStats? {
        return usageStats[toolName]
    }
    
    func getAllStats() -> [ToolUsageStats] {
        return Array(usageStats.values)
    }
    
    func generateReport() -> String {
        var report = "📊 工具使用统计报告：\n\n"
        
        let sortedStats = usageStats.values.sorted { $0.totalUsage > $1.totalUsage }
        
        for stats in sortedStats {
            report += """
            🔧 \(stats.toolName)：
              • 总使用次数：\(stats.totalUsage)
              • 成功率：\(String(format: "%.1f%%", stats.successRate * 100))
              • 平均响应时间：\(String(format: "%.2fs", stats.averageResponseTime))
            
            """
        }
        
        return report
    }
}

/// 工具使用统计
class ToolUsageStats {
    let toolName: String
    private(set) var totalUsage: Int = 0
    private(set) var successfulUsage: Int = 0
    private(set) var totalResponseTime: TimeInterval = 0
    
    init(toolName: String) {
        self.toolName = toolName
    }
    
    func recordUsage(success: Bool, duration: TimeInterval) {
        totalUsage += 1
        totalResponseTime += duration
        if success {
            successfulUsage += 1
        }
    }
    
    var successRate: Double {
        guard totalUsage > 0 else { return 0 }
        return Double(successfulUsage) / Double(totalUsage)
    }
    
    var averageResponseTime: TimeInterval {
        guard totalUsage > 0 else { return 0 }
        return totalResponseTime / TimeInterval(totalUsage)
    }
}

// MARK: - 扩展

extension AgentCapability {
    var displayName: String {
        switch self {
        case .flightSearch: return "航班搜索"
        case .hotelBooking: return "酒店预订"
        case .routePlanning: return "路线规划"
        case .budgetPlanning: return "预算管理"
        case .textGeneration: return "文本生成"
        case .dataAnalysis: return "数据分析"
        case .webSearch: return "网络搜索"
        case .travelPlanning: return "旅行规划"
        case .general: return "通用能力"
        case .hotelSearch: return "酒店搜索"
        case .budgetAnalysis: return "预算分析"
        }
    }
}


