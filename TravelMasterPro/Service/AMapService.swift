//
//  AMapService.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/31.
//

import Foundation

/// 高德地图服务 - 提供地理编码、POI搜索、路径规划等功能
class AMapService {
    private let config: MapConfiguration
    private let session: URLSession  // 修改为 let
    private var requestCache: [String: Any] = [:]
    private var lastRequestTime: Date = Date()
    private let minimumInterval: TimeInterval = 0.3 // ✅ 增加到500ms间隔
    
    // ✅ 添加并发控制
    private var activeRequestCount = 0
    private let maxConcurrentRequests = 3
    
    // 高德地图API基础URL
    private let baseURL = "https://restapi.amap.com/v3"
    
    init(config: MapConfiguration) {
        self.config = config
        
        // ✅ 创建优化的 URLSession 配置
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 15.0
        sessionConfig.timeoutIntervalForResource = 30.0
        sessionConfig.httpMaximumConnectionsPerHost = 2  // 限制每个主机的最大连接数
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfig.urlCache = nil  // 禁用 URL 缓存避免内存问题
        
        self.session = URLSession(configuration: sessionConfig)
        
        print("🔑 高德地图配置:")
        print("   - API Key: \(config.amapWebKey.prefix(8))****")
        print("   - Language: \(config.lang)")
        print("   - Default City: \(config.defaultCity)")
        print("   - Max Connections Per Host: \(sessionConfig.httpMaximumConnectionsPerHost)")
        
        // ✅ 验证 API Key 格式
        if config.amapWebKey.isEmpty || config.amapWebKey == "your_amap_web_key_here" {
            print("⚠️ API Key 未正确配置！")
        }
    }
    
    // ✅ 添加 deinit 确保资源释放
    deinit {
        session.invalidateAndCancel()
        print("🧹 AMapService 资源已释放")
    }
    
    // MARK: - 请求限流和缓存
    
    /// 请求限流延迟 - 增强版
    private func rateLimitDelay() async {
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < minimumInterval {
            let delayTime = minimumInterval - timeSinceLastRequest
            print("⏱️ 请求限流延迟: \(Int(delayTime * 1000))ms")
            try? await Task.sleep(nanoseconds: UInt64(delayTime * 1_000_000_000))
        }
        lastRequestTime = Date()
    }
    
