//
//  RoutePlannerTool.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import Foundation

/// 路线规划工具 - 基于高德地图API的智能路线规划
class RoutePlannerTool: BaseTool {
    
    init() {
        super.init(
            name: "route_planner",
            description: "智能路线规划工具，支持多目的地优化、交通方式选择、时间估算等功能",
            parameters: [
                "destinations": ParameterDefinition(
                    type: "string",
                    description: "目的地列表，逗号分隔（支持地址、地标、坐标）",
                    enumValues: nil
                ),
                "start_location": ParameterDefinition(
                    type: "string",
                    description: "起点位置（可选，默认为第一个目的地）",
                    enumValues: nil
                ),
                "travel_mode": ParameterDefinition.string(
                    "交通方式",
                    enumValues: ["walking", "driving", "transit", "cycling", "mixed"]
                ),
                "optimize_route": ParameterDefinition.string(
                    "是否优化路线顺序",
                    enumValues: ["true", "false"]
                ),
                "return_to_start": ParameterDefinition.string(
                    "是否返回起点",
                    enumValues: ["true", "false"]
                ),
                "prioritize": ParameterDefinition.string(
                    "优化优先级",
                    enumValues: ["time", "distance", "cost", "scenic"]
                ),
                "max_duration": ParameterDefinition(
                    type: "number",
                    description: "最大总用时（分钟）",
                    enumValues: nil
                ),
                "max_walking_distance": ParameterDefinition(
                    type: "number",
                    description: "最大步行距离（米）",
                    enumValues: nil
                ),
                "include_poi": ParameterDefinition.string(
                    "是否包含沿途兴趣点",
                    enumValues: ["true", "false"]
                ),
                "avoid_traffic": ParameterDefinition.string(
                    "是否避开拥堵",
                    enumValues: ["true", "false"]
                ),
                "group_nearby": ParameterDefinition.string(
                    "是否合并附近景点",
                    enumValues: ["true", "false"]
                ),
                "departure_time": ParameterDefinition(
                    type: "string",
                    description: "出发时间 (HH:mm 格式，可选)",
                    enumValues: nil
                )
            ],
            requiredParameters: ["destinations"]
        )
    }
    
    override func executeImpl(arguments: [String: Any]) async throws -> ToolResult {
        // 获取参数
        let destinationsString = try getRequiredString("destinations", from: arguments)
        let startLocation = getString("start_location", from: arguments)
        let travelMode = getString("travel_mode", from: arguments) ?? "walking"
        let optimizeRoute = getBoolean("optimize_route", from: arguments) ?? true
        let departureTime = getString("departure_time", from: arguments)
        let maxDuration = getNumber("max_duration", from: arguments)
        let avoidTraffic = getBoolean("avoid_traffic", from: arguments) ?? true
        let prioritize = getString("prioritize", from: arguments) ?? "time"
        let includePOI = getBoolean("include_poi", from: arguments) ?? false
        let groupNearby = getBoolean("group_nearby", from: arguments) ?? true
        let maxWalkingDistance = getNumber("max_walking_distance", from: arguments) ?? 500
        let returnToStart = getBoolean("return_to_start", from: arguments) ?? false
        
        do {
            // 解析目的地列表
            let destinations = destinationsString.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            guard !destinations.isEmpty else {
                throw ToolError.executionFailed("目的地列表不能为空")
            }
            
            // 创建路线规划服务
            let routePlanner = try RouteCalculationService()
            
            // 执行路线规划
            let routePlan = try await routePlanner.planOptimalRoute(
                destinations: destinations,
                startLocation: startLocation,
                travelMode: travelMode,
                optimize: optimizeRoute,
                departureTime: departureTime,
                maxDuration: maxDuration,
                avoidTraffic: avoidTraffic,
                prioritize: prioritize,
                includePOI: includePOI,
                groupNearby: groupNearby,
                maxWalkingDistance: Int(maxWalkingDistance),
                returnToStart: returnToStart
            )
            
            // 格式化结果
            let formattedResult = formatRouteResult(routePlan)
            
            return successResult(formattedResult, metadata: [
                "total_destinations": destinations.count,
                "total_duration_minutes": routePlan.totalDuration,
                "total_distance_meters": routePlan.totalDistance,
                "travel_mode": travelMode,
                "optimized": optimizeRoute,
                "route_efficiency_score": routePlan.efficiencyScore
            ])
            
        } catch {
            return errorResult("路线规划失败: \(error.localizedDescription)")
        }
    }
    
