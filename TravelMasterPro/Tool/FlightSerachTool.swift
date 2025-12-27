//
//  FlightSerachTool.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import Foundation

class FlightSearchTool: BaseTool {
    private let amadeus: AmadeusService
    
    private let cityToAirportCode: [String: String] = [
        // 中国主要城市
        "北京": "PEK",
        "上海": "PVG",
        "广州": "CAN",
        "深圳": "SZX",
        "成都": "CTU",
        "重庆": "CKG",
        "西安": "XIY",
        "杭州": "HGH",
        "南京": "NKG",
        "武汉": "WUH",
        "长沙": "CSX",
        "昆明": "KMG",
        "厦门": "XMN",
        "青岛": "TAO",
        "大连": "DLC",
        "沈阳": "SHE",
        "哈尔滨": "HRB",
        "天津": "TSN",
        "郑州": "CGO",
        "济南": "TNA",
        "太原": "TYN",
        "石家庄": "SJW",
        "乌鲁木齐": "URC",
        "兰州": "LHW",
        "银川": "INC",
        "呼和浩特": "HET",
        "南宁": "NNG",
        "海口": "HAK",
        "三亚": "SYX",
        "拉萨": "LXA",
        "贵阳": "KWE",
        "福州": "FOC",
        "合肥": "HFE",
        "南昌": "KHN",
        "长春": "CGQ",
        
        // 国际城市
        "东京": "NRT",
        "大阪": "KIX",
        "首尔": "ICN",
        "釜山": "PUS",
        "曼谷": "BKK",
        "新加坡": "SIN",
        "吉隆坡": "KUL",
        "雅加达": "CGK",
        "马尼拉": "MNL",
        "胡志明市": "SGN",
        "河内": "HAN",
        "金边": "PNH",
        "仰光": "RGN",
        "加德满都": "KTM",
        "孟买": "BOM",
        "新德里": "DEL",
        "迪拜": "DXB",
        "多哈": "DOH",
        "伊斯坦布尔": "IST",
        "莫斯科": "SVO",
        "伦敦": "LHR",
        "巴黎": "CDG",
        "法兰克福": "FRA",
        "阿姆斯特丹": "AMS",
        "罗马": "FCO",
        "马德里": "MAD",
        "纽约": "JFK",
        "洛杉矶": "LAX",
        "旧金山": "SFO",
        "芝加哥": "ORD",
        "多伦多": "YYZ",
        "温哥华": "YVR",
        "悉尼": "SYD",
        "墨尔本": "MEL"
    ]
    
