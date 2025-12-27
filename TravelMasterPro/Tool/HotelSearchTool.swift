//
//  HotelSearchTool.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import Foundation

/// 酒店搜索工具 - 提供全面的酒店搜索和筛选功能
class HotelSearchTool: BaseTool {
    
    init() {
        super.init(
            name: "hotel_search",
            description: "搜索酒店信息，支持位置、价格、设施、评分等多维度筛选",
            parameters: [
                "city": ParameterDefinition(
                    type: "string",
                    description: "目标城市名称",
                    enumValues: nil
                ),
                "checkin_date": ParameterDefinition(
                    type: "string",
                    description: "入住日期 (YYYY-MM-DD 格式)",
                    enumValues: nil
                ),
                "checkout_date": ParameterDefinition(
                    type: "string",
                    description: "退房日期 (YYYY-MM-DD 格式)",
                    enumValues: nil
                ),
                "location": ParameterDefinition(
                    type: "string",
                    description: "具体位置（地址、地标、地铁站等）",
                    enumValues: nil
                ),
                "min_price": ParameterDefinition(
                    type: "number",
                    description: "最低价格（人民币/晚）",
                    enumValues: nil
                ),
                "max_price": ParameterDefinition(
                    type: "number",
                    description: "最高价格（人民币/晚）",
                    enumValues: nil
                ),
                "star_rating": ParameterDefinition.string(
                    "酒店星级",
                    enumValues: ["1", "2", "3", "4", "5", "any"]
                ),
                "amenities": ParameterDefinition(
                    type: "string",
                    description: "必需设施，逗号分隔（wifi,pool,gym,breakfast,parking）",
                    enumValues: nil
                ),
                "hotel_type": ParameterDefinition.string(
                    "酒店类型",
                    enumValues: ["hotel", "resort", "apartment", "hostel", "guesthouse", "any"]
                ),
                "near_metro": ParameterDefinition.string(
                    "是否靠近地铁",
                    enumValues: ["true", "false"]
                ),
                "max_walk_minutes": ParameterDefinition(
                    type: "number",
                    description: "到地铁站最大步行分钟数",
                    enumValues: nil
                ),
                "guests": ParameterDefinition(
                    type: "number",
                    description: "入住人数",
                    enumValues: nil
                ),
                "rooms": ParameterDefinition(
                    type: "number",
                    description: "房间数量",
                    enumValues: nil
                ),
                "sort_by": ParameterDefinition.string(
                    "排序方式",
                    enumValues: ["price", "rating", "distance", "popularity"]
                ),
                "max_results": ParameterDefinition(
                    type: "number",
                    description: "最大返回结果数",
                    enumValues: nil
                )
            ],
            requiredParameters: ["city", "checkin_date", "checkout_date"]
        )
    }
    