    private func formatRouteResult(_ routePlan: RoutePlan) -> String {
        var result = """
        🗺️ 【智能路线规划结果】
        
        📊 路线概况：
        🚩 总目的地：\(routePlan.waypoints.count)个
        ⏱️ 预计用时：\(formatDuration(routePlan.totalDuration))
        📏 总距离：\(formatDistance(routePlan.totalDistance))
        🚶‍♂️ 交通方式：\(routePlan.travelMode)
        ⭐️ 路线评分：\(String(format: "%.1f", routePlan.efficiencyScore))/10分
        
        """
        
        // 详细路线安排
        result += "📍 详细路线安排：\n\n"
        
        for (index, waypoint) in routePlan.waypoints.enumerated() {
            let stepNumber = index + 1
            result += "【第\(stepNumber)站】\(waypoint.name)\n"
            result += "📍 地址：\(waypoint.address)\n"
            result += "⏰ 建议停留：\(formatDuration(waypoint.suggestedStayDuration))\n"
            
            if let arrivalTime = waypoint.estimatedArrivalTime {
                result += "🕐 预计到达：\(arrivalTime)\n"
            }
            
            if let tips = waypoint.tips, !tips.isEmpty {
                result += "💡 小贴士：\(tips)\n"
            }
            
            // 下一站的路线信息
            if index < routePlan.segments.count {
                let segment = routePlan.segments[index]
                result += "\n🔽 前往下一站：\n"
                result += "  📏 距离：\(formatDistance(segment.distance))\n"
                result += "  ⏱️ 用时：\(formatDuration(segment.duration))\n"
                result += "  🚶‍♂️ 方式：\(segment.transportMode)\n"
                
                if !segment.instructions.isEmpty {
                    result += "  📋 路线：\(segment.instructions)\n"
                }
            }
            
            result += "\n" + "─".repeated(count: 30) + "\n\n"
        }
        
        // 优化建议
        if !routePlan.optimizationSuggestions.isEmpty {
            result += "💡 优化建议：\n"
            for suggestion in routePlan.optimizationSuggestions {
                result += "• \(suggestion)\n"
            }
            result += "\n"
        }
        
        // 注意事项
        if !routePlan.warnings.isEmpty {
            result += "⚠️ 注意事项：\n"
            for warning in routePlan.warnings {
                result += "• \(warning)\n"
            }
        }
        
        return result
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)分钟"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)小时\(mins)分钟" : "\(hours)小时"
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))米"
        } else {
            let km = meters / 1000.0
            return String(format: "%.1f公里", km)
        }
    }
}

// MARK: - 路线计算服务

class RouteCalculationService {
    private let amapService: AMapService
    
    init() throws {
        let config = try MapConfiguration.load()
        self.amapService = AMapService(config: config)
    }
    