    init() {
        self.amadeus = AmadeusService()
        
        super.init(
            name: "flight_search",
            description: "搜索航班信息，筛选低价和免费行李额的最优航班",
            parameters: [
                "origin": ParameterDefinition(
                    type: "string",
                    description: "出发地机场代码或城市名",
                    enumValues: nil // ✅ 设为 nil，不会生成 enum 字段
                ),
                "destination": ParameterDefinition(
                    type: "string",
                    description: "目的地机场代码或城市名",
                    enumValues: nil
                ),
                "departure_date": ParameterDefinition(
                    type: "string",
                    description: "出发日期 (YYYY-MM-DD 格式)",
                    enumValues: nil
                ),
                "return_date": ParameterDefinition(
                    type: "string",
                    description: "返程日期 (YYYY-MM-DD 格式)，单程时可选",
                    enumValues: nil
                ),
                "travel_class": ParameterDefinition.string(
                    "舱位等级",
                    enumValues: ["ECONOMY", "PREMIUM_ECONOMY", "BUSINESS", "FIRST"]
                ),
                "adults": ParameterDefinition(
                    type: "number",
                    description: "成人数量",
                    enumValues: nil
                ),
                "max_price": ParameterDefinition(
                    type: "number",
                    description: "最高价格（人民币）",
                    enumValues: nil
                ),
                "prefer_free_baggage": ParameterDefinition.string(
                    "是否优先选择免费行李额航班",
                    enumValues: ["true", "false"]
                )
            ],
            requiredParameters: ["origin", "destination", "departure_date"]
        )
    }
    // ✅ 重写 executeImpl 而不是 execute
override func executeImpl(arguments: [String: Any]) async throws -> ToolResult {
    let originInput = try getRequiredString("origin", from: arguments)
    let destinationInput = try getRequiredString("destination", from: arguments)
    let departureDate = try getRequiredString("departure_date", from: arguments)
    let returnDate = getString("return_date", from: arguments)
    
    // 转换城市名称为机场代码
    let origin = convertToAirportCode(originInput)
    let destination = convertToAirportCode(destinationInput)
    
    // 验证机场代码
    if origin.count != 3 {
        return errorResult("无法识别出发地：\(originInput)。请使用标准城市名称或3字母机场代码。")
    }
    
    if destination.count != 3 {
        return errorResult("无法识别目的地：\(destinationInput)。请使用标准城市名称或3字母机场代码。")
    }
    
    // 验证日期格式
    if !isValidDate(departureDate) {
        return errorResult("出发日期格式错误，请使用 YYYY-MM-DD 格式，如：2025-09-03")
    }
    
    let adults = Int(getNumber("adults", from: arguments) ?? 1)
    let travelClass = getString("travel_class", from: arguments) ?? "ECONOMY"
    let maxPrice = getNumber("max_price", from: arguments)
    let preferFreeBaggage = getBoolean("prefer_free_baggage", from: arguments) ?? true
    
    do {
        print("🔍 开始搜索航班: \(originInput)(\(origin)) → \(destinationInput)(\(destination))")
        
        // 搜索航班
        let searchResult = try await amadeus.searchFlights(
            origin: origin,
            destination: destination,
            departureDate: departureDate,
            returnDate: returnDate,
            adults: adults,
            travelClass: travelClass
        )
        
        print("✅ 搜索完成，找到 \(searchResult.flights.count) 个航班")
        
        // 筛选和排序
        let filteredFlights = filterAndRankFlights(
            flights: searchResult.flights,
            maxPrice: maxPrice,
            preferFreeBaggage: preferFreeBaggage
        )
        
        // 格式化结果
        let formattedResult = formatFlightResults(filteredFlights, from: originInput, to: destinationInput)
        
        return successResult(formattedResult, metadata: [
            "search_params": arguments,
            "results_count": filteredFlights.count,
            "currency": "CNY",
            "origin_code": origin,
            "destination_code": destination,
            "api_used": "amadeus_real"
        ])
        
    } catch {
        print("❌ 航班搜索失败: \(error)")
        
        // 提供更详细的错误信息
        var errorMessage = "航班搜索失败"
        
        if let nsError = error as NSError? {
            switch nsError.code {
            case 400:
                errorMessage = "搜索参数错误：\(nsError.localizedDescription)"
            case 401:
                errorMessage = "API 认证失败，请检查配置"
            case 404:
                errorMessage = "未找到航班信息，请尝试其他日期或路线"
            default:
                errorMessage = "网络错误：\(nsError.localizedDescription)"
            }
        }
        
        return errorResult(errorMessage, metadata: [
            "error_type": String(describing: type(of: error)),
            "search_params": arguments,
            "origin_code": origin,
            "destination_code": destination
        ])
    }
}

// ✅ 添加日期验证方法
private func isValidDate(_ dateString: String) -> Bool {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter.date(from: dateString) != nil
}
    
    // ✅ 添加城市名称转换方法
      private func convertToAirportCode(_ input: String) -> String {
          // 如果已经是3字母代码，直接返回
          if input.count == 3 && input.allSatisfy({ $0.isLetter }) {
              return input.uppercased()
          }
          
          // 查找城市映射
          if let airportCode = cityToAirportCode[input] {
              return airportCode
          }
          
          // 尝试模糊匹配
          let matchedCity = cityToAirportCode.keys.first { city in
              city.contains(input) || input.contains(city)
          }
          
          if let city = matchedCity, let code = cityToAirportCode[city] {
              return code
          }
          
          // 返回原始输入（让API返回更具体的错误）
          return input.uppercased()
      }
    