    /// 控制并发请求数量
    private func checkConcurrentLimit() async throws {
        while activeRequestCount >= maxConcurrentRequests {
            print("⏸️ 达到最大并发限制(\(maxConcurrentRequests))，等待...")
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        activeRequestCount += 1
        print("📈 当前活跃请求: \(activeRequestCount)")
    }
    
    /// 请求完成后减少计数
    private func requestCompleted() {
        activeRequestCount = max(0, activeRequestCount - 1)
        print("📉 当前活跃请求: \(activeRequestCount)")
    }
    
    /// 坐标验证
    private func validateCoordinates(lng: Double, lat: Double) -> Bool {
        // 中国大陆坐标范围验证
        let validLngRange = 73.0...135.0
        let validLatRange = 18.0...54.0
        
        let isValid = validLngRange.contains(lng) && validLatRange.contains(lat)
        print("📍 坐标验证: (\(lng), \(lat)) - \(isValid ? "✅有效" : "❌无效")")
        
        return isValid
    }
    
    // MARK: - 统一的网络请求方法
    
    /// 统一的网络请求方法
    private func performRequest(url: URL, description: String) async throws -> Data {
        try await checkConcurrentLimit()
        defer { requestCompleted() }
        
        await rateLimitDelay()
        
        print("🌐 发起请求[\(description)]: \(url.absoluteString)")
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AMapError.networkError
            }
            
            print("📡 响应[\(description)]: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ 错误响应[\(description)]: \(responseString)")
                }
                throw AMapError.networkError
            }
            
            return data
            
        } catch {
            print("❌ 网络请求失败[\(description)]: \(error)")
            throw error
        }
    }
    
    // MARK: - 连接和功能测试
    
    /// 测试API连接是否正常
    func testConnection() async -> Bool {
        let testURL = "\(baseURL)/config/district?key=\(config.amapWebKey)&keywords=中国&subdistrict=0"
        
        guard let url = URL(string: testURL) else {
            print("❌ 测试URL无效")
            return false
        }
        
        do {
            let _ = try await performRequest(url: url, description: "连接测试")
            print("✅ 高德地图API连接正常")
            return true
        } catch {
            print("❌ 连接测试失败: \(error)")
            return false
        }
    }
    
    /// 测试已知位置的POI搜索
    func testKnownLocation() async throws -> [POIInfo] {
        // 使用北京天安门附近（肯定有酒店的地方）测试
        let testLng = 116.397477
        let testLat = 39.908692
        
        print("🧪 测试已知位置: 北京天安门广场")
        
        let urlString = "\(baseURL)/place/around?key=\(config.amapWebKey)&location=\(testLng),\(testLat)&keywords=酒店&radius=2000&offset=10&page=1&extensions=all"
        
        guard let url = URL(string: urlString) else {
            throw AMapError.invalidURL
        }
        
        let data = try await performRequest(url: url, description: "已知位置测试")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 测试响应: \(responseString)")
        }
        
        let result = try JSONDecoder().decode(POISearchResponse.self, from: data)
        print("🧪 测试结果: status=\(result.status), 找到 \(result.pois.count) 个POI")
        
        if result.infocode == "10021" {
            print("⚠️ 测试显示API配额超限")
            throw AMapError.quotaExceeded
        }
        
        return result.pois
    }
    
    // MARK: - 地理编码
    
    /// 地址转坐标 - 优化版
    func geocode(address: String) async throws -> (Double, Double) {
        // 检查缓存
        if let cached = requestCache[address] as? (Double, Double) {
            print("📱 使用缓存的地理编码结果: \(address)")
            return cached
        }
        
        var components = URLComponents(string: "\(baseURL)/geocode/geo")
        components?.queryItems = [
            URLQueryItem(name: "key", value: config.amapWebKey),
            URLQueryItem(name: "address", value: address)
        ]
        
        guard let url = components?.url else {
            throw AMapError.invalidURL
        }
        
        let data = try await performRequest(url: url, description: "地理编码")
        
        // ✅ 输出原始响应
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 地理编码原始响应: \(responseString)")
        }
        
        let result = try JSONDecoder().decode(GeocodeResponse.self, from: data)
        
        print("📊 地理编码解析结果:")
        print("   - status: \(result.status)")
        print("   - info: \(result.info)")
        print("   - geocodes数量: \(result.geocodes.count)")
        
        guard result.status == "1",
              let geocode = result.geocodes.first,
              let location = geocode.location else {
            print("❌ 地理编码失败: status=\(result.status), info=\(result.info)")
            throw AMapError.geocodeFailed
        }
        
        let coordinates = location.split(separator: ",")
        guard coordinates.count == 2,
              let lng = Double(coordinates[0]),
              let lat = Double(coordinates[1]) else {
            print("❌ 坐标解析失败: \(location)")
            throw AMapError.invalidCoordinates
        }
        
        // ✅ 添加坐标验证
        guard validateCoordinates(lng: lng, lat: lat) else {
            throw AMapError.invalidCoordinates
        }
        
        // 缓存结果
        requestCache[address] = (lng, lat)
        
        print("✅ 坐标解析成功: (\(lng), \(lat))")
        return (lng, lat)
    }
    
    // MARK: - POI搜索
    
    /// 搜索周边酒店 - 优化版本，减少请求数
    func searchHotelsAround(
        lng: Double,
        lat: Double,
        radius: Int = 5000,
        limit: Int = 50
    ) async throws -> [POIInfo] {
        
        print("🔍 开始周边酒店搜索: 坐标(\(lng), \(lat)), 半径\(radius)米")
        
        // ✅ 减少搜索策略，避免过多请求
        let searchConfigs = [
            (keywords: "酒店", types: "", description: "酒店-不限类型"),
            (keywords: "住宿", types: "", description: "住宿-不限类型"),
        ]
        
        var allPOIs: [POIInfo] = []
        
        for (index, config) in searchConfigs.enumerated() {
            print("🔍 策略 \(index + 1): 搜索[\(config.description)]")
            
            var components = URLComponents(string: "\(baseURL)/place/around")
            var queryItems = [
                URLQueryItem(name: "key", value: self.config.amapWebKey),
                URLQueryItem(name: "location", value: "\(lng),\(lat)"),
                URLQueryItem(name: "keywords", value: config.keywords),
                URLQueryItem(name: "radius", value: "\(radius)"),
                URLQueryItem(name: "offset", value: "\(min(limit, 20))"),
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "extensions", value: "all")
            ]
            
            if !config.types.isEmpty {
                queryItems.append(URLQueryItem(name: "types", value: config.types))
            }
            
            components?.queryItems = queryItems
            
            guard let url = components?.url else {
                print("❌ URL构造失败")
                continue
            }
            
            // 生成浏览器测试URL
            print("🌐 浏览器测试: \(url.absoluteString)")
            
            do {
                let data = try await performRequest(url: url, description: config.description)
                
                // ✅ 输出完整响应用于调试
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 完整响应[\(config.description)]: \(responseString)")
                }
                
                let result = try JSONDecoder().decode(POISearchResponse.self, from: data)
                
                print("📊 解析结果[\(config.description)]:")
                print("   - status: \(result.status)")
                print("   - info: \(result.info)")
                print("   - infocode: \(result.infocode)")
                print("   - count: \(result.count ?? "nil")")
                print("   - pois数量: \(result.pois.count)")
                
                // ✅ 检查各种错误情况
                if result.infocode == "10021" {
                    print("⚠️ API配额超限: \(result.info)")
                    throw AMapError.quotaExceeded
                }
                
                if result.status == "1" {
                    allPOIs.append(contentsOf: result.pois)
                    print("✅ 添加了 \(result.pois.count) 个POI")
                    
                    // 如果找到POI就停止搜索，减少请求
                    if !result.pois.isEmpty {
                        print("✅ 找到POI，停止后续搜索")
                        break
                    }
                } else {
                    print("⚠️ API状态异常: \(result.status) - \(result.info)")
                }
                
            } catch {
                print("❌ 搜索失败[\(config.description)]: \(error)")
                // 继续下一个策略，但如果是配额错误就停止
                if let amapError = error as? AMapError, amapError == .quotaExceeded {
                    throw error
                }
            }
        }
        
        // 去重
        let uniquePOIs = removeDuplicatePOIs(allPOIs)
        print("🏨 总共找到 \(uniquePOIs.count) 个唯一酒店POI")
        
        // ✅ 如果仍然没有找到，尝试文本搜索
        if uniquePOIs.isEmpty {
            print("🔄 周边搜索无结果，尝试文本搜索...")
            return try await searchHotelsByTextFallback(lng: lng, lat: lat)
        }
        
        return uniquePOIs
    }
    
    /// 文本搜索作为备选方案
    private func searchHotelsByTextFallback(lng: Double, lat: Double) async throws -> [POIInfo] {
        // 根据坐标反推城市
        let cityName = await getCityFromCoordinates(lng: lng, lat: lat)
        
        return try await searchHotelsByText(city: cityName, location: nil)
    }
    
    /// 根据坐标获取城市名
    private func getCityFromCoordinates(lng: Double, lat: Double) async -> String {
        // 简单的坐标到城市映射
        if lng >= 116.0 && lng <= 117.0 && lat >= 39.0 && lat <= 41.0 {
            return "北京"
        } else if lng >= 120.0 && lng <= 122.0 && lat >= 30.0 && lat <= 32.0 {
            return "杭州"
        } else if lng >= 121.0 && lng <= 122.0 && lat >= 31.0 && lat <= 32.0 {
            return "上海"
        } else if lng >= 113.0 && lng <= 115.0 && lat >= 22.0 && lat <= 24.0 {
            return "广州"
        } else {
            return "北京" // 默认
        }
    }
    
    /// 文本搜索酒店 - 简化版
    func searchHotelsByText(
        city: String,
        location: String? = nil
    ) async throws -> [POIInfo] {
        
        // ✅ 只使用一个最重要的搜索词
        let searchText = location != nil ? "\(city) \(location!) 酒店" : "\(city) 酒店"
        
        var components = URLComponents(string: "\(baseURL)/place/text")
        components?.queryItems = [
            URLQueryItem(name: "key", value: config.amapWebKey),
            URLQueryItem(name: "keywords", value: searchText),
            URLQueryItem(name: "city", value: city),
            URLQueryItem(name: "types", value: "100301"),
            URLQueryItem(name: "offset", value: "20"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "extensions", value: "all")
        ]
        
        guard let url = components?.url else {
            throw AMapError.invalidURL
        }
        
        print("🔗 文本搜索[\(searchText)]URL: \(url.absoluteString)")
        
        let data = try await performRequest(url: url, description: "文本搜索")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 文本搜索[\(searchText)]响应: \(responseString)")
        }
        
        let result = try JSONDecoder().decode(POISearchResponse.self, from: data)
        
        print("📊 文本搜索[\(searchText)]解析结果:")
        print("   - status: \(result.status)")
        print("   - info: \(result.info)")
        print("   - pois数量: \(result.pois.count)")
        
        // ✅ 检查API限额错误
        if result.infocode == "10021" {
            print("⚠️ API配额超限，停止文本搜索")
            throw AMapError.quotaExceeded
        }
        
        if result.status == "1" {
            print("✅ 文本搜索添加了 \(result.pois.count) 个POI")
            return result.pois
        } else {
            print("⚠️ 文本搜索警告: \(result.status) - \(result.info)")
            return []
        }
    }
    
    /// 通用 POI 搜索
    /// - Parameters:
    ///   - keyword: 搜索关键词
    ///   - city: 城市名称或编码
    ///   - types: POI类型编码，多个类型用"|"分隔。例如 "110000|060000"
    ///   - location: 偏好中心点坐标 "lon,lat"，用于提升周边结果权重
    func searchPOI(keyword: String, city: String = "", types: String? = nil, location: String? = nil) async throws -> [POIInfo] {
        var components = URLComponents(string: "\(baseURL)/place/text")
        var queryItems = [
            URLQueryItem(name: "key", value: config.amapWebKey),
            URLQueryItem(name: "keywords", value: keyword),
            URLQueryItem(name: "city", value: city),
            URLQueryItem(name: "offset", value: "20"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "extensions", value: "all")
        ]
        
        if let types = types {
            queryItems.append(URLQueryItem(name: "types", value: types))
        }
        
        if let location = location {
            queryItems.append(URLQueryItem(name: "location", value: location))
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw AMapError.invalidURL
        }
        
        print("🔗 通用POI搜索[\(keyword)]URL: \(url.absoluteString)")
        
        let data = try await performRequest(url: url, description: "通用POI搜索")
        
        let result = try JSONDecoder().decode(POISearchResponse.self, from: data)
        
        if result.status == "1" {
            return result.pois
        }
        
        return []
    }
    
    /// 去重方法
    private func removeDuplicatePOIs(_ pois: [POIInfo]) -> [POIInfo] {
        var seen = Set<String>()
        return pois.filter { poi in
            let key = poi.id ?? "\(poi.name)_\(poi.location)"
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
    
    /// 搜索周边地铁站
    func searchNearbyMetroStations(
        lng: Double,
        lat: Double,
        radius: Int
    ) async throws -> [(name: String, location: (Double, Double))] {
        
        var components = URLComponents(string: "\(baseURL)/place/around")
        components?.queryItems = [
            URLQueryItem(name: "key", value: config.amapWebKey),
            URLQueryItem(name: "location", value: "\(lng),\(lat)"),
            URLQueryItem(name: "keywords", value: "地铁站"),
            URLQueryItem(name: "types", value: "150500"),
            URLQueryItem(name: "radius", value: "\(radius)"),
            URLQueryItem(name: "offset", value: "20"),
            URLQueryItem(name: "page", value: "1")
        ]
        
        guard let url = components?.url else {
            throw AMapError.invalidURL
        }
        
        let data = try await performRequest(url: url, description: "地铁站搜索")
        
        let result = try JSONDecoder().decode(POISearchResponse.self, from: data)
        
        guard result.status == "1" else {
            return []
        }
        
        return result.pois.compactMap { poi in
            let coordinates = poi.location.split(separator: ",")
            guard coordinates.count == 2,
                  let lng = Double(coordinates[0]),
                  let lat = Double(coordinates[1]) else {
                return nil
            }
            return (name: poi.name, location: (lng, lat))
        }
    }
    
    /// 搜索航班相关POI（机场、航空公司等）
    func searchFlightPOIs(
        city: String,
        keywords: String = "机场"
    ) async throws -> [POIInfo] {
        
        var components = URLComponents(string: "\(baseURL)/place/text")
        components?.queryItems = [
            URLQueryItem(name: "key", value: config.amapWebKey),
            URLQueryItem(name: "keywords", value: keywords),
            URLQueryItem(name: "city", value: city),
            URLQueryItem(name: "types", value: "150101"),
            URLQueryItem(name: "offset", value: "20"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "extensions", value: "all")
        ]
        
        guard let url = components?.url else {
            throw AMapError.invalidURL
        }
        
        let data = try await performRequest(url: url, description: "航班POI搜索")
        
        let result = try JSONDecoder().decode(POISearchResponse.self, from: data)
        
        guard result.status == "1" else {
            throw AMapError.searchFailed
        }
        
        return result.pois
    }
    
    // MARK: - 路径规划
    
    /// 计算步行时间（秒）
    func walkingSecs(
        origin: (Double, Double),
        dest: (Double, Double)
    ) async throws -> Int {
        
        let urlString = "\(baseURL)/direction/walking?key=\(config.amapWebKey)&origin=\(origin.0),\(origin.1)&destination=\(dest.0),\(dest.1)"
        
        guard let url = URL(string: urlString) else {
            throw AMapError.invalidURL
        }
        
        let data = try await performRequest(url: url, description: "步行路径")
        
        let result = try JSONDecoder().decode(WalkingResponse.self, from: data)
        
        guard result.status == "1",
              let route = result.route,
              let path = route.paths.first else {
            throw AMapError.routePlanningFailed
        }
        
        return Int(path.duration) ?? 0
    }
    
    /// 计算驾车路径
    func drivingRoute(
        origin: (Double, Double),
        dest: (Double, Double)
    ) async throws -> RouteInfo {
        
        let urlString = "\(baseURL)/direction/driving?key=\(config.amapWebKey)&origin=\(origin.0),\(origin.1)&destination=\(dest.0),\(dest.1)&extensions=all"
        
        guard let url = URL(string: urlString) else {
            throw AMapError.invalidURL
        }
        
        let data = try await performRequest(url: url, description: "驾车路径")
        
        let result = try JSONDecoder().decode(DrivingResponse.self, from: data)
        
        guard result.status == "1",
              let route = result.route,
              let path = route.paths.first else {
            throw AMapError.routePlanningFailed
        }
        
        return RouteInfo(
            distance: Int(path.distance) ?? 0,
            duration: Int(path.duration) ?? 0,
            strategy: path.strategy ?? "",
            tolls: Int(path.tolls ?? "0") ?? 0,
            steps: path.steps.map { step in
                RouteStep(
                    instruction: step.instruction,
                    distance: Int(step.distance) ?? 0,
                    duration: Int(step.duration) ?? 0,
                    polyline: step.polyline
                )
            }
        )
    }
}

// MARK: - 数据模型

/// POI信息
struct POIInfo: Codable {
    let id: String?
    let name: String
    let type: String?
    let typecode: String?
    let address: String?
    let location: String
    let tel: String?
    let distance: String?
    let cityname: String? // ✅ 新增城市名称字段
    let bizExt: BizExt?
    let photos: [String]?
    
    struct BizExt: Codable {
        let rating: String?
        let cost: String?
        let opentime: String?
        let tel: String?
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try? container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try? container.decode(String.self, forKey: .type)
        self.typecode = try? container.decode(String.self, forKey: .typecode)
        self.address = try? container.decode(String.self, forKey: .address)
        self.location = try container.decode(String.self, forKey: .location)
        self.tel = try? container.decode(String.self, forKey: .tel)
        self.distance = try? container.decode(String.self, forKey: .distance)
        self.cityname = try? container.decode(String.self, forKey: .cityname)
        self.bizExt = try? container.decode(BizExt.self, forKey: .bizExt)
        self.photos = try? container.decode([String].self, forKey: .photos)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, type, typecode, address, location, tel, distance, cityname, bizExt, photos
    }
}

/// 地理编码响应
struct GeocodeResponse: Decodable {
    let status: String
    let info: String
    let infocode: String
    let count: String
    let geocodes: [Geocode]
    
    struct Geocode: Decodable {
        let formatted_address: String?
        let country: String?
        let province: String?
        let city: String?
        let citycode: String?
        let district: String?
        let township: [String]
        let neighborhood: NeighborhoodInfo?
        let building: BuildingInfo?
        let adcode: String?
        let street: [String]
        let number: [String]
        let location: String?
        let level: String?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            formatted_address = try? container.decode(String.self, forKey: .formatted_address)
            country = try? container.decode(String.self, forKey: .country)
            province = try? container.decode(String.self, forKey: .province)
            city = try? container.decode(String.self, forKey: .city)
            citycode = try? container.decode(String.self, forKey: .citycode)
            adcode = try? container.decode(String.self, forKey: .adcode)
            location = try? container.decode(String.self, forKey: .location)
            level = try? container.decode(String.self, forKey: .level)
            
            // 灵活处理 district 字段（字符串或数组）
            if let districtString = try? container.decode(String.self, forKey: .district) {
                district = districtString
            } else if let districtArray = try? container.decode([String].self, forKey: .district),
                      let firstDistrict = districtArray.first {
                district = firstDistrict
            } else {
                district = nil
            }
            
            // 安全解析数组字段
            township = (try? container.decode([String].self, forKey: .township)) ?? []
            street = (try? container.decode([String].self, forKey: .street)) ?? []
            number = (try? container.decode([String].self, forKey: .number)) ?? []
            neighborhood = try? container.decode(NeighborhoodInfo.self, forKey: .neighborhood)
            building = try? container.decode(BuildingInfo.self, forKey: .building)
        }
        
        private enum CodingKeys: String, CodingKey {
            case formatted_address, country, province, city, citycode, district
            case township, neighborhood, building, adcode, street, number, location, level
        }
    }
}

