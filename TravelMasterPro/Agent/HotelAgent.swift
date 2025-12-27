//
//  HotelAgent.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import Foundation

/// 酒店智能体 - 专业的酒店搜索和预订顾问
/// 继承 ToolCallAgent 的动力系统，集成酒店搜索专业工具和能力
class HotelAgent: ToolCallAgent {
    
    /// 创建酒店智能体实例
    static func create(llm: LLMService) -> HotelAgent {
        let systemPrompt = """
        你是专业的酒店搜索和预订顾问，致力于为用户找到最适合的住宿选择。
        
        ## 你的核心职责：
        1. **智能搜索**：根据用户需求搜索最合适的酒店
        2. **个性化推荐**：基于预算、位置、设施偏好提供定制建议
        3. **位置分析**：评估酒店位置的便利性（交通、景点、商圈）
        4. **性价比评估**：综合价格、设施、评价分析性价比
        5. **预订建议**：提供最佳预订时机和策略建议
        
        ## 专业特长：
        - 🏨 熟悉各类住宿类型（星级酒店、民宿、公寓、青旅等）
        - 🚇 精通交通便利性分析（地铁、机场、景点距离）
        - 💰 擅长预算优化和性价比分析
        - 📍 了解各城市热门住宿区域特点
        - ⭐️ 专业解读酒店评价和设施信息
        
        ## 工作原则：
        - 优先考虑位置便利性和安全性
        - 平衡价格与品质，追求最佳性价比
        - 充分了解用户偏好和特殊需求
        - 提供详细的酒店对比和选择建议
        - 考虑季节性价格波动和预订策略
        
        ## 可用工具：
        - hotel_search: 搜索酒店信息，支持多维度筛选
        
        当用户咨询酒店相关问题时，请使用相应工具进行搜索，并根据结果提供专业建议。
        """
        
        let tools: [Tool] = [
            HotelSearchTool()
        ]
        
        let capabilities: [AgentCapability] = [
            .hotelBooking
        ]
        
        return HotelAgent(
            name: "HotelAgent",
            systemPrompt: systemPrompt,
            capabilities: capabilities,
            tools: tools,
            llm: llm
        )
    }
    
    // MARK: - 专业方法
    
    /// 智能酒店推荐
    func recommendHotels(
        city: String,
        checkinDate: String,
        checkoutDate: String,
        guests: Int = 2,
        budget: (min: Double?, max: Double?) = (nil, nil),
        preferences: [String] = []
    ) async throws -> String {
        
        let recommendationPrompt = """
        请为用户推荐最适合的酒店：
        
        📍 目的地：\(city)
        📅 入住：\(checkinDate) → 退房：\(checkoutDate)
        👥 客人数：\(guests)人
        💰 预算：\(budget.min.map { "¥\($0)" } ?? "不限") - \(budget.max.map { "¥\($0)" } ?? "不限")
        🎯 偏好：\(preferences.isEmpty ? "无特殊要求" : preferences.joined(separator: "、"))
        
        请使用 hotel_search 工具搜索酒店，并为用户推荐最优选择。
        重点考虑：
        1. 位置便利性（交通、景点）
        2. 性价比分析
        3. 用户偏好匹配
        4. 安全性和舒适度
        """
        
        return try await run(request: recommendationPrompt)
    }
    
    /// 地铁沿线酒店搜索
    func findMetroHotels(
        city: String,
        station: String,
        checkinDate: String,
        checkoutDate: String,
        maxWalkMinutes: Int = 5
    ) async throws -> String {
        
        let metroPrompt = """
        用户需要在地铁站附近找酒店：
        
        🚇 \(city) \(station)站
        📅 \(checkinDate) → \(checkoutDate)
        🚶‍♂️ 最大步行时间：\(maxWalkMinutes)分钟
        
        请使用 hotel_near_metro 工具搜索，并分析：
        1. 各酒店到地铁站的实际步行时间
        2. 该地铁站的交通便利性
        3. 周边环境和配套设施
        4. 价格和性价比对比
        """
        
        return try await run(request: metroPrompt)
    }
    
    /// 酒店对比分析
    func compareHotels(
        city: String,
        hotelNames: [String],
        checkinDate: String,
        checkoutDate: String
    ) async throws -> String {
        
        let comparisonPrompt = """
        请对比分析以下酒店：
        
        📍 城市：\(city)
        🏨 对比酒店：\(hotelNames.joined(separator: "、"))
        📅 入住时间：\(checkinDate) → \(checkoutDate)
        
        请先搜索这些酒店的详细信息，然后从以下维度进行对比：
        1. 价格对比
        2. 位置便利性
        3. 设施和服务
        4. 用户评价
        5. 综合性价比
        
        最后给出推荐建议。
        """
        
        return try await run(request: comparisonPrompt)
    }
    
    /// 商务出行酒店推荐
    func businessHotelRecommendation(
        city: String,
        businessArea: String?,
        checkinDate: String,
        checkoutDate: String,
        budget: Double? = nil
    ) async throws -> String {
        
        let businessPrompt = """
        为商务出行推荐酒店：
        
        📍 目的地：\(city)
        🏢 商务区域：\(businessArea ?? "市中心商业区")
        📅 \(checkinDate) → \(checkoutDate)
        💰 预算：\(budget.map { "¥\($0)" } ?? "商务标准")
        
        推荐要求：
        1. 靠近商务区或交通枢纽
        2. 商务设施完善（会议室、商务中心）
        3. 网络环境优良
        4. 安静舒适，适合工作休息
        5. 餐饮便利
        
        请使用工具搜索并推荐最适合的商务酒店。
        """
        
        return try await run(request: businessPrompt)
    }
    
