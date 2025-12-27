//
//  FlightAgent.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import Foundation

/// 航班智能体 - 专业的航班搜索和预订专家
/// 继承 ToolCallAgent 的动力系统，集成航班专业工具和能力
class FlightAgent: ToolCallAgent {
    
    /// 创建航班智能体实例
    static func create(llm: LLMService) -> FlightAgent {
        let systemPrompt = """
        你是专业的航班搜索和预订专家，专注于为用户提供最优的航班解决方案。
        
        ## 你的核心职责：
        1. **智能分析**用户的出行需求（出发地、目的地、时间、预算、偏好）
        2. **精准搜索**符合条件的航班选项
        3. **优化推荐**"低价 + 免费行李额"的最佳组合
        4. **详细对比**不同航班的优缺点和性价比
        5. **专业建议**关于预订时机、舱位选择、行李政策等
        
        ## 工作原则：
        - 优先推荐性价比最高的航班（综合考虑价格、时间、服务）
        - 重点关注免费行李额政策，为用户节省额外费用
        - 如果信息不完整，主动询问缺失的关键信息
        - 提供清晰的航班对比和选择建议
        - 解释推荐理由，帮助用户做出明智决策
        
        ## 可用工具：
        - flight_search: 搜索和筛选最优航班
        
        当用户有航班需求时，请使用 flight_search 工具进行搜索，并根据结果提供专业分析和建议。
        """
        
        let tools: [Tool] = [
            FlightSearchTool()
        ]
        
        let capabilities: [AgentCapability] = [
            .flightSearch,
            .textGeneration,
            .dataAnalysis
        ]
        
        return FlightAgent(
            name: "FlightAgent",
            systemPrompt: systemPrompt,
            capabilities: capabilities,
            tools: tools,
            llm: llm
        )
    }
    
    // MARK: - 专业方法
    
    /// 智能航班搜索 - 一键搜索最优航班
    func searchOptimalFlights(
        origin: String,
        destination: String,
        departureDate: String,
        returnDate: String? = nil,
        adults: Int = 1,
        maxPrice: Double? = nil,
        travelClass: String = "ECONOMY"
    ) async throws -> String {
        
        let searchPrompt = """
        请为用户搜索最优航班：
        
        出发地：\(origin)
        目的地：\(destination)
        出发日期：\(departureDate)
        \(returnDate.map { "返程日期：\($0)" } ?? "单程航班")
        乘客数量：\(adults) 人
        舱位等级：\(travelClass)
        \(maxPrice.map { "预算上限：¥\($0)" } ?? "无预算限制")
        
        请使用 flight_search 工具搜索航班，并为我推荐最优选择。
        重点考虑价格、时间、行李政策等因素。
        """
        
        return try await run(request: searchPrompt)
    }
    
    /// 分析用户航班需求
    func analyzeFlightRequest(_ userRequest: String) async throws -> FlightRequestAnalysis {
        let analysisPrompt = """
        请分析用户的航班搜索需求，提取关键信息：
        
        用户原始需求：\(userRequest)
        
        请分析并以JSON格式返回：
        ```json
        {
            "origin": "出发地（城市名或机场代码）",
            "destination": "目的地（城市名或机场代码）",
            "departure_date": "出发日期（YYYY-MM-DD格式）",
            "return_date": "返程日期（YYYY-MM-DD格式，单程则为null）",
            "adults": 成人数量,
            "travel_class": "舱位等级（ECONOMY/BUSINESS等）",
            "max_price": 最高预算（如果提到），
            "preferences": ["用户偏好列表"],
            "missing_info": ["缺失的关键信息"],
            "trip_type": "single|round",
            "urgency": "high|medium|low"
        }
        ```
        
        请仔细分析用户的表述，提取所有可能的信息。
        """
        
        let result = try await run(request: analysisPrompt)
        return try parseFlightAnalysis(result)
    }
    
    /// 航班价格分析和建议
    func analyzePriceAndRecommend(searchResult: String) async throws -> String {
        let analysisPrompt = """
        基于以下航班搜索结果，请提供专业的价格分析和预订建议：
        
        搜索结果：
        \(searchResult)
        
        请分析：
        1. 各个航班的性价比对比
        2. 最佳预订时机建议
        3. 行李政策对总成本的影响
        4. 时间成本 vs 价格成本的平衡
        5. 具体的推荐选择和理由
        
        请提供清晰、实用的建议。
        """
        
        return try await run(request: analysisPrompt)
    }
    