    // ✅ 修改格式化结果方法，显示城市名称
    private func formatFlightResults(_ flights: [FlightOffer], from originCity: String, to destinationCity: String) -> String {
        guard !flights.isEmpty else {
            return "❌ 未找到从 \(originCity) 到 \(destinationCity) 的航班\n\n💡 建议：\n• 检查城市名称是否正确\n• 尝试使用其他日期\n• 考虑周边城市的机场"
        }
        
        var result = "🛫 找到 \(flights.count) 个从 \(originCity) 到 \(destinationCity) 的航班选择：\n\n"
        
        for (index, flight) in flights.enumerated() {
            let score = calculateFlightScore(flight)
            result += "【选择 \(index + 1)】评分: \(String(format: "%.1f", score * 100))分\n"
            result += "✈️ 航班: \(flight.airlineName) \(flight.flightNumber)\n"
            result += "📍 路线: \(flight.origin) → \(flight.destination)\n"
            result += "⏰ 时间: \(flight.departureTime) → \(flight.arrivalTime)\n"
            result += "💰 价格: ¥\(Int(flight.price))\n"
            result += "⏱️ 时长: \(formatDuration(flight.totalDurationMinutes))\n"
            result += "🔄 转机: \(flight.numberOfStops == 0 ? "直飞 ✅" : "\(flight.numberOfStops)次转机")\n"
            result += "🧳 行李: \(flight.baggageInfo)\n"
            
            if flight.hasFreeBaggage {
                result += "🎁 免费行李额 ✅\n"
            }
            
        }
        
        return result
    }
    
    // MARK: - 私有方法（保持不变）
    
    private func filterAndRankFlights(
        flights: [FlightOffer],
        maxPrice: Double?,
        preferFreeBaggage: Bool
    ) -> [FlightOffer] {
        var filtered = flights
        
        // 价格筛选
        if let maxPrice = maxPrice {
            filtered = filtered.filter { $0.price <= maxPrice }
        }
        
        // 按优先级排序
        filtered.sort { flight1, flight2 in
            // 1. 优先考虑免费行李额
            if preferFreeBaggage {
                let flight1FreeBaggage = flight1.hasFreeBaggage
                let flight2FreeBaggage = flight2.hasFreeBaggage
                
                if flight1FreeBaggage != flight2FreeBaggage {
                    return flight1FreeBaggage
                }
            }
            
            // 2. 综合评分排序
            let score1 = calculateFlightScore(flight1)
            let score2 = calculateFlightScore(flight2)
            
            return score1 > score2
        }
        
        return Array(filtered.prefix(10))
    }
    
    private func calculateFlightScore(_ flight: FlightOffer) -> Double {
        let priceScore = max(0, 1000 - flight.price) / 1000.0
        let durationScore = max(0, 24 - Double(flight.totalDurationMinutes) / 60.0) / 24.0
        let stopScore = flight.numberOfStops == 0 ? 1.0 : (1.0 / Double(flight.numberOfStops + 1))
        let baggageScore = flight.hasFreeBaggage ? 1.0 : 0.5
        
        return priceScore * 0.4 + durationScore * 0.2 + stopScore * 0.2 + baggageScore * 0.2
    }
    
    private func formatFlightResults(_ flights: [FlightOffer]) -> String {
        guard !flights.isEmpty else {
            return "未找到符合条件的航班"
        }
        
        var result = "🛫 找到 \(flights.count) 个最优航班选择：\n\n"
        
        for (index, flight) in flights.enumerated() {
            let score = calculateFlightScore(flight)
            result += "【选择 \(index + 1)】评分: \(String(format: "%.1f", score * 100))分\n"
            result += "✈️ 航班: \(flight.airlineName) \(flight.flightNumber)\n"
            result += "📍 路线: \(flight.origin) → \(flight.destination)\n"
            result += "⏰ 时间: \(flight.departureTime) → \(flight.arrivalTime)\n"
            result += "💰 价格: ¥\(Int(flight.price))\n"
            result += "⏱️ 时长: \(formatDuration(flight.totalDurationMinutes))\n"
            result += "🔄 转机: \(flight.numberOfStops == 0 ? "直飞 ✅" : "\(flight.numberOfStops)次转机")\n"
            result += "🧳 行李: \(flight.baggageInfo)\n"
            
            if flight.hasFreeBaggage {
                result += "🎁 免费行李额 ✅\n"
            }
            
            // ✅ 修复字符串重复方法
            result += "\n" + String(repeating: "─", count: 30) + "\n\n"
        }
        
        return result
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)小时\(mins)分钟"
    }
}