struct NeighborhoodInfo: Decodable {
    let name: [String]
    let type: [String]
}

struct BuildingInfo: Decodable {
    let name: [String]
    let type: [String]
}

/// POI搜索响应
struct POISearchResponse: Codable {
    let status: String
    let info: String
    let infocode: String
    let count: String?
    let suggestion: Suggestion?
    let pois: [POIInfo]
    
    struct Suggestion: Codable {
        let keywords: [String]?
        let cities: [String]?
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        status = try container.decode(String.self, forKey: .status)
        info = try container.decode(String.self, forKey: .info)
        infocode = try container.decode(String.self, forKey: .infocode)
        count = try? container.decode(String.self, forKey: .count)
        suggestion = try? container.decode(Suggestion.self, forKey: .suggestion)
        pois = (try? container.decode([POIInfo].self, forKey: .pois)) ?? []
    }
    
    private enum CodingKeys: String, CodingKey {
        case status, info, infocode, count, suggestion, pois
    }
}

/// 步行路径响应
struct WalkingResponse: Codable {
    let status: String
    let info: String
    let infocode: String
    let count: String
    let route: WalkingRoute?
    
    struct WalkingRoute: Codable {
        let origin: String
        let destination: String
        let distance: String
        let paths: [WalkingPath]
        
