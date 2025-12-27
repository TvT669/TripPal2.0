//
//  MemoryService.swift
//  TravelMasterPro
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/29.
//

import Foundation

/// 高级记忆服务 - 智能体的大脑
/// 提供智能上下文管理、会话记忆、知识存储等功能
class MemoryService: Memory {
    // 内部使用增强消息
    private var enhancedMessages: [EnhancedMessage] = []
    
    // 协议要求的属性 - 通过计算属性实现
    var messages: [Message] {
        return enhancedMessages.map { $0.message }
    }
    
    private var conversationSummaries: [ConversationSummary] = []
    private var knowledgeBase: [String: Any] = [:]
    private var userPreferences: [String: Any] = [:]
    
    // 配置参数
    private let maxMessageCount: Int
    private let maxConversationAge: TimeInterval
    private let summarizationThreshold: Int
    
    // 记忆优先级权重
    private let priorityWeights: MemoryPriorityWeights
    
    init(
        maxMessageCount: Int = 100,
        maxConversationAge: TimeInterval = 24 * 60 * 60, // 24小时
        summarizationThreshold: Int = 50,
        priorityWeights: MemoryPriorityWeights = .default
    ) {
        self.maxMessageCount = maxMessageCount
        self.maxConversationAge = maxConversationAge
        self.summarizationThreshold = summarizationThreshold
        self.priorityWeights = priorityWeights
    }
    
    // MARK: - Memory 协议实现
    
    func addMessage(_ message: Message) {
        // 创建增强消息包装器
        let enhancedMessage = EnhancedMessage(
            message: message,
            timestamp: Date(),
            importance: calculateImportance(for: message)
        )
        
        enhancedMessages.append(enhancedMessage)
        
        // 智能记忆管理
        manageMemoryIntelligently()
        
        // 更新知识库
        updateKnowledgeBase(from: message)
        
        // 学习用户偏好
        learnUserPreferences(from: message)
    }
    
    func getContext() -> String {
        let recentMessages = getRecentImportantMessages()
        let relevantSummaries = getRelevantSummaries()
        let contextualKnowledge = getContextualKnowledge()
        
        var context = ""
        
        // 1. 相关的历史摘要
        if !relevantSummaries.isEmpty {
            context += "📚 相关历史对话摘要：\n"
            for summary in relevantSummaries {
                context += "• \(summary.summary)\n"
            }
            context += "\n"
        }
        
        // 2. 用户偏好和上下文知识
        if !contextualKnowledge.isEmpty {
            context += "🧠 相关背景知识：\n\(contextualKnowledge)\n\n"
        }
        
        // 3. 最近的重要对话
        context += "💬 当前对话上下文：\n"
        context += recentMessages.map { formatMessage($0) }.joined(separator: "\n\n")
        
        return context
    }
    
    func clear() {
        // 保留系统消息和重要摘要
        let systemMessages = enhancedMessages.filter { $0.message.role == .system }
        let importantSummaries = conversationSummaries.filter { $0.importance > 0.7 }
        
        enhancedMessages = systemMessages
        conversationSummaries = importantSummaries
        
        // 保留长期知识库和用户偏好
        // knowledgeBase 和 userPreferences 不清除
    }
    
    // MARK: - 扩展接口（MemoryService 特有功能）
    
    /// 获取增强消息列表（包含时间戳和重要性）
    func getEnhancedMessages() -> [EnhancedMessage] {
        return enhancedMessages
    }
    
    /// 获取指定时间范围内的消息
    func getMessages(from startDate: Date, to endDate: Date) -> [EnhancedMessage] {
        return enhancedMessages.filter { message in
            message.timestamp >= startDate && message.timestamp <= endDate
        }
    }
    
    /// 获取高重要性消息
    func getImportantMessages(threshold: Double = 0.7) -> [EnhancedMessage] {
        return enhancedMessages.filter { $0.importance >= threshold }
    }
    
    /// 获取用户偏好摘要
    func getUserPreferencesSummary() -> String {
        guard !userPreferences.isEmpty else {
            return "暂无用户偏好数据"
        }
        
        var summary = "🎯 用户偏好概览：\n"
        
        if let travelStyle = userPreferences["travel_style"] as? String {
            summary += "• 旅行方式：\(travelStyle)\n"
        }
        
        if let budgetPreference = userPreferences["budget_preference"] as? String {
            summary += "• 预算偏好：\(budgetPreference)\n"
        }
        
        if let interests = userPreferences["interests"] as? [String], !interests.isEmpty {
            summary += "• 兴趣爱好：\(interests.joined(separator: "、"))\n"
        }
        
        return summary
    }
    