// MARK: - Amadeus 服务

class AmadeusService {
    private let apiKey: String
    private let apiSecret: String
    private let environment: String
    private let baseURL: URL
    private let urlSession: URLSession
    private var accessToken: String?
    private var tokenExpiry: Date?
    
    init() {
        // ✅ 修复配置加载逻辑
        if let configPath = Bundle.main.path(forResource: "TicketConfig", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: configPath) as? [String: Any],
           let apiKey = config["AMADEUS_API_KEY"] as? String,
           let apiSecret = config["AMADEUS_API_SECRET"] as? String,
           let environment = config["AMADEUS_ENV"] as? String {
            
            self.apiKey = apiKey
            self.apiSecret = apiSecret
            self.environment = environment
            
            print("✅ 成功加载 Amadeus 配置: \(apiKey.prefix(8))..., 环境: \(environment)")
            
        } else {
            print("❌ 无法加载 TicketConfig.plist 配置文件")
            // ✅ 使用硬编码的配置作为备选
            self.apiKey = "pFiPhszAe3L03JyAQHbsVAFG3KaeGeca"
            self.apiSecret = "FCUBsUhhBWYfAe6L"
            self.environment = "test"
        }
        
        // 设置基础URL
        if environment == "test" {
            self.baseURL = URL(string: "https://test.api.amadeus.com")!
        } else {
            self.baseURL = URL(string: "https://api.amadeus.com")!
        }
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        self.urlSession = URLSession(configuration: sessionConfig)
    }
    
    func searchFlights(
        origin: String,
        destination: String,
        departureDate: String,
        returnDate: String? = nil,
        adults: Int = 1,
        travelClass: String = "ECONOMY"
    ) async throws -> FlightSearchResult {
        
        print("🔍 开始搜索航班: \(origin) → \(destination), 日期: \(departureDate)")
        
        do {
            // ✅ 确保有有效的访问令牌
            try await ensureValidToken()
            
            // 构建请求参数
            var parameters: [String: String] = [
                "originLocationCode": origin,
                "destinationLocationCode": destination,
                "departureDate": departureDate,
                "adults": String(adults),
                "travelClass": travelClass,
                "max": "10", // 减少返回数量以提高成功率
                "currencyCode": "CNY" // 指定货币
            ]
            
            if let returnDate = returnDate {
                parameters["returnDate"] = returnDate
            }
            
            print("📤 发送航班搜索请求，参数: \(parameters)")
            
            // 发送请求
            let data = try await sendRequest(
                endpoint: "/v2/shopping/flight-offers",
                method: "GET",
                parameters: parameters
            )
            
            print("📥 收到响应数据: \(data.count) 字节")
            
            // ✅ 添加详细的响应解析
            return try parseFlightResponse(data)
            
        } catch {
            print("❌ 航班搜索失败: \(error)")
            print("📝 错误详情: \(error.localizedDescription)")
            
            // ✅ 根据错误类型提供更好的处理
            if let nsError = error as NSError? {
                if nsError.code == 400 {
                    throw NSError(domain: "AmadeusService", code: 400, userInfo: [
                        NSLocalizedDescriptionKey: "请求参数错误: 请检查城市代码和日期格式"
                    ])
                } else if nsError.code == 401 {
                    throw NSError(domain: "AmadeusService", code: 401, userInfo: [
                        NSLocalizedDescriptionKey: "API 认证失败: 请检查 API 密钥配置"
                    ])
                }
            }
            
            throw error
        }
    }
    