    override func executeImpl(arguments: [String: Any]) async throws -> ToolResult {
        print("🔍 酒店搜索参数: \(arguments)")
        
        // ✅ 获取并预处理参数（只声明一次）
          let city = try getRequiredString("city", from: arguments)
          let location = getString("location", from: arguments)
          
          // ✅ 智能日期处理 - 增加更多调试信息
          let rawCheckinDate = try getRequiredString("checkin_date", from: arguments)
          let rawCheckoutDate = try getRequiredString("checkout_date", from: arguments)
          
          print("📅 原始日期: \(rawCheckinDate) → \(rawCheckoutDate)")
          
          // 预处理日期格式 - 包含智能年份纠正
          let checkinDate = preprocessDate(rawCheckinDate)
          let checkoutDate = preprocessDate(rawCheckoutDate)
          
          print("📅 处理后的日期: \(checkinDate) → \(checkoutDate)")
          
          // 如果日期被纠正了，给用户一个友好的提示
          if rawCheckinDate != checkinDate || rawCheckoutDate != checkoutDate {
              print("💡 日期已自动调整到合理的未来时间")
          }
        
        // 安全地转换数字参数
        let guests = Int(getNumber("guests", from: arguments) ?? 2)
        let rooms = Int(getNumber("rooms", from: arguments) ?? 1)
        
        // 筛选条件
        let minPrice = getNumber("min_price", from: arguments)
        let maxPrice = getNumber("max_price", from: arguments)
        let starRating = getString("star_rating", from: arguments)
        let amenities = getString("amenities", from: arguments)?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
        let hotelType = getString("hotel_type", from: arguments) ?? "any"
        let nearMetro = getBoolean("near_metro", from: arguments) ?? (location?.contains("地铁") == true)
        
        // 修复 maxWalkMinutes 参数获取
        let maxWalkMinutes: Int
        if let walkMinutesString = getString("max_walk_minutes", from: arguments),
           let walkMinutesInt = Int(walkMinutesString) {
            maxWalkMinutes = walkMinutesInt
        } else if let walkMinutesNumber = getNumber("max_walk_minutes", from: arguments) {
            maxWalkMinutes = Int(walkMinutesNumber)
        } else {
            maxWalkMinutes = 15 // 默认15分钟
        }
        
        let sortBy = getString("sort_by", from: arguments) ?? "rating"
        let maxResults = Int(getNumber("max_results", from: arguments) ?? 8)
        
        print("📋 搜索配置: 城市=\(city), 位置=\(location ?? "无"), 地铁限制=\(nearMetro), 步行时间≤\(maxWalkMinutes)分钟")
        
        do {
            // 验证日期
            try validateDates(checkin: checkinDate, checkout: checkoutDate)
            
            // 创建搜索服务
            let searchService = HotelSearchService()
            
            // 执行搜索
            let searchResults = try await searchService.searchHotels(
                city: city,
                location: location,
                checkinDate: checkinDate,
                checkoutDate: checkoutDate,
                guests: guests,
                rooms: rooms
            )
            
            print("🔍 原始搜索结果: \(searchResults.count) 个酒店")
            
            // 应用筛选条件
            let filteredResults = try await applyFilters(
                hotels: searchResults,
                minPrice: minPrice,
                maxPrice: maxPrice,
                starRating: starRating,
                amenities: amenities,
                hotelType: hotelType,
                nearMetro: nearMetro,
                maxWalkMinutes: maxWalkMinutes,
                city: city
            )
            
            print("🔍 筛选后结果: \(filteredResults.count) 个酒店")
            
            // 排序和限制结果
            let sortedResults = sortHotels(filteredResults, by: sortBy)
            let finalResults = Array(sortedResults.prefix(maxResults))
            
            // 格式化结果
            let formattedResult = formatHotelResults(
                hotels: finalResults,
                city: city,
                location: location,
                checkinDate: checkinDate,
                checkoutDate: checkoutDate,
                maxWalkMinutes: maxWalkMinutes,
                searchCriteria: arguments
            )
            
            return successResult(formattedResult, metadata: [
                "total_found": searchResults.count,
                "after_filtering": filteredResults.count,
                "returned": finalResults.count,
                "search_location": location ?? city,
                "price_range": [minPrice, maxPrice].compactMap { $0 },
                "near_metro": nearMetro,
                "max_walk_minutes": maxWalkMinutes
            ])
            
        } catch {
            print("❌ 酒店搜索失败: \(error)")
            return errorResult("酒店搜索失败: \(error.localizedDescription)")
        }
    }
    
