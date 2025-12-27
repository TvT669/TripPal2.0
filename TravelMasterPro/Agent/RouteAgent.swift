//
//  RouteAgent.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/31.
//

import Foundation

/// 路线规划智能体 - 专业的旅行路线规划和优化顾问
/// 继承 ToolCallAgent 的动力系统，集成路线规划专业工具和能力
class RouteAgent: ToolCallAgent {
    
    /// 创建路线规划智能体实例
    static func create(llm: LLMService) -> RouteAgent {
        let systemPrompt = """
        你是专业的旅行路线规划和优化顾问，致力于为用户设计最高效、最合理的旅行路线。
        
        ## 你的核心职责：
        1. **智能路线设计**：根据用户需求设计最优旅行路线
        2. **多目标优化**：平衡时间、距离、成本、体验等多个因素
        3. **交通方式规划**：选择最适合的交通方式组合
        4. **时间管理**：合理安排游览时间和行程节奏
        5. **路线优化**：持续改进路线效率和用户体验
        
        ## 专业特长：
        - 🗺️ 精通地理信息和城市布局
        - 🚶‍♂️ 熟悉各种交通方式的特点和效率
        - ⏰ 擅长时间规划和行程优化
        - 📍 了解各地景点分布和游览特点
        - 🎯 精通路线优化算法和策略
        
        ## 工作原则：
        - 优先考虑用户的时间和体力限制
        - 合理安排游览顺序，避免重复路径
        - 充分考虑交通拥堵和开放时间
        - 平衡热门景点和小众体验
        - 预留休息时间和意外情况缓冲
        
        ## 可用工具：
        - route_planner: 智能路线规划工具，支持多目标优化
        
        当用户需要路线规划时，请使用 route_planner 工具进行计算，并根据结果提供专业建议。
        """
        
        let tools: [Tool] = [
            RoutePlannerTool()
        ]
        
        let capabilities: [AgentCapability] = [
            .routePlanning,
            .textGeneration,
            .dataAnalysis
        ]
        
        return RouteAgent(
            name: "RouteAgent",
            systemPrompt: systemPrompt,
            capabilities: capabilities,
            tools: tools,
            llm: llm
        )
    }
    
    // MARK: - 专业方法
    
    /// 智能路线规划
    func planOptimalRoute(
        destinations: [String],
        startLocation: String? = nil,
        travelMode: String = "walking",
        timeConstraint: Int? = nil,
        preferences: [String] = []
    ) async throws -> String {
        
        let planningPrompt = """
        请为用户设计最优旅行路线：
        
        📍 目的地列表：\(destinations.joined(separator: "、"))
        🚩 起点：\(startLocation ?? "第一个目的地")
        🚶‍♂️ 交通方式：\(travelMode)
        ⏰ 时间限制：\(timeConstraint.map { "\($0)分钟" } ?? "无限制")
        🎯 特殊偏好：\(preferences.isEmpty ? "无" : preferences.joined(separator: "、"))
        
        请使用 route_planner 工具进行路线规划，并提供：
        1. 最优的游览顺序
        2. 详细的时间安排
        3. 交通方式建议
        4. 路线优化说明
        5. 实用的游览建议
        """
        
        return try await run(request: planningPrompt)
    }
    
    /// 一日游路线规划
    func planDayTrip(
        city: String,
        interests: [String],
        startTime: String = "09:00",
        endTime: String = "18:00",
        travelMode: String = "mixed"
    ) async throws -> String {
        
        let dayTripPrompt = """
        请设计一日游路线方案：
        
        📍 城市：\(city)
        🎯 兴趣点：\(interests.joined(separator: "、"))
        🕘 开始时间：\(startTime)
        🕕 结束时间：\(endTime)
        🚶‍♂️ 交通方式：\(travelMode)
        
        请规划包含以下要素的一日游路线：
        1. 根据兴趣点推荐具体景点
        2. 合理的游览顺序和时间分配
        3. 午餐和休息时间安排
        4. 交通换乘和步行路线
        5. 备选方案和调整建议
        """
        
        return try await run(request: dayTripPrompt)
    }
    