    func planOptimalRoute(
        destinations: [String],
        startLocation: String?,
        travelMode: String,
        optimize: Bool,
        departureTime: String?,
        maxDuration: Double?,
        avoidTraffic: Bool,
        prioritize: String,
        includePOI: Bool,
        groupNearby: Bool,
        maxWalkingDistance: Int,
        returnToStart: Bool
    ) async throws -> RoutePlan {
        
        // 1. 解析所有地点的坐标
        var locations: [(name: String, coordinate: (Double, Double))] = []
        
        for destination in destinations {
            let coordinate = try await amapService.geocode(address: destination)
            locations.append((name: destination, coordinate: coordinate))
        }
        
        // 2. 确定起点
        let startCoordinate: (Double, Double)
        let startName: String
        
        if let startLocation = startLocation {
            startCoordinate = try await amapService.geocode(address: startLocation)
            startName = startLocation
        } else {
            startCoordinate = locations.first!.coordinate
            startName = locations.first!.name
        }
        
        // 3. 合并附近景点
        var processedLocations = locations
        if groupNearby {
            processedLocations = try await groupNearbyLocations(
                locations: locations,
                maxDistance: Double(maxWalkingDistance)
            )
        }
        
        // 4. 路线优化
        var orderedLocations = processedLocations
        if optimize && processedLocations.count > 2 {
            orderedLocations = try await optimizeRouteOrder(
                start: startCoordinate,
                locations: processedLocations,
                prioritize: prioritize,
                travelMode: travelMode
            )
        }
        
        // 5. 计算路线段
        var waypoints: [RouteWaypoint] = []
        var segments: [RouteSegment] = []
        var totalDistance: Double = 0
        var totalDuration: Int = 0
        
        // 添加起点
        waypoints.append(RouteWaypoint(
            name: startName,
            address: startLocation ?? startName,
            coordinate: startCoordinate,
            suggestedStayDuration: 0,
            estimatedArrivalTime: departureTime,
            tips: "旅程起点"
        ))
        
        var currentLocation = startCoordinate
        
        for (index, location) in orderedLocations.enumerated() {
            // 计算到下一个点的路线
            let routeInfo = try await calculateRoute(
                from: currentLocation,
                to: location.coordinate,
                mode: travelMode,
                avoidTraffic: avoidTraffic
            )
            
            // 创建路线段
            let segment = RouteSegment(
                fromIndex: waypoints.count - 1,
                toIndex: waypoints.count,
                distance: routeInfo.distance,
                duration: routeInfo.duration,
                transportMode: travelMode,
                instructions: routeInfo.instructions
            )
            segments.append(segment)
            
            // 累计距离和时间
            totalDistance += routeInfo.distance
            totalDuration += routeInfo.duration
            
            // 计算到达时间
            let arrivalTime = calculateArrivalTime(
                departureTime: departureTime,
                additionalMinutes: totalDuration
            )
            
            // 建议停留时间
            let stayDuration = suggestedStayDuration(for: location.name, travelMode: travelMode)
            totalDuration += stayDuration
            
            // 添加路点
            waypoints.append(RouteWaypoint(
                name: location.name,
                address: location.name,
                coordinate: location.coordinate,
                suggestedStayDuration: stayDuration,
                estimatedArrivalTime: arrivalTime,
                tips: generateLocationTips(location.name)
            ))
            
            currentLocation = location.coordinate
        }
        
        // 6. 如果需要返回起点
        if returnToStart && currentLocation != startCoordinate {
            let returnRouteInfo = try await calculateRoute(
                from: currentLocation,
                to: startCoordinate,
                mode: travelMode,
                avoidTraffic: avoidTraffic
            )
            
            let returnSegment = RouteSegment(
                fromIndex: waypoints.count - 1,
                toIndex: 0,
                distance: returnRouteInfo.distance,
                duration: returnRouteInfo.duration,
                transportMode: travelMode,
                instructions: returnRouteInfo.instructions
            )
            segments.append(returnSegment)
            
            totalDistance += returnRouteInfo.distance
            totalDuration += returnRouteInfo.duration
        }
        
        // 7. 生成优化建议和警告
        let suggestions = generateOptimizationSuggestions(
            waypoints: waypoints,
            totalDuration: totalDuration,
            maxDuration: maxDuration,
            travelMode: travelMode
        )
        
        let warnings = generateWarnings(
            totalDuration: totalDuration,
            maxDuration: maxDuration,
            travelMode: travelMode
        )
        
        // 8. 计算效率评分
        let efficiencyScore = calculateEfficiencyScore(
            waypoints: waypoints,
            segments: segments,
            totalDuration: totalDuration
        )
        
        return RoutePlan(
            waypoints: waypoints,
            segments: segments,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            travelMode: travelMode,
            efficiencyScore: efficiencyScore,
            optimizationSuggestions: suggestions,
            warnings: warnings
        )
    }
    
    // MARK: - 私有辅助方法
    
    private func groupNearbyLocations(
        locations: [(name: String, coordinate: (Double, Double))],
        maxDistance: Double
    ) async throws -> [(name: String, coordinate: (Double, Double))] {
        // 简化实现：合并距离很近的地点
        var grouped: [(name: String, coordinate: (Double, Double))] = []
        var processed: Set<Int> = []
        
        for (i, location) in locations.enumerated() {
            if processed.contains(i) { continue }
            
            var group = [location]
            processed.insert(i)
            
            for (j, otherLocation) in locations.enumerated() {
                if i != j && !processed.contains(j) {
                    let distance = calculateDistance(
                        from: location.coordinate,
                        to: otherLocation.coordinate
                    )
                    
                    if distance <= maxDistance {
                        group.append(otherLocation)
                        processed.insert(j)
                    }
                }
            }
            
            // 如果有多个地点，合并为一个
            if group.count > 1 {
                let centerCoordinate = calculateCenterCoordinate(
                    coordinates: group.map { $0.coordinate }
                )
                let combinedName = group.map { $0.name }.joined(separator: " & ")
                grouped.append((name: combinedName, coordinate: centerCoordinate))
            } else {
                grouped.append(location)
            }
        }
        
        return grouped
    }
    