    /// 获取知识库摘要
    func getKnowledgeBaseSummary() -> String {
        guard !knowledgeBase.isEmpty else {
            return "暂无知识库数据"
        }
        
        var summary = "🧠 知识库概览：\n"
        
        if let destinations = knowledgeBase["frequent_destinations"] as? [String], !destinations.isEmpty {
            summary += "• 常访问目的地：\(destinations.joined(separator: "、"))\n"
        }
        
        if let budgetRange = knowledgeBase["typical_budget_range"] as? String {
            summary += "• 典型预算范围：\(budgetRange)\n"
        }
        
        if let timePreference = knowledgeBase["preferred_travel_time"] as? String {
            summary += "• 偏好旅行时间：\(timePreference)\n"
        }
        
        return summary
    }
    
    // MARK: - 智能记忆管理
    
    private func manageMemoryIntelligently() {
        // 1. 检查是否需要总结
        if shouldSummarizeConversation() {
            summarizeOldConversation()
        }
        
        // 2. 清理过期记忆
        cleanupExpiredMemories()
        
        // 3. 智能压缩
        if enhancedMessages.count > maxMessageCount {
            compressMemoryIntelligently()
        }
    }
    
    private func shouldSummarizeConversation() -> Bool {
        let nonSystemMessages = enhancedMessages.filter { $0.message.role != .system }
        return nonSystemMessages.count >= summarizationThreshold
    }
    
    private func summarizeOldConversation() {
        let nonSystemMessages = enhancedMessages.filter { $0.message.role != .system }
        let messagesToSummarize = Array(nonSystemMessages.prefix(summarizationThreshold / 2))
        
        if !messagesToSummarize.isEmpty {
            let summary = createConversationSummary(from: messagesToSummarize)
            conversationSummaries.append(summary)
            
            // 移除已总结的消息（保留最近的一些作为连接）
            let systemMessages = enhancedMessages.filter { $0.message.role == .system }
            let recentMessages = Array(nonSystemMessages.suffix(summarizationThreshold / 2))
            enhancedMessages = systemMessages + recentMessages
        }
    }
    
    private func createConversationSummary(from messages: [EnhancedMessage]) -> ConversationSummary {
        let userMessages = messages.filter { $0.message.role == .user }
        let assistantMessages = messages.filter { $0.message.role == .assistant }
        
        // 提取关键信息
        let topics = extractTopics(from: messages)
        let decisions = extractDecisions(from: messages)
        let preferences = extractPreferences(from: messages)
        
        // 计算重要性
        let importance = calculateSummaryImportance(
            topics: topics,
            decisions: decisions,
            messageCount: messages.count
        )
        
        let summary = """
        话题：\(topics.joined(separator: "、"))
        主要决策：\(decisions.joined(separator: "；"))
        用户偏好：\(preferences.joined(separator: "、"))
        """
        
        return ConversationSummary(
            id: UUID(),
            timestamp: Date(),
            summary: summary,
            topics: topics,
            importance: importance,
            messageCount: messages.count
        )
    }
    
    private func compressMemoryIntelligently() {
        // 按重要性和时间排序
        let sortedMessages = enhancedMessages.sorted { msg1, msg2 in
            let score1 = calculateRetentionScore(for: msg1)
            let score2 = calculateRetentionScore(for: msg2)
            return score1 > score2
        }
        
        // 保留最重要的消息
        let retainCount = Int(Double(maxMessageCount) * 0.8) // 保留80%的空间
        enhancedMessages = Array(sortedMessages.prefix(retainCount))
        
        // 确保系统消息始终保留
        let systemMessages = enhancedMessages.filter { $0.message.role == .system }
        let nonSystemMessages = enhancedMessages.filter { $0.message.role != .system }
        enhancedMessages = systemMessages + Array(nonSystemMessages.prefix(retainCount - systemMessages.count))
    }
    
    // MARK: - 智能检索和推荐
    
    private func getRecentImportantMessages() -> [EnhancedMessage] {
        let cutoffDate = Date().addingTimeInterval(-maxConversationAge)
        let recentMessages = enhancedMessages.filter { 
            $0.timestamp > cutoffDate 
        }
        
        // 按重要性和时间排序
        return recentMessages.sorted { msg1, msg2 in
            let score1 = calculateRetentionScore(for: msg1)
            let score2 = calculateRetentionScore(for: msg2)
            return score1 > score2
        }.prefix(20).map { $0 } // 最多返回20条消息
    }
    