    private func smartYearCorrection(_ dateString: String) -> String {
    // 检测明显错误的年份并自动纠正
    let currentYear = Calendar.current.component(.year, from: Date())
    
    // 处理 2024 年的情况（在 2025 年应该纠正为 2025）
    if dateString.contains("2024-") && currentYear >= 2025 {
        let corrected = dateString.replacingOccurrences(of: "2024-", with: "\(currentYear)-")
        print("🔧 自动年份纠正: \(dateString) → \(corrected)")
        return corrected
    }
    
    // 处理其他明显的过去年份
    let pattern = "20(\\d{2})-(\\d{1,2})-(\\d{1,2})"
    if let regex = try? NSRegularExpression(pattern: pattern) {
        let nsString = dateString as NSString
        let results = regex.matches(in: dateString, range: NSRange(location: 0, length: nsString.length))
        
        for match in results {
            if let yearRange = Range(match.range(at: 1), in: dateString) {
                let yearStr = String(dateString[yearRange])
                if let year = Int("20" + yearStr), year < currentYear {
                    let corrected = dateString.replacingOccurrences(of: "20\(yearStr)-", with: "\(currentYear)-")
                    print("🔧 智能年份纠正: \(dateString) → \(corrected)")
                    return corrected
                }
            }
        }
    }
    
    return dateString
}
    // MARK: - 私有方法
    
    private func preprocessDate(_ dateString: String) -> String {
        // 清理日期字符串
        var cleaned = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = smartYearCorrection(cleaned)
        // 处理中文日期格式转换
        cleaned = cleaned.replacingOccurrences(of: "年", with: "-")
        cleaned = cleaned.replacingOccurrences(of: "月", with: "-")
        cleaned = cleaned.replacingOccurrences(of: "日", with: "")
        
        // 处理斜杠格式
        cleaned = cleaned.replacingOccurrences(of: "/", with: "-")
        
        // ✅ 智能年份纠正 - 如果是过去的年份，自动调整为未来年份
        if cleaned.hasPrefix("2024-") {
            cleaned = cleaned.replacingOccurrences(of: "2024-", with: "2025-")
            print("📅 自动纠正年份: \(dateString) → \(cleaned)")
        }
        
        // 如果是两位数年份，转换为四位数
        if cleaned.hasPrefix("24-") {
            cleaned = "2025-" + cleaned.dropFirst(3)
            print("📅 年份调整: \(dateString) → \(cleaned)")
        } else if cleaned.hasPrefix("25-") {
            cleaned = "20" + cleaned
        }
        
        // 如果没有年份且格式是 MM-DD，自动添加当前年份或下一年
        if cleaned.count == 5 && cleaned.contains("-") && !cleaned.hasPrefix("20") {
            let currentYear = Calendar.current.component(.year, from: Date())
            let components = cleaned.split(separator: "-")
            if components.count == 2, let month = Int(components[0]), month >= 1, month <= 12 {
                // 如果月份小于当前月份，使用下一年
                let currentMonth = Calendar.current.component(.month, from: Date())
                let year = month < currentMonth ? currentYear + 1 : currentYear
                cleaned = "\(year)-\(cleaned)"
                print("📅 添加年份: \(dateString) → \(cleaned)")
            }
        }
        
        return cleaned
    }
    
    private func validateDates(checkin: String, checkout: String) throws {
        do {
            let (checkinDate, checkoutDate) = try parseSmartDates(checkin: checkin, checkout: checkout)
            
            guard checkinDate < checkoutDate else {
                throw ToolError.executionFailed("退房日期必须晚于入住日期")
            }
            
            // ✅ 更宽松的过去日期处理 - 自动纠正到未来年份
            let currentDate = Date()
            if checkinDate < currentDate {
                // 计算需要调整的年份数
                let calendar = Calendar.current
                let currentYear = calendar.component(.year, from: currentDate)
                let checkinYear = calendar.component(.year, from: checkinDate)
                
                if checkinYear < currentYear {
                    // 如果是明显的过去年份，给出友好提示而不是直接报错
                    print("⚠️ 检测到过去年份 \(checkinYear)，已自动调整")
                    print("✅ 日期验证通过（已调整）: \(checkin) → \(checkout)")
                    return // 已经在 preprocessDate 中调整过了
                }
                
                // 如果是同年但过去的日期，检查是否在合理范围内
                let daysDiff = calendar.dateComponents([.day], from: checkinDate, to: currentDate).day ?? 0
                if daysDiff > 3 {
                    throw ToolError.executionFailed("""
                    入住日期似乎是过去的日期。
                    检测到的日期：\(checkin)
                    💡 请确认您要预订的是未来日期。
                    """)
                }
            }
            
            print("✅ 日期验证通过: \(checkin) → \(checkout)")
            
        } catch let error as ToolError {
            throw error
        } catch {
            throw ToolError.executionFailed("日期解析失败：\(error.localizedDescription)")
        }
    }
    