    // ✅ 添加专门的响应解析方法
    private func parseFlightResponse(_ data: Data) throws -> FlightSearchResult {
        // 先检查是否是错误响应
        if let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // 检查是否有错误
            if let errors = responseDict["errors"] as? [[String: Any]] {
                let errorMessages = errors.compactMap { $0["detail"] as? String }
                throw NSError(domain: "AmadeusService", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: "API 错误: \(errorMessages.joined(separator: ", "))"
                ])
            }
            
            // 检查是否有数据
            if let dataArray = responseDict["data"] as? [[String: Any]], dataArray.isEmpty {
                return FlightSearchResult(flights: [])
            }
            
            // ✅ 打印一小部分原始响应用于调试
            if let prettyData = try? JSONSerialization.data(withJSONObject: responseDict, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                print("📋 API响应结构样本: \(String(prettyString.prefix(1000)))")
            }
        }
        
        do {
            // ✅ 使用自定义解码器，增加容错性
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // 尝试解析航班数据
            let response = try decoder.decode(AmadeusFlightResponse.self, from: data)
            print("✅ 成功解析 \(response.data.count) 个航班")
            
            // 转换为内部格式
            var flights: [FlightOffer] = []
            for (index, flightData) in response.data.enumerated() {
                do {
                    let flight = convertToFlightOffer(flightData)
                    flights.append(flight)
                    print("✅ 转换航班 \(index + 1): \(flight.flightNumber)")
                } catch {
                    print("⚠️ 跳过航班 \(index + 1) 转换失败: \(error)")
                    // 继续处理其他航班，不因为一个航班失败而全部失败
                }
            }
            
            return FlightSearchResult(flights: flights)
            
        } catch let error as DecodingError {
            print("❌ JSON 解析失败详情:")
            switch error {
            case .keyNotFound(let key, let context):
                print("  缺失字段: \(key.stringValue)")
                print("  路径: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            case .valueNotFound(let type, let context):
                print("  值缺失: \(type)")
                print("  路径: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            case .typeMismatch(let type, let context):
                print("  类型不匹配: \(type)")
                print("  路径: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            case .dataCorrupted(let context):
                print("  数据损坏: \(context.debugDescription)")
            @unknown default:
                print("  未知解析错误: \(error)")
            }
            
            // 打印原始响应以便调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 原始响应（前1000字符）: \(String(responseString.prefix(1000)))")
            }
            
            throw NSError(domain: "AmadeusService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "JSON解析失败: \(error.localizedDescription)"
            ])
        } catch {
            print("❌ 其他解析错误: \(error)")
            throw NSError(domain: "AmadeusService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "响应解析失败: \(error.localizedDescription)"
            ])
        }
    }
    
    // ✅ 改进访问令牌获取
    private func ensureValidToken() async throws {
        if let token = accessToken,
           let expiry = tokenExpiry,
           expiry > Date() {
            print("✅ 使用现有有效令牌")
            return
        }
        
        print("🔑 获取新的访问令牌...")
        try await getAccessToken()
    }
    
    private func getAccessToken() async throws {
        let url = baseURL.appendingPathComponent("/v1/security/oauth2/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "grant_type=client_credentials&client_id=\(apiKey)&client_secret=\(apiSecret)"
        request.httpBody = body.data(using: .utf8)
        
        print("📤 请求访问令牌: \(url)")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📥 令牌响应状态: \(httpResponse.statusCode)")
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ 令牌获取失败: \(errorMessage)")
            throw NSError(domain: "AmadeusService", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "获取访问令牌失败: \(errorMessage)"
            ])
        }
        
        do {
            let tokenResponse = try JSONDecoder().decode(AmadeusTokenResponse.self, from: data)
            self.accessToken = tokenResponse.access_token
            self.tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in - 60))
            print("✅ 成功获取访问令牌，有效期到: \(tokenExpiry!)")
        } catch {
            let responseString = String(data: data, encoding: .utf8) ?? "无法解析响应"
            print("❌ 令牌解析失败: \(error), 响应: \(responseString)")
            throw error
        }
    }
    
    private func sendRequest(
        endpoint: String,
        method: String = "GET",
        parameters: [String: String]? = nil
    ) async throws -> Data {
        
        var url = baseURL.appendingPathComponent(endpoint)
        
        // 添加查询参数
        if let parameters = parameters, method == "GET" {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = parameters.map { URLQueryItem(name: $0, value: $1) }
            url = components.url!
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("📤 发送请求: \(method) \(url)")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📥 响应状态: \(httpResponse.statusCode)")
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ HTTP 错误 \(httpResponse.statusCode): \(errorMessage)")
            throw NSError(
                domain: "AmadeusService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
        }
        
        return data
    }
    
 private func convertToFlightOffer(_ data: AmadeusFlightData) -> FlightOffer {
    // ✅ 安全地解析价格
    let price = Double(data.price.total) ?? 0
    
    // ✅ 安全地获取航段信息
    let segments = data.itineraries.flatMap { $0.segments }
    guard let firstSegment = segments.first,
          let lastSegment = segments.last else {
        // 创建默认航班信息
        return createDefaultFlightOffer(id: data.id, price: price)
    }
    
    let departure = firstSegment.departure
    let arrival = lastSegment.arrival
    
    // ✅ 安全地计算时长
    let totalDuration = calculateTotalDuration(data.itineraries)
    let numberOfStops = max(0, segments.count - 1)
    
    // ✅ 安全地检查行李政策
    let hasFreeBaggage = checkFreeBaggage(data)
    let baggageInfo = formatBaggageInfo(data)
    
    // ✅ 安全地获取航空公司信息
    let carrierCode = firstSegment.carrierCode
    let flightNumber = "\(carrierCode)\(firstSegment.number)"
    
    return FlightOffer(
        id: data.id,
        airlineName: getAirlineName(carrierCode),
        flightNumber: flightNumber,
        origin: departure.iataCode,
        destination: arrival.iataCode,
        departureTime: formatDateTime(departure.at),
        arrivalTime: formatDateTime(arrival.at),
        price: price,
        totalDurationMinutes: totalDuration,
        numberOfStops: numberOfStops,
        hasFreeBaggage: hasFreeBaggage,
        baggageInfo: baggageInfo
    )
}

// ✅ 添加默认航班创建方法
private func createDefaultFlightOffer(id: String, price: Double) -> FlightOffer {
    return FlightOffer(
        id: id,
        airlineName: "未知航空",
        flightNumber: "N/A",
        origin: "N/A",
        destination: "N/A",
        departureTime: "N/A",
        arrivalTime: "N/A",
        price: price,
        totalDurationMinutes: 0,
        numberOfStops: 0,
        hasFreeBaggage: false,
        baggageInfo: "信息不完整"
    )
}
    
    // ✅ 改进时间格式化
    private func formatDateTime(_ dateTime: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateTime) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            displayFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai") // 使用北京时间
            return displayFormatter.string(from: date)
        }
        
        // 备用格式化
        if dateTime.contains("T") {
            let parts = dateTime.components(separatedBy: "T")
            if parts.count > 1 {
                let timePart = parts[1].components(separatedBy: ":")
                if timePart.count >= 2 {
                    return "\(timePart[0]):\(timePart[1])"
                }
            }
        }
        
        return dateTime
    }
    
    private func calculateTotalDuration(_ itineraries: [AmadeusItinerary]) -> Int {
        // 简化计算：返回第一个行程的总时长（分钟）
        guard let duration = itineraries.first?.duration else { return 0 }
        return parseDuration(duration)
    }
    
    private func parseDuration(_ duration: String) -> Int {
        // 解析 ISO 8601 duration 格式 (PT2H30M)
        let pattern = "PT(?:(\\d+)H)?(?:(\\d+)M)?"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: duration.utf16.count)
        
        guard let match = regex?.firstMatch(in: duration, options: [], range: range) else {
            return 0
        }
        
        var totalMinutes = 0
        
        // 小时
        if match.range(at: 1).location != NSNotFound,
           let hoursRange = Range(match.range(at: 1), in: duration),
           let hours = Int(duration[hoursRange]) {
            totalMinutes += hours * 60
        }
        
        // 分钟
        if match.range(at: 2).location != NSNotFound,
           let minutesRange = Range(match.range(at: 2), in: duration),
           let minutes = Int(duration[minutesRange]) {
            totalMinutes += minutes
        }
        
        return totalMinutes
    }
    
    private func checkFreeBaggage(_ data: AmadeusFlightData) -> Bool {
        // ✅ 增强的行李检查逻辑
        for travelerPricing in data.travelerPricings {
            for fareDetails in travelerPricing.fareDetailsBySegment {
                if let includedCheckedBags = fareDetails.includedCheckedBags,
                   let quantity = includedCheckedBags.quantity,
                   quantity > 0 {
                    return true
                }
            }
        }
        
        // 检查 pricingOptions 中的行李信息
        if let pricingOptions = data.pricingOptions,
           pricingOptions.includedCheckedBagsOnly == true {
            return true
        }
        
        return false
    }

    private func formatBaggageInfo(_ data: AmadeusFlightData) -> String {
        // ✅ 增强的行李信息格式化
        var baggageInfos: [String] = []
        
        for travelerPricing in data.travelerPricings {
            for fareDetails in travelerPricing.fareDetailsBySegment {
                if let includedCheckedBags = fareDetails.includedCheckedBags {
                    if let quantity = includedCheckedBags.quantity, quantity > 0 {
                        var info = "免费托运行李 \(quantity) 件"
                        
                        if let weight = includedCheckedBags.weight,
                           let unit = includedCheckedBags.weightUnit {
                            info += "（每件\(weight)\(unit)）"
                        }
                        
                        baggageInfos.append(info)
                    } else {
                        baggageInfos.append("无免费托运行李")
                    }
                }
            }
        }
        
        if baggageInfos.isEmpty {
            return "行李政策：请联系航空公司确认"
        }
        
        // 返回第一个有效的行李信息（通常所有段的政策相同）
        return baggageInfos.first ?? "行李政策：请联系航空公司确认"
    }
    
    private func getAirlineName(_ code: String) -> String {
        // 航空公司代码映射，这里只是示例
        let airlines = [
            "CA": "中国国际航空",
            "MU": "中国东方航空",
            "CZ": "中国南方航空",
            "3U": "四川航空",
            "9C": "春秋航空"
        ]
        return airlines[code] ?? code
    }
    

}