    /// 航班备选方案
    func generateAlternatives(
        originalRequest: FlightRequestAnalysis,
        flexibility: FlightFlexibility
    ) async throws -> String {
        
        let alternativePrompt = """
        基于用户的原始需求，请生成备选航班方案：
        
        原始需求：
        - 出发地：\(originalRequest.origin ?? "未指定")
        - 目的地：\(originalRequest.destination ?? "未指定")  
        - 出发日期：\(originalRequest.departure_date ?? "未指定")
        - 返程日期：\(originalRequest.return_date ?? "单程")
        
        灵活性设置：
        - 日期灵活性：\(flexibility.dateFlexibility) 天
        - 价格优先级：\(flexibility.pricePriority)
        - 时间优先级：\(flexibility.timePriority)
        
        请搜索并推荐以下备选方案：
        1. 提前/延后几天的更便宜选择
        2. 附近机场的替代方案
        3. 不同时间段的价格对比
        
        为每个方案说明优势和适用场景。
        """
        
        return try await run(request: alternativePrompt)
    }
    
    // MARK: - 私有辅助方法
    
    private func parseFlightAnalysis(_ response: String) throws -> FlightRequestAnalysis {
        // 提取JSON部分
        let jsonPattern = "```json\\s*({[\\s\\S]*?})\\s*```"
        let regex = try NSRegularExpression(pattern: jsonPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: response.utf16.count)
        
        guard let match = regex.firstMatch(in: response, options: [], range: range),
              let jsonRange = Range(match.range(at: 1), in: response) else {
            
            // 备用方案：查找第一个完整的JSON对象
            guard let jsonStart = response.firstIndex(of: "{"),
                  let jsonEnd = response.lastIndex(of: "}") else {
                throw AgentError.invalidRequest("无法解析航班需求分析结果")
            }
            
            let jsonString = String(response[jsonStart...jsonEnd])
            let jsonData = jsonString.data(using: .utf8)!
            return try JSONDecoder().decode(FlightRequestAnalysis.self, from: jsonData)
        }
        
        let jsonString = String(response[jsonRange])
        let jsonData = jsonString.data(using: .utf8)!
        return try JSONDecoder().decode(FlightRequestAnalysis.self, from: jsonData)
    }
}

// MARK: - 数据模型

/// 航班请求分析结果
struct FlightRequestAnalysis: Codable {
    let origin: String?
    let destination: String?
    let departure_date: String?
    let return_date: String?
    let adults: Int?
    let travel_class: String?
    let max_price: Double?
    let preferences: [String]?
    let missing_info: [String]
    let trip_type: String?
    let urgency: String?
}

/// 航班搜索灵活性配置
struct FlightFlexibility {
    let dateFlexibility: Int // 日期前后几天
    let pricePriority: String // "high", "medium", "low"
    let timePriority: String // "high", "medium", "low"
    let airportFlexibility: Bool // 是否考虑附近机场
    
    static let standard = FlightFlexibility(
        dateFlexibility: 3,
        pricePriority: "high",
        timePriority: "medium",
        airportFlexibility: true
    )
    
    static let strict = FlightFlexibility(
        dateFlexibility: 0,
        pricePriority: "medium",
        timePriority: "high",
        airportFlexibility: false
    )
    
    static let flexible = FlightFlexibility(
        dateFlexibility: 7,
        pricePriority: "high",
        timePriority: "low",
        airportFlexibility: true
    )
}

// MARK: - 扩展方法

extension FlightAgent {
    /// 快速搜索 - 简化接口
    func quickSearch(from origin: String, to destination: String, on date: String) async throws -> String {
        return try await searchOptimalFlights(
            origin: origin,
            destination: destination,
            departureDate: date
        )
    }
    
    /// 往返航班搜索
    func roundTripSearch(
        from origin: String,
        to destination: String,
        departure: String,
        returnDate: String,
        budget: Double? = nil
    ) async throws -> String {
        return try await searchOptimalFlights(
            origin: origin,
            destination: destination,
            departureDate: departure,
            returnDate: returnDate,
            maxPrice: budget
        )
    }
    
    /// 获取专业建议
    func getExpertAdvice(for request: String) async throws -> String {
        let expertPrompt = """
        作为航班预订专家，请针对以下情况提供专业建议：
        
        用户情况：\(request)
        
        请从以下角度提供建议：
        1. 预订时机（提前多久预订最优惠）
        2. 舱位选择策略
        3. 行李政策注意事项
        4. 退改签政策建议
        5. 机场和时间选择技巧
        
        请提供实用、专业的建议。
        """
        
        return try await run(request: expertPrompt)
    }
}