    /// 多日行程路线规划
    func planMultiDayItinerary(
        destinations: [String],
        days: Int,
        dailyTimeLimit: Int = 600, // 10小时
        accommodationLocations: [String]? = nil
    ) async throws -> String {
        
        let multiDayPrompt = """
        请设计\(days)天的多日行程路线：
        
        📍 总目的地：\(destinations.joined(separator: "、"))
        📅 总天数：\(days)天
        ⏰ 每日时间限制：\(dailyTimeLimit/60)小时
        🏨 住宿地点：\(accommodationLocations?.joined(separator: "、") ?? "待规划")
        
        请提供：
        1. 每日具体行程安排
        2. 景点分配和路线优化
        3. 住宿地点选择建议
        4. 跨日交通方案
        5. 行程调整的灵活性建议
        """
        
        return try await run(request: multiDayPrompt)
    }
    
    /// 主题路线规划
    func planThemeRoute(
        city: String,
        theme: String,
        duration: Int,
        difficultyLevel: String = "medium"
    ) async throws -> String {
        
        let themePrompt = """
        请设计主题特色路线：
        
        📍 城市：\(city)
        🎨 主题：\(theme)
        ⏱️ 游览时长：\(duration/60)小时
        📊 难度级别：\(difficultyLevel)
        
        主题路线要求：
        1. 深度挖掘主题相关景点和体验
        2. 设计沉浸式的游览体验
        3. 安排主题相关的特色活动
        4. 提供主题背景知识和故事
        5. 推荐主题相关的餐饮和购物
        """
        
        return try await run(request: themePrompt)
    }
    
    /// 路线优化建议
    func optimizeExistingRoute(
        currentRoute: [String],
        issues: [String],
        constraints: [String: Any] = [:]
    ) async throws -> String {
        
        let optimizationPrompt = """
        请优化现有的旅行路线：
        
        📍 当前路线：\(currentRoute.joined(separator: " → "))
        ❌ 存在问题：\(issues.joined(separator: "、"))
        ⚖️ 约束条件：\(constraints.map { "\($0.key): \($0.value)" }.joined(separator: "、"))
        
        请分析并提供：
        1. 问题根因分析
        2. 具体优化方案
        3. 调整后的路线安排
        4. 预期改善效果
        5. 替代方案和风险评估
        """
        
        return try await run(request: optimizationPrompt)
    }
    
    /// 交通方式组合建议
    func recommendTransportMix(
        destinations: [String],
        budget: Double? = nil,
        timePreference: String = "balanced"
    ) async throws -> String {
        
        let transportPrompt = """
        请推荐最佳交通方式组合：
        
        📍 目的地：\(destinations.joined(separator: "、"))
        💰 预算：\(budget.map { "¥\($0)" } ?? "无限制")
        ⏰ 时间偏好：\(timePreference)
        
        请分析：
        1. 各段路程的最佳交通方式
        2. 成本效益分析
        3. 时间效率对比
        4. 舒适度和便利性评估
        5. 综合推荐方案
        """
        
        return try await run(request: transportPrompt)
    }
    
    /// 无障碍路线规划
    func planAccessibleRoute(
        destinations: [String],
        accessibilityNeeds: [String],
        companionInfo: String? = nil
    ) async throws -> String {
        
        let accessiblePrompt = """
        请设计无障碍友好路线：
        
        📍 目的地：\(destinations.joined(separator: "、"))
        ♿ 无障碍需求：\(accessibilityNeeds.joined(separator: "、"))
        👥 陪同信息：\(companionInfo ?? "无")
        
        特殊考虑：
        1. 无障碍交通方式选择
        2. 路径坡度和台阶避免
        3. 无障碍设施确认
        4. 休息点和洗手间规划
        5. 紧急情况应对方案
        """
        
        return try await run(request: accessiblePrompt)
    }
    