// MARK: - 数据模型
struct FlightSearchResult {
    let flights: [FlightOffer]
}

struct FlightOffer {
    let id: String
    let airlineName: String
    let flightNumber: String
    let origin: String
    let destination: String
    let departureTime: String
    let arrivalTime: String
    let price: Double
    let totalDurationMinutes: Int
    let numberOfStops: Int
    let hasFreeBaggage: Bool
    let baggageInfo: String
}
struct AmadeusTokenResponse: Codable {
    let access_token: String
    let expires_in: Int
}

struct AmadeusFlightResponse: Codable {
    let data: [AmadeusFlightData]
    let meta: AmadeusMeta?
    let dictionaries: AmadeusDictionaries?
}

struct AmadeusMeta: Codable {
    let count: Int?
    let links: AmadeusLinks?
}

struct AmadeusLinks: Codable {
    let `self`: String?
}

struct AmadeusDictionaries: Codable {
    let locations: [String: AmadeusLocationInfo]?
    let aircrafts: [String: AmadeusAircraftInfo]?
    let currencies: [String: String]?
    let carriers: [String: String]?
}

struct AmadeusLocationInfo: Codable {
    let cityCode: String?
    let countryCode: String?
}

struct AmadeusAircraftInfo: Codable {
    let code: String?
    let name: String?
}