    private func getRelevantSummaries() -> [ConversationSummary] {
        // 获取最近的重要摘要
        return conversationSummaries
            .filter { $0.importance > 0.5 }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(3)
            .map { $0 }
    }
    
    private func getContextualKnowledge() -> String {
        var knowledge: [String] = []
        
        // 用户偏好
        if let travelStyle = userPreferences["travel_style"] as? String {
            knowledge.append("用户偏好旅行方式：\(travelStyle)")
        }
        if let budgetRange = userPreferences["budget_range"] as? String {
            knowledge.append("用户预算范围：\(budgetRange)")
        }
        if let interests = userPreferences["interests"] as? [String], !interests.isEmpty {
            knowledge.append("用户兴趣：\(interests.joined(separator: "、"))")
        }
        
        // 常用目的地
        if let frequentDestinations = knowledgeBase["frequent_destinations"] as? [String], !frequentDestinations.isEmpty {
            knowledge.append("常去目的地：\(frequentDestinations.joined(separator: "、"))")
        }
        
        return knowledge.joined(separator: "；")
    }
    
    // MARK: - 知识学习和更新
    
    private func updateKnowledgeBase(from message: Message) {
        let content = message.content.lowercased()
        
        // 提取目的地信息
        extractAndStoreDestinations(from: content)
        
        // 提取预算信息
        extractAndStoreBudgetInfo(from: content)
        
        // 提取时间偏好
        extractAndStoreTimePreferences(from: content)
    }
    
    private func learnUserPreferences(from message: Message) {
        guard message.role == .user else { return }
        
        let content = message.content.lowercased()
        
        // 学习旅行风格偏好
        if content.contains("自由行") || content.contains("自助游") {
            userPreferences["travel_style"] = "自由行"
        } else if content.contains("跟团") || content.contains("团队游") {
            userPreferences["travel_style"] = "跟团游"
        }
        
        // 学习预算偏好
        if content.contains("经济") || content.contains("便宜") || content.contains("省钱") {
            userPreferences["budget_preference"] = "经济型"
        } else if content.contains("豪华") || content.contains("高端") {
            userPreferences["budget_preference"] = "豪华型"
        }
        
        // 学习兴趣点
        var interests: [String] = userPreferences["interests"] as? [String] ?? []
        
        let interestKeywords = [
            "美食": ["美食", "餐厅", "小吃", "特色菜"],
            "历史": ["历史", "文化", "古迹", "博物馆"],
            "自然": ["自然", "风景", "山水", "海滩"],
            "购物": ["购物", "商场", "特产", "纪念品"],
            "娱乐": ["娱乐", "夜生活", "酒吧", "表演"]
        ]
        
        for (interest, keywords) in interestKeywords {
            if keywords.contains(where: { content.contains($0) }) {
                if !interests.contains(interest) {
                    interests.append(interest)
                }
            }
        }
        
        userPreferences["interests"] = interests
    }
    
    // MARK: - 评分和重要性计算
    
    private func calculateImportance(for message: Message) -> Double {
        var importance: Double = 0.5 // 基础重要性
        
        let content = message.content.lowercased()
        
        // 角色权重
        switch message.role {
        case .system:
            importance += priorityWeights.systemMessage
        case .user:
            importance += priorityWeights.userMessage
        case .assistant:
            importance += priorityWeights.assistantMessage
        @unknown default:
            importance += 0.3
        }
        
        // 内容重要性
        if content.contains("预订") || content.contains("确认") {
            importance += priorityWeights.actionMessage
        }
        
        if content.contains("重要") || content.contains("注意") {
            importance += priorityWeights.importantContent
        }
        
        if content.contains("偏好") || content.contains("喜欢") {
            importance += priorityWeights.preferenceMessage
        }
        
        // 长度权重（更长的消息通常更重要）
        let lengthBonus = min(Double(content.count) / 1000.0, 0.2)
        importance += lengthBonus
        
        return min(importance, 1.0)
    }
    
    private func calculateRetentionScore(for message: EnhancedMessage) -> Double {
        let importance = message.importance
        let age = Date().timeIntervalSince(message.timestamp)
        let maxAge = maxConversationAge
        
        // 时间衰减因子
        let timeFactor = max(0, 1 - (age / maxAge))
        
        return importance * 0.7 + timeFactor * 0.3
    }
    