    private func optimizeRouteOrder(
        start: (Double, Double),
        locations: [(name: String, coordinate: (Double, Double))],
        prioritize: String,
        travelMode: String
    ) async throws -> [(name: String, coordinate: (Double, Double))] {
        // 简化的TSP算法实现
        var optimized = locations
        var bestDistance = Double.infinity
        var bestOrder = locations
        
        // 尝试不同的排列组合（对于小量数据）
        if locations.count <= 6 {
            let permutations = generatePermutations(locations)
            
            for permutation in permutations.prefix(100) { // 限制计算量
                let totalDistance = try await calculateTotalRouteDistance(
                    start: start,
                    locations: permutation,
                    travelMode: travelMode
                )
                
                if totalDistance < bestDistance {
                    bestDistance = totalDistance
                    bestOrder = permutation
                }
            }
            
            optimized = bestOrder
        } else {
            // 对于大量数据，使用最近邻算法
            optimized = try await nearestNeighborOptimization(
                start: start,
                locations: locations,
                travelMode: travelMode
            )
        }
        
        return optimized
    }
    
    private func calculateRoute(
        from: (Double, Double),
        to: (Double, Double),
        mode: String,
        avoidTraffic: Bool
    ) async throws -> (distance: Double, duration: Int, instructions: String) {
        
        switch mode {
        case "walking":
            let duration = try await amapService.walkingSecs(origin: from, dest: to)
            let distance = calculateDistance(from: from, to: to)
            return (distance, duration / 60, "步行路线")
            
        case "driving":
            // 这里应该调用高德的驾车路线规划API
            let distance = calculateDistance(from: from, to: to) * 1.3 // 考虑道路曲折
            let duration = Int(distance / 500 * 60) // 假设平均速度30km/h
            return (distance, duration, "驾车路线")
            
        case "transit":
            // 公共交通路线
            let distance = calculateDistance(from: from, to: to) * 1.2
            let duration = Int(distance / 600 * 60) // 假设平均速度36km/h
            return (distance, duration, "公共交通")
            
        default:
            let duration = try await amapService.walkingSecs(origin: from, dest: to)
            let distance = calculateDistance(from: from, to: to)
            return (distance, duration / 60, "步行路线")
        }
    }
    
    private func calculateDistance(from: (Double, Double), to: (Double, Double)) -> Double {
        // 简化的距离计算（实际应使用更精确的地理距离计算）
        let deltaLat = (to.1 - from.1) * 111000 // 纬度1度约111km
        let deltaLng = (to.0 - from.0) * 111000 * cos(from.1 * .pi / 180)
        return sqrt(deltaLat * deltaLat + deltaLng * deltaLng)
    }
    
    private func calculateCenterCoordinate(
        coordinates: [(Double, Double)]
    ) -> (Double, Double) {
        let avgLng = coordinates.map { $0.0 }.reduce(0, +) / Double(coordinates.count)
        let avgLat = coordinates.map { $0.1 }.reduce(0, +) / Double(coordinates.count)
        return (avgLng, avgLat)
    }
    
    private func suggestedStayDuration(for location: String, travelMode: String) -> Int {
        // 根据地点类型建议停留时间
        let locationLower = location.lowercased()
        
        if locationLower.contains("博物馆") || locationLower.contains("museum") {
            return 120 // 2小时
        } else if locationLower.contains("公园") || locationLower.contains("park") {
            return 90 // 1.5小时
        } else if locationLower.contains("寺") || locationLower.contains("temple") {
            return 60 // 1小时
        } else if locationLower.contains("商场") || locationLower.contains("mall") {
            return 90 // 1.5小时
        } else if locationLower.contains("景点") || locationLower.contains("attraction") {
            return 90 // 1.5小时
        } else {
            return 60 // 默认1小时
        }
    }
    
    private func generateLocationTips(_ location: String) -> String? {
        // 为特定地点生成小贴士
        let locationLower = location.lowercased()
        
        if locationLower.contains("博物馆") {
            return "建议提前查看开放时间，部分展览可能需要预约"
        } else if locationLower.contains("寺") {
            return "注意着装要求，保持安静"
        } else if locationLower.contains("公园") {
            return "适合散步休息，注意天气变化"
        }
        
        return nil
    }
    
