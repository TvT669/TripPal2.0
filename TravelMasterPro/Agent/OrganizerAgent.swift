//
//  OrganizerAgent.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/12/24.
//

import Foundation
import CoreLocation

class OrganizerAgent: ObservableObject {
    private let llmService = LLMService()
    private let mapService: AMapService
    
    @Published var isProcessing = false
    @Published var progressMessage = ""
    
    init() {
        // 加载地图配置
        var mapConfig = MapConfiguration(amapWebKey: "", lang: "zh_cn", defaultCity: "北京")
        
        if let configPath = Bundle.main.path(forResource: "MapConfig", ofType: "plist"),
           let configDict = NSDictionary(contentsOfFile: configPath) as? [String: Any] {
            mapConfig = MapConfiguration(
                amapWebKey: configDict["amapWebKey"] as? String ?? "",
                lang: "zh_cn",
                defaultCity: "北京"
            )
        }
        
        self.mapService = AMapService(config: mapConfig)
    }
    
    private let systemPrompt = """
    你是一个专业的行程整理助手。用户的输入可能是一段混乱的旅行计划文本。
    你的任务是：
    1. 提取出所有的地点、时间（如果有）、以及简短的活动描述。
    2. 将结果以严格的 JSON 格式返回，不要包含任何 Markdown 标记或其他废话。
    
    JSON 格式示例：
    {
        "title": "长沙三日游",
        "nodes": [
            {
                "name": "岳麓书院",
                "description": "参观书院，感受千年学府",
                "time": "10:00" 
            }
        ]
    }
    """
    
    // 第一阶段：仅提取地点
    func extractPlaces(from text: String) async throws -> [ParsedPlace] {
        await MainActor.run {
            self.isProcessing = true
            self.progressMessage = "正在识别地点..."
        }
        
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        let prompt = """
        你是一个智能行程分析助手。请从文本中提取景点信息，并识别它们所属的天数。
        
        **提取规则**：
        1. 只提取明确的旅游景点、餐厅、地标（如"陈家祠"、"沙面岛"）。
        2. 排除：航班号、车次号、酒店名、时间、日期。
        3. 排除：交通工具、地铁站名（除非是知名地标）。
        
        **天数识别**：
        - 如果文本包含"第一天"、"Day 1"、"第二天"等标记，请识别每个景点所属的天数。
        - 如果无法识别天数，统一设置为 null。
        
        **输出格式**（严格JSON，无Markdown标记）：
        [
            {"name": "外滩", "context": "第一天：外滩看风景", "day": 1},
            {"name": "南京路", "context": "逛南京路", "day": 1},
            {"name": "豫园", "context": "第二天：豫园吃小笼包", "day": 2}
        ]
        
        待分析文本：
        \(text)
        """
        
        let messages = [Message(role: .user, content: prompt)]
        print("🤖 发送给 LLM 的 Prompt: \(prompt)")
        
        let content = try await llmService.chat(messages: messages)
        print("🤖 LLM 返回原始内容: \(content)")
        
        // 智能提取 JSON 部分 (查找第一个 [ 和最后一个 ])
        var jsonString = content
        if let startIndex = content.firstIndex(of: "["),
           let endIndex = content.lastIndex(of: "]") {
            jsonString = String(content[startIndex...endIndex])
        }
        
        // 清理可能残留的 markdown 和空白字符
        jsonString = jsonString.replacingOccurrences(of: "```json", with: "")
                               .replacingOccurrences(of: "```", with: "")
                               .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🧹 清理后的 JSON: \(jsonString)")
        
        guard let data = jsonString.data(using: .utf8) else {
            print("❌ 无法转换为 Data")
            return []
        }
        
        struct ExtractedItem: Codable {
            let name: String
            let context: String
            let day: Int?
        }
        
        do {
            let items = try JSONDecoder().decode([ExtractedItem].self, from: data)
            print("✅ 解析成功: \(items.count) 个地点")
            return items.map { ParsedPlace(name: $0.name, originalText: $0.context, day: $0.day) }
        } catch {
            print("❌ JSON 解析失败: \(error)")
            throw error
        }
    }
    