struct AmadeusFlightData: Codable {
    let type: String?
    let id: String
    let source: String?
    let instantTicketingRequired: Bool?
    let nonHomogeneous: Bool?
    let oneWay: Bool?
    let isUpsellOffer: Bool?
    let lastTicketingDate: String?
    let lastTicketingDateTime: String?
    let numberOfBookableSeats: Int?
    let price: AmadeusPrice
    let itineraries: [AmadeusItinerary]
    let travelerPricings: [AmadeusTravelerPricing]
    let pricingOptions: AmadeusPricingOptions?
    let validatingAirlineCodes: [String]?
}

struct AmadeusPricingOptions: Codable {
    let fareType: [String]?
    let includedCheckedBagsOnly: Bool?
}

struct AmadeusPrice: Codable {
    let currency: String
    let total: String
    let base: String?
    let fees: [AmadeusFee]?
    let grandTotal: String?
    let billingCurrency: String?
}

struct AmadeusFee: Codable {
    let amount: String?
    let type: String?
}

struct AmadeusItinerary: Codable {
    let duration: String
    let segments: [AmadeusSegment]
}

struct AmadeusSegment: Codable {
    let departure: AmadeusLocation
    let arrival: AmadeusLocation
    let carrierCode: String
    let number: String
    let aircraft: AmadeusAircraft?
    let operating: AmadeusOperating?
    let duration: String?
    let id: String?
    let numberOfStops: Int?
    let blacklistedInEU: Bool?
    let co2Emissions: [AmadeusCO2Emission]?
}