    private func calculateArrivalTime(departureTime: String?, additionalMinutes: Int) -> String? {
        guard let departureTime = departureTime else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let time = formatter.date(from: departureTime) else { return nil }
        
        let arrivalTime = time.addingTimeInterval(TimeInterval(additionalMinutes * 60))
        return formatter.string(from: arrivalTime)
    }
    
    private func generateOptimizationSuggestions(
        waypoints: [RouteWaypoint],
        totalDuration: Int,
        maxDuration: Double?,
        travelMode: String
    ) -> [String] {
        var suggestions: [String] = []
        
        if let maxDuration = maxDuration, Double(totalDuration) > maxDuration {
            suggestions.append("总用时超出预期，建议减少部分景点或调整停留时间")
        }
        
        if travelMode == "walking" && totalDuration > 480 { // 8小时
            suggestions.append("步行时间较长，建议考虑公共交通或分多天完成")
        }
        
        if waypoints.count > 8 {
            suggestions.append("景点较多，建议按区域分组，分多天游览")
        }
        
        return suggestions
    }
    
    private func generateWarnings(
        totalDuration: Int,
        maxDuration: Double?,
        travelMode: String
    ) -> [String] {
        var warnings: [String] = []
        
        if totalDuration > 600 { // 10小时
            warnings.append("行程安排较满，注意休息时间")
        }
        
        if travelMode == "walking" {
            warnings.append("全程步行，请准备舒适的鞋子和充足的水")
        }
        
        return warnings
    }
    
    private func calculateEfficiencyScore(
        waypoints: [RouteWaypoint],
        segments: [RouteSegment],
        totalDuration: Int
    ) -> Double {
        // 简化的效率评分算法
        let totalStayTime = waypoints.map { $0.suggestedStayDuration }.reduce(0, +)
        _ = segments.map { $0.duration }.reduce(0, +)
        
        let stayRatio = Double(totalStayTime) / Double(totalDuration)
        let baseScore = stayRatio * 10 // 停留时间占比越高评分越高
        
        return min(10.0, max(1.0, baseScore))
    }
    
    private func generatePermutations<T>(_ array: [T]) -> [[T]] {
        guard array.count > 1 else { return [array] }
        
        var result: [[T]] = []
        for i in 0..<array.count {
            let current = array[i]
            let remaining = Array(array[0..<i] + array[(i+1)...])
            let perms = generatePermutations(remaining)
            for perm in perms {
                result.append([current] + perm)
            }
        }
        return result
    }
    
    private func calculateTotalRouteDistance(
        start: (Double, Double),
        locations: [(name: String, coordinate: (Double, Double))],
        travelMode: String
    ) async throws -> Double {
        var total: Double = 0
        var current = start
        
        for location in locations {
            total += calculateDistance(from: current, to: location.coordinate)
            current = location.coordinate
        }
        
        return total
    }
    
    private func nearestNeighborOptimization(
        start: (Double, Double),
        locations: [(name: String, coordinate: (Double, Double))],
        travelMode: String
    ) async throws -> [(name: String, coordinate: (Double, Double))] {
        
        var unvisited = locations
        var route: [(name: String, coordinate: (Double, Double))] = []
        var current = start
        
        while !unvisited.isEmpty {
            let nearest = unvisited.min { location1, location2 in
                let dist1 = calculateDistance(from: current, to: location1.coordinate)
                let dist2 = calculateDistance(from: current, to: location2.coordinate)
                return dist1 < dist2
            }!
            
            route.append(nearest)
            current = nearest.coordinate
            unvisited.removeAll { $0.name == nearest.name }
        }
        
        return route
    }
}

// MARK: - 数据模型

/// 路线规划结果
struct RoutePlan {
    let waypoints: [RouteWaypoint]
    let segments: [RouteSegment]
    let totalDistance: Double
    let totalDuration: Int
    let travelMode: String
    let efficiencyScore: Double
    let optimizationSuggestions: [String]
    let warnings: [String]
}

/// 路点信息
struct RouteWaypoint {
    let name: String
    let address: String
    let coordinate: (Double, Double)
    let suggestedStayDuration: Int // 分钟
    let estimatedArrivalTime: String?
    let tips: String?
}

/// 路线段信息
struct RouteSegment {
    let fromIndex: Int
    let toIndex: Int
    let distance: Double // 米
    let duration: Int // 分钟
    let transportMode: String
    let instructions: String
}

// 字符串扩展
extension String {
    func repeated(count: Int) -> String {
        return String(repeating: self, count: count)
    }
}