    /// 恶劣天气备选路线
    func planWeatherBackupRoute(
        originalDestinations: [String],
        weatherConditions: String,
        indoorAlternatives: Bool = true
    ) async throws -> String {
        
        let weatherPrompt = """
        请设计恶劣天气备选路线：
        
        📍 原计划目的地：\(originalDestinations.joined(separator: "、"))
        🌦️ 天气状况：\(weatherConditions)
        🏢 室内替代：\(indoorAlternatives ? "需要" : "不需要")
        
        备选方案要求：
        1. 适应天气条件的景点选择
        2. 室内外活动的合理搭配
        3. 交通方式的调整建议
        4. 应急预案和风险控制
        5. 保持原有游览价值
        """
        
        return try await run(request: weatherPrompt)
    }
}

// MARK: - 扩展方法

extension RouteAgent {
    /// 快速路线规划
    func quickRoute(destinations: [String], mode: String = "walking") async throws -> String {
        return try await planOptimalRoute(
            destinations: destinations,
            travelMode: mode
        )
    }
    
    /// 步行路线规划
    func walkingRoute(destinations: [String], maxTime: Int? = nil) async throws -> String {
        return try await planOptimalRoute(
            destinations: destinations,
            travelMode: "walking",
            timeConstraint: maxTime
        )
    }
    
    /// 公共交通路线
    func transitRoute(destinations: [String]) async throws -> String {
        return try await planOptimalRoute(
            destinations: destinations,
            travelMode: "transit",
            preferences: ["成本优先", "换乘便利"]
        )
    }
    
    /// 自驾路线规划
    func drivingRoute(destinations: [String], avoidTolls: Bool = false) async throws -> String {
        let preferences = avoidTolls ? ["避免收费站", "时间优先"] : ["时间优先"]
        return try await planOptimalRoute(
            destinations: destinations,
            travelMode: "driving",
            preferences: preferences
        )
    }
    
    /// 摄影路线规划
    func photographyRoute(city: String, style: String = "风光摄影") async throws -> String {
        return try await planThemeRoute(
            city: city,
            theme: "\(style)摄影路线",
            duration: 480, // 8小时
            difficultyLevel: "medium"
        )
    }
    
    /// 美食探索路线
    func foodieRoute(city: String, cuisine: String = "当地特色") async throws -> String {
        return try await planThemeRoute(
            city: city,
            theme: "\(cuisine)美食探索",
            duration: 360, // 6小时
            difficultyLevel: "easy"
        )
    }
    
    /// 历史文化路线
    func culturalRoute(city: String, period: String = "传统文化") async throws -> String {
        return try await planThemeRoute(
            city: city,
            theme: "\(period)历史文化",
            duration: 420, // 7小时
            difficultyLevel: "medium"
        )
    }
    
    /// 亲子游路线
    func familyRoute(destinations: [String], childrenAges: [Int]) async throws -> String {
        let ageInfo = childrenAges.map(String.init).joined(separator: "、")
        return try await planOptimalRoute(
            destinations: destinations,
            travelMode: "mixed",
            preferences: ["亲子友好", "休息充足", "儿童年龄\(ageInfo)岁"]
        )
    }
    
    /// 夜游路线规划
    func nightRoute(city: String, startTime: String = "19:00") async throws -> String {
        return try await planThemeRoute(
            city: city,
            theme: "夜景夜游路线",
            duration: 180, // 3小时
            difficultyLevel: "easy"
        )
    }
    
    /// 路线时间调整
    func adjustRouteTime(
        destinations: [String],
        newTimeLimit: Int,
        priorities: [String] = []
    ) async throws -> String {
        
        let adjustmentPrompt = """
        请调整路线时间安排：
        
        📍 目的地：\(destinations.joined(separator: "、"))
        ⏰ 新时间限制：\(newTimeLimit/60)小时
        🎯 优先级：\(priorities.isEmpty ? "平衡安排" : priorities.joined(separator: "、"))
        
        请提供时间调整方案：
        1. 压缩或延长各景点游览时间
        2. 增减景点的建议
        3. 路线顺序的重新优化
        4. 时间分配的合理性分析
        """
        
        return try await run(request: adjustmentPrompt)
    }
}