struct AmadeusAircraft: Codable {
    let code: String?
}

struct AmadeusOperating: Codable {
    let carrierCode: String?
}

struct AmadeusCO2Emission: Codable {
    let weight: Int?
    let weightUnit: String?
    let cabin: String?
}

struct AmadeusLocation: Codable {
    let iataCode: String
    let terminal: String?
    let at: String
}

struct AmadeusTravelerPricing: Codable {
    let travelerId: String?
    let fareOption: String?
    let travelerType: String?
    let price: AmadeusTravelerPrice?
    let fareDetailsBySegment: [AmadeusFareDetails]
}

struct AmadeusTravelerPrice: Codable {
    let currency: String?
    let total: String?
    let base: String?
    let fees: [AmadeusFee]?
    let taxes: [AmadeusTax]?
    let refundableTaxes: String?
}

struct AmadeusTax: Codable {
    let amount: String?
    let code: String?
}

struct AmadeusFareDetails: Codable {
    let segmentId: String?
    let cabin: String?
    let fareBasis: String?
    let brandedFare: String?
    let `class`: String?
    let includedCheckedBags: AmadeusBaggage?
    let amenities: [AmadeusAmenity]?
}

struct AmadeusAmenity: Codable {
    let description: String?
    let isChargeable: Bool?
    let amenityType: String?
    let amenityProvider: AmadeusAmenityProvider?
}

struct AmadeusAmenityProvider: Codable {
    let name: String?
}

// ✅ 关键修复：让 AmadeusBaggage 完全可选
struct AmadeusBaggage: Codable {
    let quantity: Int?
    let weight: Int?
    let weightUnit: String?
    
    // ✅ 自定义解码器处理各种情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 安全解析 quantity
        if container.contains(.quantity) {
            if let quantityInt = try? container.decode(Int.self, forKey: .quantity) {
                self.quantity = quantityInt
            } else if let quantityString = try? container.decode(String.self, forKey: .quantity),
                      let quantityInt = Int(quantityString) {
                self.quantity = quantityInt
            } else {
                self.quantity = nil
            }
        } else {
            self.quantity = nil
        }
        
        // 安全解析 weight
        if container.contains(.weight) {
            self.weight = try? container.decode(Int.self, forKey: .weight)
        } else {
            self.weight = nil
        }
        
        // 安全解析 weightUnit
        if container.contains(.weightUnit) {
            self.weightUnit = try? container.decode(String.self, forKey: .weightUnit)
        } else {
            self.weightUnit = nil
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case quantity
        case weight
        case weightUnit
    }
}
