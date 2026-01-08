//
//  IntentRouter.swift
//  TravelMasterPro
//
//  Created by AI Assistant on 2026/1/8.
//

import Foundation

/// 用户意图类型
enum UserIntent {
    case complexPlanning    // 复杂规划：需要多智能体协作
    case singleQuery        // 单一查询：只需调用一个工具或智能体
    case casualChat         // 闲聊：直接 LLM 回复
    
    var description: String {
        switch self {
        case .complexPlanning: return "复杂旅行规划"
        case .singleQuery: return "单一查询"
        case .casualChat: return "日常对话"
        }
    }
}

/// 意图路由器 - 负责判断用户请求应该走哪条执行路径
class IntentRouter {
    private let llm: LLMService
    
    init(llm: LLMService) {
        self.llm = llm
    }
    
    /// 分析用户意图
    func classifyIntent(_ userInput: String) async -> UserIntent {
        // 快速模式匹配（性能优化：避免每次都调 LLM）
        if let quickIntent = quickClassify(userInput) {
            return quickIntent
        }
        
        // 复杂情况下使用 LLM 进行意图分类
        return await llmClassify(userInput)
    }
    
    // MARK: - 快速分类（基于规则）
    
    private func quickClassify(_ input: String) -> UserIntent? {
        let lowercased = input.lowercased()
        
        // 1. 明确的规划关键词
        let planningKeywords = ["规划", "计划", "行程", "帮我安排", "制定方案", "去旅游", "几天游"]
        if planningKeywords.contains(where: { lowercased.contains($0) }) {
            return .complexPlanning
        }
        
        // 2. 单一查询关键词
        let singleQueryKeywords = ["查", "搜索", "找", "推荐", "有哪些", "多少钱"]
        let singleTopics = ["机票", "航班", "酒店", "景点", "路线", "预算"]
        
        if singleQueryKeywords.contains(where: { lowercased.contains($0) }) &&
           singleTopics.contains(where: { lowercased.contains($0) }) {
            return .singleQuery
        }
        
        // 3. 闲聊关键词
        let chatKeywords = ["你好", "谢谢", "再见", "怎么样", "是什么", "为什么", "天气"]
        if chatKeywords.contains(where: { lowercased.contains($0) }) {
            return .casualChat
        }
        
        // 4. 如果输入很短（少于 10 个字），大概率是闲聊
        if input.count < 10 {
            return .casualChat
        }
        
        return nil // 无法快速判断，交给 LLM
    }
    
    // MARK: - LLM 分类（更精准但慢）
    
    private func llmClassify(_ input: String) async -> UserIntent {
        let prompt = """
        你是一个意图分类专家。请判断用户的以下输入属于哪种意图类型：
        
        用户输入：\(input)
        
        意图类型：
        1. complex_planning - 用户需要完整的旅行规划方案（涉及多个环节：交通、住宿、行程、预算等）
           例如："帮我规划一次长沙3日游"、"我想去北京玩，帮我安排行程"
        
        2. single_query - 用户只想查询单一信息或使用单一功能
           例如："查一下北京到上海的机票"、"推荐几个长沙的酒店"、"去岳麓山怎么走"
        
        3. casual_chat - 闲聊或简单问答，不涉及具体的旅行任务
           例如："你好"、"今天天气怎么样"、"你能做什么"
        
        请只返回以下三个词之一：complex_planning、single_query、casual_chat
        """
        
        do {
            let response = try await llm.chat(messages: [Message.userMessage(prompt)])
            let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            if cleaned.contains("complex_planning") {
                return .complexPlanning
            } else if cleaned.contains("single_query") {
                return .singleQuery
            } else {
                return .casualChat
            }
        } catch {
            print("⚠️ 意图分类失败，默认为闲聊: \(error)")
            return .casualChat // 失败时降级为闲聊
        }
    }
}