    // ✅ 智能日期解析方法
    private func parseSmartDates(checkin: String, checkout: String) throws -> (Date, Date) {
        let formatter = DateFormatter()
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentDate = Date()
        
        // 尝试多种日期格式
        let dateFormats = [
            "yyyy-MM-dd",    // 完整格式
            "MM-dd",         // 月-日格式
            "M-d",           // 单位数月日格式
            "yyyy/MM/dd",    // 斜杠格式
            "MM/dd",         // 斜杠月日格式
        ]
        
        var checkinDate: Date?
        var checkoutDate: Date?
        
        // 解析入住日期
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: checkin) {
                checkinDate = smartAdjustYear(date: date, currentDate: currentDate, currentYear: currentYear)
                break
            }
        }
        
        // 解析退房日期
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: checkout) {
                checkoutDate = smartAdjustYear(date: date, currentDate: currentDate, currentYear: currentYear)
                break
            }
        }
        
        guard let checkin = checkinDate, let checkout = checkoutDate else {
            throw ToolError.executionFailed("日期格式错误。支持格式：YYYY-MM-DD, MM-DD, YYYY/MM/DD, MM/DD")
        }
        
        return (checkin, checkout)
    }
    
    // ✅ 智能年份调整
    private func smartAdjustYear(date: Date, currentDate: Date, currentYear: Int) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.month, .day], from: date)
        let currentComponents = calendar.dateComponents([.month, .day], from: currentDate)
        
        // 如果解析出的日期没有年份信息，需要智能推断
        let dateYear = calendar.component(.year, from: date)
        
        // 如果年份是1970年（默认年份），说明原始输入没有年份
        if dateYear == 1970 {
            // 如果月份小于当前月份，或者月份相同但日期小于当前日期，推断为下一年
            if let month = dateComponents.month, let day = dateComponents.day,
               let currentMonth = currentComponents.month, let currentDay = currentComponents.day {
                
                let targetYear: Int
                if month < currentMonth || (month == currentMonth && day < currentDay - 3) {
                    targetYear = currentYear + 1
                } else {
                    targetYear = currentYear
                }
                
                var adjustedComponents = dateComponents
                adjustedComponents.year = targetYear
                return calendar.date(from: adjustedComponents) ?? date
            }
        }
        
        return date
    }
    
    private func applyFilters(
        hotels: [HotelInfo],
        minPrice: Double?,
        maxPrice: Double?,
        starRating: String?,
        amenities: [String],
        hotelType: String,
        nearMetro: Bool,
        maxWalkMinutes: Int,
        city: String
    ) async throws -> [HotelInfo] {
        
        var filtered = hotels
        
        // 价格筛选
        if let minPrice = minPrice {
            filtered = filtered.filter { $0.pricePerNight >= minPrice }
        }
        if let maxPrice = maxPrice {
            filtered = filtered.filter { $0.pricePerNight <= maxPrice }
        }
        
        // 星级筛选
        if let starRating = starRating, starRating != "any", let rating = Int(starRating) {
            filtered = filtered.filter { $0.starRating >= rating }
        }
        
        // 酒店类型筛选
        if hotelType != "any" {
            filtered = filtered.filter { $0.type.lowercased() == hotelType.lowercased() }
        }
        
        // 设施筛选
        if !amenities.isEmpty {
            filtered = filtered.filter { hotel in
                amenities.allSatisfy { amenity in
                    hotel.amenities.contains { $0.lowercased().contains(amenity.lowercased()) }
                }
            }
        }
        
        // 地铁站筛选
        if nearMetro {
            let config = try MapConfiguration.load()
            let amapService = AMapService(config: config)
            
            var metroFilteredHotels: [HotelInfo] = []
            for hotel in filtered {
                do {
                    let isNearMetro = try await isHotelNearMetro(
                        hotel: hotel,
                        city: city,
                        maxWalkMinutes: maxWalkMinutes,
                        amapService: amapService
                    )
                    if isNearMetro {
                        metroFilteredHotels.append(hotel)
                    }
                } catch {
                    // 如果检查失败，保留酒店（避免因网络问题丢失结果）
                    metroFilteredHotels.append(hotel)
                }
            }
            filtered = metroFilteredHotels
        }
        
        return filtered
    }
    
    private func isHotelNearMetro(
        hotel: HotelInfo,
        city: String,
        maxWalkMinutes: Int,
        amapService: AMapService
    ) async throws -> Bool {
        // 搜索酒店附近的地铁站
        let location = hotel.location
        let components = location.split(separator: ",")
        guard components.count == 2,
              let lng = Double(components[0]),
              let lat = Double(components[1]) else {
            return false
        }
        
        // 搜索附近的地铁站
        let nearbyStations = try await amapService.searchNearbyMetroStations(
            lng: lng,
            lat: lat,
            radius: maxWalkMinutes * 100 // 粗略估算：100米/分钟
        )
        
        // 检查是否有地铁站在步行范围内
        for station in nearbyStations {
            do {
                let walkingTime = try await amapService.walkingSecs(
                    origin: (lng, lat),
                    dest: station.location
                )
                let walkingMinutes = Int(ceil(Double(walkingTime) / 60.0))
                if walkingMinutes <= maxWalkMinutes {
                    return true
                }
            } catch {
                continue
            }
        }
        
        return false
    }
    
    private func sortHotels(_ hotels: [HotelInfo], by sortBy: String) -> [HotelInfo] {
        switch sortBy {
        case "price":
            return hotels.sorted { $0.pricePerNight < $1.pricePerNight }
        case "rating":
            return hotels.sorted { $0.rating > $1.rating }
        case "distance":
            return hotels.sorted { ($0.distanceFromCenter ?? Double.greatestFiniteMagnitude) < ($1.distanceFromCenter ?? Double.greatestFiniteMagnitude) }
        case "popularity":
            return hotels.sorted { $0.reviewCount > $1.reviewCount }
        default:
            return hotels.sorted { $0.rating > $1.rating }
        }
    }
    
    private func formatHotelResults(
        hotels: [HotelInfo],
        city: String,
        location: String?,
        checkinDate: String,
        checkoutDate: String,
        maxWalkMinutes: Int,
        searchCriteria: [String: Any]
    ) -> String {
        guard !hotels.isEmpty else {
            let locationDesc = location != nil ? "\(city)\(location!)" : city
            return """
            🏨 【\(locationDesc) 酒店搜索】
            📅 \(checkinDate) → \(checkoutDate)
            
            ❌ 未找到符合条件的酒店
            
            💡 建议：
            • 放宽价格范围
            • 增加地铁步行时间
            • 尝试附近其他区域
            """
        }
        
        let locationDesc = location != nil ? "\(location!)" : "\(city)市区"
        var result = """
        🏨 【\(locationDesc) 精选酒店】
        📅 \(checkinDate) → \(checkoutDate)
        🔍 找到 \(hotels.count) 家优质酒店
        
        """
        
        for (index, hotel) in hotels.enumerated() {
            let starsDisplay = String(repeating: "⭐️", count: hotel.starRating)
            let walkInfo = hotel.nearestMetro ?? "📍 位置便利"
            
            result += """
            【酒店 \(index + 1)】\(starsDisplay)
            🏨 \(hotel.name)
            📍 \(hotel.address)
            💰 ¥\(Int(hotel.pricePerNight))/晚
            ⭐️ \(String(format: "%.1f", hotel.rating))分 (\(hotel.reviewCount)条评价)
            \(walkInfo)
            🎯 \(hotel.amenities.prefix(4).joined(separator: "、"))
            
            """
        }
        
        result += """
        ---
        💡 搜索条件：步行≤\(maxWalkMinutes)分钟到地铁站
        📞 如需预订可联系各酒店前台
        """
        
        return result
    }
} // ✅ HotelSearchTool 类结束