    private func calculateSummaryImportance(topics: [String], decisions: [String], messageCount: Int) -> Double {
        var importance: Double = 0.5
        
        // 话题数量
        importance += min(Double(topics.count) * 0.1, 0.3)
        
        // 决策数量
        importance += min(Double(decisions.count) * 0.15, 0.4)
        
        // 消息数量
        importance += min(Double(messageCount) * 0.01, 0.2)
        
        return min(importance, 1.0)
    }
    
    // MARK: - 辅助方法
    
    private func cleanupExpiredMemories() {
        let cutoffDate = Date().addingTimeInterval(-maxConversationAge * 2) // 保留更长时间的摘要
        conversationSummaries.removeAll { $0.timestamp < cutoffDate }
    }
    
    private func formatMessage(_ message: EnhancedMessage) -> String {
        let roleEmoji = message.message.role == .user ? "👤" : "🤖"
        let importanceIndicator = message.importance > 0.7 ? "⭐" : ""
        
        return "\(roleEmoji)\(importanceIndicator) \(message.message.role.rawValue): \(message.message.content)"
    }
    
    private func extractTopics(from messages: [EnhancedMessage]) -> [String] {
        // 简化的主题提取（实际可以使用NLP技术）
        var topics: Set<String> = []
        
        for message in messages {
            let content = message.message.content.lowercased()
            
            if content.contains("航班") || content.contains("机票") {
                topics.insert("航班预订")
            }
            if content.contains("酒店") || content.contains("住宿") {
                topics.insert("住宿安排")
            }
            if content.contains("路线") || content.contains("景点") {
                topics.insert("行程规划")
            }
            if content.contains("预算") || content.contains("费用") {
                topics.insert("预算管理")
            }
        }
        
        return Array(topics)
    }
    
    private func extractDecisions(from messages: [EnhancedMessage]) -> [String] {
        var decisions: [String] = []
        
        for message in messages {
            let content = message.message.content
            
            if content.contains("决定") || content.contains("选择") {
                // 提取决策内容（简化实现）
                decisions.append(String(content.prefix(100)) + "...")
            }
        }
        
        return decisions
    }
    
    private func extractPreferences(from messages: [EnhancedMessage]) -> [String] {
        var preferences: [String] = []
        
        for message in messages where message.message.role == .user {
            let content = message.message.content.lowercased()
            
            if content.contains("喜欢") || content.contains("偏好") {
                // 提取偏好内容（简化实现）
                preferences.append(String(content.prefix(50)) + "...")
            }
        }
        
        return preferences
    }
    
    private func extractAndStoreDestinations(from content: String) {
        // 简化的目的地提取
        let destinations = ["北京", "上海", "广州", "深圳", "杭州", "成都", "西安", "重庆"]
        var found: [String] = knowledgeBase["frequent_destinations"] as? [String] ?? []
        
        for destination in destinations {
            if content.contains(destination) && !found.contains(destination) {
                found.append(destination)
            }
        }
        
        knowledgeBase["frequent_destinations"] = found
    }
    
    private func extractAndStoreBudgetInfo(from content: String) {
        // 提取预算信息
        if content.contains("预算") {
            // 使用正则表达式提取数字和预算范围
            // 这里简化处理
            if content.contains("万") {
                knowledgeBase["typical_budget_range"] = "高端"
            } else if content.contains("千") {
                knowledgeBase["typical_budget_range"] = "中等"
            }
        }
    }
    
    private func extractAndStoreTimePreferences(from content: String) {
        if content.contains("周末") {
            knowledgeBase["preferred_travel_time"] = "周末"
        } else if content.contains("假期") {
            knowledgeBase["preferred_travel_time"] = "长假期"
        }
    }
}

// MARK: - 增强消息包装器

/// 增强消息包装器 - 包含原始消息及其元数据
struct EnhancedMessage {
    let message: Message
    let timestamp: Date
    let importance: Double
    
    init(message: Message, timestamp: Date, importance: Double) {
        self.message = message
        self.timestamp = timestamp
        self.importance = importance
    }
}

// MARK: - 数据模型

/// 对话摘要
struct ConversationSummary: Codable {
    let id: UUID
    let timestamp: Date
    let summary: String
    let topics: [String]
    let importance: Double
    let messageCount: Int
}

/// 记忆优先级权重配置
struct MemoryPriorityWeights {
    let systemMessage: Double
    let userMessage: Double
    let assistantMessage: Double
    let actionMessage: Double
    let importantContent: Double
    let preferenceMessage: Double
    
    static let `default` = MemoryPriorityWeights(
        systemMessage: 0.8,
        userMessage: 0.6,
        assistantMessage: 0.4,
        actionMessage: 0.3,
        importantContent: 0.3,
        preferenceMessage: 0.2
    )
}