        struct WalkingPath: Codable {
            let distance: String
            let duration: String
            let steps: [WalkingStep]
            
            struct WalkingStep: Codable {
                let instruction: String
                let orientation: String?
                let distance: String
                let duration: String
                let polyline: String
            }
        }
    }
}

/// 驾车路径响应
struct DrivingResponse: Codable {
    let status: String
    let info: String
    let infocode: String
    let count: String
    let route: DrivingRoute?
    
    struct DrivingRoute: Codable {
        let origin: String
        let destination: String
        let distance: String
        let paths: [DrivingPath]
        
        struct DrivingPath: Codable {
            let distance: String
            let duration: String
            let strategy: String?
            let tolls: String?
            let tollDistance: String?
            let steps: [DrivingStep]
            
            struct DrivingStep: Codable {
                let instruction: String
                let orientation: String?
                let distance: String
                let duration: String
                let polyline: String
                let action: String?
                let assistantAction: String?
            }
        }
    }
}

/// 路径信息
struct RouteInfo {
    let distance: Int
    let duration: Int
    let strategy: String
    let tolls: Int
    let steps: [RouteStep]
}

/// 路径步骤
struct RouteStep {
    let instruction: String
    let distance: Int
    let duration: Int
    let polyline: String
}

/// 地图配置
struct MapConfiguration {
    let amapWebKey: String
    let lang: String
    let defaultCity: String
    
    static func load() throws -> MapConfiguration {
        guard let path = Bundle.main.path(forResource: "MapConfig", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path) as? [String: Any],
              let amapWebKey = config["amapWebKey"] as? String else {
            throw AMapError.configurationError
        }
        
        return MapConfiguration(
            amapWebKey: amapWebKey,
            lang: config["lang"] as? String ?? "zh_cn",
            defaultCity: config["defaultCity"] as? String ?? "北京"
        )
    }
}

/// 高德地图错误类型
enum AMapError: Error, LocalizedError {
    case invalidURL
    case networkError
    case geocodeFailed
    case searchFailed
    case routePlanningFailed
    case invalidCoordinates
    case configurationError
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .networkError:
            return "网络请求失败"
        case .geocodeFailed:
            return "地理编码失败"
        case .searchFailed:
            return "POI搜索失败"
        case .routePlanningFailed:
            return "路径规划失败"
        case .invalidCoordinates:
            return "无效的坐标"
        case .configurationError:
            return "配置文件加载失败"
        case .quotaExceeded:
            return "API调用配额已用完"
        }
    }
}