    // 第二阶段：生成最终行程
    func generatePlan(from places: [ParsedPlace]) async throws -> TripPlan {
        await MainActor.run {
            self.isProcessing = true
            self.progressMessage = "正在规划路线..."
        }
        
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        var tripNodes: [TripNode] = []
        var detectedCities: [String: Int] = [:] // 统计城市出现次数
        var targetCity: String? = nil // 目标城市（用于地理围栏）
        
        // 第一遍：快速扫描，确定主要城市
        for place in places {
            let cleanedName = cleanPlaceName(place.name)
            do {
                let pois = try await mapService.searchPOI(keyword: cleanedName)
                if let firstPOI = pois.first, let city = firstPOI.cityname, !city.isEmpty {
                    detectedCities[city, default: 0] += 1
                }
            } catch {
                // 忽略错误，继续下一个
            }
        }
        
        // 确定目标城市（出现最多的城市）
        if !detectedCities.isEmpty {
            let sortedCities = detectedCities.sorted { $0.value > $1.value }
            targetCity = sortedCities.first?.key
            print("🎯 检测到目标城市: \(targetCity ?? "未知")")
        }
        
        // 第二遍：使用城市限定搜索坐标
        for place in places {
            var coordinate = TripNode.Coordinate(latitude: 0, longitude: 0)
            
            // 第一层：清洗地点名称
            let cleanedName = cleanPlaceName(place.name)
            print("🧹 清洗地点名称: \(place.name) -> \(cleanedName)")
            
            do {
                // 第二层：加上地理偏好（城市限定）
                let pois = try await mapService.searchPOI(keyword: cleanedName, city: targetCity ?? "")
                if let firstPOI = pois.first {
                    let location = firstPOI.location
                    let parts = location.split(separator: ",")
                    if parts.count == 2,
                       let lng = Double(parts[0]),
                       let lat = Double(parts[1]) {
                        coordinate = TripNode.Coordinate(latitude: lat, longitude: lng)
                        print("✅ 找到坐标: \(cleanedName) -> (\(lat), \(lng))")
                    }
                } else {
                    print("⚠️ 未找到坐标: \(cleanedName)")
                }
            } catch {
                print("❌ 搜索失败: \(cleanedName) - \(error)")
            }
            
            // 使用 AI 识别的天数，如果没有则不分配天数
            let node = TripNode(
                name: cleanedName, // 使用清洗后的名称
                description: place.originalText,
                startTime: nil,
                day: place.day,
                coordinate: coordinate
            )
            tripNodes.append(node)
        }
        
        // 生成标题
        var title = "智能规划行程"
        if let city = targetCity {
            title = "\(city)行程"
        }
        
        return TripPlan(title: title, nodes: tripNodes)
    }
    
    // MARK: - 辅助方法：清洗地点名称
    private func cleanPlaceName(_ name: String) -> String {
        var cleaned = name
        
        // 移除常见前缀（早餐：、午餐：、晚餐：、上午：、下午：、傍晚：等）
        let prefixes = ["早餐：", "午餐：", "晚餐：", "上午：", "下午：", "傍晚：", "晚上：", "夜宵："]
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
        }
        
        // 移除括号及其内容（包括中英文括号）
        // 例如："荣华楼（百年茶楼）" -> "荣华楼"
        let patterns = [
            "\\（[^）]*\\）",  // 中文括号
            "\\([^)]*\\)",    // 英文括号
            "\\[[^\\]]*\\]",  // 方括号
            "【[^】]*】"       // 中文方括号
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(cleaned.startIndex..., in: cleaned)
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
            }
        }
        
        // 移除多余空白字符
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除常见的后缀描述
        let suffixes = [" - ", "—", " / "]
        for suffix in suffixes {
            if let range = cleaned.range(of: suffix) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