    /// 家庭旅行酒店推荐
    func familyHotelRecommendation(
        city: String,
        adults: Int,
        children: Int,
        childrenAges: [Int],
        checkinDate: String,
        checkoutDate: String
    ) async throws -> String {
        
        let familyPrompt = """
        为家庭旅行推荐酒店：
        
        👨‍👩‍👧‍👦 家庭组成：\(adults)大人 + \(children)小孩（年龄：\(childrenAges.map(String.init).joined(separator: "、"))岁）
        📍 目的地：\(city)
        📅 \(checkinDate) → \(checkoutDate)
        
        家庭出行特殊需求：
        1. 房间空间充足，适合家庭入住
        2. 儿童友好设施（游乐区、儿童床等）
        3. 安全性高，位置相对安静
        4. 周边有适合儿童的活动场所
        5. 餐饮方便，有适合儿童的选择
        
        请推荐最适合的家庭酒店。
        """
        
        return try await run(request: familyPrompt)
    }
    
    /// 预算优化建议
    func optimizeHotelBudget(
        city: String,
        checkinDate: String,
        checkoutDate: String,
        currentBudget: Double,
        targetSavings: Double
    ) async throws -> String {
        
        let optimizationPrompt = """
        帮助用户优化酒店预算：
        
        📍 \(city)
        📅 \(checkinDate) → \(checkoutDate)
        💰 当前预算：¥\(currentBudget)
        🎯 目标节省：¥\(targetSavings)
        
        请提供预算优化建议：
        1. 搜索不同价位的酒店选择
        2. 分析位置对价格的影响
        3. 推荐性价比最高的替代方案
        4. 预订时机和策略建议
        5. 其他省钱技巧
        """
        
        return try await run(request: optimizationPrompt)
    }
    
    /// 酒店预订时机建议
    func bookingTimingAdvice(
        city: String,
        checkinDate: String,
        checkoutDate: String,
        isFlexible: Bool = false
    ) async throws -> String {
        
        let timingPrompt = """
        请分析酒店预订时机和策略：
        
        📍 目的地：\(city)
        📅 计划入住：\(checkinDate) → \(checkoutDate)
        🔄 日期灵活性：\(isFlexible ? "可调整" : "固定")
        
        请分析并建议：
        1. 当前预订 vs 等待的风险和收益
        2. 该时间段的价格趋势预测
        3. 最佳预订时机建议
        4. 如果日期灵活，推荐更优惠的替代时间
        5. 预订策略和注意事项
        """
        
        return try await run(request: timingPrompt)
    }
}

// MARK: - 扩展方法

extension HotelAgent {
    /// 快速酒店搜索
    func quickSearch(
        city: String,
        checkin: String,
        checkout: String,
        maxPrice: Double? = nil
    ) async throws -> String {
        return try await recommendHotels(
            city: city,
            checkinDate: checkin,
            checkoutDate: checkout,
            budget: (nil, maxPrice)
        )
    }
    
    /// 经济型酒店推荐
    func budgetHotels(
        city: String,
        checkin: String,
        checkout: String,
        maxBudget: Double
    ) async throws -> String {
        return try await recommendHotels(
            city: city,
            checkinDate: checkin,
            checkoutDate: checkout,
            budget: (nil, maxBudget),
            preferences: ["经济实惠", "干净整洁", "交通便利"]
        )
    }
    
    /// 豪华酒店推荐
    func luxuryHotels(
        city: String,
        checkin: String,
        checkout: String,
        minStars: Int = 4
    ) async throws -> String {
        return try await recommendHotels(
            city: city,
            checkinDate: checkin,
            checkoutDate: checkout,
            preferences: ["豪华设施", "优质服务", "独特体验", "\(minStars)星及以上"]
        )
    }
    
    /// 机场附近酒店
    func airportHotels(
        city: String,
        checkin: String,
        checkout: String,
        needShuttle: Bool = true
    ) async throws -> String {
        let shuttleRequirement = needShuttle ? "提供机场接送服务" : "靠近机场交通"
        return try await recommendHotels(
            city: city,
            checkinDate: checkin,
            checkoutDate: checkout,
            preferences: ["机场附近", shuttleRequirement, "便于转机"]
        )
    }
    
    /// 取消政策分析
    func analyzeCancellationPolicy(
        hotelName: String,
        city: String,
        checkinDate: String
    ) async throws -> String {
        let policyPrompt = """
        请分析酒店取消政策和预订风险：
        
        🏨 酒店：\(hotelName)
        📍 城市：\(city)
        📅 入住日期：\(checkinDate)
        
        请分析：
        1. 该酒店的一般取消政策
        2. 特殊时期（节假日、会展）的政策变化
        3. 不同预订渠道的政策差异
        4. 预订风险评估和建议
        5. 最佳预订策略
        """
        
        return try await run(request: policyPrompt)
    }
}