// MARK: - 数据模型

/// 酒店信息
struct HotelInfo {
    let id: String
    let name: String
    let address: String
    let location: String // "lng,lat"
    let starRating: Int
    let rating: Double
    let reviewCount: Int
    let pricePerNight: Double
    let type: String
    let amenities: [String]
    let imageUrls: [String]
    let nearestMetro: String?
    let distanceFromCenter: Double?
}

/// 酒店搜索服务
class HotelSearchService {
    
    func searchHotels(
        city: String,
        location: String?,
        checkinDate: String,
        checkoutDate: String,
        guests: Int,
        rooms: Int
    ) async throws -> [HotelInfo] {
        
        print("🔍 开始搜索酒店: 城市=\(city), 位置=\(location ?? "无"), 入住=\(checkinDate)")
        
        do {
            // 加载高德地图配置
            let config = try MapConfiguration.load()
            let amapService = AMapService(config: config)
            
            // 获取搜索位置的坐标
            let searchAddress = location != nil ? "\(city)\(location!)" : city
            print("📍 正在解析地址: \(searchAddress)")
            
            let (lng, lat) = try await amapService.geocode(address: searchAddress)
            print("📍 搜索坐标: (\(lng), \(lat))")
            
            // 搜索周边酒店POI
            let hotelPOIs = try await amapService.searchHotelsAround(
                lng: lng,
                lat: lat,
                radius: 5000, // 扩大到5公里范围
                limit: 50
            )
            
            print("🏨 找到 \(hotelPOIs.count) 个酒店POI")
            
            if hotelPOIs.isEmpty {
                print("⚠️ 未找到酒店POI，可能是位置过于具体")
                // 尝试更宽泛的搜索
                let cityCoords = try await amapService.geocode(address: city)
                let cityHotels = try await amapService.searchHotelsAround(
                    lng: cityCoords.0,
                    lat: cityCoords.1,
                    radius: 10000,
                    limit: 30
                )
                print("🏨 城市级搜索找到 \(cityHotels.count) 个酒店")
                return try await convertPOIsToHotels(cityHotels, checkinDate: checkinDate, amapService: amapService)
            }
            
            // 转换为 HotelInfo 格式
            return try await convertPOIsToHotels(hotelPOIs, checkinDate: checkinDate, amapService: amapService)
            
        } catch let error as AMapError {
            print("❌ 高德地图API错误: \(error.localizedDescription)")
            throw ToolError.executionFailed("地图服务错误: \(error.localizedDescription)")
        } catch {
            print("❌ 酒店搜索异常: \(error)")
            throw ToolError.executionFailed("酒店搜索失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 私有方法
    
    private func convertPOIsToHotels(
        _ pois: [POIInfo],
        checkinDate: String,
        amapService: AMapService
    ) async throws -> [HotelInfo] {
        
        var hotelInfos: [HotelInfo] = []
        
        for (index, poi) in pois.enumerated() {
            print("🔄 处理酒店 \(index + 1): \(poi.name)")
            
            let starRating = extractStarRating(from: poi.name)
            let basePrice = generatePrice(starRating: starRating)
            let adjustedPrice = adjustPriceByDate(basePrice: basePrice, checkinDate: checkinDate)
            
            // 安全地处理可能为空的字段
            let hotelInfo = HotelInfo(
                id: poi.id ?? "hotel_\(index)",
                name: poi.name,
                address: poi.address ?? "地址待确认",
                location: poi.location,
                starRating: starRating,
                rating: generateRating(starRating: starRating),
                reviewCount: generateReviewCount(starRating: starRating),
                pricePerNight: adjustedPrice,
                type: extractHotelType(from: poi.name),
                amenities: generateAmenities(starRating: starRating),
                imageUrls: [], // 暂时为空，避免解析问题
                nearestMetro: nil,
                distanceFromCenter: Double(poi.distance ?? "0")
            )
            
            hotelInfos.append(hotelInfo)
        }
        
        // 异步填充地铁信息
        await fillMetroInfo(for: &hotelInfos, amapService: amapService)
        
        print("✅ 酒店转换完成，返回 \(hotelInfos.count) 个结果")
        return hotelInfos
    }
    
    // ✅ 只保留一个 fillMetroInfo 方法
    private func fillMetroInfo(for hotels: inout [HotelInfo], amapService: AMapService) async {
        for i in 0..<hotels.count {
            let hotel = hotels[i]
            let coordinates = hotel.location.split(separator: ",")
            
            guard coordinates.count == 2,
                  let lng = Double(coordinates[0]),
                  let lat = Double(coordinates[1]) else {
                print("⚠️ 酒店坐标格式错误: \(hotel.name)")
                continue
            }
            
            do {
                // 搜索附近地铁站
                let metroStations = try await amapService.searchNearbyMetroStations(
                    lng: lng,
                    lat: lat,
                    radius: 1500 // 扩大搜索范围到1.5公里
                )
                
                if let nearestStation = metroStations.first {
                    let walkingTime = try await amapService.walkingSecs(
                        origin: (lng, lat),
                        dest: nearestStation.location
                    )
                    let walkingMinutes = Int(ceil(Double(walkingTime) / 60.0))
                    
                    // 创建新的 HotelInfo 而不是直接修改
                    hotels[i] = HotelInfo(
                        id: hotel.id,
                        name: hotel.name,
                        address: hotel.address,
                        location: hotel.location,
                        starRating: hotel.starRating,
                        rating: hotel.rating,
                        reviewCount: hotel.reviewCount,
                        pricePerNight: hotel.pricePerNight,
                        type: hotel.type,
                        amenities: hotel.amenities,
                        imageUrls: hotel.imageUrls,
                        nearestMetro: "🚇 \(nearestStation.name) (步行\(walkingMinutes)分钟)",
                        distanceFromCenter: hotel.distanceFromCenter
                    )
                    
                    print("✅ 为 \(hotel.name) 找到最近地铁站: \(nearestStation.name)")
                } else {
                    print("⚠️ 未找到 \(hotel.name) 附近的地铁站")
                }
            } catch {
                print("⚠️ 获取地铁信息失败: \(hotel.name) - \(error)")
                // 继续处理其他酒店，不因为一个失败而中断
            }
        }
    }
    
    private func adjustPriceByDate(basePrice: Double, checkinDate: String) -> Double {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: checkinDate) else {
            return basePrice
        }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // 周末价格上涨
        if weekday == 1 || weekday == 7 { // 周日或周六
            return basePrice * 1.3
        }
        
        // 节假日价格调整
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        // 简单的节假日判断
        if (month == 10 && day >= 1 && day <= 7) || // 国庆
           (month == 1 && day >= 1 && day <= 3) || // 元旦
           (month == 2 && day >= 10 && day <= 17) { // 春节期间
            return basePrice * 1.8
        }
        
        return basePrice
    }
    
    private func extractStarRating(from name: String) -> Int {
        // 更精确的星级提取逻辑
        let patterns = [
            ("五星|5星|★★★★★|豪华|奢华", 5),
            ("四星|4星|★★★★|高级|精品", 4),
            ("三星|3星|★★★|标准|商务", 3),
            ("二星|2星|★★|快捷|经济", 2),
            ("一星|1星|★|青旅|民宿", 1)
        ]
        
        for (pattern, rating) in patterns {
            if name.range(of: pattern, options: .regularExpression) != nil {
                return rating
            }
        }
        
        // 根据酒店名称关键词推断
        if name.contains("豪华") || name.contains("国际") || name.contains("万豪") || name.contains("希尔顿") {
            return 5
        } else if name.contains("商务") || name.contains("精品") {
            return 4
        } else if name.contains("快捷") || name.contains("经济") {
            return 2
        }
        
        return 3 // 默认3星
    }
    
    private func extractHotelType(from name: String) -> String {
        if name.contains("度假") || name.contains("Resort") { return "resort" }
        if name.contains("公寓") || name.contains("Apartment") { return "apartment" }
        if name.contains("青旅") || name.contains("Hostel") { return "hostel" }
        if name.contains("民宿") || name.contains("Guest") { return "guesthouse" }
        return "hotel"
    }
    
    private func generatePrice(starRating: Int) -> Double {
        let baseRanges: [Int: (Double, Double)] = [
            1: (88, 168),
            2: (128, 298),
            3: (218, 488),
            4: (398, 888),
            5: (688, 2888)
        ]
        
        let range = baseRanges[starRating] ?? (218, 488)
        return Double.random(in: range.0...range.1)
    }
    
    private func generateRating(starRating: Int) -> Double {
        let baseRating = Double(starRating) * 0.8 + 1.2 // 1.2-5.0 范围
        return min(5.0, max(1.0, baseRating + Double.random(in: -0.3...0.8)))
    }
    
    private func generateReviewCount(starRating: Int) -> Int {
        let ranges: [Int: (Int, Int)] = [
            1: (15, 150),
            2: (30, 500),
            3: (80, 1200),
            4: (150, 2500),
            5: (300, 5000)
        ]
        
        let range = ranges[starRating] ?? (80, 800)
        return Int.random(in: range.0...range.1)
    }
    
    private func generateAmenities(starRating: Int) -> [String] {
        let basicAmenities = ["免费WiFi", "空调", "24小时前台", "热水"]
        let standardAmenities = basicAmenities + ["电视", "冰箱", "吹风机", "热水壶", "拖鞋"]
        let premiumAmenities = standardAmenities + ["健身房", "商务中心", "洗衣服务", "行李寄存", "叫车服务"]
        let luxuryAmenities = premiumAmenities + ["游泳池", "SPA", "礼宾服务", "免费停车", "自助早餐", "机场接送"]
        
        switch starRating {
        case 1: return Array(basicAmenities.shuffled().prefix(3))
        case 2: return Array(standardAmenities.shuffled().prefix(5))
        case 3: return Array(standardAmenities.shuffled().prefix(7))
        case 4: return Array(premiumAmenities.shuffled().prefix(9))
        case 5: return Array(luxuryAmenities.shuffled().prefix(12))
        default: return Array(standardAmenities.shuffled().prefix(6))
        }
    }
} // ✅ HotelSearchService 类结束

// MARK: - 测试扩展（仅在 DEBUG 模式下）
#if DEBUG
extension HotelSearchTool {
    func testDateParsing() {
        let testCases = [
            ("2025-09-25", "2025-09-28"),
            ("09-25", "09-28"),
            ("9-25", "9-28"),
            ("2025/09/25", "2025/09/28"),
            ("09/25", "09/28"),
        ]
        
        for (checkin, checkout) in testCases {
            do {
                try validateDates(checkin: checkin, checkout: checkout)
                print("✅ 测试通过: \(checkin) → \(checkout)")
            } catch {
                print("❌ 测试失败: \(checkin) → \(checkout) - \(error)")
            }
        }
    }
}
#endif


